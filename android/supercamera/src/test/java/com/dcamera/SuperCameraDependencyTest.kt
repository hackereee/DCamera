package com.dcamera

import com.dcamera.capture.CaptureResult
import com.dcamera.core.ErrorCallback
import com.dcamera.core.PhotoCapturePort
import com.dcamera.core.PreviewSessionPort
import com.dcamera.render.PreviewBridgePort
import com.dcamera.render.PreviewFrame
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class FakePreviewSessionPort(
    private val startResult: Boolean = true,
    private val stopResult: Boolean = true,
) : PreviewSessionPort {
    var startCalls = 0
    var stopCalls = 0

    override fun setFrameConsumer(consumer: (PreviewFrame) -> Unit) {}

    override fun startPreview(surfaceHandle: Long): Boolean {
        startCalls++
        return startResult
    }

    override fun stopPreview(): Boolean {
        stopCalls++
        return stopResult
    }
}

private class FakePreviewBridgePort(
    private val attachResult: Boolean = true,
) : PreviewBridgePort {
    var attachCalls = 0
    var detachCalls = 0

    override fun attachSurface(surfaceHandle: Long): Boolean {
        attachCalls++
        return attachResult
    }

    override fun detachSurface() {
        detachCalls++
    }
}

private class FakePhotoCapturePort(
    private val resultPath: String,
) : PhotoCapturePort {
    override fun capture(outputPath: String): CaptureResult = CaptureResult(resultPath)
}

class SuperCameraDependencyTest {
    @Test
    fun `startPreview失败时回滚IDLE并上报SESSION_CONFIG_FAILED`() {
        val session = FakePreviewSessionPort(startResult = false)
        val camera = SuperCamera(
            previewSession = session,
            previewBridge = FakePreviewBridgePort(),
            photoCapture = FakePhotoCapturePort("/tmp/photo.jpg"),
        )
        var code: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code0: ErrorCode, message: String) {
                code = code0
            }
        })

        assertFalse(camera.startPreview(1L))
        assertEquals(CameraState.IDLE, camera.currentState())
        assertEquals(ErrorCode.SESSION_CONFIG_FAILED, code)
    }

    @Test
    fun `render attach失败时调用session stop回滚并上报RENDER_INIT_FAILED`() {
        val session = FakePreviewSessionPort(startResult = true)
        val bridge = FakePreviewBridgePort(attachResult = false)
        val camera = SuperCamera(
            previewSession = session,
            previewBridge = bridge,
            photoCapture = FakePhotoCapturePort("/tmp/photo.jpg"),
        )
        var code: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code0: ErrorCode, message: String) {
                code = code0
            }
        })

        assertFalse(camera.startPreview(1L))
        assertEquals(1, session.stopCalls)
        assertEquals(ErrorCode.RENDER_INIT_FAILED, code)
        assertEquals(CameraState.IDLE, camera.currentState())
    }

    @Test
    fun `takePhoto返回空路径时上报FILE_IO_FAILED`() {
        val camera = SuperCamera(
            previewSession = FakePreviewSessionPort(),
            previewBridge = FakePreviewBridgePort(),
            photoCapture = FakePhotoCapturePort(""),
        )
        var code: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code0: ErrorCode, message: String) {
                code = code0
            }
        })

        assertTrue(camera.startPreview(1L))
        val result = camera.takePhoto("/tmp/photo.jpg")
        assertEquals("", result.path)
        assertEquals(ErrorCode.FILE_IO_FAILED, code)
        assertEquals(CameraState.PREVIEWING, camera.currentState())
    }
}
