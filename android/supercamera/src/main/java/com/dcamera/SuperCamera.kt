package com.dcamera

enum class WorkMode { PURE_PREVIEW, ANALYSIS, PHOTO, VIDEO }
enum class CameraState { IDLE, INITIALIZING, PREVIEWING, CAPTURING, RECORDING, RELEASING }

class SuperCamera {
    private var mode: WorkMode = WorkMode.PURE_PREVIEW
    private var state: CameraState = CameraState.IDLE

    fun setWorkMode(next: WorkMode) { mode = next }
    fun currentWorkMode(): WorkMode = mode

    fun currentState(): CameraState = state
    fun startPreview(surfaceHandle: Long) {
        state = CameraState.INITIALIZING
        state = CameraState.PREVIEWING
    }
}
