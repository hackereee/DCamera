package com.dcamera.render

class PreviewRenderBridge(
    private val renderPipeline: RenderPipelinePort = NoOpRenderPipelinePort(),
) : PreviewBridgePort {
    private var surfaceAttached: Boolean = false
    private var frameCounter: Long = 0

    override fun attachSurface(surfaceHandle: Long): Boolean {
        if (surfaceHandle == 0L) return false
        surfaceAttached = true
        frameCounter = 0
        return true
    }

    override fun detachSurface() {
        surfaceAttached = false
    }

    fun submitFrame(frame: PreviewFrame): Boolean {
        if (!surfaceAttached) return false
        if (frame.width <= 0 || frame.height <= 0) return false
        if (frame.timestampNs < 0) return false
        if (!renderPipeline.submitFrame(frame)) return false
        frameCounter++
        return true
    }

    fun frameCount(): Long = frameCounter
}
