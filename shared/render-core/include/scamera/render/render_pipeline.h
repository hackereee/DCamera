#pragma once

namespace scamera {

class RenderPipeline {
public:
    bool configurePreview(int width, int height);
    bool configureOffscreen(int width, int height);
    bool submitFrame(void* yuvFrameHandle, long long timestampNs);
};

} // namespace scamera
