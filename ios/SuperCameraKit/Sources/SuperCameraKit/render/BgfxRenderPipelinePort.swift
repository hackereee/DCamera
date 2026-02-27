import Foundation

/// Stub render pipeline port that will delegate to the native bgfx-based
/// C ABI (`scamera_render_pipeline_*`) once the shared library is built
/// and linked for iOS.
///
/// Until then every method is a no-op that returns success so that the
/// preview flow can be exercised end-to-end without the native binary.
///
/// Conforms to `PreviewBridgePort` so it can be injected into `SuperCamera`
/// as the preview bridge when the real bgfx backend is desired.
public final class BgfxRenderPipelinePort: PreviewBridgePort {
    private var attached: Bool = false

    public init() {}

    // MARK: - PreviewBridgePort

    @discardableResult
    public func attach(surfaceHandle: UInt64) -> Bool {
        guard surfaceHandle != 0 else { return false }
        // TODO: Call scamera_render_pipeline_create + configure_preview via C bridge
        attached = true
        return true
    }

    public func detach() {
        // TODO: Call scamera_render_pipeline_destroy via C bridge
        attached = false
    }

    @discardableResult
    public func submitFrame(frame: PreviewFrame) -> Bool {
        guard attached, frame.width > 0, frame.height > 0, frame.timestampNs >= 0 else {
            return false
        }
        // TODO: Call scamera_render_pipeline_submit_frame via C bridge
        return true
    }
}
