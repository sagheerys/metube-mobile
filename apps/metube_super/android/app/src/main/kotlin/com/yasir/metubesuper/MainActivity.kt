package com.yasir.metubesuper

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service يشترط هذه القاعدة بدل FlutterActivity ليصل إشعار
// الوسائط وأزرار شاشة القفل إلى المشغل (م-21).
class MainActivity : AudioServiceActivity()
