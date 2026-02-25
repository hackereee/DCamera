package com.dcamera

import kotlin.test.Test
import kotlin.test.assertEquals

class PreviewPipelineTest {
    @Test
    fun `startPreview后状态进入PREVIEWING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        assertEquals(CameraState.PREVIEWING, camera.currentState())
    }
}
