#include "scamera/core/state_machine.h"

namespace scamera {

CameraState StateMachine::current() const { return state_; }

bool StateMachine::transition(CameraState next) {
    const auto cur = state_;
    const bool valid =
        (cur == CameraState::IDLE && next == CameraState::INITIALIZING) ||
        (cur == CameraState::INITIALIZING && next == CameraState::PREVIEWING) ||
        (cur == CameraState::PREVIEWING && (next == CameraState::CAPTURING || next == CameraState::RECORDING || next == CameraState::RELEASING)) ||
        ((cur == CameraState::CAPTURING || cur == CameraState::RECORDING) && next == CameraState::PREVIEWING) ||
        (cur == CameraState::RELEASING && next == CameraState::IDLE);
    if (!valid) return false;
    state_ = next;
    return true;
}

} // namespace scamera
