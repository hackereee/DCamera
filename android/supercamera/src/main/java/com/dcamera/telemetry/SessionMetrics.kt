package com.dcamera.telemetry

data class SessionMetrics(
    var firstFrameLatencyMs: Int = 0,
    var previewFps: Int = 0,
    var renderDropRatePermille: Int = 0,
    var encoderInputFps: Int = 0,
    var avDriftMs: Int = 0,
    var modeSwitchLatencyMs: Int = 0
)
