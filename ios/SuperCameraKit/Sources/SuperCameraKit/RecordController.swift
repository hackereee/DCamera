import Foundation

public struct RecordResult { public let path: String }

public final class RecordController {
    private let frameSource: BgfxOffscreenFrameSource
    private let encoder: VideoEncoderProtocol
    private var outputPath: String = ""
    public private(set) var isRecording: Bool = false

    public init(frameSource: BgfxOffscreenFrameSource, encoder: VideoEncoderProtocol) {
        self.frameSource = frameSource
        self.encoder = encoder
    }

    public func startRecord(path: String, width: Int, height: Int) {
        outputPath = path
        encoder.start(path: path, width: width, height: height)
        isRecording = true
    }

    public func processAvailableFrames() {
        guard isRecording else { return }
        while let frame = frameSource.nextFrame() {
            _ = encoder.encodeFrame(frame)
        }
    }

    public func stopRecord() -> RecordResult {
        guard isRecording else { return RecordResult(path: "") }
        isRecording = false
        _ = encoder.finalizeOutput()
        return RecordResult(path: outputPath)
    }
}
