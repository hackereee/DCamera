# SuperCamera 预览阶段（Phase 1）设计（Camera2 + AVFoundation + bgfx）

- 日期：2026-02-27
- 状态：已确认
- 范围：仅预览能力（先完成自动+手工验证，再进入下一阶段）

## 1. 背景与目标

当前仓库的预览链路仍以占位实现为主：
- Android `NoOpPreviewSessionPort`
- iOS `NoOpPreviewSessionPort`
- `PreviewRenderBridge` 仅做句柄合法性与计数，不接真实设备帧流

本阶段目标是在不扩展拍照/录像复杂能力的前提下，完成双端真实预览闭环：
- Android 使用 Camera2 采集
- iOS 使用 AVFoundation 采集
- 预览渲染统一走 bgfx
- `startPreview/stopPreview` 稳定可重复

## 2. 约束与范围

### 2.1 已确认约束

- Android：必须使用 Camera2（不使用 CameraX）
- iOS：必须使用 AVFoundation
- 预览画面：必须通过 bgfx 渲染，不允许平台原生直出替代

### 2.2 本阶段范围（必须交付）

- 双端真机实时预览（授权后 2 秒内见首帧）
- 双端 `startPreview/stopPreview` 正常启停
- 自动化测试通过（状态机、桥接、失败回滚）
- 手工验证清单通过（双端 demo）

### 2.3 本阶段非目标（明确延期）

- 前后摄像头切换
- 相机分辨率切换
- 拍照与录像实功能补全
- 旋转矫正与复杂性能优化

> 注：前后摄切换与分辨率切换已记录为下一阶段目标。

## 3. 总体架构

本阶段采用“平台采集 + 共享 bgfx 渲染核心”方案：

1. SDK 门面层（现有 `SuperCamera`）
- 保持对外 API 语义
- 管理状态机与错误码上报

2. 平台预览会话层（真实实现）
- Android：`Camera2PreviewSessionPort`
- iOS：`AVPreviewSessionPort`
- 负责设备/会话生命周期、视频帧采集与回调

3. 共享渲染层（`shared/render-core`）
- 接收平台帧数据与时间戳
- 通过 bgfx 执行纹理上传与预览绘制
- 输出到平台 surface/layer

4. 平台渲染桥接层
- Android：`Surface`/`ANativeWindow` 与 bgfx 绑定
- iOS：`CAMetalLayer` 与 bgfx 绑定

## 4. 组件与数据流

### 4.1 Android 组件

- `Camera2PreviewSessionPort`：封装 Camera2 打开设备、创建会话、配置 `ImageReader`
- `AndroidFrameSource`：消费 `YUV_420_888` 帧并投递到 `PreviewRenderBridge`
- `AndroidBgfxSurfaceBridge`：管理 surface 附着/分离和渲染目标生命周期

### 4.2 iOS 组件

- `AVPreviewSessionPort`：封装 `AVCaptureSession` 启停与输入输出绑定
- `IOSFrameSource`：通过 `AVCaptureVideoDataOutputSampleBufferDelegate` 提交帧
- `IOSBgfxSurfaceBridge`：管理 `CAMetalLayer` 与 bgfx 视图绑定

### 4.3 主链路

1. `SuperCamera.startPreview(surfaceHandle)` 进入 `INITIALIZING`
2. 平台会话启动成功并开始输出帧
3. 帧进入 `PreviewRenderBridge.submitFrame(...)`
4. `RenderPipeline` 在 bgfx 线程渲染到目标 surface
5. 成功后状态进入 `PREVIEWING`
6. `stopPreview()` 停止会话、分离 surface、清理帧队列并回到 `IDLE`

## 5. 并发模型

- 控制面：串行队列（Android `HandlerThread` / iOS 串行 `DispatchQueue`）
- 数据面：采集回调线程 + bgfx 渲染线程
- 帧队列策略：有界队列，满时丢旧保新（latest-wins），避免预览延迟堆积

## 6. 错误处理与回滚

- 会话启动失败：`SESSION_CONFIG_FAILED`，状态回 `IDLE`
- surface/bgfx 绑定失败：`RENDER_INIT_FAILED`，回滚 stop session，再回 `IDLE`
- 非法状态调用：`INVALID_STATE`
- 单帧异常：丢弃并计数，不中断会话
- 连续异常超过阈值：上报 `RENDER_SURFACE_LOST`，触发一次自动重建（一次性）

## 7. 验证方案

### 7.1 自动化验证

1. `shared/render-core`
- 验证帧提交流程、队列上限、释放后行为

2. Android `supercamera`
- 验证启动成功、attach 失败回滚、stop 释放后不可继续收帧

3. iOS `SuperCameraKit`
- 验证会话启停、失败回滚、stop 后帧不再推进

### 7.2 手工验证（真机）

Android：
1. 授权后点击 `Start Preview`，2 秒内出现实时画面
2. 点击 `Stop Preview` 后画面停止
3. 再次 `Start Preview` 可恢复

iOS：
1. 授权后点击 `Start Preview`，2 秒内出现实时画面
2. 点击 `Stop Preview` 后画面停止
3. 再次 `Start Preview` 可恢复

## 8. 验收标准

- 双端预览真实可见，且渲染路径走 bgfx
- 双端预览启停稳定，无崩溃
- 预览相关自动化测试全通过
- demo 手工清单全通过

## 9. 下一阶段预告（不在本次实现）

- 前后摄像头切换
- 相机分辨率切换
- 拍照与录像功能补全
- 旋转矫正、性能观测与恢复策略增强
