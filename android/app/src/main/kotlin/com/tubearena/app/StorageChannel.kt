package com.tubearena.app

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Free space (StatFs) and "Save to phone" (MediaStore) for the Dart side. */
object StorageChannel {
    private const val CHANNEL = "com.tubearena.app/storage"
    private const val FOLDER = "Tube Arena"

    fun register(context: Context, messenger: BinaryMessenger) {
        val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "freeBytes" -> {
                    try {
                        val path = call.argument<String>("path") ?: context.filesDir.path
                        var dir = File(path)
                        while (!dir.exists() && dir.parentFile != null) dir = dir.parentFile!!
                        result.success(StatFs(dir.path).availableBytes)
                    } catch (e: Exception) {
                        result.error("STATFS", e.message, null)
                    }
                }
                "saveToPublic" -> {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name")
                    val mimeType = call.argument<String>("mimeType") ?: "video/*"
                    val audio = call.argument<Boolean>("audio") ?: false
                    if (path == null || name == null) {
                        result.error("ARGS", "path and name are required", null)
                        return@setMethodCallHandler
                    }
                    // Copying can take a while for large videos; keep it off the main thread.
                    Thread {
                        try {
                            val saved = saveToPublic(context, File(path), name, mimeType, audio)
                            main.post { result.success(saved) }
                        } catch (e: Exception) {
                            main.post { result.error("SAVE", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToPublic(context: Context, source: File, name: String, mimeType: String, audio: Boolean): String {
        if (!source.exists()) throw IOException("Source file is missing")
        val directory = if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val collection = if (audio) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$directory/$FOLDER")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values) ?: throw IOException("MediaStore insert failed")
            try {
                val output = resolver.openOutputStream(uri) ?: throw IOException("Cannot open output")
                output.use { out -> FileInputStream(source).use { input -> input.copyTo(out) } }
                val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                if (resolver.update(uri, done, null, null) != 1) {
                    throw IOException("MediaStore could not publish the saved media.")
                }
            } catch (e: Exception) {
                // Remove the pending row so a failed save cannot leave an
                // invisible, orphaned MediaStore item behind.
                try {
                    resolver.delete(uri, null, null)
                } catch (cleanupError: Exception) {
                    e.addSuppressed(cleanupError)
                }
                throw e
            }
            return uri.toString()
        }

        // Android 9 and older: write to the public folder directly (needs
        // WRITE_EXTERNAL_STORAGE, requested by the Dart side) and index it.
        @Suppress("DEPRECATION")
        val folder = File(Environment.getExternalStoragePublicDirectory(directory), FOLDER)
        if (!folder.exists() && !folder.mkdirs()) throw IOException("Cannot create $folder")
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var target = File(folder, name)
        var n = 2
        while (target.exists()) {
            target = File(folder, "$base ($n)$ext")
            n++
        }
        try {
            FileInputStream(source).use { input -> FileOutputStream(target).use { out -> input.copyTo(out) } }
            val scanFinished = CountDownLatch(1)
            val scannedUri = AtomicReference<Uri?>(null)
            MediaScannerConnection.scanFile(context, arrayOf(target.path), arrayOf(mimeType)) { _, uri ->
                scannedUri.set(uri)
                scanFinished.countDown()
            }
            if (!scanFinished.await(15, TimeUnit.SECONDS) || scannedUri.get() == null) {
                throw IOException("The saved file could not be indexed by Android Media Scanner.")
            }
            return target.path
        } catch (e: Exception) {
            // A failed or unindexed copy should not be reported as a success.
            if (target.exists()) target.delete()
            throw e
        }
    }
}
