// RenderPipelineCBridge.h
// C bridge header that imports the shared render pipeline C ABI.
//
// When the native library (libscamera_render_core) is built and linked,
// this header will provide Swift access to the C functions via the
// accompanying modulemap.
//
// For now, the shared library is NOT yet linked to the iOS SwiftPM package,
// so this header serves as a placeholder documenting the intended interface.

#pragma once

// The shared C ABI header lives at:
//   shared/render-core/include/scamera/render/render_pipeline_c.h
//
// Once the static/dynamic library is built for iOS (arm64) and linked into
// the SwiftPM target, uncomment the include below:
//
// #include "scamera/render/render_pipeline_c.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward-declare the opaque pipeline handle.
typedef struct scamera_render_pipeline scamera_render_pipeline;

// Frame output descriptor.
typedef struct {
    const void* data;
    int data_size;
    long long timestamp_ns;
} scamera_offscreen_frame;

// Lifecycle
scamera_render_pipeline* scamera_render_pipeline_create(void);
void scamera_render_pipeline_destroy(scamera_render_pipeline* p);

// Configuration
bool scamera_render_pipeline_configure_preview(scamera_render_pipeline* p, int width, int height);
bool scamera_render_pipeline_configure_offscreen(scamera_render_pipeline* p, int width, int height);

// Frame submission
bool scamera_render_pipeline_submit_frame(scamera_render_pipeline* p, void* frame_handle, long long timestamp_ns);
bool scamera_render_pipeline_consume_offscreen(scamera_render_pipeline* p, scamera_offscreen_frame* out);

#ifdef __cplusplus
}
#endif
