package com.dcamera.render

class PreviewRenderBridge {
    fun attachSurface(surfaceHandle: Long): Boolean = surfaceHandle != 0L
    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean = frameHandle != 0L && tsNs >= 0
}
