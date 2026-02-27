# Preview Phase 1 (Camera2 + AVFoundation + bgfx) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成双端真实预览闭环（Android Camera2 + iOS AVFoundation 采集，统一经 bgfx 渲染），并通过自动化与手工验证。

**Architecture:** 保持 `SuperCamera` 门面与状态机语义不变，新增平台真实预览会话实现，并通过 `PreviewRenderBridge -> RenderPipelinePort` 接入共享渲染层。共享层提供可被 Android/iOS 调用的 C ABI，平台侧分别通过 JNI / C bridge 调用，保证预览显示路径全部经 bgfx。

**Tech Stack:** Kotlin + Camera2 + JUnit + Gradle，Swift + AVFoundation + XCTest + SwiftPM/Xcode，C++17 + CMake + CTest + C ABI bridge。

---

## 执行约束

- 严格按 `@test-driven-development` 执行：每个任务必须先看到失败测试（RED），再最小实现（GREEN）。
- 发现异常先走 `@systematic-debugging`，不并发尝试多个修复。
- 每任务独立提交，保证可回滚。
- 本计划仅覆盖“预览阶段”；前后摄切换、分辨率切换延期到下一阶段。

### Task 1: 调整共享渲染队列策略为 latest-wins（丢旧保新）

**Files:**
- Modify: `shared/render-core/tests/test_render_pipeline.cpp`
- Modify: `shared/render-core/src/render_pipeline.cpp`

**Step 1: Write the failing test**

在 `shared/render-core/tests/test_render_pipeline.cpp` 新增用例（放在“帧队列有界”段之后）：

```cpp
// 队列满时采用 latest-wins：丢弃最旧帧并接收新帧
{
    RenderPipeline p;
    p.configurePreview(1280, 720);
    p.configureOffscreen(1920, 1080);
    char data[4] = {1, 2, 3, 4};
    ASSERT(p.submitFrame(data, 1));
    ASSERT(p.submitFrame(data, 2));
    ASSERT(p.submitFrame(data, 3));
    ASSERT(p.submitFrame(data, 4)); // 旧实现会返回 false

    auto f1 = p.consumeOffscreenFrame();
    ASSERT(f1.timestampNs == 2); // 期望 timestamp=1 被丢弃
}
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`  
Expected: FAIL（第 4 次 `submitFrame` 或首帧时间戳断言失败）。

**Step 3: Write minimal implementation**

在 `shared/render-core/src/render_pipeline.cpp` 的 `submitFrame` 中替换队列满逻辑：

```cpp
if (static_cast<int>(frameQueue_.size()) >= kMaxQueueSize) {
    frameQueue_.pop_front(); // 丢弃最旧帧，确保低延迟预览
}
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`  
Expected: PASS。

**Step 5: Commit**

```bash
git add shared/render-core/tests/test_render_pipeline.cpp \
        shared/render-core/src/render_pipeline.cpp
git commit -m "feat(render-core): use latest-wins frame queue policy"
```

### Task 2: 为共享渲染层提供 C ABI（供 Android/iOS 调用）

**Files:**
- Create: `shared/render-core/include/scamera/render/render_pipeline_c.h`
- Create: `shared/render-core/src/render_pipeline_c.cpp`
- Create: `shared/render-core/tests/test_render_pipeline_c.cpp`
- Modify: `shared/render-core/CMakeLists.txt`

**Step 1: Write the failing test**

新增 `shared/render-core/tests/test_render_pipeline_c.cpp`：

```cpp
#include "scamera/render/render_pipeline_c.h"

int main() {
    auto* p = scamera_render_pipeline_create();
    if (!p) return 1;
    if (!scamera_render_pipeline_configure_preview(p, 1280, 720)) return 2;
    if (!scamera_render_pipeline_configure_offscreen(p, 1280, 720)) return 3;

    unsigned char data[4] = {1, 2, 3, 4};
    if (!scamera_render_pipeline_submit_frame(p, data, 100)) return 4;

    scamera_offscreen_frame f{};
    if (!scamera_render_pipeline_consume_offscreen(p, &f)) return 5;
    if (f.timestamp_ns != 100) return 6;

    scamera_render_pipeline_destroy(p);
    return 0;
}
```

