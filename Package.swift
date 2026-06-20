// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Perch",
    platforms: [
        .macOS(.v14) // SwiftUI window scenes + modern drag APIs settle on macOS 14+
    ],
    products: [
        .executable(name: "Perch", targets: ["Perch"])
    ],
    targets: [
        .executableTarget(
            name: "Perch",
            path: "Sources/Perch",
            swiftSettings: [
                // Pragmatic language mode: Carbon C-callbacks and AppKit delegate
                // patterns interoperate far more cleanly under the v5 model while we
                // still compile with the Swift 6.2 toolchain.
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PerchTests",
            dependencies: ["Perch"],
            path: "Tests/PerchTests"
        )
    ]
)
