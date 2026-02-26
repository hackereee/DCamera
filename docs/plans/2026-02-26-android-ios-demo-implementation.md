# Android/iOS Demo 工程 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在仓库内新增 Android 与 iOS 两个平台的可运行 demo 工程，用于手工验证 `supercamera` 与 `supercamera-ui` 的基础链路（预览/拍照/录像/基础控件），并覆盖动态权限申请流程。

**Architecture:** Android demo 使用独立 sample Gradle 根工程，本地依赖 `../../android/supercamera` 与 `../../android/supercamera-ui`。iOS demo 使用独立 SwiftUI App 工程，本地链接 `ios/SuperCameraKit` 与 `ios/SuperCameraUI`。两端统一通过轻量 `DemoViewModel/Controller` 管理权限状态、按钮可用性和结果面板。

**Tech Stack:** Kotlin + AndroidX + JUnit + Gradle，SwiftUI + AVFoundation + XCTest + Xcodebuild。

---

## 执行约束

- 严格按 `@test-driven-development` 执行：先失败测试，再最小实现。
- 每个任务单独提交，提交粒度按任务边界。
- 遇到异常先使用 `@systematic-debugging`，不要扩大改动范围。
- 任务完成与里程碑完成前执行 `@verification-before-completion`。

### 任务 1：搭建 Android demo 工程骨架（本地源码依赖）

**Files:**
- Create: `samples/android-app/settings.gradle.kts`
- Create: `samples/android-app/build.gradle.kts`
- Create: `samples/android-app/gradle.properties`
- Create: `samples/android-app/app/build.gradle.kts`
- Create: `samples/android-app/app/src/main/AndroidManifest.xml`
- Create: `samples/android-app/app/src/main/java/com/dcamera/demo/Bootstrap.kt`
- Create: `samples/android-app/app/src/test/java/com/dcamera/demo/BootstrapTest.kt`

**Step 1: 写失败测试**

```kotlin
// samples/android-app/app/src/test/java/com/dcamera/demo/BootstrapTest.kt
package com.dcamera.demo

import kotlin.test.Test
import kotlin.test.assertEquals

class BootstrapTest {
    @Test
    fun `demo工程可识别基础应用ID`() {
        assertEquals("com.dcamera.demo", Bootstrap.applicationId())
    }
}
```

**Step 2: 运行并确认失败**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest`
Expected: FAIL（`Bootstrap` 未定义）。

**Step 3: 最小实现（含工程配置）**

```kotlin
// samples/android-app/settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "supercamera-android-demo"
include(":app")
include(":supercamera")
project(":supercamera").projectDir = file("../../android/supercamera")
include(":supercamera-ui")
project(":supercamera-ui").projectDir = file("../../android/supercamera-ui")
```

```kotlin
// samples/android-app/build.gradle.kts
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("com.android.library") version "8.7.3" apply false
    kotlin("android") version "2.0.21" apply false
}
```

```properties
# samples/android-app/gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
```

```kotlin
// samples/android-app/app/build.gradle.kts
plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    namespace = "com.dcamera.demo"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.dcamera.demo"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    implementation(project(":supercamera"))
    implementation(project(":supercamera-ui"))

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")

    testImplementation(kotlin("test"))
}
```

```xml
<!-- samples/android-app/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <application
        android:allowBackup="true"
        android:label="SuperCameraDemo"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar" />
</manifest>
```

```kotlin
// samples/android-app/app/src/main/java/com/dcamera/demo/Bootstrap.kt
package com.dcamera.demo

object Bootstrap {
    fun applicationId(): String = "com.dcamera.demo"
}
```

**Step 4: 运行并确认通过**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest`
Expected: PASS。

**Step 5: 提交**

```bash
git add samples/android-app/settings.gradle.kts \
        samples/android-app/build.gradle.kts \
        samples/android-app/gradle.properties \
        samples/android-app/app/build.gradle.kts \
        samples/android-app/app/src/main/AndroidManifest.xml \
        samples/android-app/app/src/main/java/com/dcamera/demo/Bootstrap.kt \
        samples/android-app/app/src/test/java/com/dcamera/demo/BootstrapTest.kt
git commit -m "feat(sample-android): scaffold demo project with local module dependencies"
```