并在 `shared/render-core/CMakeLists.txt` 添加（先不实现 C API）：

```cmake
add_executable(test_render_pipeline_c tests/test_render_pipeline_c.cpp)
target_include_directories(test_render_pipeline_c PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_render_pipeline_c COMMAND test_render_pipeline_c)
```

**Step 2: Run test to verify it fails**

Run: `cmake --build build && ctest --test-dir build -R test_render_pipeline_c --output-on-failure`  
Expected: FAIL（头文件/符号缺失）。

**Step 3: Write minimal implementation**

新增 `render_pipeline_c.h`（核心声明）：

```cpp
#pragma once
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct scamera_render_pipeline scamera_render_pipeline;
typedef struct {
    const void* data;
    int data_size;
    long long timestamp_ns;
} scamera_offscreen_frame;

scamera_render_pipeline* scamera_render_pipeline_create(void);
void scamera_render_pipeline_destroy(scamera_render_pipeline* p);
bool scamera_render_pipeline_configure_preview(scamera_render_pipeline* p, int width, int height);
bool scamera_render_pipeline_configure_offscreen(scamera_render_pipeline* p, int width, int height);
bool scamera_render_pipeline_submit_frame(scamera_render_pipeline* p, void* frame_handle, long long timestamp_ns);
bool scamera_render_pipeline_consume_offscreen(scamera_render_pipeline* p, scamera_offscreen_frame* out);

#ifdef __cplusplus
}
#endif
```

新增 `render_pipeline_c.cpp`：用 `RenderPipeline` 做薄包装。

并在 `shared/render-core/CMakeLists.txt` 增加：

```cmake
add_library(scamera_render_core STATIC
    src/render_pipeline.cpp
    src/render_pipeline_c.cpp
)
target_include_directories(scamera_render_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(test_render_pipeline_c PRIVATE scamera_render_core)
```

**Step 4: Run test to verify it passes**

Run: `cmake --build build && ctest --test-dir build -R test_render_pipeline_c --output-on-failure`  
Expected: PASS。

**Step 5: Commit**

```bash
git add shared/render-core/include/scamera/render/render_pipeline_c.h \
        shared/render-core/src/render_pipeline_c.cpp \
        shared/render-core/tests/test_render_pipeline_c.cpp \
        shared/render-core/CMakeLists.txt
git commit -m "feat(render-core): expose C ABI for preview render pipeline"
```

### Task 3: Android 预览桥接改为真实帧对象而非裸句柄

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/render/PreviewFrame.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/render/RenderPipelinePort.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt`
- Modify: `android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt`

**Step 1: Write the failing test**

在 `PreviewRenderBridgeTest.kt` 新增：

```kotlin
@Test
fun `submitFrame把完整帧对象透传给pipeline`() {
    val pipeline = FakeRenderPipelinePort(submitResult = true)
    val bridge = PreviewRenderBridge(renderPipeline = pipeline)
    bridge.attachSurface(1L)

    val frame = PreviewFrame(
        y = byteArrayOf(1, 2),
        u = byteArrayOf(3),
        v = byteArrayOf(4),
        width = 1280,
        height = 720,
        timestampNs = 123L,
    )
    assertTrue(bridge.submitFrame(frame))
    assertEquals(123L, pipeline.lastTs)
    assertEquals(1280, pipeline.lastWidth)
}
```

**Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.render.PreviewRenderBridgeTest"`  
Expected: FAIL（`PreviewFrame` 或新方法签名不存在）。

**Step 3: Write minimal implementation**

新增 `PreviewFrame.kt`：

```kotlin
package com.dcamera.render

data class PreviewFrame(
    val y: ByteArray,
    val u: ByteArray,
    val v: ByteArray,
    val width: Int,
    val height: Int,
    val timestampNs: Long,
)
```

修改 `RenderPipelinePort.kt`：

```kotlin
interface RenderPipelinePort {
    fun submitFrame(frame: PreviewFrame): Boolean
}
```

修改 `PreviewRenderBridge.kt`：`submitFrame(frame: PreviewFrame)` 并转发给 `renderPipeline`。

