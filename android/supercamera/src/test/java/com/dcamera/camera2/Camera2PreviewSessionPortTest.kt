package com.dcamera.camera2

import com.dcamera.render.PreviewFrame
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FakeCamera2Facade(
    private val startResult: Boolean = true,
) : Camera2Facade {
    override fun start(surfaceHandle: Long, onFrame: (PreviewFrame) -> Unit): Boolean {
        if (startResult) {
            onFrame(
                PreviewFrame(
                    y = ByteArray(0),
                    u = ByteArray(0),
                    v = ByteArray(0),
                    width = 1920,
                    height = 1080,
                    timestampNs = System.nanoTime(),
                )
            )
        }
        return startResult
    }

    override fun stop(): Boolean = true
}

class Camera2PreviewSessionPortTest {
    @Test
    fun `startPreview成功后可把帧投递给consumer`() {
        val facade = FakeCamera2Facade(startResult = true)
        val port = Camera2PreviewSessionPort(facade)
        var delivered = 0
        port.setFrameConsumer { delivered++ }

        assertTrue(port.startPreview(1L))
        assertEquals(1, delivered)
    }
}
