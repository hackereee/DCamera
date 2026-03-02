import XCTest
@testable import SuperCameraKit

final class TimestampConversionTests: XCTestCase {
    func test常规时间戳转换为纳秒() {
        let ns = TimestampConversion.toNanoseconds(value: 3, timescale: 2)
        XCTAssertEqual(ns, 1_500_000_000)
    }

    func test超大时间戳转换会安全截断为Int64Max() {
        let ns = TimestampConversion.toNanoseconds(value: Int64.max, timescale: 1)
        XCTAssertEqual(ns, Int64.max)
    }

    func test无效timescale返回零() {
        let ns = TimestampConversion.toNanoseconds(value: 100, timescale: 0)
        XCTAssertEqual(ns, 0)
    }

    func test负时间戳返回零() {
        let ns = TimestampConversion.toNanoseconds(value: -1, timescale: 1)
        XCTAssertEqual(ns, 0)
    }
}