### 任务 2：实现 Android DemoController（权限门禁 + 基础链路状态）

**Files:**
- Create: `samples/android-app/app/src/main/java/com/dcamera/demo/DemoController.kt`
- Create: `samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt`

**Step 1: 写失败测试**

```kotlin
// samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt
package com.dcamera.demo

import com.dcamera.SuperCamera
import com.dcamera.ui.BasicCameraView
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DemoControllerTest {
    @Test
    fun `未授权时禁止预览与拍照`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = false, micGranted = false)

        assertFalse(controller.startPreview(1L))
        val photoPath = controller.takePhoto("/tmp/p.jpg")
        assertEquals("", photoPath)
        assertEquals("权限未授予", controller.lastMessage)
    }

    @Test
    fun `授权后可启动预览并拍照`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = true, micGranted = true)

        assertTrue(controller.startPreview(1L))
        val photoPath = controller.takePhoto("/tmp/p.jpg")
        assertTrue(photoPath.endsWith(".jpg"))
    }

    @Test
    fun `录像开关遵循状态机`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        controller.onPermissionResult(cameraGranted = true, micGranted = true)
        controller.startPreview(1L)

        assertTrue(controller.toggleRecord("/tmp/v.mp4"))
        assertEquals(true, controller.recording)
        assertTrue(controller.toggleRecord("/tmp/v.mp4"))
        assertEquals(false, controller.recording)
    }

    @Test
    fun `ui组件点击后REC标记可见`() {
        val controller = DemoController(SuperCamera(), BasicCameraView())
        assertEquals("", controller.uiBadge())
        controller.toggleUiRecordBadge()
        assertEquals("REC", controller.uiBadge())
    }
}
```

**Step 2: 运行并确认失败**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest --tests "com.dcamera.demo.DemoControllerTest"`
Expected: FAIL（`DemoController` 未定义）。

**Step 3: 最小实现**

```kotlin
// samples/android-app/app/src/main/java/com/dcamera/demo/DemoController.kt
package com.dcamera.demo

import com.dcamera.SuperCamera
import com.dcamera.ui.BasicCameraView

class DemoController(
    private val camera: SuperCamera,
    private val basicCameraView: BasicCameraView,
) {
    var cameraGranted: Boolean = false
        private set
    var micGranted: Boolean = false
        private set
    var previewing: Boolean = false
        private set
    var recording: Boolean = false
        private set
    var lastMessage: String = ""
        private set

    fun onPermissionResult(cameraGranted: Boolean, micGranted: Boolean) {
        this.cameraGranted = cameraGranted
        this.micGranted = micGranted
        if (!cameraGranted) {
            lastMessage = "权限未授予"
        }
    }

    fun startPreview(surfaceHandle: Long): Boolean {
        if (!cameraGranted) {
            lastMessage = "权限未授予"
            return false
        }
        val ok = camera.startPreview(surfaceHandle)
        previewing = ok
        lastMessage = if (ok) "预览已启动" else "预览启动失败"
        return ok
    }

    fun takePhoto(path: String): String {
        if (!cameraGranted) {
            lastMessage = "权限未授予"
            return ""
        }
        val result = camera.takePhoto(path)
        lastMessage = if (result.path.isBlank()) "拍照失败" else "拍照成功"
        return result.path
    }

    fun toggleRecord(path: String): Boolean {
        if (!cameraGranted || !micGranted) {
            lastMessage = "权限未授予"
            return false
        }
        if (!previewing) {
            lastMessage = "请先启动预览"
            return false
        }

        return if (!recording) {
            val ok = camera.startRecord(path)
            recording = ok
            lastMessage = if (ok) "开始录像" else "开始录像失败"
            ok
        } else {
            val result = camera.stopRecord()
            val ok = result.path.isNotBlank()
            recording = false
            lastMessage = if (ok) "停止录像" else "停止录像失败"
            ok
        }
    }

    fun toggleUiRecordBadge() {
        basicCameraView.onRecordTapped()
    }

    fun uiBadge(): String = basicCameraView.recordingBadgeText()
}
```

**Step 4: 运行并确认通过**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest --tests "com.dcamera.demo.DemoControllerTest"`
Expected: PASS。

