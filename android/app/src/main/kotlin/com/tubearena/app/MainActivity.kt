package com.tubearena.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// audio_service needs the activity to share its FlutterEngine with the
// background media service, which is what AudioServiceActivity provides.
// That engine outlives the activity, so the channels below only use the
// application context and keep working while downloads run in the background.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        StorageChannel.register(applicationContext, messenger)
        DownloadNotifications.register(applicationContext, messenger)
    }
}
