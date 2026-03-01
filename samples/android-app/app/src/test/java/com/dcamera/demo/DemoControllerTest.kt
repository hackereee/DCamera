package com.dcamera.demo

import com.dcamera.SuperCamera
import com.dcamera.ui.BasicCameraView
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DemoControllerTest {
    @Test
    fun `未授权时禁止预览与拍照`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = false, micGranted = false)

        assertFalse(controller.startPreview(1L))
        val photoPath = controller.takePhoto("/tmp/p.jpg")
        assertEquals("", photoPath)
        assertEquals("权限未授予", controller.lastMessage)
    }

    @Test
    fun `授权后可启动预览并拍照`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = true, micGranted = true)

        assertTrue(controller.startPreview(1L))
        val photoPath = controller.takePhoto("/tmp/p.jpg")
        assertTrue(photoPath.endsWith(".jpg"))
    }

    @Test
    fun `录像开关遵循状态机`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = true, micGranted = true)
        controller.startPreview(1L)

        assertTrue(controller.toggleRecord("/tmp/v.mp4"))
        assertEquals(true, controller.recording)
        assertTrue(controller.toggleRecord("/tmp/v.mp4"))
        assertEquals(false, controller.recording)
    }

    @Test
    fun `ui组件点击后REC标记可见`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        assertEquals("", controller.uiBadge())
        controller.toggleUiRecordBadge()
        assertEquals("REC", controller.uiBadge())
    }

    @Test
    fun `未启动预览时录像被阻止`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = true, micGranted = true)

        assertFalse(controller.toggleRecord("/tmp/v.mp4"))
        assertEquals("请先启动预览", controller.lastMessage)
    }

    @Test
    fun `预览启动后可停止并回到idle提示`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = true, micGranted = true)
        assertTrue(controller.startPreview(1L))
        assertTrue(controller.stopPreview())
        assertEquals("预览已停止", controller.lastMessage)
    }

    @Test
    fun `预览显示层启动失败时返回失败`() {
        val controller = DemoController(
            camera = SuperCamera(),
            basicCameraView = BasicCameraView(),
            previewDisplay = FakePreviewDisplayPort(startResult = false, stopResult = true),
        )
        controller.onPermissionResult(cameraGranted = true, micGranted = true)

        assertFalse(controller.startPreview(1L))
        assertEquals("预览启动失败", controller.lastMessage)
    }
}

private class FakePreviewDisplayPort(
    private val startResult: Boolean,
    private val stopResult: Boolean,
) : PreviewDisplayPort {
    override fun startPreview(): Boolean = startResult
    override fun stopPreview(): Boolean = stopResult
}
