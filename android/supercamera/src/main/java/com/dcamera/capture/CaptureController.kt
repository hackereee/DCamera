package com.dcamera.capture

data class CaptureResult(val path: String)

class CaptureController {
    fun takePhoto(outputPath: String): CaptureResult = CaptureResult(outputPath)
}
