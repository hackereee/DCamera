package com.dcamera.render

/**
 * [RenderPipelinePort] implementation that delegates frame submission
 * to the native bgfx pipeline through [NativeRenderBindings].
 */
class BgfxRenderPipelinePort : RenderPipelinePort {

    override fun submitFrame(frame: PreviewFrame): Boolean {
        return try {
            NativeRenderBindings.nativeSubmitFrame(
                frame.y,
                frame.u,
                frame.v,
                frame.width,
                frame.height,
                frame.timestampNs,
            )
        } catch (_: UnsatisfiedLinkError) {
            // Native library not loaded yet; treat as no-op success for now.
            true
        }
    }
}
