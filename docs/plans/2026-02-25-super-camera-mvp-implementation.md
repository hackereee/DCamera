# 超级相机 MVP 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 构建可落地的 V1 原生相机库：Android/iOS 双端原生控制，bgfx 统一预览（纯预览/分析预览/录像预览），支持拍照、录像与基础可复用 UI。

**架构：** 采集和编码封装保留平台原生实现；共享 C++/bgfx 渲染核心负责预览与离屏输出。录像编码输入来自 bgfx 离屏结果，保证预览与成片一致（所见即所得）。

**技术栈：** Android Camera2 + MediaCodec/MediaMuxer + Kotlin/JUnit；iOS AVCaptureSession + AVAssetWriter + Swift/XCTest；Shared C++17 + bgfx + CMake/CTest。

---

## 执行约束

- 每个任务严格执行 TDD：先写失败测试，再最小实现，再验证通过。
- 单个任务控制在 2-5 分钟动作粒度。
- 每任务单独提交，保持小步提交历史。
- 任一异常失败使用 `@systematic-debugging` 排查。
- 任务或里程碑声明完成前执行 `@verification-before-completion`。

### 任务 1：搭建工程骨架与最小可构建基线

**文件：**
- 新建：`CMakeLists.txt`
- 新建：`shared/render-core/CMakeLists.txt`
- 新建：`shared/render-core/tests/test_build_smoke.cpp`
- 新建：`android/settings.gradle.kts`
- 新建：`android/build.gradle.kts`
- 新建：`ios/SuperCameraKit.xcodeproj/project.pbxproj`（或等效生成文件）

**步骤 1：写失败测试**

```cpp
// shared/render-core/tests/test_build_smoke.cpp
int main() {
    return 1;
}
```

**步骤 2：运行并确认失败**

运行：`cmake -S . -B build && cmake --build build && ctest --test-dir build --output-on-failure`
预期：`test_build_smoke` 失败。

**步骤 3：最小实现**

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

**步骤 4：运行并确认通过**

运行：`cmake -S . -B build && cmake --build build && ctest --test-dir build --output-on-failure`
预期：`test_build_smoke` 通过。

**步骤 5：提交**

```bash
git add CMakeLists.txt shared/render-core/CMakeLists.txt shared/render-core/tests/test_build_smoke.cpp android ios
git commit -m "chore: 初始化多端工程骨架与构建基线"
```

### 任务 2：共享契约类型（模式/状态/错误码）

**文件：**
- 新建：`shared/render-core/include/scamera/core/types.h`
- 新建：`shared/render-core/src/types.cpp`
- 新建：`shared/render-core/tests/test_types.cpp`
- 修改：`shared/render-core/CMakeLists.txt`

**步骤 1：写失败测试**

```cpp
#include "scamera/core/types.h"
int main() {
    return static_cast<int>(scamera::WorkMode::ANALYSIS) == 1 ? 0 : 1;
}
```

**步骤 2：运行并确认失败**

运行：`cmake --build build && ctest --test-dir build -R test_types --output-on-failure`
预期：头文件或符号缺失导致失败。

**步骤 3：最小实现**

