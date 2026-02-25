# 超级相机库架构设计（V1）

- 日期：2026-02-25
- 项目：DCamera
- 平台：Android + iOS 原生
- 状态：已确认

## 1. 目标与边界

### 1.1 V1 目标（MVP）

- 相机采集与预览
- 拍照
- 录像
- 分析模式预览（为后续扫码/AI 连续分析打基础）
- 可复用基础 UI 组件（非完整业务页面）

### 1.2 已确认约束

- 对外 API：原生优先
  - Android：Kotlin API
  - iOS：Swift API
- 采集控制：
  - Android：纯 Camera2
  - iOS：AVCaptureSession
- 最低系统版本：
  - Android 7.0+
  - iOS 13+
- 渲染：
  - 预览统一走 bgfx（纯预览/分析预览/录像预览）
- 录像输入：
  - 编码输入来自 bgfx 离屏渲染结果（目标：所见即所得）

## 2. 方案决策

### 2.1 候选方案

1. 原生优先 + 共享 C++ 渲染核心
2. 共享 C++ 媒体核心 + 平台薄适配
3. 双端完全原生 + 仅共享规范

### 2.2 选型结果

采用方案 1：原生优先 + 共享 C++ 渲染核心。

原因：

- 符合 MVP 的交付速度与风险控制。
- 保留平台采集与编码的稳定性。
- 为后续滤镜/水印统一到渲染链路预留空间。

## 3. 总体架构

### 3.1 分层结构

1. 平台采集层（Platform Capture Layer）
- Android Camera2 负责相机设备、会话与请求控制。
- iOS AVCaptureSession 负责设备输入输出与会话控制。

2. 共享渲染层（Shared Render Core, C++/bgfx）
- 接收相机帧并上传 GPU 纹理。
- 处理旋转、镜像、裁切。
- 输出到预览表面。
- 输出离屏帧供录像编码。

3. 平台媒体层（Media Action Layer）
- 拍照：
  - Android `ImageReader/JPEG`
  - iOS `AVCapturePhotoOutput`
- 录像编码封装：
  - Android `MediaCodec + MediaMuxer`
  - iOS `AVAssetWriter`

4. SDK 门面层（SDK Facade）
- Android Kotlin / iOS Swift 对外 API。
- 统一状态、错误码、回调语义。

5. 基础 UI 层（Basic UI Kit）
- 预览容器、拍照按钮、录像按钮、状态提示。
- 允许业务侧替换 UI 外观和交互。

### 3.2 核心组件

- `CameraSessionController`
  - `startPreview(config)`
  - `stopPreview()`
  - `updateControl(controlPatch)`

- `PreviewRenderBridge`
  - `attachSurface(viewHandle)`
  - `detachSurface()`
  - `onFrameAvailable(frame, transform, ts)`

- `CaptureController`
  - `takePhoto(options)`
  - `cancelCapture()`

- `RecordController`
  - `startRecord(options)`
  - `stopRecord()`
  - `pauseRecord()/resumeRecord()`（V1 可选）

- `ResolutionSelector`
  - `select(mode, screenSpec, cameraCapabilities)`
  - `resolveFallback(requested)`

- `SdkFacade`
  - `onStateChanged`
  - `onError(code, message, cause)`
  - `onPhotoSaved`
  - `onRecordSaved`

### 3.3 状态机

`IDLE -> INITIALIZING -> PREVIEWING -> CAPTURING/RECORDING -> PREVIEWING -> RELEASING -> IDLE`

- 非法切换统一返回：`INVALID_STATE`
- 双端行为保持一致

## 4. 数据流与线程模型

### 4.1 数据流

1. 预览流（全部模式统一）
- Camera2 / AVCapture 输出 YUV
- `PreviewRenderBridge` 封装帧信息（buffer + ts + transform）
- `Shared Render Core(bgfx)` 渲染
- 输出至预览视图

2. 拍照流（原生高质量输出）
- 调用 `CaptureController.takePhoto`
- 平台原生输出 JPEG（V1 默认）
- 回调文件路径与元数据