**Step 5: 提交**

```bash
git add samples/android-app/app/src/main/java/com/dcamera/demo/DemoController.kt \
        samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt
git commit -m "feat(sample-android): add demo controller for permission and camera actions"
```

### 任务 3：实现 Android Demo Activity（动态权限 + 手工验证界面）

**Files:**
- Create: `samples/android-app/app/src/main/res/layout/activity_main.xml`
- Create: `samples/android-app/app/src/main/java/com/dcamera/demo/MainActivity.kt`
- Modify: `samples/android-app/app/src/main/AndroidManifest.xml`
- Modify: `samples/android-app/README.md`

**Step 1: 写失败测试**

```kotlin
// append samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt
@Test
fun `未启动预览时录像被阻止`() {
    val controller = DemoController(SuperCamera(), BasicCameraView())
    controller.onPermissionResult(cameraGranted = true, micGranted = true)

    assertFalse(controller.toggleRecord("/tmp/v.mp4"))
    assertEquals("请先启动预览", controller.lastMessage)
}
```

**Step 2: 运行并确认失败**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest --tests "com.dcamera.demo.DemoControllerTest.未启动预览时录像被阻止"`
Expected: FAIL（`toggleRecord` 未覆盖此文案或逻辑）。

**Step 3: 最小实现（Activity + 布局）**

```xml
<!-- samples/android-app/app/src/main/res/layout/activity_main.xml -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp">

    <TextView
        android:id="@+id/tvPreview"
        android:layout_width="match_parent"
        android:layout_height="140dp"
        android:gravity="center"
        android:text="Preview Placeholder" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal">

        <Button
            android:id="@+id/btnPreview"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Start Preview" />

        <Button
            android:id="@+id/btnPhoto"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Take Photo" />
    </LinearLayout>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal">

        <Button
            android:id="@+id/btnRecord"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Start/Stop Record" />

        <Button
            android:id="@+id/btnUi"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Toggle UI Badge" />
    </LinearLayout>

    <TextView
        android:id="@+id/tvUiBadge"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="" />

    <TextView
        android:id="@+id/tvResult"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="" />
</LinearLayout>
```

```kotlin
// samples/android-app/app/src/main/java/com/dcamera/demo/MainActivity.kt
package com.dcamera.demo

import android.Manifest
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.dcamera.SuperCamera
import com.dcamera.ui.BasicCameraView

class MainActivity : AppCompatActivity() {
    private val controller = DemoController(SuperCamera(), BasicCameraView())

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val cameraGranted = result[Manifest.permission.CAMERA] == true
        val micGranted = result[Manifest.permission.RECORD_AUDIO] == true
        controller.onPermissionResult(cameraGranted, micGranted)
        refreshResult()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        permissionLauncher.launch(arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
        ))

        findViewById<Button>(R.id.btnPreview).setOnClickListener {
            controller.startPreview(1L)
            refreshResult()
        }

        findViewById<Button>(R.id.btnPhoto).setOnClickListener {
            controller.takePhoto("/tmp/demo_photo.jpg")
            refreshResult()
        }

        findViewById<Button>(R.id.btnRecord).setOnClickListener {
            controller.toggleRecord("/tmp/demo_video.mp4")
            refreshResult()
        }

        findViewById<Button>(R.id.btnUi).setOnClickListener {
            controller.toggleUiRecordBadge()
            refreshResult()
        }

        refreshResult()
    }

    private fun refreshResult() {
        findViewById<TextView>(R.id.tvUiBadge).text = controller.uiBadge()
        findViewById<TextView>(R.id.tvResult).text = controller.lastMessage
    }
}
```

```xml
<!-- update samples/android-app/app/src/main/AndroidManifest.xml -->
<application ...>
    <activity
        android:name=".MainActivity"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent-filter>
    </activity>
