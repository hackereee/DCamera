package com.dcamera

import com.dcamera.core.CameraEvent
import com.dcamera.core.ErrorCallback
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SuperCameraLifecycleTest {

    @Test
    fun `初始状态为IDLE`() {
        val camera = SuperCamera()
        assertEquals(CameraState.IDLE, camera.currentState())
    }

    @Test
    fun `startPreview从IDLE转到PREVIEWING`() {
        val camera = SuperCamera()
        assertTrue(camera.startPreview(1L))
        assertEquals(CameraState.PREVIEWING, camera.currentState())
    }

    @Test
    fun `startPreview非法状态返回false并触发错误回调`() {
        val camera = SuperCamera()
        var errorCode: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code: ErrorCode, message: String) { errorCode = code }
        })
        camera.startPreview(1L) // IDLE -> PREVIEWING
        assertFalse(camera.startPreview(1L)) // PREVIEWING -> PREVIEWING 非法
        assertEquals(ErrorCode.INVALID_STATE, errorCode)
    }

    @Test
    fun `stopPreview从PREVIEWING转到IDLE`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        assertTrue(camera.stopPreview())
        assertEquals(CameraState.IDLE, camera.currentState())
    }

    @Test
    fun `startRecord从PREVIEWING转到RECORDING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        assertTrue(camera.startRecord("/tmp/out.mp4"))
        assertEquals(CameraState.RECORDING, camera.currentState())
    }

    @Test
    fun `stopRecord从RECORDING回到PREVIEWING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        camera.startRecord("/tmp/out.mp4")
        val result = camera.stopRecord()
        assertEquals(CameraState.PREVIEWING, camera.currentState())
        assertTrue(result.path.endsWith(".mp4"))
    }

    @Test
    fun `takePhoto从PREVIEWING转到CAPTURING再回到PREVIEWING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        val result = camera.takePhoto("/tmp/photo.jpg")
        assertEquals(CameraState.PREVIEWING, camera.currentState())
        assertTrue(result.path.endsWith(".jpg"))
    }
}
