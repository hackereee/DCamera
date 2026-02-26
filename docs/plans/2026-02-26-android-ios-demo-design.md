# Android 与 iOS Demo 工程设计（手工验证 supercamera / supercamera-ui）

- 日期：2026-02-26
- 状态：已确认
- 目标：提供 Android 与 iOS 两个平台可运行 demo，用于手工验证 `supercamera` 与 `supercamera-ui` 基础能力。

## 1. 背景与目标

当前仓库仅有 `samples/android-app/README.md` 与 `samples/ios-app/README.md` 的接入说明，没有可直接运行的示例工程。为了降低回归验证成本，需要新增双平台 demo 工程，保证每次库能力变更后都能快速手工验证。

本次范围仅覆盖基础链路，不扩展业务逻辑。

## 2. 范围与非目标

### 2.1 本次范围

- Android demo：本地源码依赖 `:supercamera` 与 `:supercamera-ui`
- iOS demo：SwiftUI demo，本地路径依赖 `SuperCameraKit` 与 `SuperCameraUI`
- 两端统一验证以下能力：
  1. 启动预览
  2. 拍照
  3. 开始录像 / 停止录像
  4. `supercamera-ui` 基础控件可见且可点击
- 动态权限申请：
  - Android：`CAMERA`，以及录像前 `RECORD_AUDIO`
  - iOS：`Camera`（及录像所需 `Microphone`）
- 权限拒绝时必须有可见提示，并阻止非法动作

### 2.2 非目标

- 不做复杂路由、多页面业务流程
- 不做网络上传、媒体管理、账号体系
- 不做发布形态依赖（Maven/CocoaPods/远程 SPM）

## 3. 方案选择

已选方案：**方案 A（仓库内双平台最小 demo 工程）**。

理由：
- 与当前“手工验证组件库”目标最匹配
- 上手快、维护成本低
- 能直接跟随本地源码变更进行验证

## 4. 总体架构

### 4.1 目录与工程形态

- Android：在 `samples/android-app/` 下新增可运行 demo app（本地依赖根工程模块）
- iOS：在 `samples/ios-app/` 下新增 SwiftUI 可运行 demo app（本地路径依赖 `ios/` 下两个 Swift Package）

### 4.2 页面架构（两端一致）

单页 `CameraDemoScreen`，包含四个区域：

1. `PreviewContainer`
- 已授权：展示预览承载区域
- 未授权：展示占位与权限提示

2. `PrimaryActions`
- `Start Preview`
- `Take Photo`
- `Start Record`
- `Stop Record`

3. `UiKitSection`
- 集成 `supercamera-ui` 基础控件并暴露点击交互

4. `ResultPanel`
- 展示最近一次操作结果（成功/失败、路径、提示信息）

## 5. 交互状态机

### 5.1 页面状态

- `permissionState`: `unknown | granted | denied`
- `cameraState`: `idle | previewing | recording`
- `lastMessage`: 最近操作文本结果

### 5.2 按钮可用性规则

- 未授权：禁用相机动作，只允许“请求权限”
- 授权且 `idle`：允许 `Start Preview`
- `previewing`：允许 `Take Photo`、`Start Record`
- `recording`：允许 `Stop Record`，禁用其他冲突动作

## 6. 权限与错误处理

### 6.1 动态权限

- Android
  - 首次进入页面请求 `CAMERA`
  - 点击开始录像前检查/请求 `RECORD_AUDIO`
- iOS
  - 进入页面或首次相机动作前检查授权状态
  - `Info.plist` 配置相机与麦克风用途说明文案

### 6.2 错误处理策略

- 权限拒绝：提示“请前往系统设置开启权限”
- 非法状态调用：在 `ResultPanel` 显示失败原因
- 拍照/录像返回空路径：明确标记失败，不吞错
- 所有错误必须可见，不允许静默失败

## 7. 手工验收清单

1. 首次进入触发权限弹窗，允许后可启动预览
2. 拒绝权限时按钮禁用且出现引导文案
3. 预览状态拍照成功，显示图片路径
4. 预览状态开始录像并停止，显示视频路径
5. `supercamera-ui` 基础控件可见并可点击
6. 录像中触发不允许动作时有明确提示

## 8. 文档交付

需更新以下文档：

- `samples/android-app/README.md`
- `samples/ios-app/README.md`

文档至少包含：
- 运行前置条件
- 启动方式
- 验证步骤
- 常见问题排查

## 9. 风险与约束

- 本地源码依赖路径在 CI/不同机器上可能有差异，需要 README 明确目录前提
- iOS 真机权限行为与模拟器存在差异，需标注推荐验证环境
- Android 不同系统版本权限弹窗行为不同，需在结果面板中显示当前状态便于排查

## 10. 结论

本设计以“最小可运行、可重复手工验证”为优先，先完成双平台基础验证闭环，再按后续需求扩展模式切换与异常路径覆盖。
