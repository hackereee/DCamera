#pragma once
#include "scamera/core/types.h"

namespace scamera {

class StateMachine {
public:
    CameraState current() const;
    bool transition(CameraState next);
private:
    CameraState state_ = CameraState::IDLE;
};

} // namespace scamera
