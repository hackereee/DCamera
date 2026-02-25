import XCTest
@testable import SuperCameraUI

final class BasicCameraViewTests: XCTestCase {
    func test点击录制后显示REC标记() {
        let view = BasicCameraView()
        view.onRecordTapped()
        XCTAssertEqual(view.recordingBadgeText(), "REC")
    }
}
