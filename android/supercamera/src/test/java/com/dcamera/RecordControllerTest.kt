package com.dcamera

import com.dcamera.record.BgfxOffscreenFrameSource
import com.dcamera.record.RecordController
import com.dcamera.record.VideoEncoder
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class FakeBgfxFrameSource : BgfxOffscreenFrameSource {
    val frames = mutableListOf<ByteArray>()
    private var index = 0

    override fun nextFrame(): ByteArray? =
        if (index < frames.size) {
            frames[index++]
        } else {
            null
        }
}

class FakeVideoEncoder : VideoEncoder {
    val encodedFrames = mutableListOf<ByteArray>()
    var started = false
    var finalized = false

    override fun start(path: String, width: Int, height: Int) {
        started = true
    }

    override fun encodeFrame(data: ByteArray): Boolean {
        encodedFrames.add(data)
        return true
    }

    override fun finalize(outputPath: String): Boolean {
        finalized = true
        return true
    }

    override fun release() {}
}

class RecordControllerTest {
    @Test
    fun `startRecord初始化编码器`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        val controller = RecordController(source, encoder)
        controller.startRecord("/tmp/test.mp4", 1920, 1080)
        assertTrue(encoder.started)
        assertTrue(controller.isRecording())
    }

    @Test
    fun `processFrames消费帧源并编码`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        source.frames.add(byteArrayOf(1, 2, 3))
        source.frames.add(byteArrayOf(4, 5, 6))

        val controller = RecordController(source, encoder)
        controller.startRecord("/tmp/test.mp4", 1920, 1080)
        controller.processAvailableFrames()
        assertEquals(2, encoder.encodedFrames.size)
    }

    @Test
    fun `stopRecord返回mp4路径并终止编码器`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        val controller = RecordController(source, encoder)
        controller.startRecord("/tmp/test.mp4", 1920, 1080)
        val result = controller.stopRecord()
        assertTrue(result.path.endsWith(".mp4"))
        assertTrue(encoder.finalized)
        assertFalse(controller.isRecording())
    }

    @Test
    fun `未开始录制时stopRecord返回空路径`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        val controller = RecordController(source, encoder)
        val result = controller.stopRecord()
        assertEquals("", result.path)
    }
}
