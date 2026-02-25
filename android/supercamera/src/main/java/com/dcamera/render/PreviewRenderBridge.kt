package com.dcamera.render

class PreviewRenderBridge {
    private var surfaceAttached: Boolean = false
    private var frameCounter: Long = 0

    fun attachSurface(surfaceHandle: Long): Boolean {
        if (surfaceHandle == 0L) return false
        surfaceAttached = true
        frameCounter = 0
        return true
    }

    fun detachSurface() {
        surfaceAttached = false
    }

    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean {
        if (!surfaceAttached || frameHandle == 0L || tsNs < 0) return false
        frameCounter++
        // TODO: real implementation forwards the frame to native render pipeline.
        return true
    }

    fun frameCount(): Long = frameCounter
}
