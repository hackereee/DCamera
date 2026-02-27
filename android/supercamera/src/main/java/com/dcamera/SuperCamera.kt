package com.dcamera

import com.dcamera.capture.CaptureResult
import com.dcamera.core.CaptureControllerAdapter
import com.dcamera.core.ErrorCallback
import com.dcamera.core.NoOpPreviewSessionPort
import com.dcamera.core.PhotoCapturePort
import com.dcamera.core.PreviewSessionPort
import com.dcamera.record.RecordResult
import com.dcamera.render.PreviewBridgePort
import com.dcamera.render.PreviewRenderBridge

enum class WorkMode { PURE_PREVIEW, ANALYSIS, PHOTO, VIDEO }
enum class CameraState { IDLE, INITIALIZING, PREVIEWING, CAPTURING, RECORDING, RELEASING }
enum class ErrorCode {
    NONE,
    PERMISSION,
    DEVICE_UNAVAILABLE,
    SESSION_CONFIG_FAILED,
    RENDER_INIT_FAILED,
    RENDER_SURFACE_LOST,
    ENCODER_INIT_FAILED,
    ENCODER_BACKPRESSURE,
    FILE_IO_FAILED,
    THERMAL_THROTTLE,
    INVALID_STATE
}

class SuperCamera(
    private val previewSession: PreviewSessionPort = NoOpPreviewSessionPort(),
    private val previewBridge: PreviewBridgePort = PreviewRenderBridge(),
    private val photoCapture: PhotoCapturePort = CaptureControllerAdapter(),
) {
    private var mode: WorkMode = WorkMode.PURE_PREVIEW
    private var state: CameraState = CameraState.IDLE
    private var errorCallback: ErrorCallback? = null
    private var recordPath: String = ""

    fun setWorkMode(next: WorkMode) { mode = next }
    fun currentWorkMode(): WorkMode = mode
    fun currentState(): CameraState = state
    fun setErrorCallback(cb: ErrorCallback) { errorCallback = cb }

    fun startPreview(surfaceHandle: Long): Boolean {
        if (state != CameraState.IDLE) {
            errorCallback?.onError(
                ErrorCode.INVALID_STATE,
                "startPreview requires IDLE state, current=$state",
            )
            return false
        }
        state = CameraState.INITIALIZING
        previewSession.setFrameConsumer { previewBridge.submitFrame(it) }
        if (!previewSession.startPreview(surfaceHandle)) {
            state = CameraState.IDLE
            errorCallback?.onError(ErrorCode.SESSION_CONFIG_FAILED, "preview session init failed")
            return false
        }
        if (!previewBridge.attachSurface(surfaceHandle)) {
            previewSession.stopPreview()
            state = CameraState.IDLE
            errorCallback?.onError(ErrorCode.RENDER_INIT_FAILED, "preview bridge attach failed")
            return false
        }
        state = CameraState.PREVIEWING
        return true
    }

    fun stopPreview(): Boolean {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(
                ErrorCode.INVALID_STATE,
                "stopPreview requires PREVIEWING state, current=$state",
            )
            return false
        }
        state = CameraState.RELEASING
        previewBridge.detachSurface()
        val stopped = previewSession.stopPreview()
        state = CameraState.IDLE
        if (!stopped) {
            errorCallback?.onError(ErrorCode.SESSION_CONFIG_FAILED, "preview session stop failed")
            return false
        }
        return true
    }

    fun startRecord(path: String): Boolean {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(
                ErrorCode.INVALID_STATE,
                "startRecord requires PREVIEWING state, current=$state",
            )
            return false
        }
        recordPath = path
        state = CameraState.RECORDING
        return true
    }

    fun stopRecord(): RecordResult {
        if (state != CameraState.RECORDING) {
            errorCallback?.onError(
                ErrorCode.INVALID_STATE,
                "stopRecord requires RECORDING state, current=$state",
            )
            return RecordResult("")
        }
        state = CameraState.PREVIEWING
        return RecordResult(recordPath)
    }

    fun takePhoto(outputPath: String): CaptureResult {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(
                ErrorCode.INVALID_STATE,
                "takePhoto requires PREVIEWING state, current=$state",
            )
            return CaptureResult("")
        }
        state = CameraState.CAPTURING
        val result = photoCapture.capture(outputPath)
        state = CameraState.PREVIEWING
        if (result.path.isBlank()) {
            errorCallback?.onError(ErrorCode.FILE_IO_FAILED, "photo capture returned empty path")
        }
        return result
    }
}
