package com.tubearena.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Ongoing download progress (via [DownloadService]) and completion notifications. */
object DownloadNotifications {
    private const val CHANNEL = "com.tubearena.app/download_notifications"
    private const val PROGRESS_CHANNEL_ID = "downloads_progress"
    private const val RESULT_CHANNEL_ID = "downloads_result"
    const val PROGRESS_NOTIFICATION_ID = 4101

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "showProgress" -> {
                        showProgress(
                            context,
                            call.argument<String>("title") ?: "Downloading",
                            call.argument<String>("text") ?: "",
                            call.argument<Int>("percent") ?: -1,
                        )
                        result.success(null)
                    }
                    "stopProgress" -> {
                        context.stopService(Intent(context, DownloadService::class.java))
                        manager(context).cancel(PROGRESS_NOTIFICATION_ID)
                        result.success(null)
                    }
                    "showResult" -> {
                        showResult(
                            context,
                            call.argument<String>("id") ?: "",
                            call.argument<String>("title") ?: "",
                            call.argument<Boolean>("success") ?: true,
                            call.argument<String>("message"),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NOTIFY", e.message, null)
            }
        }
    }

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = manager(context)
        manager.createNotificationChannel(
            NotificationChannel(PROGRESS_CHANNEL_ID, "Download progress", NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(RESULT_CHANNEL_ID, "Finished downloads", NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    private fun builder(context: Context, channelId: String): Notification.Builder {
        ensureChannels(context)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
    }

    private fun openAppIntent(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun buildProgress(context: Context, title: String, text: String, percent: Int): Notification =
        builder(context, PROGRESS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setProgress(100, percent.coerceIn(0, 100), percent < 0)
            .setContentIntent(openAppIntent(context))
            .build()

    private fun showProgress(context: Context, title: String, text: String, percent: Int) {
        if (DownloadService.running) {
            manager(context).notify(PROGRESS_NOTIFICATION_ID, buildProgress(context, title, text, percent))
            return
        }
        val intent = Intent(context, DownloadService::class.java)
            .putExtra("title", title)
            .putExtra("text", text)
            .putExtra("percent", percent)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            // Android 12+ refuses to start a foreground service from the
            // background; show a plain notification instead.
            manager(context).notify(PROGRESS_NOTIFICATION_ID, buildProgress(context, title, text, percent))
        }
    }

    private fun showResult(context: Context, id: String, title: String, success: Boolean, message: String?) {
        val notification = builder(context, RESULT_CHANNEL_ID)
            .setSmallIcon(if (success) android.R.drawable.stat_sys_download_done else android.R.drawable.stat_notify_error)
            .setContentTitle(if (success) "Download complete" else "Download failed")
            .setContentText(if (message.isNullOrBlank() || success) title else "$title: $message")
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(context))
            .build()
        manager(context).notify(id.hashCode() and 0x7fffffff, notification)
    }
}

/**
 * A dataSync foreground service that keeps the process alive while downloads
 * run in Dart. It does no work itself; Dart updates its notification.
 */
class DownloadService : Service() {
    companion object {
        @Volatile
        var running = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        // Enter the foreground right away so a quick stop can never race it.
        goForeground(DownloadNotifications.buildProgress(this, "Downloading", "", -1))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground(
            DownloadNotifications.buildProgress(
                this,
                intent?.getStringExtra("title") ?: "Downloading",
                intent?.getStringExtra("text") ?: "",
                intent?.getIntExtra("percent", -1) ?: -1,
            ),
        )
        // If Android kills the process, Dart is gone too; don't restart empty.
        return START_NOT_STICKY
    }

    private fun goForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                DownloadNotifications.PROGRESS_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(DownloadNotifications.PROGRESS_NOTIFICATION_ID, notification)
        }
    }

    // Android 15 limits dataSync services to 6 hours a day.
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }
}
