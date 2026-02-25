public final class BasicCameraView {
    private var recording = false
    public init() {}
    public func onRecordTapped() { recording.toggle() }
    public func recordingBadgeText() -> String { recording ? "REC" : "" }
}
