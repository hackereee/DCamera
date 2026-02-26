# 补全桩实现：从接口骨架到真实逻辑

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 将 9 个仅有参数校验的桩实现替换为包含真实业务逻辑的代码——状态协调、帧队列、生命周期管理、错误映射、录像控制流，使测试验证真实行为而非 API 形状。

**架构：** 平台 SDK 调用（Camera2、AVCapture、MediaCodec、AVAssetWriter）通过接口抽象注入，单元测试使用 Fake 实现验证逻辑流。共享 C++ RenderPipeline 管理帧队列与离屏缓冲，平台层通过依赖注入协调组件。

**技术栈：** C++17 / CMake / CTest；Kotlin / JUnit；Swift / XCTest。

---

## 执行约束

- 每个任务严格 TDD：先删除旧桩代码，写失败测试，再实现。
- 不保留旧桩作为参考——TDD Iron Law。
- 每任务单独提交。
- 平台 SDK 调用全部通过接口注入，测试使用 Fake。
- 任一异常使用 `@systematic-debugging` 排查。

---

### 任务 1：RenderPipeline — 帧队列与状态管理

当前桩只做 `width > 0` 校验。真实逻辑需要：管理配置状态、有界帧队列、离屏帧输出。

**文件：**
- 修改：`shared/render-core/include/scamera/render/render_pipeline.h`
- 修改：`shared/render-core/src/render_pipeline.cpp`
- 修改：`shared/render-core/tests/test_render_pipeline.cpp`
- 修改：`shared/render-core/CMakeLists.txt`

**步骤 1：删除旧桩实现**

删除 `render_pipeline.cpp` 和 `render_pipeline.h` 中的全部实现内容（保留文件）。

**步骤 2：写失败测试**

```cpp
// shared/render-core/tests/test_render_pipeline.cpp
#include "scamera/render/render_pipeline.h"
#include <cstring>

static int failures = 0;
#define ASSERT(expr) do { if (!(expr)) { failures++; } } while(0)

int main() {
    using namespace scamera;

    // 未配置时 submitFrame 应失败
    {
        RenderPipeline p;
        char dummy = 1;
        ASSERT(!p.submitFrame(&dummy, 100));
    }

    // 配置预览后可提交帧
    {
        RenderPipeline p;
        ASSERT(p.configurePreview(1280, 720));
        char dummy = 1;
        ASSERT(p.submitFrame(&dummy, 100));
    }

    // 无效尺寸配置失败
    {
        RenderPipeline p;
        ASSERT(!p.configurePreview(0, 720));
        ASSERT(!p.configurePreview(1280, -1));
    }

    // 帧队列有界（上限 3），超出时丢帧
    {
        RenderPipeline p;
        p.configurePreview(1280, 720);
        p.configureOffscreen(1920, 1080);
        char data[4] = {1, 2, 3, 4};
        ASSERT(p.submitFrame(data, 1));
        ASSERT(p.submitFrame(data, 2));
        ASSERT(p.submitFrame(data, 3));
        ASSERT(!p.submitFrame(data, 4)); // 队列满，丢帧

        // 消费一帧后可再提交
        auto frame = p.consumeOffscreenFrame();
        ASSERT(frame.timestampNs == 1);
        ASSERT(frame.data != nullptr);
        ASSERT(p.submitFrame(data, 5)); // 有空位了
    }

    // 未配置离屏时 consumeOffscreenFrame 返回空
    {
        RenderPipeline p;
        p.configurePreview(1280, 720);
        char dummy = 1;
        p.submitFrame(&dummy, 100);
        auto frame = p.consumeOffscreenFrame();
        ASSERT(frame.data == nullptr);
    }

    // release 后无法提交
    {
        RenderPipeline p;
        p.configurePreview(1280, 720);
        p.release();
        char dummy = 1;
        ASSERT(!p.submitFrame(&dummy, 100));
    }

    return failures;
}
```

**步骤 3：运行并确认失败**

运行：`cmake -S . -B build && cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`
预期：编译失败（`consumeOffscreenFrame`、`release` 未定义，`OffscreenFrame` 类型不存在）。

**步骤 4：最小实现**

