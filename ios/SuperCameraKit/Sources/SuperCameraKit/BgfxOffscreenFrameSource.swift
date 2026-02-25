import Foundation

public protocol BgfxOffscreenFrameSource {
    func nextFrame() -> Data?
}
