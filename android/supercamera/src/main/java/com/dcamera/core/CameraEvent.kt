package com.dcamera.core

import com.dcamera.ErrorCode

enum class CameraEvent {
    PREVIEW_STARTED,
    PREVIEW_STOPPED,
    CAPTURE_COMPLETED,
    RECORDING_STARTED,
    RECORDING_STOPPED,
}

interface ErrorCallback {
    fun onError(code: ErrorCode, message: String)
}
