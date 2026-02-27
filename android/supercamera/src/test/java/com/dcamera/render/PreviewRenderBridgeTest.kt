package com.dcamera.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class FakeRenderPipelinePort(
    private val submitResult: Boolean,
) : RenderPipelinePort {
    var submitCalls = 0
    var lastTs: Long = -1
    var lastWidth: Int = -1

    override fun submitFrame(frame: PreviewFrame): Boolean {
        submitCalls++
        lastTs = frame.timestampNs
        lastWidth = frame.width
        return submitResult
    }
}

private fun makeFrame(
    width: Int = 1280,
    height: Int = 720,
    timestampNs: Long = 100L,
) = PreviewFrame(
    y = byteArrayOf(1),
    u = byteArrayOf(2),
    v = byteArrayOf(3),
    width = width,
    height = height,
    timestampNs = timestampNs,
)

class PreviewRenderBridgeTest {
    @Test
    fun `未attach时submitFrame返回false`() {
        val bridge = PreviewRenderBridge()
        assertFalse(bridge.submitFrame(makeFrame()))
    }

    @Test
    fun `attachSurface后submitFrame成功`() {
        val bridge = PreviewRenderBridge()
        assertTrue(bridge.attachSurface(1L))
        assertTrue(bridge.submitFrame(makeFrame()))
    }

    @Test
    fun `attachSurface零值handle失败`() {
        val bridge = PreviewRenderBridge()
        assertFalse(bridge.attachSurface(0L))
    }

    @Test
    fun `detachSurface后submitFrame失败`() {
        val bridge = PreviewRenderBridge()
        bridge.attachSurface(1L)
        bridge.detachSurface()
        assertFalse(bridge.submitFrame(makeFrame()))
    }

    @Test
    fun `帧计数正确递增`() {
        val bridge = PreviewRenderBridge()
        bridge.attachSurface(1L)
        bridge.submitFrame(makeFrame(timestampNs = 100L))
        bridge.submitFrame(makeFrame(timestampNs = 200L))
        assertEquals(2, bridge.frameCount())
    }

    @Test
    fun `pipeline submit失败时返回false且frameCount不增加`() {
        val pipeline = FakeRenderPipelinePort(submitResult = false)
        val bridge = PreviewRenderBridge(renderPipeline = pipeline)
        bridge.attachSurface(1L)

        assertFalse(bridge.submitFrame(makeFrame(timestampNs = 99L)))
        assertEquals(0, bridge.frameCount())
        assertEquals(1, pipeline.submitCalls)
    }

    @Test
    fun `pipeline submit成功时返回true并记录参数`() {
        val pipeline = FakeRenderPipelinePort(submitResult = true)
        val bridge = PreviewRenderBridge(renderPipeline = pipeline)
        bridge.attachSurface(1L)

        assertTrue(bridge.submitFrame(makeFrame(width = 1920, timestampNs = 88L)))
        assertEquals(1, bridge.frameCount())
        assertEquals(1920, pipeline.lastWidth)
        assertEquals(88L, pipeline.lastTs)
    }

    @Test
    fun `submitFrame把完整帧对象透传给pipeline`() {
        val pipeline = FakeRenderPipelinePort(submitResult = true)
        val bridge = PreviewRenderBridge(renderPipeline = pipeline)
        bridge.attachSurface(1L)

        val frame = PreviewFrame(
            y = byteArrayOf(1, 2),
            u = byteArrayOf(3),
            v = byteArrayOf(4),
            width = 1280,
            height = 720,
            timestampNs = 123L,
        )
        assertTrue(bridge.submitFrame(frame))
        assertEquals(123L, pipeline.lastTs)
        assertEquals(1280, pipeline.lastWidth)
    }
}