</application>
```

```md
<!-- update samples/android-app/README.md -->
# Android Demo 工程

## 运行

```bash
cd android
./gradlew -p ../samples/android-app :app:assembleDebug
```

安装 `samples/android-app/app/build/outputs/apk/debug/app-debug.apk` 后启动。

## 手工验证

1. 首次进入确认相机/麦克风权限弹窗出现。
2. 允许后点击 `Start Preview`，结果区显示“预览已启动”。
3. 点击 `Take Photo`，结果区显示“拍照成功”。
4. 点击 `Start/Stop Record` 两次，结果区依次显示开始/停止录像。
5. 点击 `Toggle UI Badge`，`tvUiBadge` 显示 `REC`。
```

**Step 4: 运行并确认通过**

Run: `cd android && ./gradlew -p ../samples/android-app :app:testDebugUnitTest :app:assembleDebug`
Expected: PASS。

**Step 5: 提交**

```bash
git add samples/android-app/app/src/main/res/layout/activity_main.xml \
        samples/android-app/app/src/main/java/com/dcamera/demo/MainActivity.kt \
        samples/android-app/app/src/main/AndroidManifest.xml \
        samples/android-app/app/src/test/java/com/dcamera/demo/DemoControllerTest.kt \
        samples/android-app/README.md
git commit -m "feat(sample-android): add demo activity with runtime permissions and manual flow"
```

### 任务 4：搭建 iOS SwiftUI Demo 工程（本地依赖包）

**Files:**
- Create: `samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj/project.pbxproj`（Xcode 生成）
- Create: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/SuperCameraDemoApp.swift`
- Create: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift`
- Create: `samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift`

**Step 1: 写失败测试**

```swift
// samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift
import XCTest
@testable import SuperCameraDemo

final class FakePermissionService: PermissionService {
    var cameraGranted: Bool
    var micGranted: Bool

    init(cameraGranted: Bool, micGranted: Bool) {
        self.cameraGranted = cameraGranted
        self.micGranted = micGranted
    }

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        completion(cameraGranted)
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        completion(micGranted)
    }
}

final class DemoViewModelTests: XCTestCase {
    func test未授权时提示权限不足() {
        let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: false, micGranted: false))
        vm.requestInitialPermissions()
        XCTAssertEqual(vm.lastMessage, "请在系统设置开启权限")
        XCTAssertFalse(vm.permissionsGranted)
    }
}
```

**Step 2: 运行并确认失败**

Run: `xcodebuild -project samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj -scheme SuperCameraDemo -destination 'platform=iOS Simulator,name=iPhone 15' test`
Expected: FAIL（`DemoViewModel`/`PermissionService` 未定义）。

**Step 3: 最小实现**

```swift
// samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift
import Foundation
import SuperCameraKit
import SuperCameraUI
import AVFoundation

protocol PermissionService {
    func requestCameraPermission(completion: @escaping (Bool) -> Void)
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void)
}

final class DefaultPermissionService: PermissionService {
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}

@MainActor
final class DemoViewModel: ObservableObject {
    @Published var permissionsGranted: Bool = false
    @Published var previewing: Bool = false
    @Published var recording: Bool = false
    @Published var lastMessage: String = ""
    @Published var uiBadge: String = ""

    private let camera = SuperCamera()
    private let ui = BasicCameraView()
    private let permissionService: PermissionService

    init(permissionService: PermissionService = DefaultPermissionService()) {
        self.permissionService = permissionService
    }

    func requestInitialPermissions() {
        permissionService.requestCameraPermission { cameraGranted in
            self.permissionService.requestMicrophonePermission { micGranted in
                Task { @MainActor in
                    self.permissionsGranted = cameraGranted && micGranted
                    self.lastMessage = self.permissionsGranted ? "权限已授权" : "请在系统设置开启权限"
                }
            }
        }
    }
}
```

```swift
// samples/ios-app/SuperCameraDemo/SuperCameraDemo/SuperCameraDemoApp.swift
import SwiftUI