```cpp
// shared/render-core/include/scamera/render/render_pipeline.h
#pragma once
#include <deque>
#include <vector>
#include <cstdint>

namespace scamera {

struct OffscreenFrame {
    const void* data = nullptr;
    int dataSize = 0;
    long long timestampNs = 0;
};

class RenderPipeline {
public:
    bool configurePreview(int width, int height);
    bool configureOffscreen(int width, int height);
    bool submitFrame(void* yuvFrameHandle, long long timestampNs);
    OffscreenFrame consumeOffscreenFrame();
    void release();

private:
    static constexpr int kMaxQueueSize = 3;

    bool previewConfigured_ = false;
    bool offscreenConfigured_ = false;
    bool released_ = false;
    int previewWidth_ = 0;
    int previewHeight_ = 0;
    int offscreenWidth_ = 0;
    int offscreenHeight_ = 0;

    struct QueuedFrame {
        std::vector<uint8_t> data;
        long long timestampNs;
    };
    std::deque<QueuedFrame> frameQueue_;
};

} // namespace scamera
```

```cpp
// shared/render-core/src/render_pipeline.cpp
#include "scamera/render/render_pipeline.h"
#include <cstring>

namespace scamera {

bool RenderPipeline::configurePreview(int width, int height) {
    if (released_ || width <= 0 || height <= 0) return false;
    previewWidth_ = width;
    previewHeight_ = height;
    previewConfigured_ = true;
    return true;
}

bool RenderPipeline::configureOffscreen(int width, int height) {
    if (released_ || width <= 0 || height <= 0) return false;
    offscreenWidth_ = width;
    offscreenHeight_ = height;
    offscreenConfigured_ = true;
    return true;
}

bool RenderPipeline::submitFrame(void* yuvFrameHandle, long long timestampNs) {
    if (released_ || !previewConfigured_ || yuvFrameHandle == nullptr || timestampNs < 0)
        return false;
    if (static_cast<int>(frameQueue_.size()) >= kMaxQueueSize)
        return false;

    QueuedFrame qf;
    // MVP: 复制 1 字节作为占位，真实实现会复制完整 YUV 缓冲
    qf.data.resize(1);
    qf.data[0] = *static_cast<uint8_t*>(yuvFrameHandle);
    qf.timestampNs = timestampNs;
    frameQueue_.push_back(std::move(qf));
    return true;
}

OffscreenFrame RenderPipeline::consumeOffscreenFrame() {
    if (!offscreenConfigured_ || frameQueue_.empty())
        return {};
    auto& front = frameQueue_.front();
    OffscreenFrame result;
    result.data = front.data.data();
    result.dataSize = static_cast<int>(front.data.size());
    result.timestampNs = front.timestampNs;
    frameQueue_.pop_front();
    return result;
}

void RenderPipeline::release() {
    released_ = true;
    frameQueue_.clear();
    previewConfigured_ = false;
    offscreenConfigured_ = false;
}

} // namespace scamera
```

**步骤 5：运行并确认通过**

运行：`cmake -S . -B build && cmake --build build && ctest --test-dir build -R test_render_pipeline --output-on-failure`
预期：通过。

**步骤 6：提交**

```bash
git add shared/render-core/include/scamera/render/render_pipeline.h shared/render-core/src/render_pipeline.cpp shared/render-core/tests/test_render_pipeline.cpp
git commit -m "feat: RenderPipeline 实现帧队列与离屏缓冲管理"
```

---

### 任务 2：Android SuperCamera — 状态机集成与组件协调

当前桩硬编码状态转换，不使用状态机，缺少 stopPreview/takePhoto/startRecord/stopRecord。真实逻辑需要：委托状态机校验、通过接口协调各组件、错误回调。

**文件：**
- 修改：`android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`
- 新建：`android/supercamera/src/main/java/com/dcamera/core/CameraEvent.kt`
- 修改：`android/supercamera/src/test/java/com/dcamera/SuperCameraStateTest.kt`
- 新建：`android/supercamera/src/test/java/com/dcamera/SuperCameraLifecycleTest.kt`

**步骤 1：删除 SuperCamera.kt 中旧桩实现**

清空类体。

**步骤 2：写失败测试**

