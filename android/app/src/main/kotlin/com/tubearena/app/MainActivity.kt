package com.tubearena.app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val exportChannel = "com.tubearena.app/media_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "exportMedia" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val destination = call.argument<String>("destination")
                        if (sourcePath.isNullOrBlank() ||
                            (destination != "Music" && destination != "Movies")) {
                            result.error("INVALID_ARGUMENT", "A valid source and destination are required.", null)
                        } else {
                            try {
                                result.success(exportMedia(File(sourcePath), destination))
                            } catch (error: Exception) {
                                result.error("EXPORT_FAILED", error.message ?: "Could not export media.", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun exportMedia(source: File, destination: String): String {
        if (!source.isFile || !source.canRead()) {
            throw IOException("The source file cannot be read.")
        }

        val extension = source.extension.lowercase()
        val mimeType = MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(extension)
            ?: if (destination == "Music") "audio/webm" else "video/webm"
        val collection: Uri = if (destination == "Music") {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
        var displayName = source.name
        var suffix = 2
        while (resolverQuery(collection, projection, displayName)) {
            val dot = source.name.lastIndexOf('.')
            val base = if (dot > 0) source.name.substring(0, dot) else source.name
            val ext = if (dot > 0) source.name.substring(dot) else ""
            displayName = base + " (" + suffix + ")" + ext
            suffix++
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${destination}/Tube Arena"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            } else {
                val directory = File(
                    Environment.getExternalStoragePublicDirectory(
                        if (destination == "Music") Environment.DIRECTORY_MUSIC
                        else Environment.DIRECTORY_MOVIES
                    ),
                    "Tube Arena"
                )
                if (!directory.exists() && !directory.mkdirs()) {
                    throw IOException("Could not create the public media folder.")
                }
                put(MediaStore.MediaColumns.DATA, File(directory, source.name).absolutePath)
            }
        }

        val resolver = contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw IOException("Android could not create the destination media entry.")

        try {
            val output = resolver.openOutputStream(uri, "w")
                ?: throw IOException("Android could not open the destination file.")
            output.use { stream ->
                FileInputStream(source).use { input -> input.copyTo(stream) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val completed = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, completed, null, null)
            } else {
                MediaScannerConnection.scanFile(
                    this,
                    arrayOf(uriToPath(uri) ?: ""),
                    arrayOf(mimeType),
                    null
                )
            }
            return displayName
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun resolverQuery(
        collection: Uri,
        projection: Array<String>,
        displayName: String
    ): Boolean {
        contentResolver.query(
            collection,
            projection,
            "display_name = ?",
            arrayOf(displayName),
            null
        )?.use { cursor ->
            return cursor.moveToFirst()
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun uriToPath(uri: Uri): String? {
        val projection = arrayOf(MediaStore.MediaColumns.DATA)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return null
    }
}