**Step 4: Run test to verify it passes**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.render.PreviewRenderBridgeTest"`  
Expected: PASS。

**Step 5: Commit**

```bash
git add android/supercamera/src/main/java/com/dcamera/render/PreviewFrame.kt \
        android/supercamera/src/main/java/com/dcamera/render/RenderPipelinePort.kt \
        android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt \
        android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt
git commit -m "refactor(android): switch preview bridge to structured frame object"
```

### Task 4: Android 实现 Camera2PreviewSessionPort（可单测的门面注入）

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/camera2/Camera2Facade.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/camera2/Camera2PreviewSessionPort.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/core/CameraPorts.kt`
- Create: `android/supercamera/src/test/java/com/dcamera/camera2/Camera2PreviewSessionPortTest.kt`
- Modify: `android/supercamera/src/test/java/com/dcamera/SuperCameraDependencyTest.kt`

**Step 1: Write the failing test**

新增 `Camera2PreviewSessionPortTest.kt`：

```kotlin
class Camera2PreviewSessionPortTest {
    @Test
    fun `startPreview成功后可把帧投递给consumer`() {
        val facade = FakeCamera2Facade(startResult = true)
        val port = Camera2PreviewSessionPort(facade)
        var delivered = 0
        port.setFrameConsumer { delivered++ }

        assertTrue(port.startPreview(1L))
        assertEquals(1, delivered)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.camera2.Camera2PreviewSessionPortTest"`  
Expected: FAIL（类/接口未定义）。

**Step 3: Write minimal implementation**

在 `CameraPorts.kt` 扩展接口：

```kotlin
interface PreviewSessionPort {
    fun setFrameConsumer(consumer: (PreviewFrame) -> Unit)
    fun startPreview(surfaceHandle: Long): Boolean
    fun stopPreview(): Boolean
}
```

新增 `Camera2Facade.kt`：

```kotlin
interface Camera2Facade {
    fun start(surfaceHandle: Long, onFrame: (PreviewFrame) -> Unit): Boolean
    fun stop(): Boolean
}
```

新增 `Camera2PreviewSessionPort.kt`：保存 consumer，`startPreview` 时调用 facade.start 并转发帧。

同步调整 `NoOpPreviewSessionPort` 与测试中的 `FakePreviewSessionPort` 实现新接口。

**Step 4: Run test to verify it passes**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.camera2.Camera2PreviewSessionPortTest" --tests "com.dcamera.SuperCameraDependencyTest"`  
Expected: PASS。

**Step 5: Commit**

```bash
git add android/supercamera/src/main/java/com/dcamera/camera2/Camera2Facade.kt \
        android/supercamera/src/main/java/com/dcamera/camera2/Camera2PreviewSessionPort.kt \
        android/supercamera/src/main/java/com/dcamera/core/CameraPorts.kt \
        android/supercamera/src/test/java/com/dcamera/camera2/Camera2PreviewSessionPortTest.kt \
        android/supercamera/src/test/java/com/dcamera/SuperCameraDependencyTest.kt
git commit -m "feat(android): add Camera2 preview session port with frame consumer"
```

### Task 5: Android 接入 bgfx native pipeline 并打通 demo 预览启停

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/render/NativeRenderBindings.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/render/BgfxRenderPipelinePort.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`
- Modify: `samples/android-app/app/src/main/res/layout/activity_main.xml`
- Modify: `samples/android-app/app/src/main/java/com/dcamera/demo/MainActivity.kt`
- Modify: `samples/android-app/app/src/main/java/com/dcamera/demo/DemoController.kt`
- Modify: `samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt`

**Step 1: Write the failing test**

在 `DemoControllerTest.kt` 新增：

```kotlin
@Test
fun `预览启动后可停止并回到idle提示`() {
    val controller = DemoController(SuperCamera(), BasicCameraView())
    controller.onPermissionResult(cameraGranted = true, micGranted = true)
    assertTrue(controller.startPreview(1L))
    assertTrue(controller.stopPreview())
    assertEquals("预览已停止", controller.lastMessage)
}
```

**Step 2: Run test to verify it fails**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest --tests "com.dcamera.demo.DemoControllerTest"`  
Expected: FAIL（`stopPreview` 缺失）。

**Step 3: Write minimal implementation**

`DemoController.kt` 增加：

```kotlin
fun stopPreview(): Boolean {
    val ok = camera.stopPreview()
    previewing = false
    lastMessage = if (ok) "预览已停止" else "预览停止失败"
    return ok
}
```

并完成以下最小接入：
- `NativeRenderBindings` 暴露 JNI 方法（`attachSurface/submitFrame/detachSurface`）
- `BgfxRenderPipelinePort` 实现 `RenderPipelinePort` 调 native
- `SuperCamera.startPreview()` 中注册 `previewSession.setFrameConsumer { previewBridge.submitFrame(it) }`
- Android demo 布局把 `tvPreview` 改为 `TextureView`，新增 `Stop Preview` 按钮并绑定 `controller.stopPreview()`

**Step 4: Run test to verify it passes**

Run:
- `cd android && ./gradlew :supercamera:testDebugUnitTest`
- `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest :app:assembleDebug`

Expected: PASS + `assembleDebug` 成功。

**Step 5: Commit**

```bash
git add android/supercamera/src/main/java/com/dcamera/render/NativeRenderBindings.kt \
        android/supercamera/src/main/java/com/dcamera/render/BgfxRenderPipelinePort.kt \
        android/supercamera/src/main/java/com/dcamera/SuperCamera.kt \
        samples/android-app/app/src/main/res/layout/activity_main.xml \
        samples/android-app/app/src/main/java/com/dcamera/demo/MainActivity.kt \
        samples/android-app/app/src/main/java/com/dcamera/demo/DemoController.kt \
        samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt
git commit -m "feat(android): wire preview session to bgfx pipeline and demo stop flow"
```

### Task 6: iOS 预览桥接改为真实帧对象并补 AVPreviewSessionPort

**Files:**
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/PreviewFrame.swift`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/av/AVFoundationSessionFacade.swift`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/av/AVPreviewSessionPort.swift`
- Modify: `ios/SuperCameraKit/Sources/SuperCameraKit/CameraPorts.swift`
- Modify: `ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift`
- Create: `ios/SuperCameraKit/Tests/SuperCameraKitTests/AVPreviewSessionPortTests.swift`
- Modify: `ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraDependencyTests.swift`

**Step 1: Write the failing test**

新增 `AVPreviewSessionPortTests.swift`：

```swift
final class AVPreviewSessionPortTests: XCTestCase {
    func testStartPreview成功后可向consumer投递帧() {
        let facade = FakeAVFoundationSessionFacade(startResult: true)
        let port = AVPreviewSessionPort(facade: facade)
        var delivered = 0
        port.setFrameConsumer { _ in delivered += 1 }

        XCTAssertTrue(port.startPreview(surfaceHandle: 1))
        XCTAssertEqual(delivered, 1)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd ios/SuperCameraKit && swift test --filter AVPreviewSessionPortTests`  
Expected: FAIL（类/协议未定义）。

**Step 3: Write minimal implementation**

`CameraPorts.swift` 扩展协议：

```swift
public protocol PreviewSessionPort {
    func setFrameConsumer(_ consumer: @escaping (PreviewFrame) -> Void)
    func startPreview(surfaceHandle: UInt64) -> Bool
    func stopPreview() -> Bool
}
```

新增 `PreviewFrame.swift`、`AVFoundationSessionFacade.swift`、`AVPreviewSessionPort.swift`，并在 `NoOpPreviewSessionPort` 中实现 `setFrameConsumer` 空操作。  
`PreviewRenderBridge.submitFrame` 改为接收 `PreviewFrame`。

**Step 4: Run test to verify it passes**

Run: `cd ios/SuperCameraKit && swift test`  
Expected: PASS（含新测试和既有测试）。

**Step 5: Commit**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/PreviewFrame.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/av/AVFoundationSessionFacade.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/av/AVPreviewSessionPort.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/CameraPorts.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift \
        ios/SuperCameraKit/Tests/SuperCameraKitTests/AVPreviewSessionPortTests.swift \
        ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraDependencyTests.swift
git commit -m "feat(ios): add AV preview session port and structured frame flow"
```

### Task 7: iOS 接入 bgfx C bridge 并打通 demo 预览启停

**Files:**
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/render/BgfxRenderPipelinePort.swift`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/render/RenderPipelineCBridge.h`
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/render/RenderPipelineCBridge.modulemap`
- Modify: `ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift`
- Modify: `samples/ios-app/README.md`

**Step 1: Write the failing test**

在 `DemoViewModelTests.swift` 新增：

```swift
func test预览启动后可停止并提示已停止() {
    let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: true))
    vm.requestInitialPermissions()
    XCTAssertTrue(vm.startPreview())
    XCTAssertTrue(vm.stopPreview())
    XCTAssertEqual(vm.lastMessage, "预览已停止")
}
```

**Step 2: Run test to verify it fails**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter DemoViewModelTests`  
Expected: FAIL（`stopPreview` 缺失）。

**Step 3: Write minimal implementation**

`DemoViewModel.swift` 增加：

```swift
@discardableResult
func stopPreview() -> Bool {
    let ok = camera.stopPreview()
    previewing = false
    lastMessage = ok ? "预览已停止" : "预览停止失败"
    return ok
}
```

并完成以下最小接入：
- `BgfxRenderPipelinePort` 通过 C bridge 调 `scamera_render_pipeline_*`
- `SuperCamera.startPreview` 注册 `previewSession.setFrameConsumer { previewBridge.submitFrame(frame: $0) }`
- README 增加 iOS 预览启停手工验证步骤

**Step 4: Run test to verify it passes**

Run:
- `cd ios/SuperCameraKit && swift test`
- `cd samples/ios-app/SuperCameraDemo && swift test`

Expected: PASS。

**Step 5: Commit**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/render/BgfxRenderPipelinePort.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/render/RenderPipelineCBridge.h \
        ios/SuperCameraKit/Sources/SuperCameraKit/render/RenderPipelineCBridge.modulemap \
        ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift \
        samples/ios-app/README.md
git commit -m "feat(ios): wire preview flow to bgfx bridge and stop-preview demo flow"
```

### Task 8: 统一验证与文档收口（自动 + 手工）

**Files:**
- Modify: `docs/testing/mvp-manual-checklist.md`
- Modify: `scripts/verify_mvp.sh`
- Modify: `samples/android-app/README.md`
- Modify: `samples/ios-app/README.md`

**Step 1: Write the failing test**

在 `docs/testing/mvp-manual-checklist.md` 先新增“预览停止后可恢复”条目，然后在 `scripts/tests/` 新增检查脚本（若不存在则创建）：

```bash
#!/usr/bin/env bash
set -euo pipefail
grep -q "预览停止后可恢复" docs/testing/mvp-manual-checklist.md
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/test_sample_readme_has_manual_checklist.sh && bash scripts/tests/test_preview_stop_checklist.sh`  
Expected: FAIL（新增条目尚未完整同步到 README 或 checklist）。

**Step 3: Write minimal implementation**

- 更新 Android/iOS README 的手工验证步骤，明确 `Start Preview -> Stop Preview -> Start Preview` 循环。
- 在 `scripts/verify_mvp.sh` 增加：
  - `:supercamera:testDebugUnitTest`（Android）
  - `swift test`（iOS kit + sample）
  - 文档清单检查脚本

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify_mvp.sh`  
Expected: PASS（含 C++、Android、iOS、sample 与 checklist 检查）。

**Step 5: Commit**

```bash
git add docs/testing/mvp-manual-checklist.md \
        scripts/verify_mvp.sh \
        samples/android-app/README.md \
        samples/ios-app/README.md \
        scripts/tests/test_preview_stop_checklist.sh
git commit -m "chore: finalize preview phase verification gates and docs"
```

## 里程碑完成定义（Phase 1 Done）

- Android：Camera2 真实预览 + bgfx 渲染可见，启停稳定。
- iOS：AVFoundation 真实预览 + bgfx 渲染可见，启停稳定。
- 自动化验证全绿；手工清单全通过。
- 明确记录延期项：前后摄切换、分辨率切换。
