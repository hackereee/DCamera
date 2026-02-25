package com.dcamera

enum class WorkMode { PURE_PREVIEW, ANALYSIS, PHOTO, VIDEO }

class SuperCamera {
    private var mode: WorkMode = WorkMode.PURE_PREVIEW
    fun setWorkMode(next: WorkMode) { mode = next }
    fun currentWorkMode(): WorkMode = mode
}
