package com.dcamera.record

interface BgfxOffscreenFrameSource {
    fun nextFrame(): ByteArray?
}
