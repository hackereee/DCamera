import XCTest
@testable import SuperCameraKit

final class PreviewPipelineTests: XCTestCase {
    func test预览桥接attachSurface返回true() {
        let bridge = PreviewRenderBridge()
        XCTAssertTrue(bridge.attach(surfaceHandle: 1))
    }

    func test预览桥接attachSurface零值返回false() {
        let bridge = PreviewRenderBridge()
        XCTAssertFalse(bridge.attach(surfaceHandle: 0))
    }
}
