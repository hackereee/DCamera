// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuperCameraUI",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "SuperCameraUI", targets: ["SuperCameraUI"]),
    ],
    targets: [
        .target(name: "SuperCameraUI", path: "Sources/SuperCameraUI"),
        .testTarget(name: "SuperCameraUITests", dependencies: ["SuperCameraUI"], path: "Tests/SuperCameraUITests"),
    ]
)
