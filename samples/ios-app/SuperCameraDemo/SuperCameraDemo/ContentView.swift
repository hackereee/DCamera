import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("SuperCamera Demo")
                .font(.title)

            CameraPreviewContainer(onSurfaceReady: { handle in
                vm.setPreviewSurfaceHandle(handle)
            })
            .frame(height: 300)

            HStack(spacing: 16) {
                Button(vm.previewing ? "Stop Preview" : "Start Preview") {
                    if vm.previewing {
                        vm.stopPreview()
                    } else {
                        _ = vm.startPreview()
                    }
                }
                Button("Take Photo") {
                    _ = vm.takePhoto(path: NSTemporaryDirectory() + "photo.jpg")
                }
            }

            HStack(spacing: 16) {
                Button(vm.recording ? "Stop Record" : "Start Record") {
                    _ = vm.toggleRecord(path: NSTemporaryDirectory() + "video.mp4")
                }
                Button("Toggle UI Badge") {
                    vm.toggleUiBadge()
                }
            }

            if !vm.uiBadge.isEmpty {
                Text("UI Badge: \(vm.uiBadge)")
                    .foregroundColor(.red)
                    .font(.headline)
            }

            Text(vm.lastMessage)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .padding()
        .onAppear {
            vm.requestInitialPermissions()
        }
    }
}
