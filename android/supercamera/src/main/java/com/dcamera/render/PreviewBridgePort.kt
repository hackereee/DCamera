package com.dcamera.render

interface PreviewBridgePort {
    fun attachSurface(surfaceHandle: Long): Boolean
    fun detachSurface()
    fun submitFrame(frame: PreviewFrame): Boolean
}
