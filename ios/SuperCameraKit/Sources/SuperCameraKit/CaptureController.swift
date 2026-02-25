import Foundation

public struct CaptureResult { public let path: String }

public final class CaptureController {
    public init() {}
    public func takePhoto(outputPath: String) -> CaptureResult {
        CaptureResult(path: outputPath)
    }
}
