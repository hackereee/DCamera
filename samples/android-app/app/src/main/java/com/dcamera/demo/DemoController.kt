package com.dcamera.demo

import com.dcamera.SuperCamera
import com.dcamera.ui.BasicCameraView

class DemoController(
    private val camera: SuperCamera,
    private val basicCameraView: BasicCameraView,
) {
    var cameraGranted: Boolean = false
        private set
    var micGranted: Boolean = false
        private set
    var previewing: Boolean = false
        private set
    var recording: Boolean = false
        private set
    var lastMessage: String = ""
        private set

    fun onPermissionResult(cameraGranted: Boolean, micGranted: Boolean) {
        this.cameraGranted = cameraGranted
        this.micGranted = micGranted
        if (!cameraGranted) {
            lastMessage = "权限未授予"
        }
    }

    fun startPreview(surfaceHandle: Long): Boolean {
        if (!cameraGranted) {
            lastMessage = "权限未授予"
            return false
        }
        val ok = camera.startPreview(surfaceHandle)
        previewing = ok
        lastMessage = if (ok) "预览已启动" else "预览启动失败"
        return ok
    }

    fun stopPreview(): Boolean {
        val ok = camera.stopPreview()
        previewing = false
        lastMessage = if (ok) "预览已停止" else "预览停止失败"
        return ok
    }

    fun takePhoto(path: String): String {
        if (!cameraGranted) {
            lastMessage = "权限未授予"
            return ""
        }
        val result = camera.takePhoto(path)
        lastMessage = if (result.path.isBlank()) "拍照失败" else "拍照成功"
        return result.path
    }

    fun toggleRecord(path: String): Boolean {
        if (!cameraGranted || !micGranted) {
            lastMessage = "权限未授予"
            return false
        }
        if (!previewing) {
            lastMessage = "请先启动预览"
            return false
        }

        return if (!recording) {
            val ok = camera.startRecord(path)
            recording = ok
            lastMessage = if (ok) "开始录像" else "开始录像失败"
            ok
        } else {
            val result = camera.stopRecord()
            val ok = result.path.isNotBlank()
            recording = false
            lastMessage = if (ok) "停止录像" else "停止录像失败"
            ok
        }
    }

    fun toggleUiRecordBadge() {
        basicCameraView.onRecordTapped()
    }

    fun uiBadge(): String = basicCameraView.recordingBadgeText()
}
