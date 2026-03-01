package com.dcamera.demo

interface PreviewDisplayPort {
    fun startPreview(): Boolean
    fun stopPreview(): Boolean
}

class NoOpPreviewDisplayPort : PreviewDisplayPort {
    override fun startPreview(): Boolean = true
    override fun stopPreview(): Boolean = true
}
