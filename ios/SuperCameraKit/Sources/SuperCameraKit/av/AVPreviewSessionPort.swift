import Foundation

public final class AVPreviewSessionPort: PreviewSessionPort {
    private let facade: AVFoundationSessionFacade
    private var frameConsumer: ((PreviewFrame) -> Void)?

    public init(facade: AVFoundationSessionFacade) {
        self.facade = facade
    }

    public func setFrameConsumer(_ consumer: @escaping (PreviewFrame) -> Void) {
        frameConsumer = consumer
    }

    public func startPreview(surfaceHandle: UInt64) -> Bool {
        guard let consumer = frameConsumer else { return false }
        return facade.start(surfaceHandle: surfaceHandle, onFrame: { frame in consumer(frame) })
    }

    public func stopPreview() -> Bool {
        return facade.stop()
    }
}
