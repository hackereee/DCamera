import Foundation

public protocol AVFoundationSessionFacade {
    func start(surfaceHandle: UInt64, onFrame: @escaping (PreviewFrame) -> Void) -> Bool
    func stop() -> Bool
}
