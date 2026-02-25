import Foundation

public struct RecordResult { public let path: String }

public final class RecordController {
    private let frameSource: BgfxOffscreenFrameSource
    private var outputPath: String = ""

    public init(frameSource: BgfxOffscreenFrameSource) {
        self.frameSource = frameSource
    }

    public func startRecord(path: String) {
        outputPath = path
    }

    public func stopRecord() -> RecordResult {
        RecordResult(path: outputPath)
    }
}
