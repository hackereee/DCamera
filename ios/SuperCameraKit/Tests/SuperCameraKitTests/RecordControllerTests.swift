import XCTest
@testable import SuperCameraKit

final class FakeBgfxSource: BgfxOffscreenFrameSource {
    var frames: [Data] = []
    private var index = 0

    func nextFrame() -> Data? {
        guard index < frames.count else { return nil }
        let frame = frames[index]
        index += 1
        return frame
    }
}

final class FakeVideoEncoder: VideoEncoderProtocol {
    var encodedFrames: [Data] = []
    var started = false
    var finalized = false

    func start(path: String, width: Int, height: Int) {
        started = true
    }

    func encodeFrame(_ data: Data) -> Bool {
        encodedFrames.append(data)
        return true
    }

    func finalizeOutput() -> Bool {
        finalized = true
        return true
    }

    func release() {}
}

final class RecordControllerTests: XCTestCase {
    func testStartRecord初始化编码器() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        let controller = RecordController(frameSource: source, encoder: encoder)
        controller.startRecord(path: "/tmp/out.mp4", width: 1920, height: 1080)
        XCTAssertTrue(encoder.started)
        XCTAssertTrue(controller.isRecording)
    }

    func testProcessFrames消费帧源并编码() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        source.frames = [Data([1, 2, 3]), Data([4, 5, 6])]
        let controller = RecordController(frameSource: source, encoder: encoder)
        controller.startRecord(path: "/tmp/out.mp4", width: 1920, height: 1080)
        controller.processAvailableFrames()
        XCTAssertEqual(encoder.encodedFrames.count, 2)
    }

    func testStopRecord返回mp4路径() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        let controller = RecordController(frameSource: source, encoder: encoder)
        controller.startRecord(path: "/tmp/out.mp4", width: 1920, height: 1080)
        let result = controller.stopRecord()
        XCTAssertTrue(result.path.hasSuffix(".mp4"))
        XCTAssertTrue(encoder.finalized)
        XCTAssertFalse(controller.isRecording)
    }

    func test未开始录制时stopRecord返回空路径() {
        let encoder = FakeVideoEncoder()
        let source = FakeBgfxSource()
        let controller = RecordController(frameSource: source, encoder: encoder)
        let result = controller.stopRecord()
        XCTAssertEqual(result.path, "")
    }
}
