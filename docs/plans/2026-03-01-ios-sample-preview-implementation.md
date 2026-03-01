# iOS Sample Preview Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让 `samples/ios-app/SuperCameraDemo` 显示真实相机预览，并把权限策略改为“预览看相机权限、录制再看麦克风权限”。

**Architecture:** 保持 sample 通过 `SuperCameraKit` 工作，不在 UI 层绕过 SDK。先在 `DemoViewModel` 修正权限与 surface handle 契约，再在 `SuperCameraKit` 增加可用于 iOS 真实预览的构造入口，最后把 SwiftUI 占位视图替换为真实预览容器并联调。

**Tech Stack:** Swift 5.9, SwiftUI, AVFoundation, UIKit (`UIViewRepresentable`), Swift Package Manager, xcodebuild, XCTest

---

**Required skills during execution:** `@superpowers:test-driven-development` `@superpowers:systematic-debugging` `@superpowers:verification-before-completion`

### Task 1: 拆分预览与录制权限门禁（DemoViewModel）

**Files:**
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift`

**Step 1: Write the failing test**

在 `DemoViewModelTests.swift` 追加两个测试（先只写测试）：

```swift
func test仅相机授权也可启动预览() {
    let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: false))
    vm.requestInitialPermissions()
    XCTAssertTrue(vm.startPreview())
    XCTAssertEqual(vm.lastMessage, "预览已启动")
}

func test麦克风未授权时录制被阻止并提示() {
    let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: false))
    vm.requestInitialPermissions()
    XCTAssertTrue(vm.startPreview())
    XCTAssertFalse(vm.toggleRecord(path: "/tmp/v.mp4"))
    XCTAssertEqual(vm.lastMessage, "请在系统设置开启麦克风权限")
}
```

**Step 2: Run test to verify it fails**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter DemoViewModelTests`  
Expected: FAIL（当前实现把 `permissionsGranted = camera && mic`，会导致第一个测试失败）

**Step 3: Write minimal implementation**

在 `DemoViewModel.swift` 做最小改动：

```swift
@Published var cameraPermissionGranted: Bool = false
@Published var microphonePermissionGranted: Bool = false

func requestInitialPermissions() {
    permissionService.requestCameraPermission { [self] cameraGranted in
        self.cameraPermissionGranted = cameraGranted
        self.permissionService.requestMicrophonePermission { micGranted in
            self.microphonePermissionGranted = micGranted
            self.permissionsGranted = cameraGranted // 兼容旧字段，语义改为“可预览”
            self.lastMessage = cameraGranted ? "权限已授权" : "请在系统设置开启相机权限"
        }
    }
}

func startPreview() -> Bool {
    guard cameraPermissionGranted else {
        lastMessage = "请在系统设置开启相机权限"
        return false
    }
    ...
}

func toggleRecord(path: String) -> Bool {
    guard cameraPermissionGranted else {
        lastMessage = "请在系统设置开启相机权限"
        return false
    }
    guard microphonePermissionGranted else {
        lastMessage = "请在系统设置开启麦克风权限"
        return false
    }
    ...
}
```

**Step 4: Run test to verify it passes**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter DemoViewModelTests`  
Expected: PASS

**Step 5: Commit**

```bash
git add samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift
git commit -m "fix(sample-ios): split preview and recording permission gates"
```

### Task 2: 建立 surface handle 契约，移除硬编码 handle

**Files:**
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift`

**Step 1: Write the failing test**

在 `DemoViewModelTests.swift` 增加测试，约束“没有 surface handle 不允许启动预览”：

```swift
func test缺少预览surfaceHandle时启动预览失败() {
    let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: true))
    vm.requestInitialPermissions()
    XCTAssertFalse(vm.startPreview())
    XCTAssertEqual(vm.lastMessage, "预览启动失败（渲染目标无效）")
}
```

**Step 2: Run test to verify it fails**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter 缺少预览surfaceHandle时启动预览失败`  
Expected: FAIL（当前代码硬编码 `surfaceHandle = 1`）

**Step 3: Write minimal implementation**

在 `DemoViewModel.swift` 增加 surface handle 存储与 setter：

```swift
private var previewSurfaceHandle: UInt64?

func setPreviewSurfaceHandle(_ handle: UInt64?) {
    previewSurfaceHandle = handle
}

func startPreview() -> Bool {
    guard cameraPermissionGranted else {
        lastMessage = "请在系统设置开启相机权限"
        return false
    }
    guard let handle = previewSurfaceHandle, handle != 0 else {
        lastMessage = "预览启动失败（渲染目标无效）"
        return false
    }
    let ok = camera.startPreview(surfaceHandle: handle)
    previewing = ok
    lastMessage = ok ? "预览已启动" : "预览启动失败（会话初始化失败）"
    return ok
}
```

同时更新旧测试：在需要 `startPreview()` 成功的测试里先调用 `vm.setPreviewSurfaceHandle(1)`。

**Step 4: Run test to verify it passes**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter DemoViewModelTests`  
Expected: PASS

**Step 5: Commit**

```bash
git add samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift
git commit -m "fix(sample-ios): require valid preview surface handle"
```

### Task 3: 在 SuperCameraKit 增加 iOS 真实预览依赖注入入口

**Files:**
- Create: `ios/SuperCameraKit/Sources/SuperCameraKit/av/LiveAVFoundationSessionFacade.swift`
- Modify: `ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift`
- Modify: `ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift`

**Step 1: Write the failing test**

先在 `SuperCameraStateTests.swift` 加一个状态约束测试（录制中不能停止预览）：

