import XCTest
@testable import SuperCameraKit

final class FakePreviewSessionPort: PreviewSessionPort {
    var startResult: Bool
    var stopResult: Bool
    var startCalls = 0
    var stopCalls = 0

    init(startResult: Bool = true, stopResult: Bool = true) {
        self.startResult = startResult
        self.stopResult = stopResult
    }

    func setFrameConsumer(_ consumer: @escaping (PreviewFrame) -> Void) {}

    func startPreview(surfaceHandle: UInt64) -> Bool {
        startCalls += 1
        return startResult
    }

    func stopPreview() -> Bool {
        stopCalls += 1
        return stopResult
    }
}

final class FakePreviewBridgePort: PreviewBridgePort {
    var attachResult: Bool
    var attachCalls = 0
    var detachCalls = 0
    var submitFrameCalls = 0

    init(attachResult: Bool = true) {
        self.attachResult = attachResult
    }

    func attach(surfaceHandle: UInt64) -> Bool {
        attachCalls += 1
        return attachResult
    }

    func detach() {
        detachCalls += 1
    }

    func submitFrame(frame: PreviewFrame) -> Bool {
        submitFrameCalls += 1
        return true
    }
}

final class FakePhotoCapturePort: PhotoCapturePort {
    let resultPath: String

    init(resultPath: String) {
        self.resultPath = resultPath
    }

    func capture(outputPath: String) -> CaptureResult {
        CaptureResult(path: resultPath)
    }
}

final class SuperCameraDependencyTests: XCTestCase {
    func testStartPreviewSession失败上报sessionConfigFailed() {
        let camera = SuperCamera(
            previewSession: FakePreviewSessionPort(startResult: false),
            previewBridge: FakePreviewBridgePort(),
            photoCapture: FakePhotoCapturePort(resultPath: "/tmp/p.jpg")
        )
        var code: SCErrorCode?
        camera.setErrorCallback { c, _ in code = c }

        XCTAssertFalse(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(camera.currentState(), .idle)
        XCTAssertEqual(code, .sessionConfigFailed)
    }

    func testStartPreviewRenderAttach失败会回滚stop并上报renderInitFailed() {
        let session = FakePreviewSessionPort(startResult: true)
        let camera = SuperCamera(
            previewSession: session,
            previewBridge: FakePreviewBridgePort(attachResult: false),
            photoCapture: FakePhotoCapturePort(resultPath: "/tmp/p.jpg")
        )
        var code: SCErrorCode?
        camera.setErrorCallback { c, _ in code = c }

        XCTAssertFalse(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(session.stopCalls, 1)
        XCTAssertEqual(code, .renderInitFailed)
        XCTAssertEqual(camera.currentState(), .idle)
    }

    func testTakePhoto空路径上报fileIOFailed() {
        let camera = SuperCamera(
            previewSession: FakePreviewSessionPort(),
            previewBridge: FakePreviewBridgePort(),
            photoCapture: FakePhotoCapturePort(resultPath: "")
        )
        var code: SCErrorCode?
        camera.setErrorCallback { c, _ in code = c }

        XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
        let result = camera.takePhoto(outputPath: "/tmp/p.jpg")
        XCTAssertEqual(result.path, "")
        XCTAssertEqual(code, .fileIOFailed)
        XCTAssertEqual(camera.currentState(), .previewing)
    }

    func testLiveIOS工厂使用注入依赖() {
        let session = FakePreviewSessionPort()
        let bridge = FakePreviewBridgePort()
        let camera = SuperCamera.makeLiveIOS(
            previewSession: session,
            previewBridge: bridge,
            photoCapture: FakePhotoCapturePort(resultPath: "/tmp/p.jpg")
        )

        XCTAssertTrue(camera.startPreview(surfaceHandle: 1))
        XCTAssertEqual(session.startCalls, 1)
        XCTAssertEqual(bridge.attachCalls, 1)
    }
}
