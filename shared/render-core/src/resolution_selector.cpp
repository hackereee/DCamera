#include "scamera/core/resolution_selector.h"
#include <cmath>

namespace scamera {

static double ratio_delta(int w, int h, double target) {
    return std::abs((static_cast<double>(w) / static_cast<double>(h)) - target);
}

Resolution ResolutionSelector::select(WorkMode mode, int screenWidth, int screenHeight, const std::vector<Resolution>& supported) const {
    if (supported.empty()) return {1280, 720};

    if (mode == WorkMode::PHOTO || mode == WorkMode::VIDEO) {
        const Resolution priority[] = {{1920,1080}, {1600,900}, {1280,720}, {960,540}};
        for (auto p : priority) {
            for (const auto& s : supported) {
                if (s.width == p.width && s.height == p.height) return s;
            }
        }
        return supported.front();
    }

    const double targetRatio = static_cast<double>(screenWidth) / static_cast<double>(screenHeight);
    Resolution best = supported.front();
    double bestRatio = ratio_delta(best.width, best.height, targetRatio);
    double bestArea = std::abs((best.width * best.height) - (screenWidth * screenHeight));

    for (const auto& s : supported) {
        double rd = ratio_delta(s.width, s.height, targetRatio);
        double ad = std::abs((s.width * s.height) - (screenWidth * screenHeight));
        if (rd < bestRatio || (rd == bestRatio && ad < bestArea)) {
            best = s;
            bestRatio = rd;
            bestArea = ad;
        }
    }
    return best;
}

} // namespace scamera
