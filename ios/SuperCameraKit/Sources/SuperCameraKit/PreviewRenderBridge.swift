import Foundation

public final class PreviewRenderBridge {
    private var surfaceAttached: Bool = false
    public private(set) var frameCount: Int = 0

    public init() {}

    @discardableResult
    public func attach(surfaceHandle: UInt64) -> Bool {
        guard surfaceHandle != 0 else { return false }
        surfaceAttached = true
        frameCount = 0
        return true
    }

    public func detach() {
        surfaceAttached = false
    }

    @discardableResult
    public func submitFrame(frameHandle: UInt64, timestampNs: Int64) -> Bool {
        guard surfaceAttached, frameHandle != 0, timestampNs >= 0 else { return false }
        frameCount += 1
        return true
    }
}