```cpp
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

**步骤 4：运行并确认通过**

运行：`cmake --build build && ctest --test-dir build -R test_types --output-on-failure`
预期：`test_types` 通过。

**步骤 5：提交**

```bash
git add shared/render-core/include/scamera/core/types.h shared/render-core/src/types.cpp shared/render-core/tests/test_types.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: 新增共享模式状态与错误码契约"
```

### 任务 3：实现共享状态机

**文件：**
- 新建：`shared/render-core/include/scamera/core/state_machine.h`
- 新建：`shared/render-core/src/state_machine.cpp`
- 新建：`shared/render-core/tests/test_state_machine.cpp`
- 修改：`shared/render-core/CMakeLists.txt`

**步骤 1：写失败测试**

```cpp
#include "scamera/core/state_machine.h"
int main() {
    scamera::StateMachine sm;
    if (!sm.transition(scamera::CameraState::INITIALIZING)) return 1;
    return sm.current() == scamera::CameraState::INITIALIZING ? 0 : 1;
}
```

**步骤 2：运行并确认失败**

运行：`cmake --build build && ctest --test-dir build -R test_state_machine --output-on-failure`
预期：缺失实现或状态切换错误导致失败。

**步骤 3：最小实现**

```cpp
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
```

**步骤 4：运行并确认通过**

运行：`cmake --build build && ctest --test-dir build -R test_state_machine --output-on-failure`
预期：通过。

**步骤 5：提交**

```bash
git add shared/render-core/include/scamera/core/state_machine.h shared/render-core/src/state_machine.cpp shared/render-core/tests/test_state_machine.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: 实现共享生命周期状态机"
```

### 任务 4：实现 ResolutionSelector（按模式选择分辨率）

**文件：**
- 新建：`shared/render-core/include/scamera/core/resolution_selector.h`
- 新建：`shared/render-core/src/resolution_selector.cpp`
- 新建：`shared/render-core/tests/test_resolution_selector.cpp`
- 修改：`shared/render-core/CMakeLists.txt`

**步骤 1：写失败测试**

```cpp
#include "scamera/core/resolution_selector.h"

int main() {
    using namespace scamera;
    ResolutionSelector selector;
    Resolution r = selector.select(WorkMode::VIDEO, 1080, 1920, {{1280, 720}, {1920, 1080}});
    return (r.width == 1920 && r.height == 1080) ? 0 : 1;
}
```

**步骤 2：运行并确认失败**

运行：`cmake --build build && ctest --test-dir build -R test_resolution_selector --output-on-failure`
预期：类或策略缺失导致失败。

**步骤 3：最小实现**

```cpp
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
```

```cpp
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
```

**步骤 4：运行并确认通过**

运行：`cmake --build build && ctest --test-dir build -R test_resolution_selector --output-on-failure`
预期：通过。

**步骤 5：提交**

```bash
git add shared/render-core/include/scamera/core/resolution_selector.h shared/render-core/src/resolution_selector.cpp shared/render-core/tests/test_resolution_selector.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: 实现按模式分辨率选择器"
```

### 任务 5：共享渲染管线接口（预览+离屏）

**文件：**
- 新建：`shared/render-core/include/scamera/render/render_pipeline.h`
- 新建：`shared/render-core/src/render_pipeline.cpp`
- 新建：`shared/render-core/tests/test_render_pipeline.cpp`
- 修改：`shared/render-core/CMakeLists.txt`

**步骤 1：写失败测试**

```cpp
#include "scamera/render/render_pipeline.h"

int main() {
    scamera::RenderPipeline p;
    bool ok = p.configurePreview(1280, 720) && p.configureOffscreen(1920, 1080);
    return ok ? 0 : 1;
}
```

**步骤 2：运行并确认失败**

运行：`cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`
预期：接口未实现导致失败。

**步骤 3：最小实现**

```cpp
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

**步骤 4：运行并确认通过**

运行：`cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`
预期：通过。

**步骤 5：提交**

```bash
git add shared/render-core/include/scamera/render/render_pipeline.h shared/render-core/src/render_pipeline.cpp shared/render-core/tests/test_render_pipeline.cpp shared/render-core/CMakeLists.txt
git commit -m "feat: 新增预览与离屏渲染接口"
```

### 任务 6：Android 门面层与状态映射

**文件：**
- 新建：`android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`
- 新建：`android/supercamera/src/main/java/com/dcamera/core/CameraEvent.kt`
- 新建：`android/supercamera/src/test/java/com/dcamera/SuperCameraStateTest.kt`
- 新建：`android/supercamera/build.gradle.kts`
- 修改：`android/settings.gradle.kts`

**步骤 1：写失败测试**

```kotlin
package com.dcamera

import kotlin.test.Test
import kotlin.test.assertEquals

class SuperCameraStateTest {
    @Test
    fun 切换到视频模式后门面状态正确更新() {
        val camera = SuperCamera()
        camera.setWorkMode(WorkMode.VIDEO)
        assertEquals(WorkMode.VIDEO, camera.currentWorkMode())
    }
}
```

**步骤 2：运行并确认失败**

