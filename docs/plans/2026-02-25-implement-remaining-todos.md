# 剩余 TODO 运行时实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 清理 Android/iOS 相机门面中的运行时 TODO，完成真实协作链路（会话、预览桥、拍照）并补齐失败路径测试与回归守卫。

**Architecture:** 将平台能力通过可注入端口抽象，`SuperCamera` 只负责生命周期编排和错误码映射，避免直接耦合平台 SDK。`PreviewRenderBridge` 的帧提交流程改为委托渲染管线端口，保证“提交成功才计数”。新增脚本化回归检查，防止运行时代码再次引入 `TODO: real implementation`。

**Tech Stack:** Kotlin/JUnit/Gradle，Swift/XCTest/SwiftPM，Bash，CMake/CTest。

---

## 执行约束

- 严格执行 `@test-driven-development`：先写失败测试、确认失败、最小实现、确认通过。
- 任意异常先用 `@systematic-debugging`，避免盲改。
- 完成前必须执行 `@verification-before-completion`（以 `scripts/verify_mvp.sh` 为准）。
- 每个任务单独提交，保持提交边界清晰。

### 任务 1：Android SuperCamera TODO 落地（预览初始化/释放 + 拍照委托）

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/core/CameraPorts.kt`
- Create: `android/supercamera/src/main/java/com/dcamera/render/PreviewBridgePort.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/SuperCamera.kt`
- Create: `android/supercamera/src/test/java/com/dcamera/SuperCameraDependencyTest.kt`

**Step 1: 写失败测试**

```kotlin
// android/supercamera/src/test/java/com/dcamera/SuperCameraDependencyTest.kt
package com.dcamera

import com.dcamera.capture.CaptureResult
import com.dcamera.core.ErrorCallback
import com.dcamera.core.PhotoCapturePort
import com.dcamera.core.PreviewSessionPort
import com.dcamera.render.PreviewBridgePort
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class FakePreviewSessionPort(
    private val startResult: Boolean = true,
    private val stopResult: Boolean = true,
) : PreviewSessionPort {
    var startCalls = 0
    var stopCalls = 0

    override fun startPreview(surfaceHandle: Long): Boolean {
        startCalls++
        return startResult
    }

    override fun stopPreview(): Boolean {
        stopCalls++
        return stopResult
    }
}

private class FakePreviewBridgePort(
    private val attachResult: Boolean = true,
) : PreviewBridgePort {
    var attachCalls = 0
    var detachCalls = 0

    override fun attachSurface(surfaceHandle: Long): Boolean {
        attachCalls++
        return attachResult
    }

    override fun detachSurface() {
        detachCalls++
    }
}

private class FakePhotoCapturePort(
    private val resultPath: String,
) : PhotoCapturePort {
    override fun capture(outputPath: String): CaptureResult = CaptureResult(resultPath)
}

class SuperCameraDependencyTest {
    @Test
    fun `startPreview失败时回滚IDLE并上报SESSION_CONFIG_FAILED`() {
        val session = FakePreviewSessionPort(startResult = false)
        val camera = SuperCamera(
            previewSession = session,
            previewBridge = FakePreviewBridgePort(),
            photoCapture = FakePhotoCapturePort("/tmp/photo.jpg"),
        )
        var code: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code0: ErrorCode, message: String) {
                code = code0
            }
        })

        assertFalse(camera.startPreview(1L))
        assertEquals(CameraState.IDLE, camera.currentState())
        assertEquals(ErrorCode.SESSION_CONFIG_FAILED, code)
    }

    @Test
    fun `render attach失败时调用session stop回滚并上报RENDER_INIT_FAILED`() {
        val session = FakePreviewSessionPort(startResult = true)
        val bridge = FakePreviewBridgePort(attachResult = false)
        val camera = SuperCamera(
            previewSession = session,
            previewBridge = bridge,
            photoCapture = FakePhotoCapturePort("/tmp/photo.jpg"),
        )
        var code: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code0: ErrorCode, message: String) {
                code = code0
            }
        })

        assertFalse(camera.startPreview(1L))
        assertEquals(1, session.stopCalls)
        assertEquals(ErrorCode.RENDER_INIT_FAILED, code)
        assertEquals(CameraState.IDLE, camera.currentState())
    }

    @Test
    fun `takePhoto返回空路径时上报FILE_IO_FAILED`() {
        val camera = SuperCamera(
            previewSession = FakePreviewSessionPort(),
            previewBridge = FakePreviewBridgePort(),
            photoCapture = FakePhotoCapturePort(""),
        )
        var code: ErrorCode? = null
        camera.setErrorCallback(object : ErrorCallback {
            override fun onError(code0: ErrorCode, message: String) {
                code = code0
            }
        })

        assertTrue(camera.startPreview(1L))
        val result = camera.takePhoto("/tmp/photo.jpg")
        assertEquals("", result.path)
        assertEquals(ErrorCode.FILE_IO_FAILED, code)
        assertEquals(CameraState.PREVIEWING, camera.currentState())
    }
}
```

**Step 2: 运行并确认失败**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.SuperCameraDependencyTest"`
Expected: FAIL（`PreviewSessionPort`/`PhotoCapturePort` 未定义，或构造函数参数不匹配）。

