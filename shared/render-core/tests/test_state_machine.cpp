#include "scamera/core/state_machine.h"
int main() {
    scamera::StateMachine sm;
    if (!sm.transition(scamera::CameraState::INITIALIZING)) return 1;
    return sm.current() == scamera::CameraState::INITIALIZING ? 0 : 1;
}
