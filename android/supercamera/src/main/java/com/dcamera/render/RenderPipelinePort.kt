package com.dcamera.render

interface RenderPipelinePort {
    fun submitFrame(frame: PreviewFrame): Boolean
}

class NoOpRenderPipelinePort : RenderPipelinePort {
    override fun submitFrame(frame: PreviewFrame): Boolean = true
}
