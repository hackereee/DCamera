#pragma once
#include <deque>
#include <vector>
#include <cstdint>

namespace scamera {

struct OffscreenFrame {
    const void* data = nullptr;
    int dataSize = 0;
    long long timestampNs = 0;
};

class RenderPipeline {
public:
    bool configurePreview(int width, int height);
    bool configureOffscreen(int width, int height);
    bool submitFrame(void* yuvFrameHandle, long long timestampNs);
    OffscreenFrame consumeOffscreenFrame();
    void release();

private:
    static constexpr int kMaxQueueSize = 3;

    bool previewConfigured_ = false;
    bool offscreenConfigured_ = false;
    bool released_ = false;
    int previewWidth_ = 0;
    int previewHeight_ = 0;
    int offscreenWidth_ = 0;
    int offscreenHeight_ = 0;

    struct QueuedFrame {
        std::vector<uint8_t> data;
        long long timestampNs;
    };
    std::deque<QueuedFrame> frameQueue_;
};

} // namespace scamera
