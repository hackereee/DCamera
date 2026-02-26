package com.dcamera.demo

import kotlin.test.Test
import kotlin.test.assertEquals

class BootstrapTest {
    @Test
    fun `demo工程可识别基础应用ID`() {
        assertEquals("com.dcamera.demo", Bootstrap.applicationId())
    }
}
