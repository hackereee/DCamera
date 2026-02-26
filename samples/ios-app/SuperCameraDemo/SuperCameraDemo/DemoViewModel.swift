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
}
