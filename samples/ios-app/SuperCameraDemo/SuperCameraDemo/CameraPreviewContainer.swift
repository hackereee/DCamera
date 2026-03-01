import SwiftUI

#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation
import UIKit

struct CameraPreviewContainer: UIViewRepresentable {
    let onSurfaceReady: (UInt64) -> Void

    final class PreviewHostView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        let raw = Unmanaged.passUnretained(view).toOpaque()
        onSurfaceReady(UInt64(UInt(bitPattern: raw)))
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}
}
#else
struct CameraPreviewContainer: View {
    let onSurfaceReady: (UInt64) -> Void

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(Text("Preview Unsupported").foregroundColor(.secondary))
            .onAppear {
                onSurfaceReady(0)
            }
    }
}
#endif
