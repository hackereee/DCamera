package com.dcamera.render

interface RenderPipelinePort {
    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean
}

class NoOpRenderPipelinePort : RenderPipelinePort {
    override fun submitFrame(frameHandle: Long, tsNs: Long): Boolean = true
}
