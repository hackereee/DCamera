#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit

public final class LiveAVFoundationSessionFacade: NSObject, AVFoundationSessionFacade {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.dcamera.supercamera.preview")
    private var onFrame: ((PreviewFrame) -> Void)?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?

    public override init() {
        super.init()
    }

    public func start(surfaceHandle: UInt64, onFrame: @escaping (PreviewFrame) -> Void) -> Bool {
        guard surfaceHandle != 0 else { return false }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(surfaceHandle)) else { return false }
        let view = Unmanaged<UIView>.fromOpaque(ptr).takeUnretainedValue()
        guard let layer = view.layer as? AVCaptureVideoPreviewLayer else { return false }
        guard let device = AVCaptureDevice.default(for: .video) else { return false }

        self.onFrame = onFrame
        previewLayer = layer
        layer.videoGravity = .resizeAspectFill
        layer.session = session

        do {
            session.beginConfiguration()
            session.sessionPreset = .high
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(input)

            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return false
            }
            session.addOutput(output)
            session.commitConfiguration()
        } catch {
            return false
        }

        session.startRunning()
        return session.isRunning
    }

    public func stop() -> Bool {
        output.setSampleBufferDelegate(nil, queue: nil)
        if session.isRunning {
            session.stopRunning()
        }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.commitConfiguration()
        previewLayer?.session = nil
        previewLayer = nil
        onFrame = nil
        return !session.isRunning
    }
}

extension LiveAVFoundationSessionFacade: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let callback = onFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let uvBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            return
        }

        let yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        let uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        let uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        let yData = Data(bytes: yBase, count: yStride * yHeight)
        let uvData = Data(bytes: uvBase, count: uvStride * uvHeight)
        var uData = Data(count: uvWidth * uvHeight)
        var vData = Data(count: uvWidth * uvHeight)

        uvData.withUnsafeBytes { src in
            guard let srcBytes = src.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            uData.withUnsafeMutableBytes { uBuffer in
                vData.withUnsafeMutableBytes { vBuffer in
                    guard let uBytes = uBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let vBytes = vBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }

                    var index = 0
                    for row in 0..<uvHeight {
                        let rowStart = row * uvStride
                        for col in 0..<uvWidth {
                            let offset = rowStart + col * 2
                            uBytes[index] = srcBytes[offset]
                            vBytes[index] = srcBytes[offset + 1]
                            index += 1
                        }
                    }
                }
            }
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampNs = pts.timescale > 0 ? Int64(pts.value) * 1_000_000_000 / Int64(pts.timescale) : 0
        let frame = PreviewFrame(
            y: yData,
            u: uData,
            v: vData,
            width: yWidth,
            height: yHeight,
            timestampNs: timestampNs
        )
        callback(frame)
    }
}
#endif
