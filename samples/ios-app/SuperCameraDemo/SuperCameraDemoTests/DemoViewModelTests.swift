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

    func test预览启动后可停止并提示已停止() {
        let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: true))
        vm.requestInitialPermissions()
        XCTAssertTrue(vm.startPreview())
        XCTAssertTrue(vm.stopPreview())
        XCTAssertEqual(vm.lastMessage, "预览已停止")
    }

    // MARK: - Android-parity tests

    func test未授权时预览被阻止() {
        let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: false, micGranted: false))
        vm.requestInitialPermissions()
        XCTAssertFalse(vm.startPreview())
        XCTAssertEqual(vm.lastMessage, "请在系统设置开启权限")
    }

    func test未授权时拍照被阻止() {
        let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: false, micGranted: false))
        vm.requestInitialPermissions()
        XCTAssertFalse(vm.takePhoto(path: "/tmp/p.jpg"))
        XCTAssertEqual(vm.lastMessage, "请在系统设置开启权限")
    }

    func test未启动预览时录像被阻止() {
        let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: true, micGranted: true))
        vm.requestInitialPermissions()
        XCTAssertFalse(vm.toggleRecord(path: "/tmp/v.mp4"))
        XCTAssertEqual(vm.lastMessage, "请先启动预览")
    }

    func testViewModelPublishedPropertiesExist() {
        let vm = DemoViewModel(permissionService: FakePermissionService(cameraGranted: false, micGranted: false))
        // Verify all @Published properties are accessible
        XCTAssertFalse(vm.permissionsGranted)
        XCTAssertFalse(vm.previewing)
        XCTAssertFalse(vm.recording)
        XCTAssertEqual(vm.lastMessage, "")
        XCTAssertEqual(vm.uiBadge, "")
    }
}
