#include "scamera/render/render_pipeline_c.h"

int main() {
    auto* p = scamera_render_pipeline_create();
    if (!p) return 1;
    if (!scamera_render_pipeline_configure_preview(p, 1280, 720)) return 2;
    if (!scamera_render_pipeline_configure_offscreen(p, 1280, 720)) return 3;

    unsigned char data[4] = {1, 2, 3, 4};
    if (!scamera_render_pipeline_submit_frame(p, data, 100)) return 4;

    scamera_offscreen_frame f{};
    if (!scamera_render_pipeline_consume_offscreen(p, &f)) return 5;
    if (f.timestamp_ns != 100) return 6;

    scamera_render_pipeline_destroy(p);
    return 0;
}
