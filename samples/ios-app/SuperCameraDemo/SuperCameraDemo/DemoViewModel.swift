import Foundation
import SuperCameraKit
import SuperCameraUI
#if canImport(AVFoundation)
import AVFoundation
#endif

protocol PermissionService {
    func requestCameraPermission(completion: @escaping (Bool) -> Void)
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void)
}

final class DefaultPermissionService: PermissionService {
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        #if canImport(AVFoundation)
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
        #else
        completion(false)
        #endif
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        #if canImport(AVFoundation)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
        #else
        completion(false)
        #endif
    }
}

final class DemoViewModel: ObservableObject {
    @Published var permissionsGranted: Bool = false
    @Published var cameraPermissionGranted: Bool = false
    @Published var microphonePermissionGranted: Bool = false
    @Published var previewing: Bool = false
    @Published var recording: Bool = false
    @Published var lastMessage: String = ""
    @Published var uiBadge: String = ""

    private let camera: SuperCamera
    private let ui = BasicCameraView()
    private let permissionService: PermissionService
    private var previewSurfaceHandle: UInt64?

    init(
        permissionService: PermissionService = DefaultPermissionService(),
        camera: SuperCamera? = nil
    ) {
        self.permissionService = permissionService
        if let camera {
            self.camera = camera
        } else {
            #if canImport(AVFoundation) && canImport(UIKit)
            self.camera = SuperCamera.makeLiveIOS()
            #else
            self.camera = SuperCamera()
            #endif
        }
    }

    func requestInitialPermissions() {
        permissionService.requestCameraPermission { [self] cameraGranted in
            self.cameraPermissionGranted = cameraGranted
            self.permissionService.requestMicrophonePermission { micGranted in
                self.microphonePermissionGranted = micGranted
                self.permissionsGranted = cameraGranted
                self.lastMessage = self.permissionsGranted ? "权限已授权" : "请在系统设置开启权限"
            }
        }
    }

    func startPreview() -> Bool {
        guard cameraPermissionGranted else {
            lastMessage = "请在系统设置开启权限"
            return false
        }
        guard let handle = previewSurfaceHandle, handle != 0 else {
            lastMessage = "预览启动失败（渲染目标无效）"
            return false
        }
        let ok = camera.startPreview(surfaceHandle: handle)
        previewing = ok
        lastMessage = ok ? "预览已启动" : "预览启动失败"
        return ok
    }

    func setPreviewSurfaceHandle(_ handle: UInt64?) {
        previewSurfaceHandle = handle
    }

    @discardableResult
    func stopPreview() -> Bool {
        let ok = camera.stopPreview()
        previewing = false
        lastMessage = ok ? "预览已停止" : "预览停止失败"
        return ok
    }

    func takePhoto(path: String) -> Bool {
        guard cameraPermissionGranted else {
            lastMessage = "请在系统设置开启权限"
            return false
        }
        let result = camera.takePhoto(outputPath: path)
        let ok = !result.path.isEmpty
        lastMessage = ok ? "拍照成功" : "拍照失败"
        return ok
    }

    func toggleRecord(path: String) -> Bool {
        guard cameraPermissionGranted else {
            lastMessage = "请在系统设置开启权限"
            return false
        }
        guard microphonePermissionGranted else {
            lastMessage = "请在系统设置开启麦克风权限"
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
