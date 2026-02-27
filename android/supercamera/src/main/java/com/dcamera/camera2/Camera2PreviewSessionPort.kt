package com.dcamera.camera2

import com.dcamera.core.PreviewSessionPort
import com.dcamera.render.PreviewFrame

class Camera2PreviewSessionPort(
    private val facade: Camera2Facade,
) : PreviewSessionPort {

    private var frameConsumer: ((PreviewFrame) -> Unit)? = null

    override fun setFrameConsumer(consumer: (PreviewFrame) -> Unit) {
        frameConsumer = consumer
    }

    override fun startPreview(surfaceHandle: Long): Boolean {
        val consumer = frameConsumer ?: return false
        return facade.start(surfaceHandle) { frame -> consumer(frame) }
    }

    override fun stopPreview(): Boolean {
        return facade.stop()
    }
}
