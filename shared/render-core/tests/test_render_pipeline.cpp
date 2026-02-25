#include "scamera/render/render_pipeline.h"

int main() {
    scamera::RenderPipeline p;
    bool ok = p.configurePreview(1280, 720) && p.configureOffscreen(1920, 1080);
    return ok ? 0 : 1;
}
