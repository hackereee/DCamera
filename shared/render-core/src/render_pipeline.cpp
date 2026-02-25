#include "scamera/render/render_pipeline.h"

namespace scamera {

bool RenderPipeline::configurePreview(int width, int height) {
    return width > 0 && height > 0;
}

bool RenderPipeline::configureOffscreen(int width, int height) {
    return width > 0 && height > 0;
}

bool RenderPipeline::submitFrame(void* yuvFrameHandle, long long timestampNs) {
    return yuvFrameHandle != nullptr && timestampNs >= 0;
}

} // namespace scamera
