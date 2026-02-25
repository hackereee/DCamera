import Foundation

public final class PreviewRenderBridge {
    public init() {}
    public func attach(surfaceHandle: UInt64) -> Bool { surfaceHandle != 0 }
    public func submitFrame(frameHandle: UInt64, timestampNs: Int64) -> Bool { frameHandle != 0 && timestampNs >= 0 }
}
