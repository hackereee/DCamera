package com.dcamera.render

interface PreviewBridgePort {
    fun attachSurface(surfaceHandle: Long): Boolean
    fun detachSurface()
}
