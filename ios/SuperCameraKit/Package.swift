// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuperCameraKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "SuperCameraKit", targets: ["SuperCameraKit"]),
    ],
    targets: [
        .target(name: "SuperCameraKit", path: "Sources/SuperCameraKit"),
        .testTarget(name: "SuperCameraKitTests", dependencies: ["SuperCameraKit"], path: "Tests/SuperCameraKitTests"),
    ]
)
