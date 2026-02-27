package com.dcamera.core

import com.dcamera.capture.CaptureController
import com.dcamera.capture.CaptureResult
import com.dcamera.render.PreviewFrame

interface PreviewSessionPort {
    fun setFrameConsumer(consumer: (PreviewFrame) -> Unit)
    fun startPreview(surfaceHandle: Long): Boolean
    fun stopPreview(): Boolean
}

interface PhotoCapturePort {
    fun capture(outputPath: String): CaptureResult
}

class NoOpPreviewSessionPort : PreviewSessionPort {
    override fun setFrameConsumer(consumer: (PreviewFrame) -> Unit) {}
    override fun startPreview(surfaceHandle: Long): Boolean = surfaceHandle != 0L
    override fun stopPreview(): Boolean = true
}

class CaptureControllerAdapter(
    private val controller: CaptureController = CaptureController(),
) : PhotoCapturePort {
    override fun capture(outputPath: String): CaptureResult = controller.takePhoto(outputPath)
}
