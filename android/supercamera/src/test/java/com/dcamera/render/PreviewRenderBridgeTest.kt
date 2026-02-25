package com.dcamera.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

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
}