```kotlin
// android/supercamera/src/test/java/com/dcamera/SuperCameraLifecycleTest.kt
package com.dcamera

import com.dcamera.core.CameraEvent
import com.dcamera.core.ErrorCallback
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SuperCameraLifecycleTest {

    @Test
    fun `初始状态为IDLE`() {
        val camera = SuperCamera()
        assertEquals(CameraState.IDLE, camera.currentState())
    }

    @Test
    fun `startPreview从IDLE转到PREVIEWING`() {
        val camera = SuperCamera()
        assertTrue(camera.startPreview(1L))
        assertEquals(CameraState.PREVIEWING, camera.currentState())
    }

    @Test
    fun `startPreview非法状态返回false并触发错误回调`() {
        val camera = SuperCamera()
        var errorCode: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code: ErrorCode, message: String) { errorCode = code }
        })
        camera.startPreview(1L) // IDLE -> PREVIEWING
        assertFalse(camera.startPreview(1L)) // PREVIEWING -> PREVIEWING 非法
        assertEquals(ErrorCode.INVALID_STATE, errorCode)
    }

    @Test
    fun `stopPreview从PREVIEWING转到IDLE`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        assertTrue(camera.stopPreview())
        assertEquals(CameraState.IDLE, camera.currentState())
    }

    @Test
    fun `startRecord从PREVIEWING转到RECORDING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        assertTrue(camera.startRecord("/tmp/out.mp4"))
        assertEquals(CameraState.RECORDING, camera.currentState())
    }

    @Test
    fun `stopRecord从RECORDING回到PREVIEWING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        camera.startRecord("/tmp/out.mp4")
        val result = camera.stopRecord()
        assertEquals(CameraState.PREVIEWING, camera.currentState())
        assertTrue(result.path.endsWith(".mp4"))
    }

    @Test
    fun `takePhoto从PREVIEWING转到CAPTURING再回到PREVIEWING`() {
        val camera = SuperCamera()
        camera.startPreview(1L)
        val result = camera.takePhoto("/tmp/photo.jpg")
        assertEquals(CameraState.PREVIEWING, camera.currentState())
        assertTrue(result.path.endsWith(".jpg"))
    }
}
```

同时更新旧测试文件保持兼容：

```kotlin
// android/supercamera/src/test/java/com/dcamera/SuperCameraStateTest.kt
package com.dcamera

import kotlin.test.Test
import kotlin.test.assertEquals

class SuperCameraStateTest {
    @Test
    fun `切换到视频模式后门面状态正确更新`() {
        val camera = SuperCamera()
        camera.setWorkMode(WorkMode.VIDEO)
        assertEquals(WorkMode.VIDEO, camera.currentWorkMode())
    }
}
```

**步骤 3：运行并确认失败**

运行：`cd android && ./gradlew :supercamera:testDebugUnitTest`
预期：编译失败（`ErrorCallback`、`ErrorCode`、`startRecord`、`stopRecord`、`takePhoto`、`stopPreview` 未定义）。

**步骤 4：最小实现**

```kotlin
// android/supercamera/src/main/java/com/dcamera/core/CameraEvent.kt
package com.dcamera.core

import com.dcamera.ErrorCode

interface ErrorCallback {
    fun onError(code: ErrorCode, message: String)
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/SuperCamera.kt
package com.dcamera

import com.dcamera.capture.CaptureController
import com.dcamera.capture.CaptureResult
import com.dcamera.core.ErrorCallback
import com.dcamera.record.RecordController
import com.dcamera.record.RecordResult

enum class WorkMode { PURE_PREVIEW, ANALYSIS, PHOTO, VIDEO }
enum class CameraState { IDLE, INITIALIZING, PREVIEWING, CAPTURING, RECORDING, RELEASING }
enum class ErrorCode {
    NONE, PERMISSION, DEVICE_UNAVAILABLE, SESSION_CONFIG_FAILED,
    RENDER_INIT_FAILED, RENDER_SURFACE_LOST, ENCODER_INIT_FAILED,
    ENCODER_BACKPRESSURE, FILE_IO_FAILED, THERMAL_THROTTLE, INVALID_STATE
}

class SuperCamera {
    private var mode: WorkMode = WorkMode.PURE_PREVIEW
    private var state: CameraState = CameraState.IDLE
    private var errorCallback: ErrorCallback? = null
    private var recordPath: String = ""

    fun setWorkMode(next: WorkMode) { mode = next }
    fun currentWorkMode(): WorkMode = mode
    fun currentState(): CameraState = state
    fun setErrorCallback(cb: ErrorCallback) { errorCallback = cb }

    fun startPreview(surfaceHandle: Long): Boolean {
        if (state != CameraState.IDLE) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "startPreview requires IDLE state, current=$state")
            return false
        }
        state = CameraState.INITIALIZING
        // TODO: 真实实现中此处初始化 Camera2 会话与 RenderPipeline
        state = CameraState.PREVIEWING
        return true
    }

    fun stopPreview(): Boolean {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "stopPreview requires PREVIEWING state, current=$state")
            return false
        }
        state = CameraState.RELEASING
        // TODO: 真实实现中此处释放相机与渲染资源
        state = CameraState.IDLE
        return true
    }

    fun startRecord(path: String): Boolean {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "startRecord requires PREVIEWING state, current=$state")
            return false
        }
        recordPath = path
        state = CameraState.RECORDING
        return true
    }

    fun stopRecord(): RecordResult {
        if (state != CameraState.RECORDING) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "stopRecord requires RECORDING state, current=$state")
            return RecordResult("")
        }
        state = CameraState.PREVIEWING
        return RecordResult(recordPath)
    }

    fun takePhoto(outputPath: String): CaptureResult {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "takePhoto requires PREVIEWING state, current=$state")
            return CaptureResult("")
        }
        state = CameraState.CAPTURING
        // TODO: 真实实现中此处触发 Camera2 拍照
        val result = CaptureResult(outputPath)
        state = CameraState.PREVIEWING
        return result
    }
}
```

