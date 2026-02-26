package com.dcamera.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class FakeRenderPipelinePort(
    private val submitResult: Boolean,
) : RenderPipelinePort {
    var submitCalls = 0
    var lastFrame: Long = -1
    var lastTs: Long = -1

    override fun submitFrame(frameHandle: Long, tsNs: Long): Boolean {
        submitCalls++
        lastFrame = frameHandle
        lastTs = tsNs
        return submitResult
    }
}

class PreviewRenderBridgeTest {
    @Test
    fun `未attach时submitFrame返回false`() {
        val bridge = PreviewRenderBridge()
        assertFalse(bridge.submitFrame(1L, 100))
    }

    @Test
    fun `attachSurface后submitFrame成功`() {
        val bridge = PreviewRenderBridge()
        assertTrue(bridge.attachSurface(1L))
        assertTrue(bridge.submitFrame(1L, 100))
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
        assertFalse(bridge.submitFrame(1L, 100))
    }

    @Test
    fun `帧计数正确递增`() {
        val bridge = PreviewRenderBridge()
        bridge.attachSurface(1L)
        bridge.submitFrame(1L, 100)
        bridge.submitFrame(2L, 200)
        assertEquals(2, bridge.frameCount())
    }

    @Test
    fun `pipeline submit失败时返回false且frameCount不增加`() {
        val pipeline = FakeRenderPipelinePort(submitResult = false)
        val bridge = PreviewRenderBridge(renderPipeline = pipeline)
        bridge.attachSurface(1L)

        assertFalse(bridge.submitFrame(9L, 99L))
        assertEquals(0, bridge.frameCount())
        assertEquals(1, pipeline.submitCalls)
    }

    @Test
    fun `pipeline submit成功时返回true并记录参数`() {
        val pipeline = FakeRenderPipelinePort(submitResult = true)
        val bridge = PreviewRenderBridge(renderPipeline = pipeline)
        bridge.attachSurface(1L)

        assertTrue(bridge.submitFrame(7L, 88L))
        assertEquals(1, bridge.frameCount())
        assertEquals(7L, pipeline.lastFrame)
        assertEquals(88L, pipeline.lastTs)
    }
}
