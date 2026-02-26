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
