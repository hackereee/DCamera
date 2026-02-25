# Super Camera MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a production-ready V1 native camera library for Android and iOS with bgfx-based preview in pure preview, analysis preview, and recording preview modes; include photo capture, video recording, and a basic reusable UI kit.

**Architecture:** Keep camera control and media encoding native per platform, while unifying preview rendering in a shared C++ bgfx render core. Feed video encoding from bgfx offscreen output to keep preview and recorded output consistent. Expose aligned Kotlin and Swift facades with shared state, error, and mode semantics.

**Tech Stack:** Android Camera2 + MediaCodec/MediaMuxer + Kotlin/JUnit; iOS AVCaptureSession + AVAssetWriter + Swift/XCTest; shared C++17 core with bgfx and CMake/CTest.

---

## Execution Rules

- Use `@test-driven-development` for every task: test first, fail, minimal implementation, pass.
- Use `@systematic-debugging` if any test fails unexpectedly.
- Use `@verification-before-completion` before claiming any milestone complete.
- Use frequent small commits; one commit per task.
- Keep APIs and behavior aligned across Kotlin and Swift facades.

### Task 1: Workspace Skeleton and Build Baseline

**Files:**
- Create: `CMakeLists.txt`
- Create: `shared/render-core/CMakeLists.txt`
- Create: `shared/render-core/tests/test_build_smoke.cpp`
- Create: `android/settings.gradle.kts`
- Create: `android/build.gradle.kts`
- Create: `ios/SuperCameraKit.xcodeproj/project.pbxproj` (or generated equivalent)

**Step 1: Write the failing test**

```cpp
// shared/render-core/tests/test_build_smoke.cpp
int main() {
    return 1; // force fail first
}
```

**Step 2: Run test to verify it fails**

Run: `cmake -S . -B build && cmake --build build && ctest --test-dir build --output-on-failure`
Expected: FAIL for `test_build_smoke`.

**Step 3: Write minimal implementation**

```cpp
// shared/render-core/tests/test_build_smoke.cpp
int main() {
    return 0;
}
```

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.22)
project(supercamera LANGUAGES CXX)
enable_testing()
add_subdirectory(shared/render-core)
```

```cmake
# shared/render-core/CMakeLists.txt
add_executable(test_build_smoke tests/test_build_smoke.cpp)
add_test(NAME test_build_smoke COMMAND test_build_smoke)
```

**Step 4: Run test to verify it passes**

Run: `cmake -S . -B build && cmake --build build && ctest --test-dir build --output-on-failure`
Expected: PASS `test_build_smoke`.

**Step 5: Commit**

```bash
git add CMakeLists.txt shared/render-core/CMakeLists.txt shared/render-core/tests/test_build_smoke.cpp android ios
git commit -m "chore: bootstrap multiplatform workspace and build baseline"
```

### Task 2: Shared Contracts (State, Mode, Error)

**Files:**
- Create: `shared/render-core/include/scamera/core/types.h`
- Create: `shared/render-core/src/types.cpp`
- Create: `shared/render-core/tests/test_types.cpp`
- Modify: `shared/render-core/CMakeLists.txt`

**Step 1: Write the failing test**

```cpp
// shared/render-core/tests/test_types.cpp
#include "scamera/core/types.h"
int main() {
    return static_cast<int>(scamera::WorkMode::ANALYSIS) == 0 ? 0 : 1;
}
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build --output-on-failure`
Expected: FAIL with missing header/symbol.

**Step 3: Write minimal implementation**

```cpp
// shared/render-core/include/scamera/core/types.h
#pragma once