运行：`./gradlew :android:supercamera:testDebugUnitTest --tests "com.dcamera.SuperCameraStateTest"`
预期：`SuperCamera` 或 `WorkMode` 未定义导致失败。

**步骤 3：最小实现**

```kotlin
package com.dcamera

enum class WorkMode { PURE_PREVIEW, ANALYSIS, PHOTO, VIDEO }

class SuperCamera {
    private var mode: WorkMode = WorkMode.PURE_PREVIEW
    fun setWorkMode(next: WorkMode) { mode = next }
    fun currentWorkMode(): WorkMode = mode
}
```

**步骤 4：运行并确认通过**

运行：`./gradlew :android:supercamera:testDebugUnitTest --tests "com.dcamera.SuperCameraStateTest"`
预期：通过。

**步骤 5：提交**

```bash
git add android/supercamera android/settings.gradle.kts
git commit -m "feat(android): 门面模式状态映射与单测"
```

### 任务 7：Android Camera2 到 bgfx 预览桥接

**文件：**
- 新建：`android/supercamera/src/main/java/com/dcamera/camera2/Camera2SessionController.kt`
- 新建：`android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt`
- 新建：`android/supercamera/src/androidTest/java/com/dcamera/PreviewPipelineInstrumentedTest.kt`
- 修改：`android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`

**步骤 1：写失败测试**

```kotlin
@Test
fun startPreview后状态进入PREVIEWING() {
    val camera = SuperCamera()
    camera.startPreview(FakeSurfaceHandle(1L))
    assertEquals(CameraState.PREVIEWING, camera.currentState())
}
```

**步骤 2：运行并确认失败**

运行：`./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.PreviewPipelineInstrumentedTest`
预期：预览桥接或状态流转未实现导致失败。

**步骤 3：最小实现**

```kotlin
package com.dcamera.render

class PreviewRenderBridge {
    fun attachSurface(surfaceHandle: Long): Boolean = surfaceHandle != 0L
    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean = frameHandle != 0L && tsNs >= 0
}
```

```kotlin
enum class CameraState { IDLE, INITIALIZING, PREVIEWING, CAPTURING, RECORDING, RELEASING }

private var state: CameraState = CameraState.IDLE
fun currentState(): CameraState = state
fun startPreview(surface: FakeSurfaceHandle) {
    state = CameraState.INITIALIZING
    state = CameraState.PREVIEWING
}
```

**步骤 4：运行并确认通过**

运行：`./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.PreviewPipelineInstrumentedTest`
预期：通过。

**步骤 5：提交**

```bash
git add android/supercamera/src/main android/supercamera/src/androidTest
git commit -m "feat(android): 接入Camera2到bgfx预览桥接链路"
```

### 任务 8：Android 拍照与 bgfx 离屏录像控制器

**文件：**
- 新建：`android/supercamera/src/main/java/com/dcamera/capture/CaptureController.kt`
- 新建：`android/supercamera/src/main/java/com/dcamera/record/RecordController.kt`
- 新建：`android/supercamera/src/main/java/com/dcamera/record/BgfxOffscreenFrameSource.kt`
- 新建：`android/supercamera/src/androidTest/java/com/dcamera/RecordControllerInstrumentedTest.kt`
- 修改：`android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`

**步骤 1：写失败测试**

```kotlin
@Test
fun startStopRecord返回mp4路径() {
    val controller = RecordController(FakeBgfxFrameSource())
    controller.startRecord("/tmp/test.mp4")
    val result = controller.stopRecord()
    assertTrue(result.path.endsWith(".mp4"))
}
```

**步骤 2：运行并确认失败**

运行：`./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.RecordControllerInstrumentedTest`
预期：录像控制器或离屏输入未实现导致失败。

**步骤 3：最小实现**

```kotlin
package com.dcamera.record

interface BgfxOffscreenFrameSource {
    fun nextFrame(): ByteArray?
}
```

```kotlin
package com.dcamera.record

data class RecordResult(val path: String)

class RecordController(private val frameSource: BgfxOffscreenFrameSource) {
    private var output: String = ""
    fun startRecord(path: String) { output = path }
    fun stopRecord(): RecordResult = RecordResult(output)
}
```

