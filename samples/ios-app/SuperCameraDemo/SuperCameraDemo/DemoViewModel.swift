import Foundation
import SuperCameraKit
import SuperCameraUI

protocol PermissionService {
    func requestCameraPermission(completion: @escaping (Bool) -> Void)
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void)
}

final class DefaultPermissionService: PermissionService {
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        // In real app: AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        completion(false)
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        // In real app: AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
        completion(false)
    }
}

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
        permissionService.requestCameraPermission { [self] cameraGranted in
            self.permissionService.requestMicrophonePermission { micGranted in
                self.permissionsGranted = cameraGranted && micGranted
                self.lastMessage = self.permissionsGranted ? "权限已授权" : "请在系统设置开启权限"
            }
        }
    }

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

    @discardableResult
    func stopPreview() -> Bool {
        let ok = camera.stopPreview()
        previewing = false
        lastMessage = ok ? "预览已停止" : "预览停止失败"
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
