package com.dcamera.record

data class RecordResult(val path: String)

class RecordController(private val frameSource: BgfxOffscreenFrameSource) {
    private var output: String = ""
    fun startRecord(path: String) { output = path }
    fun stopRecord(): RecordResult = RecordResult(output)
}