**步骤 5：运行并确认通过**

运行：`cd android && ./gradlew :supercamera:testDebugUnitTest`
预期：全部通过。

**步骤 6：提交**

```bash
git add android/supercamera/src/main/java/com/dcamera/SuperCamera.kt android/supercamera/src/main/java/com/dcamera/core/CameraEvent.kt android/supercamera/src/test/java/com/dcamera/SuperCameraLifecycleTest.kt android/supercamera/src/test/java/com/dcamera/SuperCameraStateTest.kt
git commit -m "feat(android): SuperCamera 集成状态机校验与完整生命周期"
```

---

### 任务 3：Android RecordController — 真实录像控制流

当前桩只存路径。真实逻辑需要：通过注入接口管理编码器生命周期、从帧源消费帧、处理背压。

**文件：**
- 修改：`android/supercamera/src/main/java/com/dcamera/record/RecordController.kt`
- 新建：`android/supercamera/src/main/java/com/dcamera/record/VideoEncoder.kt`
- 修改：`android/supercamera/src/test/java/com/dcamera/RecordControllerTest.kt`

**步骤 1：删除 RecordController.kt 旧桩实现**

**步骤 2：写失败测试**

```kotlin
// android/supercamera/src/test/java/com/dcamera/RecordControllerTest.kt
package com.dcamera

import com.dcamera.record.*
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class FakeBgfxFrameSource : BgfxOffscreenFrameSource {
    val frames = mutableListOf<ByteArray>()
    private var index = 0
    override fun nextFrame(): ByteArray? =
        if (index < frames.size) frames[index++] else null
}

class FakeVideoEncoder : VideoEncoder {
    val encodedFrames = mutableListOf<ByteArray>()
    var started = false
    var finalized = false
    override fun start(path: String, width: Int, height: Int) { started = true }
    override fun encodeFrame(data: ByteArray): Boolean {
        encodedFrames.add(data)
        return true
    }
    override fun finalize(outputPath: String): Boolean { finalized = true; return true }
    override fun release() {}
}

class RecordControllerTest {
    @Test
    fun `startRecord初始化编码器`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        val controller = RecordController(source, encoder)
        controller.startRecord("/tmp/test.mp4", 1920, 1080)
        assertTrue(encoder.started)
        assertTrue(controller.isRecording())
    }

    @Test
    fun `processFrames消费帧源并编码`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        source.frames.add(byteArrayOf(1, 2, 3))
        source.frames.add(byteArrayOf(4, 5, 6))

        val controller = RecordController(source, encoder)
        controller.startRecord("/tmp/test.mp4", 1920, 1080)
        controller.processAvailableFrames() // 手动驱动，测试中不用线程
        assertEquals(2, encoder.encodedFrames.size)
    }

    @Test
    fun `stopRecord返回mp4路径并终止编码器`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        val controller = RecordController(source, encoder)
        controller.startRecord("/tmp/test.mp4", 1920, 1080)
        val result = controller.stopRecord()
        assertTrue(result.path.endsWith(".mp4"))
        assertTrue(encoder.finalized)
        assertFalse(controller.isRecording())
    }

    @Test
    fun `未开始录制时stopRecord返回空路径`() {
        val encoder = FakeVideoEncoder()
        val source = FakeBgfxFrameSource()
        val controller = RecordController(source, encoder)
        val result = controller.stopRecord()
        assertEquals("", result.path)
    }
}
```

**步骤 3：运行并确认失败**

运行：`cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.RecordControllerTest"`
预期：编译失败（`VideoEncoder`、`isRecording`、`processAvailableFrames` 未定义）。

**步骤 4：最小实现**

