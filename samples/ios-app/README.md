# iOS Demo 工程

演示如何接入 SuperCameraKit 完成预览、拍照、录像。

## 运行

### Xcode 工程（推荐）

1. 用 Xcode 打开 `samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcworkspace`（不要直接打开 `.xcodeproj`，否则会与 `Package.swift` 产生包冲突）
2. 选择 iPhone 模拟器运行（Scheme: `SuperCameraDemo`）

### 重新生成 Xcode 工程

如果修改了 `project.yml`，需重新生成：

```bash
brew install xcodegen   # 首次安装
cd samples/ios-app/SuperCameraDemo && xcodegen generate
```

### SPM 测试

```bash
cd samples/ios-app/SuperCameraDemo && swift test
```

## 接入步骤

```swift
let camera = SuperCamera()
camera.setWorkMode(.video)
```

> 完整样例待 bgfx 渲染层集成后补充。

## 手工验证

1. 首次进入确认相机/麦克风权限弹窗出现。
2. 允许后点击 `Start Preview`，页面提示"预览已启动"。
3. 点击 `Take Photo`，提示"拍照成功"。
4. 点击 `Stop Preview`，页面提示"预览已停止"，确认预览画面已停止。
5. 再次点击 `Start Preview`，页面提示"预览已启动"，确认预览画面恢复（形成 `Start Preview -> Stop Preview -> Start Preview` 循环）。
6. 点击 `Start/Stop Record` 两次，提示开始/停止录像。
7. 点击 `Toggle UI Badge`，页面显示 `UI Badge: REC`。
