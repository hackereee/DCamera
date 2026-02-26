# Android Demo 工程

## 运行

```bash
cd android
./gradlew -p ../samples/android-app :app:assembleDebug
```

安装 `samples/android-app/app/build/outputs/apk/debug/app-debug.apk` 后启动。

## 手工验证

1. 首次进入确认相机/麦克风权限弹窗出现。
2. 允许后点击 `Start Preview`，结果区显示"预览已启动"。
3. 点击 `Take Photo`，结果区显示"拍照成功"。
4. 点击 `Start/Stop Record` 两次，结果区依次显示开始/停止录像。
5. 点击 `Toggle UI Badge`，`tvUiBadge` 显示 `REC`。
