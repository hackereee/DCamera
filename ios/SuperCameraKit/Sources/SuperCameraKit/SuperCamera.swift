import Foundation

public enum WorkMode { case purePreview, analysis, photo, video }

public final class SuperCamera {
    private var mode: WorkMode = .purePreview
    public init() {}
    public func setWorkMode(_ mode: WorkMode) { self.mode = mode }
    public func currentWorkMode() -> WorkMode { mode }
}