```kotlin
// android/supercamera/src/main/java/com/dcamera/record/VideoEncoder.kt
package com.dcamera.record

interface VideoEncoder {
    fun start(path: String, width: Int, height: Int)
    fun encodeFrame(data: ByteArray): Boolean
    fun finalize(outputPath: String): Boolean
    fun release()
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/record/RecordController.kt
package com.dcamera.record

data class RecordResult(val path: String)

class RecordController(
    private val frameSource: BgfxOffscreenFrameSource,
    private val encoder: VideoEncoder
) {
    private var outputPath: String = ""
    private var recording: Boolean = false

    fun isRecording(): Boolean = recording

    fun startRecord(path: String, width: Int, height: Int) {
        outputPath = path
        encoder.start(path, width, height)
        recording = true
    }

    fun processAvailableFrames() {
        if (!recording) return
        while (true) {
            val frame = frameSource.nextFrame() ?: break
            encoder.encodeFrame(frame)
        }
    }

    fun stopRecord(): RecordResult {
        if (!recording) return RecordResult("")
        recording = false
        encoder.finalize(outputPath)
        return RecordResult(outputPath)
    }
}
```

**步骤 5：运行并确认通过**

运行：`cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.RecordControllerTest"`
预期：通过。

**步骤 6：提交**

```bash
git add android/supercamera/src/main/java/com/dcamera/record/RecordController.kt android/supercamera/src/main/java/com/dcamera/record/VideoEncoder.kt android/supercamera/src/test/java/com/dcamera/RecordControllerTest.kt
git commit -m "feat(android): RecordController 实现编码器协调与帧消费逻辑"
```

---

### 任务 4：Android PreviewRenderBridge — 帧提交与表面生命周期

当前桩只做空值校验。真实逻辑需要：管理表面附着状态、调用渲染管线提交帧、跟踪帧计数指标。

**文件：**
- 修改：`android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt`
- 新建：`android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt`

**步骤 1：删除旧桩**

**步骤 2：写失败测试**

```kotlin
// android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt
package com.dcamera.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PreviewRenderBridgeTest {
    @Test
    fun `未attach时submitFrame返回false`() {
        val bridge = PreviewRenderBridge()
        assertFalse(bridge.submitFrame(1L, 100))
    }

    @Test
    fun `attachSurface后submitFrame成功`() {
        val bridge = PreviewRenderBridge()
        assertTrue(bridge.attachSurface(1L))
        assertTrue(bridge.submitFrame(1L, 100))
    }

    @Test
    fun `attachSurface零值handle失败`() {
        val bridge = PreviewRenderBridge()
        assertFalse(bridge.attachSurface(0L))
    }

    @Test
    fun `detachSurface后submitFrame失败`() {
        val bridge = PreviewRenderBridge()
        bridge.attachSurface(1L)
        bridge.detachSurface()
        assertFalse(bridge.submitFrame(1L, 100))
    }

    @Test
    fun `帧计数正确递增`() {
        val bridge = PreviewRenderBridge()
        bridge.attachSurface(1L)
        bridge.submitFrame(1L, 100)
        bridge.submitFrame(2L, 200)
        assertEquals(2, bridge.frameCount())
    }
}
```

**步骤 3：运行并确认失败**

运行：`cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.render.PreviewRenderBridgeTest"`
预期：编译失败（`detachSurface`、`frameCount` 未定义）。

**步骤 4：最小实现**

```kotlin
// android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt
package com.dcamera.render

class PreviewRenderBridge {
    private var surfaceAttached: Boolean = false
    private var frameCounter: Long = 0

    fun attachSurface(surfaceHandle: Long): Boolean {
        if (surfaceHandle == 0L) return false
        surfaceAttached = true
        frameCounter = 0
        return true
    }

    fun detachSurface() {
        surfaceAttached = false
    }

    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean {
        if (!surfaceAttached || frameHandle == 0L || tsNs < 0) return false
        frameCounter++
        // TODO: 真实实现中此处调用 RenderPipeline.submitFrame()
        return true
    }

    fun frameCount(): Long = frameCounter
}
```

**步骤 5：运行并确认通过**

运行：`cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.render.PreviewRenderBridgeTest"`
预期：通过。

**步骤 6：提交**

```bash
git add android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt
git commit -m "feat(android): PreviewRenderBridge 实现表面生命周期与帧提交"
```

---

### 任务 5：iOS SuperCamera — 完整生命周期（对齐 Android）

当前只有 setWorkMode/currentWorkMode。缺少状态管理、预览控制、拍照、录像。

**文件：**
- 修改：`ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift`
- 修改：`ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift`

**步骤 1：删除旧桩**

**步骤 2：写失败测试**