```swift
func test录制中停止预览失败且状态保持录制中() {
    let camera = SuperCamera()
    XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
    XCTAssertTrue(camera.startRecord(path: "/tmp/out.mp4"))
    XCTAssertFalse(camera.stopPreview())
    XCTAssertEqual(camera.currentState(), .recording)
}
```

**Step 2: Run test to verify it fails**

Run: `cd ios/SuperCameraKit && swift test --filter 录制中停止预览失败且状态保持录制中`  
Expected: FAIL（当前 `stopPreview` 仅要求 `.previewing`，此测试用于锁定状态保护）

**Step 3: Write minimal implementation**

1) 在 `SuperCamera.swift` 增加工厂方法，供 sample 明确创建 iOS live camera（非默认 NoOp）：

```swift
public static func makeLiveIOS(
    previewSession: PreviewSessionPort,
    previewBridge: PreviewBridgePort = PreviewRenderBridge(),
    photoCapture: PhotoCapturePort = CaptureControllerAdapter()
) -> SuperCamera {
    SuperCamera(previewSession: previewSession, previewBridge: previewBridge, photoCapture: photoCapture)
}
```

2) 调整 `stopPreview()`，录制中返回失败并上报 `.invalidState`。

3) 新建 `LiveAVFoundationSessionFacade.swift`（`#if canImport(AVFoundation) && canImport(UIKit)`）：
- 将 `surfaceHandle` 还原为 `UIView` 指针；
- 取 `view.layer`（要求 `AVCaptureVideoPreviewLayer`）并绑定 `session`；
- 启动 `AVCaptureSession` + `AVCaptureVideoDataOutput`；
- 在回调中产出 `PreviewFrame`；
- `stop()` 停止 session 并清理 output/delegate。

**Step 4: Run test to verify it passes**

Run: `cd ios/SuperCameraKit && swift test`  
Expected: PASS

**Step 5: Commit**

```bash
git add ios/SuperCameraKit/Sources/SuperCameraKit/SuperCamera.swift \
        ios/SuperCameraKit/Sources/SuperCameraKit/av/LiveAVFoundationSessionFacade.swift \
        ios/SuperCameraKit/Tests/SuperCameraKitTests/SuperCameraStateTests.swift
git commit -m "feat(ios-kit): add live AVFoundation preview session entrypoint"
```

### Task 4: 用 SwiftUI 真实预览容器替换占位图

**Files:**
- Create: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/CameraPreviewContainer.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/ContentView.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift`
- Test: `samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift`

**Step 1: Write the failing test**

在 `DemoViewModelTests.swift` 增加“设置 surface 后可启动预览”测试：

```swift
func test设置surface后可启动预览() {
    let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: true))
    vm.requestInitialPermissions()
    vm.setPreviewSurfaceHandle(1)
    XCTAssertTrue(vm.startPreview())
}
```

**Step 2: Run test to verify it fails**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter 设置surface后可启动预览`  
Expected: FAIL（在 Task 3 之前 sample 仍未连接 live preview）

**Step 3: Write minimal implementation**

新增 `CameraPreviewContainer.swift`：

```swift
import SwiftUI
import AVFoundation

struct CameraPreviewContainer: UIViewRepresentable {
    let onSurfaceReady: (UInt64) -> Void

    final class PreviewHostView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        let ptr = Unmanaged.passUnretained(view).toOpaque()
        onSurfaceReady(UInt64(UInt(bitPattern: ptr)))
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}
}
```

替换 `ContentView.swift` 占位块：

```swift
CameraPreviewContainer { handle in
    vm.setPreviewSurfaceHandle(handle)
}
.frame(height: 300)
```

并让 `DemoViewModel` 使用 Task 3 新增的 live 构造入口（在 iOS 运行时）。

**Step 4: Run test to verify it passes**

Run: `cd samples/ios-app/SuperCameraDemo && swift test --filter DemoViewModelTests`  
Expected: PASS

**Step 5: Commit**

```bash
git add samples/ios-app/SuperCameraDemo/SuperCameraDemo/CameraPreviewContainer.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/ContentView.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift
git commit -m "feat(sample-ios): wire real preview container and surface handle"
```

### Task 5: 全量验证与文档更新

**Files:**
- Modify: `samples/ios-app/README.md`

**Step 1: Write the failing test**

为手工验收标准写一个轻量脚本测试（可选）：

```bash
#!/usr/bin/env bash
set -euo pipefail
rg -n "预览仅依赖相机权限|录制需要麦克风权限" samples/ios-app/README.md
```

保存到：`scripts/tests/test_ios_sample_preview_permissions_doc.sh`

**Step 2: Run test to verify it fails**

Run: `bash scripts/tests/test_ios_sample_preview_permissions_doc.sh`  
Expected: FAIL（README 还未补充新规则）

**Step 3: Write minimal implementation**

更新 `samples/ios-app/README.md`：
- 明确预览与录制权限策略；
- 新增排障说明（无画面时检查权限与 surface 初始化顺序）。

**Step 4: Run test to verify it passes**

Run:
- `bash scripts/tests/test_ios_sample_preview_permissions_doc.sh`
- `cd samples/ios-app/SuperCameraDemo && swift test`
- `xcodebuild -resolvePackageDependencies -workspace samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcworkspace -scheme SuperCameraDemo`

Expected: 全部 PASS

**Step 5: Commit**

```bash
git add samples/ios-app/README.md scripts/tests/test_ios_sample_preview_permissions_doc.sh
git commit -m "docs(sample-ios): document preview/record permission behavior"
```