3. 录像流（WYSIWYG）
- 调用 `RecordController.startRecord`
- bgfx 离屏帧作为编码输入
- 平台编码封装输出 MP4
- 结束回调路径、时长、尺寸、错误信息

### 4.2 线程模型

- UI 主线程：仅交互和 API 入口
- 相机控制线程：串行控制设备与会话
- 帧接收线程：帧拉取与队列调度
- 渲染线程：bgfx 提交与图形执行
- 编码线程：音视频编码与封装

原则：控制面串行，数据面并行；帧队列有界，避免积压。

## 5. 分辨率策略

### 5.1 工作模式

- `PURE_PREVIEW`
- `ANALYSIS`
- `PHOTO`
- `VIDEO`

### 5.2 ANALYSIS 模式（全屏倒推）

输入：
- 预览容器尺寸
- 方向信息
- 设备支持分辨率

算法：
- 第一优先级：与屏幕目标长宽比误差最小
- 第二优先级：与屏幕目标面积误差最小
- 平局策略：选择计算开销更低分辨率

目标：
- 降低分析坐标映射偏差
- 保持视觉取景与分析范围一致

### 5.3 PHOTO / VIDEO 模式

优先级：
- 1920x1080
- 1600x900
- 1280x720
- 960x540

说明：
- 拍照与录像可以独立选型。
- 若设备不支持 1080p，按阶梯回退。

### 5.4 动态切换

- API：`setWorkMode(mode)`
- 切换时重配输出与渲染链路
- 目标中断：短暂黑屏可控（目标 < 300ms）
- 回调：`onModeChanged(effectiveResolution)`

## 6. 错误处理与稳定性

### 6.1 统一错误域

- `PERMISSION`
- `DEVICE_UNAVAILABLE`
- `SESSION_CONFIG_FAILED`
- `RENDER_INIT_FAILED`
- `RENDER_SURFACE_LOST`
- `ENCODER_INIT_FAILED`
- `ENCODER_BACKPRESSURE`
- `FILE_IO_FAILED`
- `THERMAL_THROTTLE`
- `INVALID_STATE`

### 6.2 恢复策略

可恢复：
- `surface lost`
- 短时编码背压
- 临时中断

处理：
- 自动重建渲染目标/会话
- 必要时降级帧率

不可恢复：
- 权限撤销
- 编码器初始化硬失败

处理：
- 立即停止相关流程
- 返回明确错误与建议动作

可选兜底开关：
- `enableNativeEncodeFallback`（默认 `false`）
- bgfx 编码链路不可用时回退原生直编，并显式标记非所见即所得

### 6.3 观测能力

关键指标：
- 首帧时延
- 预览 FPS
- 渲染掉帧率
- 编码输入 FPS
- A/V 漂移
- 模式切换时延

日志：
- 结构化日志，按 `sessionId` 串联全链路。
- 支持导出会话诊断快照。

## 7. 测试策略

- 单元测试：
  - `ResolutionSelector`
  - 状态机合法/非法流转
  - 错误码映射一致性
- 集成测试：
  - 预览/拍照/录像主链路
  - 模式切换稳定性
  - bgfx 离屏编码输入一致性
- 设备回归：
  - Android 多 SoC、多机型
  - iOS 至少两代芯片与不同比例屏幕
- 非功能验证：
  - 启动时延、帧率、内存峰值、温升

## 8. 里程碑

- `M1`：预览链路打通（bgfx）
- `M2`：拍照能力可用
- `M3`：录像（bgfx 离屏输入）可用
- `M4`：分析模式与动态切换可用
- `M5`：稳定性与可观测性收敛

## 9. 后续扩展预留

渲染通道预留：
- `BaseFramePass -> FilterPass -> WatermarkPass -> DisplayPass/EncodePass`

意义：
- 滤镜/水印可以同时作用于预览与录像输出。
- 天然满足所见即所得目标。

## 10. 验收标准

- 三类预览模式全部走 bgfx。
- 录像编码输入来自 bgfx 离屏输出。
- 分辨率选择具备模式化规则且可复现。
- Android/iOS API 的状态和错误语义一致。