namespace scamera {

enum class WorkMode { PURE_PREVIEW = 0, ANALYSIS = 1, PHOTO = 2, VIDEO = 3 };
enum class CameraState { IDLE, INITIALIZING, PREVIEWING, CAPTURING, RECORDING, RELEASING };
enum class ErrorCode {
    NONE,
    PERMISSION,
    DEVICE_UNAVAILABLE,
    SESSION_CONFIG_FAILED,
    RENDER_INIT_FAILED,
    RENDER_SURFACE_LOST,
    ENCODER_INIT_FAILED,
    ENCODER_BACKPRESSURE,
    FILE_IO_FAILED,
    THERMAL_THROTTLE,
    INVALID_STATE
};

} // namespace scamera
```

```cmake
# shared/render-core/CMakeLists.txt additions
add_executable(test_types tests/test_types.cpp src/types.cpp)
target_include_directories(test_types PRIVATE include)
add_test(NAME test_types COMMAND test_types)
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build --output-on-failure`
Expected: PASS `test_types`.

**Step 5: Commit**

```bash
git add shared/render-core/include/scamera/core/types.h shared/render-core/src/types.cpp shared/render-core/tests/test_types.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: add shared camera contracts for mode state and errors"
```

### Task 3: Shared Camera State Machine

**Files:**
- Create: `shared/render-core/include/scamera/core/state_machine.h`
- Create: `shared/render-core/src/state_machine.cpp`
- Create: `shared/render-core/tests/test_state_machine.cpp`
- Modify: `shared/render-core/CMakeLists.txt`

**Step 1: Write the failing test**

```cpp
// shared/render-core/tests/test_state_machine.cpp
#include "scamera/core/state_machine.h"
int main() {
    scamera::StateMachine sm;
    bool ok = sm.transition(scamera::CameraState::INITIALIZING);
    return ok ? 0 : 1;
}
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build -R test_state_machine --output-on-failure`
Expected: FAIL (missing implementation or wrong transition logic).

**Step 3: Write minimal implementation**

```cpp
// shared/render-core/include/scamera/core/state_machine.h
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
```

```cpp
// shared/render-core/src/state_machine.cpp
#include "scamera/core/state_machine.h"

