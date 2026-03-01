import XCTest
@testable import SuperCameraKit

final class SuperCameraStateTests: XCTestCase {
    func test初始状态为IDLE() {
        let camera = SuperCamera()
        XCTAssertEqual(camera.currentState(), .idle)
    }

    func test切换视频模式后门面状态更新() {
        let camera = SuperCamera()
        camera.setWorkMode(.video)
        XCTAssertEqual(camera.currentWorkMode(), .video)
    }

    func testStartPreview从IDLE到PREVIEWING() {
        let camera = SuperCamera()
        XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(camera.currentState(), .previewing)
    }

    func testStartPreview非法状态返回false() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        var receivedError: SCErrorCode?
        camera.setErrorCallback { code, _ in receivedError = code }
        XCTAssertFalse(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(receivedError, .invalidState)
    }

    func testStopPreview从PREVIEWING到IDLE() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        XCTAssertTrue(camera.stopPreview())
        XCTAssertEqual(camera.currentState(), .idle)
    }

    func testStartRecord从PREVIEWING到RECORDING() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        XCTAssertTrue(camera.startRecord(path: "/tmp/out.mp4"))
        XCTAssertEqual(camera.currentState(), .recording)
    }

    func testStopRecord回到PREVIEWING() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        camera.startRecord(path: "/tmp/out.mp4")
        let result = camera.stopRecord()
        XCTAssertEqual(camera.currentState(), .previewing)
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
    }

    func test录制中停止预览失败且状态保持录制中() {
        let camera = SuperCamera()
        XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
        XCTAssertTrue(camera.startRecord(path: "/tmp/out.mp4"))
        XCTAssertFalse(camera.stopPreview())
        XCTAssertEqual(camera.currentState(), .recording)
    }

    func testTakePhoto回到PREVIEWING() {
        let camera = SuperCamera()
        camera.startPreview(surfaceHandle: 1)
        let result = camera.takePhoto(outputPath: "/tmp/photo.jpg")
        XCTAssertEqual(camera.currentState(), .previewing)
        XCTAssertTrue(result.path.hasSuffix(".jpg"))
    }
}
