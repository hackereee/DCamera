package com.dcamera.record

interface VideoEncoder {
    fun start(path: String, width: Int, height: Int)
    fun encodeFrame(data: ByteArray): Boolean
    fun finalize(outputPath: String): Boolean
    fun release()
}
