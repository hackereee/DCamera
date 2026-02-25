import Foundation

public struct SessionMetrics {
    public var firstFrameLatencyMs: Int = 0
    public var previewFps: Int = 0
    public var renderDropRatePermille: Int = 0
    public var encoderInputFps: Int = 0
    public var avDriftMs: Int = 0
    public var modeSwitchLatencyMs: Int = 0

    public init() {}
}
