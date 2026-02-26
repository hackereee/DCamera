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
    private let previewSession: PreviewSessionPort
    private let previewBridge: PreviewBridgePort
    private let photoCapture: PhotoCapturePort

    public init(
        previewSession: PreviewSessionPort = NoOpPreviewSessionPort(),
        previewBridge: PreviewBridgePort = PreviewRenderBridge(),
        photoCapture: PhotoCapturePort = CaptureControllerAdapter()
    ) {
        self.previewSession = previewSession
        self.previewBridge = previewBridge
        self.photoCapture = photoCapture
    }

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
        guard previewSession.startPreview(surfaceHandle: surfaceHandle) else {
            state = .idle
            errorCallback?(.sessionConfigFailed, "preview session init failed")
            return false
        }
        guard previewBridge.attach(surfaceHandle: surfaceHandle) else {
            _ = previewSession.stopPreview()
            state = .idle
            errorCallback?(.renderInitFailed, "preview bridge attach failed")
            return false
        }
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
        previewBridge.detach()
        let stopped = previewSession.stopPreview()
        state = .idle
        if !stopped {
            errorCallback?(.sessionConfigFailed, "preview session stop failed")
            return false
        }
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
        let result = photoCapture.capture(outputPath: outputPath)
        state = .previewing
        if result.path.isEmpty {
            errorCallback?(.fileIOFailed, "photo capture returned empty path")
        }
        return result
    }
}
