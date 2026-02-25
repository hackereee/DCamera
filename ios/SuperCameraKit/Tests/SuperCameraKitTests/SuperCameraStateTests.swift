import XCTest
@testable import SuperCameraKit

final class SuperCameraStateTests: XCTestCase {
    func test切换视频模式后门面状态更新() {
        let camera = SuperCamera()
        camera.setWorkMode(.video)
        XCTAssertEqual(camera.currentWorkMode(), .video)
    }
}
