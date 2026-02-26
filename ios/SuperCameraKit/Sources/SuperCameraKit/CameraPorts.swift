import Foundation

public protocol PreviewSessionPort {
    func startPreview(surfaceHandle: UInt64) -> Bool
    func stopPreview() -> Bool
}

public protocol PreviewBridgePort {
    func attach(surfaceHandle: UInt64) -> Bool
    func detach()
}

public protocol PhotoCapturePort {
    func capture(outputPath: String) -> CaptureResult
}

public final class NoOpPreviewSessionPort: PreviewSessionPort {
    public init() {}

    public func startPreview(surfaceHandle: UInt64) -> Bool { surfaceHandle != 0 }

    public func stopPreview() -> Bool { true }
}

public final class CaptureControllerAdapter: PhotoCapturePort {
    private let controller: CaptureController

    public init(controller: CaptureController = CaptureController()) {
        self.controller = controller
    }

    public func capture(outputPath: String) -> CaptureResult {
        controller.takePhoto(outputPath: outputPath)
    }
}
