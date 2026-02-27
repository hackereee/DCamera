package com.dcamera.camera2

import com.dcamera.render.PreviewFrame

interface Camera2Facade {
    fun start(surfaceHandle: Long, onFrame: (PreviewFrame) -> Unit): Boolean
    fun stop(): Boolean
}
