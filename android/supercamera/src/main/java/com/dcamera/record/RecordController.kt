package com.dcamera.record

data class RecordResult(val path: String)

class RecordController(
    private val frameSource: BgfxOffscreenFrameSource,
    private val encoder: VideoEncoder,
) {
    private var outputPath: String = ""
    private var recording: Boolean = false

    fun isRecording(): Boolean = recording

    fun startRecord(path: String, width: Int, height: Int) {
        outputPath = path
        encoder.start(path, width, height)
        recording = true
    }

    fun processAvailableFrames() {
        if (!recording) return
        while (true) {
            val frame = frameSource.nextFrame() ?: break
            encoder.encodeFrame(frame)
        }
    }

    fun stopRecord(): RecordResult {
        if (!recording) return RecordResult("")
        recording = false
        encoder.finalize(outputPath)
        return RecordResult(outputPath)
    }
}
