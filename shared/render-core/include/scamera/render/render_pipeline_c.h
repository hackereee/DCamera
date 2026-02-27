#pragma once
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct scamera_render_pipeline scamera_render_pipeline;
typedef struct {
    const void* data;
    int data_size;
    long long timestamp_ns;
} scamera_offscreen_frame;

scamera_render_pipeline* scamera_render_pipeline_create(void);
void scamera_render_pipeline_destroy(scamera_render_pipeline* p);
bool scamera_render_pipeline_configure_preview(scamera_render_pipeline* p, int width, int height);
bool scamera_render_pipeline_configure_offscreen(scamera_render_pipeline* p, int width, int height);
bool scamera_render_pipeline_submit_frame(scamera_render_pipeline* p, void* frame_handle, long long timestamp_ns);
bool scamera_render_pipeline_consume_offscreen(scamera_render_pipeline* p, scamera_offscreen_frame* out);

#ifdef __cplusplus
}
#endif
