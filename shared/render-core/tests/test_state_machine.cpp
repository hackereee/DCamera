#include "scamera/core/state_machine.h"

static int failures = 0;
#define ASSERT(expr) do { if (!(expr)) { failures++; } } while(0)

int main() {
    using namespace scamera;

    // 初始状态
    { StateMachine sm; ASSERT(sm.current() == CameraState::IDLE); }

    // 完整生命周期
    {
        StateMachine sm;
        ASSERT(sm.transition(CameraState::INITIALIZING));
        ASSERT(sm.transition(CameraState::PREVIEWING));
        ASSERT(sm.transition(CameraState::RECORDING));
        ASSERT(sm.transition(CameraState::PREVIEWING));
        ASSERT(sm.transition(CameraState::RELEASING));
        ASSERT(sm.transition(CameraState::IDLE));
    }

    // 拍照路径
    {
        StateMachine sm;
        sm.transition(CameraState::INITIALIZING);
        sm.transition(CameraState::PREVIEWING);
        ASSERT(sm.transition(CameraState::CAPTURING));
        ASSERT(sm.current() == CameraState::CAPTURING);
        ASSERT(sm.transition(CameraState::PREVIEWING));
    }

    // 非法转换
    {
        StateMachine sm;
        ASSERT(!sm.transition(CameraState::PREVIEWING)); // IDLE -> PREVIEWING 非法
        ASSERT(!sm.transition(CameraState::RECORDING));  // IDLE -> RECORDING 非法
        ASSERT(sm.current() == CameraState::IDLE);       // 状态不变
    }

    // PREVIEWING 不能直接到 IDLE
    {
        StateMachine sm;
        sm.transition(CameraState::INITIALIZING);
        sm.transition(CameraState::PREVIEWING);
        ASSERT(!sm.transition(CameraState::IDLE));
    }

    // RECORDING 不能直接到 IDLE
    {
        StateMachine sm;
        sm.transition(CameraState::INITIALIZING);
        sm.transition(CameraState::PREVIEWING);
        sm.transition(CameraState::RECORDING);
        ASSERT(!sm.transition(CameraState::IDLE));
        ASSERT(!sm.transition(CameraState::RELEASING));
    }

    return failures;
}
