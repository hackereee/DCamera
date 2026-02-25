package com.dcamera

import com.dcamera.record.BgfxOffscreenFrameSource
import com.dcamera.record.RecordController
import kotlin.test.Test
import kotlin.test.assertTrue

class FakeBgfxFrameSource : BgfxOffscreenFrameSource {
    override fun nextFrame(): ByteArray? = null
}

class RecordControllerTest {
    @Test
    fun `startStopRecord返回mp4路径`() {
        val controller = RecordController(FakeBgfxFrameSource())
        controller.startRecord("/tmp/test.mp4")
        val result = controller.stopRecord()
        assertTrue(result.path.endsWith(".mp4"))
    }
}
