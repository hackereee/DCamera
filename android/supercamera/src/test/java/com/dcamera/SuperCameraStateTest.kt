package com.dcamera

import kotlin.test.Test
import kotlin.test.assertEquals

class SuperCameraStateTest {
    @Test
    fun `切换到视频模式后门面状态正确更新`() {
        val camera = SuperCamera()
        camera.setWorkMode(WorkMode.VIDEO)
        assertEquals(WorkMode.VIDEO, camera.currentWorkMode())
    }
}