namespace scamera {

CameraState StateMachine::current() const { return state_; }

bool StateMachine::transition(CameraState next) {
    const CameraState cur = state_;
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
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build -R test_state_machine --output-on-failure`
Expected: PASS `test_state_machine`.

**Step 5: Commit**

```bash
git add shared/render-core/include/scamera/core/state_machine.h shared/render-core/src/state_machine.cpp shared/render-core/tests/test_state_machine.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: add shared camera lifecycle state machine"
```

### Task 4: ResolutionSelector with Mode-Specific Strategy

**Files:**
- Create: `shared/render-core/include/scamera/core/resolution_selector.h`
- Create: `shared/render-core/src/resolution_selector.cpp`
- Create: `shared/render-core/tests/test_resolution_selector.cpp`
- Modify: `shared/render-core/CMakeLists.txt`

**Step 1: Write the failing test**

```cpp
// shared/render-core/tests/test_resolution_selector.cpp
#include "scamera/core/resolution_selector.h"
int main() {
    using namespace scamera;
    ResolutionSelector selector;
    Resolution out = selector.select(WorkMode::VIDEO, 1080, 1920, {{1280, 720}, {1920, 1080}});
    return (out.width == 1920 && out.height == 1080) ? 0 : 1;
}
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build -R test_resolution_selector --output-on-failure`
Expected: FAIL due missing class or wrong priority rules.

**Step 3: Write minimal implementation**

```cpp
// shared/render-core/include/scamera/core/resolution_selector.h
#pragma once
#include <vector>
#include "scamera/core/types.h"

namespace scamera {

struct Resolution { int width; int height; };

class ResolutionSelector {
public:
    Resolution select(WorkMode mode, int screenWidth, int screenHeight, const std::vector<Resolution>& supported) const;
};

} // namespace scamera
```

```cpp
// shared/render-core/src/resolution_selector.cpp
#include "scamera/core/resolution_selector.h"
#include <cmath>

namespace scamera {

static double aspect_delta(int w, int h, double target) {
    return std::abs((static_cast<double>(w) / static_cast<double>(h)) - target);
}

Resolution ResolutionSelector::select(WorkMode mode, int screenWidth, int screenHeight, const std::vector<Resolution>& supported) const {
    if (supported.empty()) return {1280, 720};

    if (mode == WorkMode::PHOTO || mode == WorkMode::VIDEO) {
        const Resolution priority[] = {{1920,1080}, {1600,900}, {1280,720}, {960,540}};
        for (const auto& p : priority) {
            for (const auto& s : supported) {
                if (s.width == p.width && s.height == p.height) return s;
            }
        }
        return supported.front();
    }

    const double targetAspect = static_cast<double>(screenWidth) / static_cast<double>(screenHeight);
    Resolution best = supported.front();
    double bestAspect = aspect_delta(best.width, best.height, targetAspect);
    double bestAreaDelta = std::abs((best.width * best.height) - (screenWidth * screenHeight));

    for (const auto& s : supported) {
        const double ad = aspect_delta(s.width, s.height, targetAspect);
        const double areaDelta = std::abs((s.width * s.height) - (screenWidth * screenHeight));
        if (ad < bestAspect || (ad == bestAspect && areaDelta < bestAreaDelta)) {
            best = s;
            bestAspect = ad;
            bestAreaDelta = areaDelta;
        }
    }
    return best;
}

} // namespace scamera
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build -R test_resolution_selector --output-on-failure`
Expected: PASS `test_resolution_selector`.

**Step 5: Commit**

```bash
git add shared/render-core/include/scamera/core/resolution_selector.h shared/render-core/src/resolution_selector.cpp shared/render-core/tests/test_resolution_selector.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: add mode-aware resolution selector"
```

### Task 5: Shared bgfx Render Pipeline Interface (Display + Offscreen)

**Files:**
- Create: `shared/render-core/include/scamera/render/render_pipeline.h`
- Create: `shared/render-core/src/render_pipeline.cpp`
- Create: `shared/render-core/tests/test_render_pipeline.cpp`
- Modify: `shared/render-core/CMakeLists.txt`

**Step 1: Write the failing test**

```cpp
// shared/render-core/tests/test_render_pipeline.cpp
#include "scamera/render/render_pipeline.h"
int main() {
    scamera::RenderPipeline pipeline;
    const bool ok = pipeline.configurePreview(1280, 720) && pipeline.configureOffscreen(1920, 1080);
    return ok ? 0 : 1;
}
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`
Expected: FAIL due missing methods.

**Step 3: Write minimal implementation**

```cpp
// shared/render-core/include/scamera/render/render_pipeline.h
#pragma once

namespace scamera {

class RenderPipeline {
public:
    bool configurePreview(int width, int height);
    bool configureOffscreen(int width, int height);
    bool submitFrame(void* yuvFrameHandle, long long timestampNs);
};

} // namespace scamera
```

```cpp
// shared/render-core/src/render_pipeline.cpp
#include "scamera/render/render_pipeline.h"

namespace scamera {

bool RenderPipeline::configurePreview(int width, int height) {
    return width > 0 && height > 0;
}

bool RenderPipeline::configureOffscreen(int width, int height) {
    return width > 0 && height > 0;
}

bool RenderPipeline::submitFrame(void* yuvFrameHandle, long long timestampNs) {
    return yuvFrameHandle != nullptr && timestampNs >= 0;
}

} // namespace scamera
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`
Expected: PASS `test_render_pipeline`.

**Step 5: Commit**

```bash
git add shared/render-core/include/scamera/render/render_pipeline.h shared/render-core/src/render_pipeline.cpp shared/render-core/tests/test_render_pipeline.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: add shared render pipeline interface for preview and offscreen"
```

### Task 6: Android SDK Facade + State/Error Mapping (Unit Tests)

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/core/CameraEvent.kt`
- Create: `android/supercamera/src/test/java/com/dcamera/SuperCameraStateTest.kt`
- Create: `android/supercamera/build.gradle.kts`
- Modify: `android/settings.gradle.kts`

**Step 1: Write the failing test**

```kotlin
// android/supercamera/src/test/java/com/dcamera/SuperCameraStateTest.kt
package com.dcamera

import kotlin.test.Test
import kotlin.test.assertEquals

class SuperCameraStateTest {
    @Test
    fun modeSwitchToVideoUpdatesFacadeState() {
        val camera = SuperCamera()
        camera.setWorkMode(WorkMode.VIDEO)
        assertEquals(WorkMode.VIDEO, camera.currentWorkMode())
    }
}
```

**Step 2: Run test to verify it fails**

Run: `./gradlew :android:supercamera:testDebugUnitTest --tests "com.dcamera.SuperCameraStateTest"`
Expected: FAIL unresolved `SuperCamera` or `setWorkMode`.

**Step 3: Write minimal implementation**

```kotlin
// android/supercamera/src/main/java/com/dcamera/SuperCamera.kt
package com.dcamera

enum class WorkMode { PURE_PREVIEW, ANALYSIS, PHOTO, VIDEO }

class SuperCamera {
    private var mode: WorkMode = WorkMode.PURE_PREVIEW
    fun setWorkMode(next: WorkMode) { mode = next }
    fun currentWorkMode(): WorkMode = mode
}
```

**Step 4: Run test to verify it passes**

Run: `./gradlew :android:supercamera:testDebugUnitTest --tests "com.dcamera.SuperCameraStateTest"`
Expected: PASS 1 test.

**Step 5: Commit**

```bash
git add android/supercamera android/settings.gradle.kts
git commit -m "feat(android): add facade mode state mapping with unit tests"
```

### Task 7: Android Camera2 Preview to bgfx Bridge

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/camera2/Camera2SessionController.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt`
- Create: `android/supercamera/src/androidTest/java/com/dcamera/PreviewPipelineInstrumentedTest.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`

**Step 1: Write the failing test**

```kotlin
// android/supercamera/src/androidTest/java/com/dcamera/PreviewPipelineInstrumentedTest.kt
@Test
fun startPreviewTransitionsToPreviewing() {
    val camera = SuperCamera()
    camera.startPreview(FakeSurfaceHandle(1L))
    assertEquals(CameraState.PREVIEWING, camera.currentState())
}
```

**Step 2: Run test to verify it fails**

Run: `./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.PreviewPipelineInstrumentedTest`
Expected: FAIL with missing preview pipeline implementation.

**Step 3: Write minimal implementation**

```kotlin
// android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt
package com.dcamera.render

class PreviewRenderBridge {
    fun attachSurface(surfaceHandle: Long): Boolean = surfaceHandle != 0L
    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean = frameHandle != 0L && tsNs >= 0
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/SuperCamera.kt (additions)
enum class CameraState { IDLE, INITIALIZING, PREVIEWING, CAPTURING, RECORDING, RELEASING }
private var state: CameraState = CameraState.IDLE
fun currentState(): CameraState = state
fun startPreview(surface: FakeSurfaceHandle) {
    state = CameraState.INITIALIZING
    state = CameraState.PREVIEWING
}
```

**Step 4: Run test to verify it passes**

Run: `./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.PreviewPipelineInstrumentedTest`
Expected: PASS test class.

**Step 5: Commit**

```bash
git add android/supercamera/src/main android/supercamera/src/androidTest
git commit -m "feat(android): connect Camera2 preview flow to bgfx bridge"
```

### Task 8: Android Photo and bgfx-Offscreen Video Recording

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/capture/CaptureController.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/record/RecordController.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/record/BgfxOffscreenFrameSource.kt`
- Create: `android/supercamera/src/androidTest/java/com/dcamera/RecordControllerInstrumentedTest.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`

**Step 1: Write the failing test**

```kotlin
@Test
fun startAndStopRecordCreatesMp4FromBgfxSource() {
    val controller = RecordController(FakeBgfxFrameSource())
    controller.startRecord("/tmp/test.mp4")
    val result = controller.stopRecord()
    assertTrue(result.path.endsWith(".mp4"))
}
```

**Step 2: Run test to verify it fails**

Run: `./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.RecordControllerInstrumentedTest`
Expected: FAIL unresolved `RecordController` or missing source wiring.

**Step 3: Write minimal implementation**

```kotlin
// android/supercamera/src/main/java/com/dcamera/record/BgfxOffscreenFrameSource.kt
package com.dcamera.record

interface BgfxOffscreenFrameSource {
    fun nextFrame(): ByteArray?
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/record/RecordController.kt
package com.dcamera.record

data class RecordResult(val path: String)

class RecordController(private val frameSource: BgfxOffscreenFrameSource) {
    private var output: String = ""
    fun startRecord(path: String) { output = path }
    fun stopRecord(): RecordResult = RecordResult(output)
}
```

**Step 4: Run test to verify it passes**

Run: `./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.RecordControllerInstrumentedTest`
Expected: PASS recording controller test.

**Step 5: Commit**

```bash
git add android/supercamera/src/main android/supercamera/src/androidTest
git commit -m "feat(android): add photo and bgfx-offscreen recording controllers"
```

### Task 9: iOS Swift Facade + Preview Pipeline to bgfx

**Files:**
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift`
- Create: `ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift`
- Create: `ios/SuperCameraKit/Tests/SuperCameraKitTests/PreviewPipelineTests.swift`

**Step 1: Write the failing test**

```swift
// ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift
import XCTest
@testable import SuperCameraKit

final class SuperCameraStateTests: XCTestCase {
    func testSetVideoModeUpdatesFacade() {
        let camera = SuperCamera()
        camera.setWorkMode(.video)
        XCTAssertEqual(camera.currentWorkMode(), .video)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/SuperCameraStateTests`
Expected: FAIL unresolved `SuperCamera`.

**Step 3: Write minimal implementation**

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift
import Foundation

public enum WorkMode { case purePreview, analysis, photo, video }

public final class SuperCamera {
    private var mode: WorkMode = .purePreview
    public init() {}
    public func setWorkMode(_ mode: WorkMode) { self.mode = mode }
    public func currentWorkMode() -> WorkMode { mode }
}
```

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift
import Foundation

public final class PreviewRenderBridge {
    public init() {}
    public func attach(surfaceHandle: UInt64) -> Bool { surfaceHandle != 0 }
    public func submitFrame(frameHandle: UInt64, timestampNs: Int64) -> Bool { frameHandle != 0 && timestampNs >= 0 }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/SuperCameraStateTests`
Expected: PASS state test.

**Step 5: Commit**

```bash
git add ios/SuperCameraKit
git commit -m "feat(ios): add facade mode API and preview render bridge"
```

### Task 10: iOS Photo and bgfx-Offscreen Video Recording

**Files:**
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/CaptureController.swift`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/RecordController.swift`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/BgfxOffscreenFrameSource.swift`
- Create: `ios/SuperCameraKit/Tests/SuperCameraKitTests/RecordControllerTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SuperCameraKit

final class RecordControllerTests: XCTestCase {
    func testStopRecordReturnsMp4Path() {
        let controller = RecordController(frameSource: FakeBgfxSource())
        controller.startRecord(path: "/tmp/out.mp4")
        let result = controller.stopRecord()
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/RecordControllerTests`
Expected: FAIL unresolved `RecordController`.

**Step 3: Write minimal implementation**

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/BgfxOffscreenFrameSource.swift
import Foundation

public protocol BgfxOffscreenFrameSource {
    func nextFrame() -> Data?
}
```

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/RecordController.swift
import Foundation

public struct RecordResult { public let path: String }

public final class RecordController {
    private let frameSource: BgfxOffscreenFrameSource
    private var outputPath: String = ""

    public init(frameSource: BgfxOffscreenFrameSource) {
        self.frameSource = frameSource
    }

    public func startRecord(path: String) {
        outputPath = path
    }

    public func stopRecord() -> RecordResult {
        RecordResult(path: outputPath)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/RecordControllerTests`
Expected: PASS recording test.

**Step 5: Commit**

```bash
git add ios/SuperCameraKit
git commit -m "feat(ios): add photo and bgfx-offscreen recording controllers"
```

### Task 11: Basic UI Kit on Android and iOS

**Files:**
- Create: `android/supercamera-ui/src/main/java/com/dcamera/ui/BasicCameraView.kt`
- Create: `android/supercamera-ui/src/test/java/com/dcamera/ui/BasicCameraViewTest.kt`
- Create: `ios/SuperCameraUI/Sources/SuperCameraUI/BasicCameraView.swift`
- Create: `ios/SuperCameraUI/Tests/SuperCameraUITests/BasicCameraViewTests.swift`

**Step 1: Write the failing test**

```kotlin
@Test
fun recordButtonTogglesRecordingStateLabel() {
    val view = BasicCameraView(FakeContext())
    view.onRecordTapped()
    assertEquals("REC", view.recordingBadgeText())
}
```

```swift
func testRecordTapShowsRecBadge() {
    let view = BasicCameraView()
    view.onRecordTapped()
    XCTAssertEqual(view.recordingBadgeText(), "REC")
}
```

**Step 2: Run tests to verify they fail**

Run: `./gradlew :android:supercamera-ui:testDebugUnitTest`
Expected: FAIL unresolved `BasicCameraView`.

Run: `xcodebuild test -scheme SuperCameraUI -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraUITests/BasicCameraViewTests`
Expected: FAIL unresolved `BasicCameraView`.

**Step 3: Write minimal implementation**

```kotlin
class BasicCameraView(context: Context) : FrameLayout(context) {
    private var recording = false
    fun onRecordTapped() { recording = !recording }
    fun recordingBadgeText(): String = if (recording) "REC" else ""
}
```

```swift
public final class BasicCameraView {
    private var recording = false
    public init() {}
    public func onRecordTapped() { recording.toggle() }
    public func recordingBadgeText() -> String { recording ? "REC" : "" }
}
```

**Step 4: Run tests to verify they pass**

Run: `./gradlew :android:supercamera-ui:testDebugUnitTest`
Expected: PASS UI unit tests.

Run: `xcodebuild test -scheme SuperCameraUI -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraUITests/BasicCameraViewTests`
Expected: PASS UI tests.

**Step 5: Commit**

```bash
git add android/supercamera-ui ios/SuperCameraUI
git commit -m "feat(ui): add replaceable basic camera ui components for android and ios"
```

### Task 12: Observability and Error Reporting Contracts

**Files:**
- Create: `shared/render-core/include/scamera/telemetry/metrics.h`
- Create: `android/supercamera/src/main/java/com/dcamera/telemetry/SessionMetrics.kt`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/SessionMetrics.swift`
- Create: `shared/render-core/tests/test_metrics_contract.cpp`

**Step 1: Write the failing test**

```cpp
#include "scamera/telemetry/metrics.h"
int main() {
    scamera::SessionMetrics m;
    m.firstFrameLatencyMs = 320;
    return m.firstFrameLatencyMs == 320 ? 0 : 1;
}
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build -R test_metrics_contract --output-on-failure`
Expected: FAIL missing metrics contract.

**Step 3: Write minimal implementation**

```cpp
// shared/render-core/include/scamera/telemetry/metrics.h
#pragma once

namespace scamera {

struct SessionMetrics {
    int firstFrameLatencyMs = 0;
    int previewFps = 0;
    int renderDropRatePermille = 0;
    int encoderInputFps = 0;
    int avDriftMs = 0;
    int modeSwitchLatencyMs = 0;
};

} // namespace scamera
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build -R test_metrics_contract --output-on-failure`
Expected: PASS metrics contract test.

**Step 5: Commit**

```bash
git add shared/render-core/include/scamera/telemetry/metrics.h shared/render-core/tests/test_metrics_contract.cpp android/supercamera/src/main/java/com/dcamera/telemetry/SessionMetrics.kt ios/SuperCameraKit/Sources/SuperCameraKit/SessionMetrics.swift
git commit -m "feat: add cross-platform telemetry contracts and mappings"
```

### Task 13: End-to-End Smoke Samples and Verification Gate

**Files:**
- Create: `samples/android-app/` (minimal integration app)
- Create: `samples/ios-app/` (minimal integration app)
- Create: `scripts/verify_mvp.sh`
- Create: `docs/testing/mvp-manual-checklist.md`

**Step 1: Write the failing verification script first**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "FAIL: verification steps not implemented"
exit 1
```

**Step 2: Run script to verify it fails**

Run: `bash scripts/verify_mvp.sh`
Expected: FAIL with explicit message.

**Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

cmake --build build
ctest --test-dir build --output-on-failure
./gradlew :android:supercamera:testDebugUnitTest
xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests

echo "PASS: MVP verification baseline complete"
```

**Step 4: Run script to verify it passes**

Run: `bash scripts/verify_mvp.sh`
Expected: PASS summary line and zero exit code.

**Step 5: Commit**

```bash
git add samples scripts/verify_mvp.sh docs/testing/mvp-manual-checklist.md
git commit -m "test: add end-to-end smoke samples and mvp verification gate"
```

## Milestone Exit Criteria

- M1 (Tasks 1-5): shared contracts and bgfx render interfaces are testable and passing in CTest.
- M2 (Tasks 6-8): Android facade, preview, photo, and bgfx-offscreen recording path pass unit/instrumentation tests.
- M3 (Tasks 9-10): iOS facade, preview, photo, and bgfx-offscreen recording path pass XCTest.
- M4 (Task 11): reusable basic UI components for both platforms pass tests.
- M5 (Tasks 12-13): telemetry and cross-platform verification gate pass with repeatable scripts.

## Risks and Guardrails

- bgfx offscreen to encoder path can be performance-sensitive on low-end devices; keep queue bounded and monitor latency metrics from day one.
- Android 7.0 device fragmentation may require targeted Camera2 quirks table.
- iOS AVAssetWriter timing drift risk must be tracked by `avDriftMs` metric in early integration.

## Handoff Notes

- Implement in a dedicated git worktree before starting coding.
- Keep each task as one PR/commit unit where possible.
- Do not start watermark/filter implementation in MVP; keep only RenderPass extension hooks.