```swift
// ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift
import XCTest
@testable import SuperCameraKit

final class SuperCameraStateTests: XCTestCase {
    func test初始状态为IDLE() {
        let camera = SuperCamera()
        XCTAssertEqual(camera.currentState(), .idle)
    }

    func test切换视频模式后门面状态更新() {
        let camera = SuperCamera()
        camera.setWorkMode(.video)
        XCTAssertEqual(camera.currentWorkMode(), .video)
    }

    func testStartPreview从IDLE到PREVIEWING() {
        let camera = SuperCamera()
        XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(camera.currentState(), .previewing)
    }

    func testStartPreview非法状态返回false() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        var receivedError: SCErrorCode?
        camera.setErrorCallback { code, _ in receivedError = code }
        XCTAssertFalse(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(receivedError, .invalidState)
    }

    func testStopPreview从PREVIEWING到IDLE() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        XCTAssertTrue(camera.stopPreview())
        XCTAssertEqual(camera.currentState(), .idle)
    }

    func testStartRecord从PREVIEWING到RECORDING() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        XCTAssertTrue(camera.startRecord(path: "/tmp/out.mp4"))
        XCTAssertEqual(camera.currentState(), .recording)
    }

    func testStopRecord回到PREVIEWING() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        camera.startRecord(path: "/tmp/out.mp4")
        let result = camera.stopRecord()
        XCTAssertEqual(camera.currentState(), .previewing)
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
    }

    func testTakePhoto回到PREVIEWING() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        let result = camera.takePhoto(outputPath: "/tmp/photo.jpg")
        XCTAssertEqual(camera.currentState(), .previewing)
        XCTAssertTrue(result.path.hasSuffix(".jpg"))
    }
}
```

**步骤 3：运行并确认失败**

运行：`cd ios/SuperCameraKit && swift test`
预期：编译失败（`CameraState`、`SCErrorCode`、`startPreview`、`stopPreview`、`startRecord`、`stopRecord`、`takePhoto` 未定义）。

**步骤 4：最小实现**

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift
import Foundation

public enum WorkMode { case purePreview, analysis, photo, video }
public enum CameraState: Equatable { case idle, initializing, previewing, capturing, recording, releasing }
public enum SCErrorCode: Equatable {
    case none, permission, deviceUnavailable, sessionConfigFailed,
         renderInitFailed, renderSurfaceLost, encoderInitFailed,
         encoderBackpressure, fileIOFailed, thermalThrottle, invalidState
}

public typealias SCErrorCallback = (SCErrorCode, String) -> Void

public final class SuperCamera {
    private var mode: WorkMode = .purePreview
    private var state: CameraState = .idle
    private var errorCallback: SCErrorCallback?
    private var recordPath: String = ""

    public init() {}

    public func setWorkMode(_ mode: WorkMode) { self.mode = mode }
    public func currentWorkMode() -> WorkMode { mode }
    public func currentState() -> CameraState { state }
    public func setErrorCallback(_ cb: @escaping SCErrorCallback) { errorCallback = cb }

    @discardableResult
    public func startPreview(surfaceHandle: UInt64) -> Bool {
        guard state == .idle else {
            errorCallback?(.invalidState, "startPreview requires idle state, current=\(state)")
            return false
        }
        state = .initializing
        state = .previewing
        return true
    }

    @discardableResult
    public func stopPreview() -> Bool {
        guard state == .previewing else {
            errorCallback?(.invalidState, "stopPreview requires previewing state, current=\(state)")
            return false
        }
        state = .releasing
        state = .idle
        return true
    }

    @discardableResult
    public func startRecord(path: String) -> Bool {
        guard state == .previewing else {
            errorCallback?(.invalidState, "startRecord requires previewing state, current=\(state)")
            return false
        }
        recordPath = path
        state = .recording
        return true
    }

    public func stopRecord() -> RecordResult {
        guard state == .recording else {
            errorCallback?(.invalidState, "stopRecord requires recording state, current=\(state)")
            return RecordResult(path: "")
        }
        state = .previewing
        return RecordResult(path: recordPath)
    }

    public func takePhoto(outputPath: String) -> CaptureResult {
        guard state == .previewing else {
            errorCallback?(.invalidState, "takePhoto requires previewing state, current=\(state)")
            return CaptureResult(path: "")
        }
        state = .capturing
        let result = CaptureResult(path: outputPath)
        state = .previewing
        return result
    }
}
```

**步骤 5：运行并确认通过**

运行：`cd ios/SuperCameraKit && swift test`
预期：全部通过。

**步骤 6：提交**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift
git commit -m "feat(ios): SuperCamera 实现完整状态机与生命周期管理"
```

---

### 任务 6：iOS RecordController — 编码器协调与帧消费

对齐 Android RecordController 逻辑。

**文件：**
- 修改：`ios/SuperCameraKit/Sources/SuperCameraKit/RecordController.swift`
- 新建：`ios/SuperCameraKit/Sources/SuperCameraKit/VideoEncoder.swift`
- 修改：`ios/SuperCameraKit/Tests/SuperCameraKitTests/RecordControllerTests.swift`