**Step 3: 最小实现**

```kotlin
// android/supercamera/src/main/java/com/dcamera/core/CameraPorts.kt
package com.dcamera.core

import com.dcamera.capture.CaptureController
import com.dcamera.capture.CaptureResult

interface PreviewSessionPort {
    fun startPreview(surfaceHandle: Long): Boolean
    fun stopPreview(): Boolean
}

interface PhotoCapturePort {
    fun capture(outputPath: String): CaptureResult
}

class NoOpPreviewSessionPort : PreviewSessionPort {
    override fun startPreview(surfaceHandle: Long): Boolean = surfaceHandle != 0L
    override fun stopPreview(): Boolean = true
}

class CaptureControllerAdapter(
    private val controller: CaptureController = CaptureController(),
) : PhotoCapturePort {
    override fun capture(outputPath: String): CaptureResult = controller.takePhoto(outputPath)
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/render/PreviewBridgePort.kt
package com.dcamera.render

interface PreviewBridgePort {
    fun attachSurface(surfaceHandle: Long): Boolean
    fun detachSurface()
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/SuperCamera.kt（关键变更）
import com.dcamera.core.CaptureControllerAdapter
import com.dcamera.core.NoOpPreviewSessionPort
import com.dcamera.core.PhotoCapturePort
import com.dcamera.core.PreviewSessionPort
import com.dcamera.render.PreviewBridgePort
import com.dcamera.render.PreviewRenderBridge

class SuperCamera(
    private val previewSession: PreviewSessionPort = NoOpPreviewSessionPort(),
    private val previewBridge: PreviewBridgePort = PreviewRenderBridge(),
    private val photoCapture: PhotoCapturePort = CaptureControllerAdapter(),
) {
    // ... existing fields

    fun startPreview(surfaceHandle: Long): Boolean {
        if (state != CameraState.IDLE) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "startPreview requires IDLE state, current=$state")
            return false
        }
        state = CameraState.INITIALIZING
        if (!previewSession.startPreview(surfaceHandle)) {
            state = CameraState.IDLE
            errorCallback?.onError(ErrorCode.SESSION_CONFIG_FAILED, "preview session init failed")
            return false
        }
        if (!previewBridge.attachSurface(surfaceHandle)) {
            previewSession.stopPreview()
            state = CameraState.IDLE
            errorCallback?.onError(ErrorCode.RENDER_INIT_FAILED, "preview bridge attach failed")
            return false
        }
        state = CameraState.PREVIEWING
        return true
    }

    fun stopPreview(): Boolean {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "stopPreview requires PREVIEWING state, current=$state")
            return false
        }
        state = CameraState.RELEASING
        previewBridge.detachSurface()
        val stopped = previewSession.stopPreview()
        state = CameraState.IDLE
        if (!stopped) {
            errorCallback?.onError(ErrorCode.SESSION_CONFIG_FAILED, "preview session stop failed")
            return false
        }
        return true
    }

    fun takePhoto(outputPath: String): CaptureResult {
        if (state != CameraState.PREVIEWING) {
            errorCallback?.onError(ErrorCode.INVALID_STATE, "takePhoto requires PREVIEWING state, current=$state")
            return CaptureResult("")
        }
        state = CameraState.CAPTURING
        val result = photoCapture.capture(outputPath)
        state = CameraState.PREVIEWING
        if (result.path.isBlank()) {
            errorCallback?.onError(ErrorCode.FILE_IO_FAILED, "photo capture returned empty path")
        }
        return result
    }
}
```

**Step 4: 运行并确认通过**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.SuperCameraDependencyTest" --tests "com.dcamera.SuperCameraLifecycleTest"`
Expected: PASS。

**Step 5: 提交**

```bash
git add android/supercamera/src/main/java/com/dcamera/core/CameraPorts.kt \
        android/supercamera/src/main/java/com/dcamera/render/PreviewBridgePort.kt \
        android/supercamera/src/main/java/com/dcamera/SuperCamera.kt \
        android/supercamera/src/test/java/com/dcamera/SuperCameraDependencyTest.kt
git commit -m "feat(android): wire SuperCamera preview and capture collaborators"
```