**步骤 4：运行并确认通过**

运行：`./gradlew :android:supercamera:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.dcamera.RecordControllerInstrumentedTest`
预期：通过。

**步骤 5：提交**

```bash
git add android/supercamera/src/main android/supercamera/src/androidTest
git commit -m "feat(android): 新增拍照与bgfx离屏录像控制器"
```

### 任务 9：iOS 门面层与预览桥接

**文件：**
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift`
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift`
- 新建：`ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift`
- 新建：`ios/SuperCameraKit/Tests/SuperCameraKitTests/PreviewPipelineTests.swift`

**步骤 1：写失败测试**

```swift
import XCTest
@testable import SuperCameraKit

final class SuperCameraStateTests: XCTestCase {
    func test切换视频模式后门面状态更新() {
        let camera = SuperCamera()
        camera.setWorkMode(.video)
        XCTAssertEqual(camera.currentWorkMode(), .video)
    }
}
```

**步骤 2：运行并确认失败**

运行：`xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/SuperCameraStateTests`
预期：门面层未实现导致失败。

**步骤 3：最小实现**

```swift
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
import Foundation

public final class PreviewRenderBridge {
    public init() {}
    public func attach(surfaceHandle: UInt64) -> Bool { surfaceHandle != 0 }
    public func submitFrame(frameHandle: UInt64, timestampNs: Int64) -> Bool { frameHandle != 0 && timestampNs >= 0 }
}
```

**步骤 4：运行并确认通过**

运行：`xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/SuperCameraStateTests`
预期：通过。

**步骤 5：提交**

```bash
git add ios/SuperCameraKit
git commit -m "feat(ios): 门面模式API与预览桥接基础实现"
```

### 任务 10：iOS 拍照与 bgfx 离屏录像控制器

**文件：**
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/CaptureController.swift`
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/RecordController.swift`
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/BgfxOffscreenFrameSource.swift`
- 新建：`ios/SuperCameraKit/Tests/SuperCameraKitTests/RecordControllerTests.swift`

**步骤 1：写失败测试**

```swift
import XCTest
@testable import SuperCameraKit

final class RecordControllerTests: XCTestCase {
    func test停止录像返回mp4路径() {
        let controller = RecordController(frameSource: FakeBgfxSource())
        controller.startRecord(path: "/tmp/out.mp4")
        let result = controller.stopRecord()
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
    }
}
```

**步骤 2：运行并确认失败**

运行：`xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/RecordControllerTests`
预期：录像控制器或协议未实现导致失败。

**步骤 3：最小实现**

```swift
import Foundation

public protocol BgfxOffscreenFrameSource {
    func nextFrame() -> Data?
}
```

```swift
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

**步骤 4：运行并确认通过**

运行：`xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests/RecordControllerTests`
预期：通过。

**步骤 5：提交**

```bash
git add ios/SuperCameraKit
git commit -m "feat(ios): 新增拍照与bgfx离屏录像控制器"
```

### 任务 11：基础 UI 组件（Android + iOS）

**文件：**
- 新建：`android/supercamera-ui/src/main/java/com/dcamera/ui/BasicCameraView.kt`
- 新建：`android/supercamera-ui/src/test/java/com/dcamera/ui/BasicCameraViewTest.kt`
- 新建：`ios/SuperCameraUI/Sources/SuperCameraUI/BasicCameraView.swift`
- 新建：`ios/SuperCameraUI/Tests/SuperCameraUITests/BasicCameraViewTests.swift`

**步骤 1：写失败测试**

```kotlin
@Test
fun 点击录制按钮后显示REC角标() {
    val view = BasicCameraView(FakeContext())
    view.onRecordTapped()
    assertEquals("REC", view.recordingBadgeText())
}
```

```swift
func test点击录制后显示REC标记() {
    let view = BasicCameraView()
    view.onRecordTapped()
    XCTAssertEqual(view.recordingBadgeText(), "REC")
}
```

**步骤 2：运行并确认失败**

运行：`./gradlew :android:supercamera-ui:testDebugUnitTest`
预期：Android 失败（类缺失）。

