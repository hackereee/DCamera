#pragma once

namespace scamera {

struct SessionMetrics {
    int firstFrameLatencyMs = 0;
    int previewFps = 0;
    int renderDropRatePermille = 0;
    int encoderInputFps = 0;
    int avDriftMs = 0;
    int modeSwitchLatencyMs = 0;
};

} // namespace scamera
