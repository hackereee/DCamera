package com.dcamera.ui

import kotlin.test.Test
import kotlin.test.assertEquals

class BasicCameraViewTest {
    @Test
    fun `点击录制按钮后显示REC角标`() {
        val view = BasicCameraView()
        view.onRecordTapped()
        assertEquals("REC", view.recordingBadgeText())
    }
}
