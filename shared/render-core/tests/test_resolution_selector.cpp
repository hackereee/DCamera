#include "scamera/core/resolution_selector.h"

int main() {
    using namespace scamera;
    ResolutionSelector selector;
    Resolution r = selector.select(WorkMode::VIDEO, 1080, 1920, {{1280, 720}, {1920, 1080}});
    return (r.width == 1920 && r.height == 1080) ? 0 : 1;
}
