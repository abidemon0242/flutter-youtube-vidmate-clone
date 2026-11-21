package com.tubearena.app

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs the activity to share its FlutterEngine with the
// background media service, which is what AudioServiceActivity provides.
class MainActivity : AudioServiceActivity()
