# MVP 手动验证清单

## 自动化测试（scripts/verify_mvp.sh）

- [ ] C++ 共享核心：6 个测试全部通过
- [ ] Android 单元测试：supercamera + supercamera-ui 模块通过
- [ ] iOS SuperCameraKit：4 个测试全部通过
- [ ] iOS SuperCameraUI：1 个测试通过

## 设备验证（需真机或模拟器）

### Android

- [ ] 预览画面正常显示（bgfx 渲染）
- [ ] 预览停止后可恢复（Start Preview -> Stop Preview -> Start Preview）
- [ ] 拍照保存 JPEG 至指定路径
- [ ] 录像保存 MP4 至指定路径
- [ ] 模式切换（纯预览 / 分析 / 拍照 / 录像）无崩溃
- [ ] 状态回调正确触发

### iOS

- [ ] 预览画面正常显示（bgfx 渲染）
- [ ] 预览停止后可恢复（Start Preview -> Stop Preview -> Start Preview）
- [ ] 拍照保存至指定路径
- [ ] 录像保存 MP4 至指定路径
- [ ] 模式切换无崩溃
- [ ] 状态回调正确触发

## 性能基线

- [ ] 首帧时延 < 500ms
- [ ] 预览帧率 >= 25fps
- [ ] 录像编码输入帧率 >= 25fps
- [ ] A/V 漂移 < 50ms
