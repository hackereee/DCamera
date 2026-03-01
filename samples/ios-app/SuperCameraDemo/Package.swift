// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuperCameraDemo",
    platforms: [.iOS(.v16), .macOS(.v13)],
    dependencies: [
        .package(path: "../../../ios/SuperCameraKit"),
        .package(path: "../../../ios/SuperCameraUI"),
    ],
    targets: [
        .target(
            name: "SuperCameraDemo",
            dependencies: [
                .product(name: "SuperCameraKit", package: "SuperCameraKit"),
                .product(name: "SuperCameraUI", package: "SuperCameraUI"),
            ],
            path: "SuperCameraDemo",
            exclude: ["SuperCameraDemoApp.swift", "ContentView.swift", "Info.plist"]
        ),
        .testTarget(
            name: "SuperCameraDemoTests",
            dependencies: ["SuperCameraDemo"],
            path: "SuperCameraDemoTests"
        ),
    ]
)