### 任务 2：Android PreviewRenderBridge TODO 落地（submitFrame 委托渲染管线）

**Files:**
- Create: `android/supercamera/src/main/java/com/dcamera/render/RenderPipelinePort.kt`
- Modify: `android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt`
- Modify: `android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt`

**Step 1: 写失败测试**

```kotlin
// 追加到 android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt
private class FakeRenderPipelinePort(
    private val submitResult: Boolean,
) : RenderPipelinePort {
    var submitCalls = 0
    var lastFrame: Long = -1
    var lastTs: Long = -1

    override fun submitFrame(frameHandle: Long, tsNs: Long): Boolean {
        submitCalls++
        lastFrame = frameHandle
        lastTs = tsNs
        return submitResult
    }
}

@Test
fun `pipeline submit失败时返回false且frameCount不增加`() {
    val pipeline = FakeRenderPipelinePort(submitResult = false)
    val bridge = PreviewRenderBridge(renderPipeline = pipeline)
    bridge.attachSurface(1L)

    assertFalse(bridge.submitFrame(9L, 99L))
    assertEquals(0, bridge.frameCount())
    assertEquals(1, pipeline.submitCalls)
}

@Test
fun `pipeline submit成功时返回true并记录参数`() {
    val pipeline = FakeRenderPipelinePort(submitResult = true)
    val bridge = PreviewRenderBridge(renderPipeline = pipeline)
    bridge.attachSurface(1L)

    assertTrue(bridge.submitFrame(7L, 88L))
    assertEquals(1, bridge.frameCount())
    assertEquals(7L, pipeline.lastFrame)
    assertEquals(88L, pipeline.lastTs)
}
```

**Step 2: 运行并确认失败**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.render.PreviewRenderBridgeTest"`
Expected: FAIL（`RenderPipelinePort` 未定义或构造参数不匹配）。

**Step 3: 最小实现**

```kotlin
// android/supercamera/src/main/java/com/dcamera/render/RenderPipelinePort.kt
package com.dcamera.render

interface RenderPipelinePort {
    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean
}

class NoOpRenderPipelinePort : RenderPipelinePort {
    override fun submitFrame(frameHandle: Long, tsNs: Long): Boolean = true
}
```

```kotlin
// android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt
package com.dcamera.render

class PreviewRenderBridge(
    private val renderPipeline: RenderPipelinePort = NoOpRenderPipelinePort(),
) : PreviewBridgePort {
    private var surfaceAttached: Boolean = false
    private var frameCounter: Long = 0

    override fun attachSurface(surfaceHandle: Long): Boolean {
        if (surfaceHandle == 0L) return false
        surfaceAttached = true
        frameCounter = 0
        return true
    }

    override fun detachSurface() {
        surfaceAttached = false
    }

    fun submitFrame(frameHandle: Long, tsNs: Long): Boolean {
        if (!surfaceAttached || frameHandle == 0L || tsNs < 0) return false
        if (!renderPipeline.submitFrame(frameHandle, tsNs)) return false
        frameCounter++
        return true
    }

    fun frameCount(): Long = frameCounter
}
```

**Step 4: 运行并确认通过**

Run: `cd android && ./gradlew :supercamera:testDebugUnitTest --tests "com.dcamera.render.PreviewRenderBridgeTest" --tests "com.dcamera.SuperCameraDependencyTest"`
Expected: PASS。

**Step 5: 提交**

```bash
git add android/supercamera/src/main/java/com/dcamera/render/RenderPipelinePort.kt \
        android/supercamera/src/main/java/com/dcamera/render/PreviewRenderBridge.kt \
        android/supercamera/src/test/java/com/dcamera/render/PreviewRenderBridgeTest.kt
git commit -m "feat(android): forward preview frames to render pipeline port"
```

### 任务 3：iOS SuperCamera TODO 落地（会话/渲染生命周期委托）

**Files:**
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/CameraPorts.swift`
- Modify: `ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift`
- Modify: `ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift`
- Create: `ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraDependencyTests.swift`

**Step 1: 写失败测试**

```swift
// ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraDependencyTests.swift
import XCTest
@testable import SuperCameraKit

final class FakePreviewSessionPort: PreviewSessionPort {
    var startResult: Bool
    var stopResult: Bool
    var startCalls = 0
    var stopCalls = 0

    init(startResult: Bool = true, stopResult: Bool = true) {
        self.startResult = startResult
        self.stopResult = stopResult
    }

