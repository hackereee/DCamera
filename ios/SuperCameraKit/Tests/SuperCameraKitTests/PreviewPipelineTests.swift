import XCTest
@testable import SuperCameraKit

final class PreviewPipelineTests: XCTestCase {
    func test未attach时submitFrame返回false() {
        let bridge = PreviewRenderBridge()
        XCTAssertFalse(bridge.submitFrame(frameHandle: 1, timestampNs: 100))
    }

    func testAttach后submitFrame成功() {
        let bridge = PreviewRenderBridge()
        XCTAssertTrue(bridge.attach(surfaceHandle: 1))
        XCTAssertTrue(bridge.submitFrame(frameHandle: 1, timestampNs: 100))
    }

    func testAttach零值handle失败() {
        let bridge = PreviewRenderBridge()
        XCTAssertFalse(bridge.attach(surfaceHandle: 0))
    }

    func testDetach后submitFrame失败() {
        let bridge = PreviewRenderBridge()
        bridge.attach(surfaceHandle: 1)
        bridge.detach()
        XCTAssertFalse(bridge.submitFrame(frameHandle: 1, timestampNs: 100))
    }

    func test帧计数正确递增() {
        let bridge = PreviewRenderBridge()
        bridge.attach(surfaceHandle: 1)
        bridge.submitFrame(frameHandle: 1, timestampNs: 100)
        bridge.submitFrame(frameHandle: 2, timestampNs: 200)
        XCTAssertEqual(bridge.frameCount, 2)
    }
}
