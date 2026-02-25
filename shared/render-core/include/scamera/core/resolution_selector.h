#pragma once
#include <vector>
#include "scamera/core/types.h"

namespace scamera {

struct Resolution {
    int width;
    int height;
};

class ResolutionSelector {
public:
    Resolution select(WorkMode mode, int screenWidth, int screenHeight, const std::vector<Resolution>& supported) const;
};

} // namespace scamera