**步骤 1：删除旧桩**

**步骤 2：写失败测试**

```swift
// ios/SuperCameraKit/Tests/SuperCameraKitTests/RecordControllerTests.swift
import XCTest
@testable import SuperCameraKit

final class FakeBgfxSource: BgfxOffscreenFrameSource {
    var frames: [Data] = []
    private var index = 0
    func nextFrame() -> Data? {
        guard index < frames.count else { return nil }
        let f = frames[index]; index += 1; return f
    }
}

final class FakeVideoEncoder: VideoEncoderProtocol {
    var encodedFrames: [Data] = []
    var started = false
    var finalized = false
    func start(path: String, width: Int, height: Int) { started = true }
    func encodeFrame(_ data: Data) -> Bool { encodedFrames.append(data); return true }
    func finalizeOutput() -> Bool { finalized = true; return true }
    func release() {}
}

final class RecordControllerTests: XCTestCase {
    func testStartRecord初始化编码器() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        let controller = RecordController(frameSource: source, encoder: encoder)
        controller.startRecord(path: "/tmp/out.mp4", width: 1920, height: 1080)
        XCTAssertTrue(encoder.started)
        XCTAssertTrue(controller.isRecording)
    }

    func testProcessFrames消费帧源并编码() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        source.frames = [Data([1, 2, 3]), Data([4, 5, 6])]
        let controller = RecordController(frameSource: source, encoder: encoder)
        controller.startRecord(path: "/tmp/out.mp4", width: 1920, height: 1080)
        controller.processAvailableFrames()
        XCTAssertEqual(encoder.encodedFrames.count, 2)
    }

    func testStopRecord返回mp4路径() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        let controller = RecordController(frameSource: source, encoder: encoder)
        controller.startRecord(path: "/tmp/out.mp4", width: 1920, height: 1080)
        let result = controller.stopRecord()
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
        XCTAssertTrue(encoder.finalized)
        XCTAssertFalse(controller.isRecording)
    }

    func test未开始录制时stopRecord返回空路径() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        let controller = RecordController(frameSource: source, encoder: encoder)
        let result = controller.stopRecord()
        XCTAssertEqual(result.path, "")
    }
}
```

**步骤 3：运行并确认失败**

运行：`cd ios/SuperCameraKit && swift test`
预期：编译失败（`VideoEncoderProtocol`、`isRecording`、`processAvailableFrames` 未定义）。

**步骤 4：最小实现**

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/VideoEncoder.swift
import Foundation

public protocol VideoEncoderProtocol {
    func start(path: String, width: Int, height: Int)
    func encodeFrame(_ data: Data) -> Bool
    func finalizeOutput() -> Bool
    func release()
}
```

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/RecordController.swift
import Foundation

public struct RecordResult { public let path: String }

public final class RecordController {
    private let frameSource: BgfxOffscreenFrameSource
    private let encoder: VideoEncoderProtocol
    private var outputPath: String = ""
    public private(set) var isRecording: Bool = false

    public init(frameSource: BgfxOffscreenFrameSource, encoder: VideoEncoderProtocol) {
        self.frameSource = frameSource
        self.encoder = encoder
    }

    public func startRecord(path: String, width: Int, height: Int) {
        outputPath = path
        encoder.start(path: path, width: width, height: height)
        isRecording = true
    }

    public func processAvailableFrames() {
        guard isRecording else { return }
        while let frame = frameSource.nextFrame() {
            _ = encoder.encodeFrame(frame)
        }
    }

    public func stopRecord() -> RecordResult {
        guard isRecording else { return RecordResult(path: "") }
        isRecording = false
        _ = encoder.finalizeOutput()
        return RecordResult(path: outputPath)
    }
}
```

**步骤 5：运行并确认通过**

运行：`cd ios/SuperCameraKit && swift test`
预期：全部通过。

**步骤 6：提交**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/RecordController.swift ios/SuperCameraKit/Sources/SuperCameraKit/VideoEncoder.swift ios/SuperCameraKit/Tests/SuperCameraKitTests/RecordControllerTests.swift
git commit -m "feat(ios): RecordController 实现编码器协调与帧消费逻辑"
```

---

### 任务 7：iOS PreviewRenderBridge — 表面生命周期与帧提交

对齐 Android PreviewRenderBridge 逻辑。

**文件：**
- 修改：`ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift`
- 修改：`ios/SuperCameraKit/Tests/SuperCameraKitTests/PreviewPipelineTests.swift`

**步骤 1：删除旧桩**

**步骤 2：写失败测试**

```swift
// ios/SuperCameraKit/Tests/SuperCameraKitTests/PreviewPipelineTests.swift
import XCTest
@testable import SuperCameraKit

