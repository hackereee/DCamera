# iOS Sample 预览功能设计

## 背景与问题

当前 iOS sample 的“预览”不可用，根因是 demo 并未接入真实预览链路：
- UI 只有占位视图（`Preview Placeholder`），没有真实预览容器。
- `DemoViewModel` 使用 `SuperCamera()` 默认依赖，默认 `PreviewSessionPort` 为 `NoOpPreviewSessionPort`，不会连接真实相机输入。
- `startPreview(surfaceHandle:)` 使用硬编码 `1`，并非来自真实渲染目标。

## 目标

- 在 `samples/ios-app/SuperCameraDemo` 中实现可见的真实预览画面。
- 保持 sample 通过 `SuperCameraKit` 使用预览能力，而不是绕过 SDK 直接写在 sample UI 层。
- 权限策略调整为：
  - 预览仅依赖相机权限；
  - 录制在启动时额外校验麦克风权限。

## 非目标

- 本次不做完整 bgfx 端到端渲染接入。
- 不扩展额外业务能力（滤镜、特效、复杂拍摄参数）。

## 方案对比

1. Sample 直接接 `AVCaptureVideoPreviewLayer`，绕过 `SuperCameraKit`
- 优点：见效快
- 缺点：与 SDK 架构脱节，后续要返工

2. 在 `SuperCameraKit` 中补齐 AVFoundation 预览链路，并由 sample 走 SDK（选型）
- 优点：验证真实 SDK 行为，后续可平滑替换为 bgfx
- 缺点：改动中等

3. 直接做 bgfx 预览完整链路
- 优点：最接近最终形态
- 缺点：成本与排障复杂度最高

选型：方案 2。

## 架构设计

### 组件

- `SuperCameraKit`
  - 补充可用于 iOS 真实预览的构造入口（如工厂方法或依赖注入入口）。
  - 使用 `AVPreviewSessionPort` + `AVFoundationSessionFacade` 的真实实现连接相机帧流。
- `SuperCameraDemo`
  - 将 `Preview Placeholder` 替换为真实预览容器（`UIViewRepresentable`）。
  - 由预览容器回传 `surfaceHandle` 给 `DemoViewModel`，不再硬编码。

### 数据流

1. `ContentView` 创建真实预览容器并获取可用 `surfaceHandle`。
2. `DemoViewModel.startPreview()` 使用该 `surfaceHandle` 调用 `SuperCamera.startPreview(...)`。
3. `SuperCamera` 通过真实 `PreviewSessionPort` 获取帧并提交到 `PreviewBridgePort`。
4. 预览停止时由 `SuperCamera.stopPreview()` 统一释放。

## 权限与状态设计

### 权限策略

- 预览仅检查 camera 权限，不要求 mic。
- 启动录制时再校验 mic 权限，未授权直接失败并提示。

### 状态约束

- 录制中禁止停止预览；需先停止录制，再停止预览。
- 保持状态机一致，避免出现“录制中但预览已停”的非法组合状态。

## 错误处理与可观测性

- `DemoViewModel` 接入 `SuperCamera` 错误回调，将错误映射到明确中文提示。
- 失败提示分层：
  - 无相机权限；
  - 会话启动失败；
  - 渲染目标无效；
  - 无麦克风权限（仅录制路径）。

## 测试策略

### 单元测试（TDD）

- `DemoViewModelTests`
  - 仅 camera 授权时可启动预览；
  - camera 通过、mic 拒绝时：预览成功，录制失败并提示；
  - 无效 `surfaceHandle` 时启动预览失败并提示。
- `SuperCameraKitTests`
  - AV preview session 成功/失败路径；
  - 录制中 stopPreview 的保护逻辑。

### 集成验证

- `cd samples/ios-app/SuperCameraDemo && swift test`
- `xcodebuild -resolvePackageDependencies -workspace samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcworkspace -scheme SuperCameraDemo`
- 可选：`xcodebuild ... test` 验证 sample Xcode target。

## 验收标准

- 点击 `Start Preview` 能看到实时画面。
- 麦克风拒绝时：预览可用、录制不可用。
- 录制中尝试停止预览会被拦截并提示先停录制。
- 页面提示与真实行为一致，不出现“状态显示成功但画面无变化”的假成功。