@main
struct SuperCameraDemoApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SuperCamera Demo")
        }
    }
}
```

**Step 4: 运行并确认通过**

Run: `xcodebuild -project samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj -scheme SuperCameraDemo -destination 'platform=iOS Simulator,name=iPhone 15' test`
Expected: PASS。

**Step 5: 提交**

```bash
git add samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj/project.pbxproj \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/SuperCameraDemoApp.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift
git commit -m "feat(sample-ios): scaffold swiftui demo with permission view model"
```

### 任务 5：实现 iOS Demo 页面与基础手工验证链路

**Files:**
- Create: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/ContentView.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift`
- Modify: `samples/ios-app/SuperCameraDemo/SuperCameraDemo/SuperCameraDemoApp.swift`
- Modify: `samples/ios-app/README.md`

**Step 1: 写失败测试**

```swift
// append samples/ios-app/SuperCameraDemo/SuperCameraDemoTests/DemoViewModelTests.swift
func test授权后可预览拍照录像并更新ui标记() {
    let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: true))
    vm.requestInitialPermissions()

    XCTAssertTrue(vm.permissionsGranted)
    XCTAssertTrue(vm.startPreview())
    XCTAssertTrue(vm.takePhoto(path: "/tmp/p.jpg"))
    XCTAssertTrue(vm.toggleRecord(path: "/tmp/v.mp4"))
    XCTAssertTrue(vm.toggleRecord(path: "/tmp/v.mp4"))

    XCTAssertEqual(vm.uiBadge, "")
    vm.toggleUiBadge()
    XCTAssertEqual(vm.uiBadge, "REC")
}
```

**Step 2: 运行并确认失败**

Run: `xcodebuild -project samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj -scheme SuperCameraDemo -destination 'platform=iOS Simulator,name=iPhone 15' test`
Expected: FAIL（`startPreview/takePhoto/toggleRecord/toggleUiBadge` 未定义）。

**Step 3: 最小实现（ViewModel + SwiftUI 页面）**

```swift
// samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift（追加方法）
@MainActor
extension DemoViewModel {
    func startPreview() -> Bool {
        guard permissionsGranted else {
            lastMessage = "请在系统设置开启权限"
            return false
        }
        let ok = camera.startPreview(surfaceHandle: 1)
        previewing = ok
        lastMessage = ok ? "预览已启动" : "预览启动失败"
        return ok
    }

    func takePhoto(path: String) -> Bool {
        guard permissionsGranted else {
            lastMessage = "请在系统设置开启权限"
            return false
        }
        let result = camera.takePhoto(outputPath: path)
        let ok = !result.path.isEmpty
        lastMessage = ok ? "拍照成功" : "拍照失败"
        return ok
    }

    func toggleRecord(path: String) -> Bool {
        guard permissionsGranted else {
            lastMessage = "请在系统设置开启权限"
            return false
        }
        guard previewing else {
            lastMessage = "请先启动预览"
            return false
        }
        if !recording {
            let ok = camera.startRecord(path: path)
            recording = ok
            lastMessage = ok ? "开始录像" : "开始录像失败"
            return ok
        } else {
            let result = camera.stopRecord()
            let ok = !result.path.isEmpty
            recording = false
            lastMessage = ok ? "停止录像" : "停止录像失败"
            return ok
        }
    }

    func toggleUiBadge() {
        ui.onRecordTapped()
        uiBadge = ui.recordingBadgeText()
    }
}
```

