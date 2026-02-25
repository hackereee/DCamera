#include "scamera/telemetry/metrics.h"
int main() {
    scamera::SessionMetrics m;
    m.firstFrameLatencyMs = 320;
    return m.firstFrameLatencyMs == 320 ? 0 : 1;
}
