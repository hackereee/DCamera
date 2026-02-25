# Android 最小接入样例

演示如何接入 SuperCamera 库完成预览、拍照、录像。

## 接入步骤

```kotlin
val camera = SuperCamera()
camera.setWorkMode(WorkMode.VIDEO)
camera.startPreview(surfaceHandle)
```

> 完整样例待 bgfx 渲染层集成后补充。
