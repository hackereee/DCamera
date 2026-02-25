import XCTest
@testable import SuperCameraKit

final class FakeBgfxSource: BgfxOffscreenFrameSource {
    func nextFrame() -> Data? { nil }
}

final class RecordControllerTests: XCTestCase {
    func test停止录像返回mp4路径() {
        let controller = RecordController(frameSource: FakeBgfxSource())
        controller.startRecord(path: "/tmp/out.mp4")
        let result = controller.stopRecord()
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
    }
}