运行：`xcodebuild test -scheme SuperCameraUI -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraUITests/BasicCameraViewTests`
预期：iOS 失败（类缺失）。

**步骤 3：最小实现**

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

**步骤 4：运行并确认通过**

运行：`./gradlew :android:supercamera-ui:testDebugUnitTest`
预期：通过。

运行：`xcodebuild test -scheme SuperCameraUI -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraUITests/BasicCameraViewTests`
预期：通过。

**步骤 5：提交**

```bash
git add android/supercamera-ui ios/SuperCameraUI
git commit -m "feat(ui): 增加可替换基础相机UI组件"
```

### 任务 12：可观测性契约与双端映射

**文件：**
- 新建：`shared/render-core/include/scamera/telemetry/metrics.h`
- 新建：`android/supercamera/src/main/java/com/dcamera/telemetry/SessionMetrics.kt`
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/SessionMetrics.swift`
- 新建：`shared/render-core/tests/test_metrics_contract.cpp`

**步骤 1：写失败测试**

```cpp
#include "scamera/telemetry/metrics.h"
int main() {
    scamera::SessionMetrics m;
    m.firstFrameLatencyMs = 320;
    return m.firstFrameLatencyMs == 320 ? 0 : 1;
}
```

**步骤 2：运行并确认失败**

运行：`cmake --build build && ctest --test-dir build -R test_metrics_contract --output-on-failure`
预期：契约缺失导致失败。

**步骤 3：最小实现**

```cpp
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

**步骤 4：运行并确认通过**

运行：`cmake --build build && ctest --test-dir build -R test_metrics_contract --output-on-failure`
预期：通过。

**步骤 5：提交**

```bash
git add shared/render-core/include/scamera/telemetry/metrics.h shared/render-core/tests/test_metrics_contract.cpp android/supercamera/src/main/java/com/dcamera/telemetry/SessionMetrics.kt ios/SuperCameraKit/Sources/SuperCameraKit/SessionMetrics.swift
git commit -m "feat: 增加跨端会话指标契约与映射"
```

### 任务 13：端到端样例与验证脚本

**文件：**
- 新建：`samples/android-app/`（最小接入样例）
- 新建：`samples/ios-app/`（最小接入样例）
- 新建：`scripts/verify_mvp.sh`
- 新建：`docs/testing/mvp-manual-checklist.md`

**步骤 1：先写失败脚本**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "FAIL: 验证步骤尚未实现"
exit 1
```

**步骤 2：运行并确认失败**

运行：`bash scripts/verify_mvp.sh`
预期：失败并打印失败原因。

**步骤 3：最小实现**

```bash
#!/usr/bin/env bash
set -euo pipefail

cmake --build build
ctest --test-dir build --output-on-failure
./gradlew :android:supercamera:testDebugUnitTest
xcodebuild test -scheme SuperCameraKit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SuperCameraKitTests

echo "PASS: MVP 验证基线通过"
```

**步骤 4：运行并确认通过**

运行：`bash scripts/verify_mvp.sh`
预期：0 退出码并输出 `PASS`。

**步骤 5：提交**

```bash
git add samples scripts/verify_mvp.sh docs/testing/mvp-manual-checklist.md
git commit -m "test: 增加端到端样例与MVP验证脚本"
```

## 里程碑退出标准

- M1（任务 1-5）：共享核心契约与渲染接口测试全部通过。
- M2（任务 6-8）：Android 预览/拍照/录像链路测试通过。
- M3（任务 9-10）：iOS 预览/拍照/录像链路测试通过。
- M4（任务 11）：双端基础 UI 组件测试通过。
- M5（任务 12-13）：可观测性与验证脚本可稳定复跑。

## 风险与控制

- bgfx 离屏到编码输入的性能敏感，必须保持有界队列与背压控制。
- Android 7.0 机型碎片化高，需尽早维护 Camera2 机型兼容策略。
- iOS 录像时间戳漂移风险需通过 `avDriftMs` 指标持续监控。

## 交接说明

- 在独立 worktree 中按任务顺序执行。
- 每个任务完成即提交，避免跨任务叠改。
- V1 不落地滤镜/水印功能，仅保留 RenderPass 扩展钩子。
