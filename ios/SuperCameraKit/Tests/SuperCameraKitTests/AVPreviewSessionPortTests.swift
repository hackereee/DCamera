import XCTest
@testable import SuperCameraKit

final class FakeAVFoundationSessionFacade: AVFoundationSessionFacade {
    let startResult: Bool

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func start(surfaceHandle: UInt64, onFrame: @escaping (PreviewFrame) -> Void) -> Bool {
        if startResult {
            let dummyFrame = PreviewFrame(
                y: Data(repeating: 0, count: 4),
                u: Data(repeating: 128, count: 1),
                v: Data(repeating: 128, count: 1),
                width: 2,
                height: 2,
                timestampNs: 1000
            )
            onFrame(dummyFrame)
        }
        return startResult
    }

    func stop() -> Bool {
        return true
    }
}

final class AVPreviewSessionPortTests: XCTestCase {
    func testStartPreview成功后可向consumer投递帧() {
        let facade = FakeAVFoundationSessionFacade(startResult: true)
        let port = AVPreviewSessionPort(facade: facade)
        var delivered = 0
        port.setFrameConsumer { _ in delivered += 1 }

        XCTAssertTrue(port.startPreview(surfaceHandle: 1))
        XCTAssertEqual(delivered, 1)
    }

    func testStartPreview失败时不投递帧() {
        let facade = FakeAVFoundationSessionFacade(startResult: false)
        let port = AVPreviewSessionPort(facade: facade)
        var delivered = 0
        port.setFrameConsumer { _ in delivered += 1 }

        XCTAssertFalse(port.startPreview(surfaceHandle: 1))
        XCTAssertEqual(delivered, 0)
    }

    func testNoConsumer时startPreview返回false() {
        let facade = FakeAVFoundationSessionFacade(startResult: true)
        let port = AVPreviewSessionPort(facade: facade)

        XCTAssertFalse(port.startPreview(surfaceHandle: 1))
    }
}
