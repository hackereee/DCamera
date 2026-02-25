package com.dcamera.ui

class BasicCameraView {
    private var recording = false
    fun onRecordTapped() { recording = !recording }
    fun recordingBadgeText(): String = if (recording) "REC" else ""
}
