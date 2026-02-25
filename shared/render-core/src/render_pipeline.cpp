#include "scamera/render/render_pipeline.h"
#include <cstring>

namespace scamera {

bool RenderPipeline::configurePreview(int width, int height) {
    if (released_ || width <= 0 || height <= 0) return false;
    previewWidth_ = width;
    previewHeight_ = height;
    previewConfigured_ = true;
    return true;
}

bool RenderPipeline::configureOffscreen(int width, int height) {
    if (released_ || width <= 0 || height <= 0) return false;
    offscreenWidth_ = width;
    offscreenHeight_ = height;
    offscreenConfigured_ = true;
    return true;
}

bool RenderPipeline::submitFrame(void* yuvFrameHandle, long long timestampNs) {
    if (released_ || !previewConfigured_ || yuvFrameHandle == nullptr || timestampNs < 0)
        return false;
    if (static_cast<int>(frameQueue_.size()) >= kMaxQueueSize)
        return false;

    QueuedFrame qf;
    // MVP: 复制 1 字节作为占位，真实实现会复制完整 YUV 缓冲
    qf.data.resize(1);
    qf.data[0] = *static_cast<uint8_t*>(yuvFrameHandle);
    qf.timestampNs = timestampNs;
    frameQueue_.push_back(std::move(qf));
    return true;
}

OffscreenFrame RenderPipeline::consumeOffscreenFrame() {
    if (!offscreenConfigured_ || frameQueue_.empty())
        return {};
    auto& front = frameQueue_.front();
    OffscreenFrame result;
    result.data = front.data.data();
    result.dataSize = static_cast<int>(front.data.size());
    result.timestampNs = front.timestampNs;
    frameQueue_.pop_front();
    return result;
}

void RenderPipeline::release() {
    released_ = true;
    frameQueue_.clear();
    previewConfigured_ = false;
    offscreenConfigured_ = false;
}

} // namespace scamera
