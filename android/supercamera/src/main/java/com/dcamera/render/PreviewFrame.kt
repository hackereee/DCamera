package com.dcamera.render

data class PreviewFrame(
    val y: ByteArray,
    val u: ByteArray,
    val v: ByteArray,
    val width: Int,
    val height: Int,
    val timestampNs: Long,
)