    func startPreview(surfaceHandle: UInt64) -> Bool {
        startCalls += 1
        return startResult
    }

    func stopPreview() -> Bool {
        stopCalls += 1
        return stopResult
    }
}

final class FakePreviewBridgePort: PreviewBridgePort {
    var attachResult: Bool
    var attachCalls = 0
    var detachCalls = 0

    init(attachResult: Bool = true) {
        self.attachResult = attachResult
    }

    func attach(surfaceHandle: UInt64) -> Bool {
        attachCalls += 1
        return attachResult
    }

    func detach() {
        detachCalls += 1
    }
}

final class FakePhotoCapturePort: PhotoCapturePort {
    let resultPath: String

    init(resultPath: String) {
        self.resultPath = resultPath
    }

    func capture(outputPath: String) -> CaptureResult {
        CaptureResult(path: resultPath)
    }
}

final class SuperCameraDependencyTests: XCTestCase {
    func testStartPreviewSession失败上报sessionConfigFailed() {
        let camera = SuperCamera(
            previewSession: FakePreviewSessionPort(startResult: false),
            previewBridge: FakePreviewBridgePort(),
            photoCapture: FakePhotoCapturePort(resultPath: "/tmp/p.jpg")
        )
        var code: SCErrorCode?
        camera.setErrorCallback { c, _ in code = c }

        XCTAssertFalse(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(camera.currentState(), .idle)
        XCTAssertEqual(code, .sessionConfigFailed)
    }

    func testStartPreviewRenderAttach失败会回滚stop并上报renderInitFailed() {
        let session = FakePreviewSessionPort(startResult: true)
        let camera = SuperCamera(
            previewSession: session,
            previewBridge: FakePreviewBridgePort(attachResult: false),
            photoCapture: FakePhotoCapturePort(resultPath: "/tmp/p.jpg")
        )
        var code: SCErrorCode?
        camera.setErrorCallback { c, _ in code = c }

        XCTAssertFalse(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(session.stopCalls, 1)
        XCTAssertEqual(code, .renderInitFailed)
        XCTAssertEqual(camera.currentState(), .idle)
    }

    func testTakePhoto空路径上报fileIOFailed() {
        let camera = SuperCamera(
            previewSession: FakePreviewSessionPort(),
            previewBridge: FakePreviewBridgePort(),
            photoCapture: FakePhotoCapturePort(resultPath: "")
        )
        var code: SCErrorCode?
        camera.setErrorCallback { c, _ in code = c }

        XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
        let result = camera.takePhoto(outputPath: "/tmp/p.jpg")
        XCTAssertEqual(result.path, "")
        XCTAssertEqual(code, .fileIOFailed)
        XCTAssertEqual(camera.currentState(), .previewing)
    }
}
```

**Step 2: 运行并确认失败**

Run: `cd ios/SuperCameraKit && swift test --filter SuperCameraDependencyTests`
Expected: FAIL（`PreviewSessionPort` / `PreviewBridgePort` / 新构造函数不存在）。

**Step 3: 最小实现**

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/CameraPorts.swift
import Foundation

public protocol PreviewSessionPort {
    func startPreview(surfaceHandle: UInt64) -> Bool
    func stopPreview() -> Bool
}

public protocol PreviewBridgePort {
    func attach(surfaceHandle: UInt64) -> Bool
    func detach()
}

public protocol PhotoCapturePort {
    func capture(outputPath: String) -> CaptureResult
}

public final class NoOpPreviewSessionPort: PreviewSessionPort {
    public init() {}

    public func startPreview(surfaceHandle: UInt64) -> Bool { surfaceHandle != 0 }

    public func stopPreview() -> Bool { true }
}

public final class CaptureControllerAdapter: PhotoCapturePort {
    private let controller: CaptureController

    public init(controller: CaptureController = CaptureController()) {
        self.controller = controller
    }

    public func capture(outputPath: String) -> CaptureResult {
        controller.takePhoto(outputPath: outputPath)
    }
}
```

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift
public final class PreviewRenderBridge: PreviewBridgePort {
    // existing implementation
}
```

```swift
// ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift（关键变更）
public final class SuperCamera {
    private var mode: WorkMode = .purePreview
    private var state: CameraState = .idle
    private var errorCallback: SCErrorCallback?
    private var recordPath: String = ""

    private let previewSession: PreviewSessionPort
    private let previewBridge: PreviewBridgePort
    private let photoCapture: PhotoCapturePort

    public init(
        previewSession: PreviewSessionPort = NoOpPreviewSessionPort(),
        previewBridge: PreviewBridgePort = PreviewRenderBridge(),
        photoCapture: PhotoCapturePort = CaptureControllerAdapter()
    ) {
        self.previewSession = previewSession
        self.previewBridge = previewBridge
        self.photoCapture = photoCapture
    }

    @discardableResult
    public func startPreview(surfaceHandle: UInt64) -> Bool {
        guard state == .idle else {
            errorCallback?(.invalidState, "startPreview requires idle state, current=\(state)")
            return false
        }
        state = .initializing
        guard previewSession.startPreview(surfaceHandle: surfaceHandle) else {
            state = .idle
            errorCallback?(.sessionConfigFailed, "preview session init failed")
            return false
        }
        guard previewBridge.attach(surfaceHandle: surfaceHandle) else {
            _ = previewSession.stopPreview()
            state = .idle
            errorCallback?(.renderInitFailed, "preview bridge attach failed")
            return false
        }
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
        previewBridge.detach()
        let stopped = previewSession.stopPreview()
        state = .idle
        if !stopped {
            errorCallback?(.sessionConfigFailed, "preview session stop failed")
            return false
        }
        return true
    }

    public func takePhoto(outputPath: String) -> CaptureResult {
        guard state == .previewing else {
            errorCallback?(.invalidState, "takePhoto requires previewing state, current=\(state)")
            return CaptureResult(path: "")
        }
        state = .capturing
        let result = photoCapture.capture(outputPath: outputPath)
        state = .previewing
        if result.path.isEmpty {
            errorCallback?(.fileIOFailed, "photo capture returned empty path")
        }
        return result
    }
}
```

**Step 4: 运行并确认通过**

Run: `cd ios/SuperCameraKit && swift test --filter SuperCameraDependencyTests && swift test`
Expected: PASS。

**Step 5: 提交**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/CameraPorts.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/PreviewRenderBridge.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift \
        ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraDependencyTests.swift
git commit -m "feat(ios): wire SuperCamera preview and capture collaborators"
```

### 任务 4：新增 TODO 回归守卫并接入全量验证

**Files:**
- Create: `scripts/check_no_runtime_todo.sh`
- Create: `scripts/tests/test_check_no_runtime_todo.sh`
- Modify: `scripts/verify_mvp.sh`

**Step 1: 写失败测试**

```bash
# scripts/tests/test_check_no_runtime_todo.sh
#!/usr/bin/env bash
set -euo pipefail

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

echo "// TODO: real implementation still pending" > "$TMP_FILE"

if bash "$(cd "$(dirname "$0")/.." && pwd)/check_no_runtime_todo.sh" "$TMP_FILE"; then
  echo "Expected TODO check to fail, but it passed"
  exit 1
fi

echo "PASS: TODO check correctly fails on TODO marker"
```

**Step 2: 运行并确认失败**

Run: `bash scripts/tests/test_check_no_runtime_todo.sh`
Expected: 因 `scripts/check_no_runtime_todo.sh` 不存在而失败。

**Step 3: 最小实现**

```bash
# scripts/check_no_runtime_todo.sh
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  TARGETS=(
    "$REPO_ROOT/android/supercamera/src/main"
    "$REPO_ROOT/ios/SuperCameraKit/Sources"
  )
fi

if rg -n "TODO: real implementation" "${TARGETS[@]}"; then
  echo "FAIL: unresolved runtime TODO found"
  exit 1
fi

echo "PASS: no unresolved runtime TODO markers"
```

```bash
# scripts/verify_mvp.sh（在原检查前新增）
echo "=== [1/5] Runtime TODO 回归检查 ==="
bash "$REPO_ROOT/scripts/check_no_runtime_todo.sh"

# 原有步骤整体顺延为 [2/5]...[5/5]
```

**Step 4: 运行并确认通过**

Run: `bash scripts/tests/test_check_no_runtime_todo.sh && bash scripts/verify_mvp.sh`
Expected: PASS。

**Step 5: 提交**

```bash
git add scripts/check_no_runtime_todo.sh \
        scripts/tests/test_check_no_runtime_todo.sh \
        scripts/verify_mvp.sh
git commit -m "test: add runtime TODO regression guard"
```

---

## 里程碑退出标准

- `rg -n "TODO: real implementation" android/supercamera/src/main ios/SuperCameraKit/Sources` 无匹配。
- Android `SuperCamera` 覆盖：session 启动失败、bridge attach 失败回滚、拍照空路径失败映射。
- Android `PreviewRenderBridge` 覆盖：对渲染管线端口的提交流程与计数语义。
- iOS `SuperCamera` 覆盖同样失败矩阵与状态回滚。
- `bash scripts/verify_mvp.sh` 全链路通过。