```swift
// samples/ios-app/SuperCameraDemo/SuperCameraDemo/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 160)
                .overlay(Text("Preview Placeholder"))

            HStack {
                Button("Start Preview") { _ = vm.startPreview() }
                Button("Take Photo") { _ = vm.takePhoto(path: "/tmp/demo_photo.jpg") }
            }

            HStack {
                Button("Start/Stop Record") { _ = vm.toggleRecord(path: "/tmp/demo_video.mp4") }
                Button("Toggle UI Badge") { vm.toggleUiBadge() }
            }

            Text("UI Badge: \(vm.uiBadge)")
            Text(vm.lastMessage).font(.footnote)
        }
        .padding()
        .onAppear { vm.requestInitialPermissions() }
    }
}
```

```swift
// samples/ios-app/SuperCameraDemo/SuperCameraDemo/SuperCameraDemoApp.swift
import SwiftUI

@main
struct SuperCameraDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```md
<!-- update samples/ios-app/README.md -->
# iOS Demo 工程

## 运行

1. 用 Xcode 打开 `samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj`
2. 选择 iPhone 模拟器运行 `SuperCameraDemo`

## 手工验证

1. 首次进入确认相机/麦克风权限弹窗出现。
2. 允许后点击 `Start Preview`，页面提示“预览已启动”。
3. 点击 `Take Photo`，提示“拍照成功”。
4. 点击 `Start/Stop Record` 两次，提示开始/停止录像。
5. 点击 `Toggle UI Badge`，页面显示 `UI Badge: REC`。
```

**Step 4: 运行并确认通过**

Run: `xcodebuild -project samples/ios-app/SuperCameraDemo/SuperCameraDemo.xcodeproj -scheme SuperCameraDemo -destination 'platform=iOS Simulator,name=iPhone 15' test`
Expected: PASS。

**Step 5: 提交**

```bash
git add samples/ios-app/SuperCameraDemo/SuperCameraDemo/ContentView.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/DemoViewModel.swift \
        samples/ios-app/SuperCameraDemo/SuperCameraDemo/SuperCameraDemoApp.swift \
        samples/ios-app/README.md
git commit -m "feat(sample-ios): add manual verification screen for camera and ui kit"
```

### 任务 6：全量验证与文档收口

**Files:**
- Modify: `scripts/verify_mvp.sh`（可选：增加 sample build 检查）
- Modify: `samples/android-app/README.md`
- Modify: `samples/ios-app/README.md`

**Step 1: 写失败测试（脚本断言）**

```bash
# scripts/tests/test_sample_readme_has_manual_checklist.sh
#!/usr/bin/env bash
set -euo pipefail

rg -n "手工验证" samples/android-app/README.md
rg -n "手工验证" samples/ios-app/README.md
```

**Step 2: 运行并确认失败**

Run: `bash scripts/tests/test_sample_readme_has_manual_checklist.sh`
Expected: 若 README 未包含“手工验证”章节则 FAIL。

**Step 3: 最小实现**

```bash
# scripts/verify_mvp.sh 中追加（放在 Android 单测之后）
echo "=== [x/x] Android Demo 构建 ==="
cd "$REPO_ROOT/android"
./gradlew -p ../samples/android-app :app:assembleDebug

# iOS demo 构建建议独立在 README 提供 xcodebuild 命令，避免 CI 设备差异
```

**Step 4: 运行并确认通过**

Run: `bash scripts/tests/test_sample_readme_has_manual_checklist.sh && bash scripts/verify_mvp.sh`
Expected: PASS。

**Step 5: 提交**

```bash
git add scripts/tests/test_sample_readme_has_manual_checklist.sh \
        scripts/verify_mvp.sh \
        samples/android-app/README.md \
        samples/ios-app/README.md
git commit -m "test: add sample demo verification checklist and build gate"
```

---

## 里程碑退出标准

- Android 与 iOS 均有可运行 demo 工程（非 README 伪样例）。
- 两端都覆盖动态权限申请，拒绝时有 UI 提示。
- 两端都可手工执行：预览、拍照、开始/停止录像、`supercamera-ui` 控件交互。
- README 含可执行启动步骤与手工验证清单。
- 核心验证命令通过：
  - Android demo 单测与构建通过
  - iOS demo 测试通过
  - `bash scripts/verify_mvp.sh` 通过
