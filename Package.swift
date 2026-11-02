// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "macSlider",
    platforms: [.macOS(.v14)],
    targets: [
        // Header-only C module: struct layouts for Apple's private MultitouchSupport framework.
        .target(name: "MultitouchBridge"),
        // Gesture engine and touch types. Pure Foundation so it builds and tests without Xcode.
        .target(name: "macSliderCore"),
        .executableTarget(
            name: "macSlider",
            dependencies: ["MultitouchBridge", "macSliderCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(name: "macSliderTests", dependencies: ["macSliderCore"]),
    ]
)
