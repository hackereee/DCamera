#include "scamera/core/types.h"
int main() {
    return static_cast<int>(scamera::WorkMode::ANALYSIS) == 1 ? 0 : 1;
}
