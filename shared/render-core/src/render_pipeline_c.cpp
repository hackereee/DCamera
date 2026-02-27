#include "scamera/render/render_pipeline_c.h"
#include "scamera/render/render_pipeline.h"

struct scamera_render_pipeline {
    scamera::RenderPipeline impl;
};

extern "C" {

scamera_render_pipeline* scamera_render_pipeline_create(void) {
    return new (std::nothrow) scamera_render_pipeline();
}

void scamera_render_pipeline_destroy(scamera_render_pipeline* p) {
    if (p) {
        p->impl.release();
        delete p;
    }
}

bool scamera_render_pipeline_configure_preview(scamera_render_pipeline* p, int width, int height) {
    if (!p) return false;
    return p->impl.configurePreview(width, height);
}

bool scamera_render_pipeline_configure_offscreen(scamera_render_pipeline* p, int width, int height) {
    if (!p) return false;
    return p->impl.configureOffscreen(width, height);
}

bool scamera_render_pipeline_submit_frame(scamera_render_pipeline* p, void* frame_handle, long long timestamp_ns) {
    if (!p) return false;
    return p->impl.submitFrame(frame_handle, timestamp_ns);
}

bool scamera_render_pipeline_consume_offscreen(scamera_render_pipeline* p, scamera_offscreen_frame* out) {
    if (!p || !out) return false;
    scamera::OffscreenFrame frame = p->impl.consumeOffscreenFrame();
    if (!frame.data) return false;

    out->data = frame.data;
    out->data_size = frame.dataSize;
    out->timestamp_ns = frame.timestampNs;
    return true;
}

} // extern "C"