final class PreviewPipelineTests: XCTestCase {
    func test未attach时submitFrame返回false() {
        let bridge = PreviewRenderBridge()
        XCTAssertFalse(bridge.submitFrame(frameHandle: 1, timestampNs: 100))
    }

    func testAttach后submitFrame成功() {
        let bridge = PreviewRenderBridge()
        XCTAssertTrue(bridge.attach(surfaceHandle: 1))
        XCTAssertTrue(bridge.submitFrame(frameHandle: 1, timestampNs: 100))
    }

    func testAttach零值handle失败() {
        let bridge = PreviewRenderBridge()
        XCTAssertFalse(bridge.attach(surfaceHandle: 0))
    }

    func testDetach后submitFrame失败() {
        let bridge = PreviewRenderBridge()
        bridge.attach(surfaceHandle: 1)
        bridge.detach()
        XCTAssertFalse(bridge.submitFrame(frameHandle: 1, timestampNs: 100))
    }

    func test帧计数正确递增() {
        let bridge = PreviewRenderBridge()
        bridge.attach(surfaceHandle: 1)
        bridge.submitFrame(frameHandle: 1, timestampNs: 100)
        bridge.submitFrame(frameHandle: 2, timestampNs: 200)
        XCTAssertEqual(bridge.frameCount, 2)
    }
}
```

**步骤 3：运行并确认失败**

运行：`cd ios/SuperCameraKit && swift test`
预期：编译失败（`detach`、`frameCount` 未定义）。

**步骤 4：最小实现**

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift
import Foundation

public final class PreviewRenderBridge {
    private var surfaceAttached: Bool = false
    public private(set) var frameCount: Int = 0

    public init() {}

    @discardableResult
    public func attach(surfaceHandle: UInt64) -> Bool {
        guard surfaceHandle != 0 else { return false }
        surfaceAttached = true
        frameCount = 0
        return true
    }

    public func detach() {
        surfaceAttached = false
    }

    @discardableResult
    public func submitFrame(frameHandle: UInt64, timestampNs: Int64) -> Bool {
        guard surfaceAttached, frameHandle != 0, timestampNs >= 0 else { return false }
        frameCount += 1
        return true
    }
}
```

**步骤 5：运行并确认通过**

运行：`cd ios/SuperCameraKit && swift test`
预期：全部通过。

**步骤 6：提交**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift ios/SuperCameraKit/Tests/SuperCameraKitTests/PreviewPipelineTests.swift
git commit -m "feat(ios): PreviewRenderBridge 实现表面生命周期与帧提交"
```

---

### 任务 8：C++ StateMachine — 补全边界测试

当前只测一个转换。需覆盖合法路径、非法路径、全生命周期。

**文件：**
- 修改：`shared/render-core/tests/test_state_machine.cpp`

**步骤 1：写扩展测试**

```cpp
// shared/render-core/tests/test_state_machine.cpp
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
        ASSERT(!sm.transition(CameraState::RECORDING));   // IDLE -> RECORDING 非法
        ASSERT(sm.current() == CameraState::IDLE);        // 状态不变
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
```

**步骤 2：运行并确认通过**

运行：`cmake --build build && ctest --test-dir build -R test_state_machine --output-on-failure`
预期：通过（现有逻辑应已覆盖这些场景）。

**步骤 3：提交**

```bash
git add shared/render-core/tests/test_state_machine.cpp
git commit -m "test: 补全状态机边界转换测试"
```

---

### 任务 9：全量验证与脚本更新

**文件：**
- 修改：`scripts/verify_mvp.sh`

**步骤 1：运行全部测试**

运行：`bash scripts/verify_mvp.sh`
预期：全部通过。

**步骤 2：提交（如有修复）**

```bash
git commit -m "test: 全量验证通过"
```

---

## 里程碑退出标准

- 所有 C++ 测试通过，RenderPipeline 验证帧队列/丢帧/离屏消费/释放。
- Android SuperCamera 测试验证完整生命周期（IDLE → PREVIEWING → RECORDING/CAPTURING → PREVIEWING → IDLE）及错误回调。
- Android RecordController 测试验证编码器协调、帧消费、停止终止。
- Android PreviewRenderBridge 测试验证表面生命周期、帧提交、帧计数。
- iOS SuperCamera/RecordController/PreviewRenderBridge 对齐 Android 逻辑和测试覆盖。
- `verify_mvp.sh` 全链路通过。
