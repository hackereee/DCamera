import Foundation

public enum WorkMode { case purePreview, analysis, photo, video }
public enum CameraState: Equatable { case idle, initializing, previewing, capturing, recording, releasing }
public enum SCErrorCode: Equatable {
    case none
    case permission
    case deviceUnavailable
    case sessionConfigFailed
    case renderInitFailed
    case renderSurfaceLost
    case encoderInitFailed
    case encoderBackpressure
    case fileIOFailed
    case thermalThrottle
    case invalidState
}

public typealias SCErrorCallback = (SCErrorCode, String) -> Void

public final class SuperCamera {
    private var mode: WorkMode = .purePreview
    private var state: CameraState = .idle
    private var errorCallback: SCErrorCallback?
    private var recordPath: String = ""

    public init() {}

    public func setWorkMode(_ mode: WorkMode) { self.mode = mode }
    public func currentWorkMode() -> WorkMode { mode }
    public func currentState() -> CameraState { state }
    public func setErrorCallback(_ cb: @escaping SCErrorCallback) { errorCallback = cb }

    @discardableResult
    public func startPreview(surfaceHandle: UInt64) -> Bool {
        guard state == .idle else {
            errorCallback?(.invalidState, "startPreview requires idle state, current=\(state)")
            return false
        }
        state = .initializing
        // TODO: real implementation initializes AVCapture session and render pipeline.
        state = .previewing
        return true
    }

    @discardableResult
    public func stopPreview() -> Bool {
        guard state == .previewing else {
            errorCallback?(.invalidState, "stopPreview requires previewing state, current=\(state)")
            return false
        }
        state = .releasing
        // TODO: real implementation tears down camera and renderer resources.
        state = .idle
        return true
    }

    @discardableResult
    public func startRecord(path: String) -> Bool {
        guard state == .previewing else {
            errorCallback?(.invalidState, "startRecord requires previewing state, current=\(state)")
            return false
        }
        recordPath = path
        state = .recording
        return true
    }

    public func stopRecord() -> RecordResult {
        guard state == .recording else {
            errorCallback?(.invalidState, "stopRecord requires recording state, current=\(state)")
            return RecordResult(path: "")
        }
        state = .previewing
        return RecordResult(path: recordPath)
    }

    public func takePhoto(outputPath: String) -> CaptureResult {
        guard state == .previewing else {
            errorCallback?(.invalidState, "takePhoto requires previewing state, current=\(state)")
            return CaptureResult(path: "")
        }
        state = .capturing
        let result = CaptureResult(path: outputPath)
        state = .previewing
        return result
    }
}
