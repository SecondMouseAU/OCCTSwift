// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Use local xcframework when developing (repo checkout) or when consumed via a LOCAL PATH dependency;
// remote URL when consumed by URL (CI / SPI / remote SPM). Set OCCTSWIFT_LOCAL=1 to force local path,
// or OCCTSWIFT_REMOTE=1 to force remote URL.
//
// Detection resolves against THIS manifest's own directory (`#filePath`), NOT the process CWD. When
// OCCTSwift is a path dependency the manifest is evaluated with CWD = the *consumer's* root, so a
// CWD-relative "Libraries/…" check fails and falls back to the URL — making every local consumer
// download + extract its own 1.3 GB copy. Resolving against `#filePath` lets a path-dep consumer find
// OCCTSwift's in-place (gitignored) `Libraries/OCCT.xcframework` and SHARE the single copy. A URL
// consumer clones OCCTSwift into .build/checkouts (no `Libraries/`), so this still falls back to the
// remote zip there.
let occtPackageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let useLocalBinary: Bool = {
    if ProcessInfo.processInfo.environment["OCCTSWIFT_REMOTE"] == "1" { return false }
    if ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1" { return true }
    return FileManager.default.fileExists(atPath: occtPackageDir + "/Libraries/OCCT.xcframework/Info.plist")
}()

let occtTarget: Target = useLocalBinary
    ? .binaryTarget(
        name: "OCCT",
        path: "Libraries/OCCT.xcframework"
    )
    : .binaryTarget(
        name: "OCCT",
        url: "https://github.com/gsdali/OCCTSwift/releases/download/v1.7.1/OCCT.xcframework.zip",
        checksum: "588aea7eb588063b906878fb66f4a2b91de6b8034be95dcb5212470deff8bccf"
    )

let package = Package(
    name: "OCCTSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .visionOS(.v1),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "OCCTSwift",
            targets: ["OCCTSwift"]
        ),
    ],
    targets: [
        // Swift API layer - public interface
        .target(
            name: "OCCTSwift",
            dependencies: ["OCCTBridge"],
            path: "Sources/OCCTSwift",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // Objective-C++ bridge to OCCT
        .target(
            name: "OCCTBridge",
            dependencies: ["OCCT"],
            path: "Sources/OCCTBridge",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                // Platform-specific header search paths for XCFramework
                .headerSearchPath("../../Libraries/OCCT.xcframework/macos-arm64/Headers", .when(platforms: [.macOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/ios-arm64/Headers", .when(platforms: [.iOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/ios-arm64-simulator/Headers", .when(platforms: [.iOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/xros-arm64/Headers", .when(platforms: [.visionOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/xros-arm64-simulator/Headers", .when(platforms: [.visionOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/tvos-arm64/Headers", .when(platforms: [.tvOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/tvos-arm64-simulator/Headers", .when(platforms: [.tvOS])),
                .define("OCCT_AVAILABLE", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),

        // OCCT binary framework - auto-selects local or remote
        occtTarget,

        // Tests — split into per-domain targets so editing/compiling one domain
        // (e.g. threads) recompiles only that small module, never the whole suite.
        // `swift build --target OCCTThreadTests` type-checks just that target in seconds.
        .testTarget(name: "OCCTAnalysisTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTAnalysisTests"),
        .testTarget(name: "OCCTCurveTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTCurveTests"),
        .testTarget(name: "OCCTDrawingTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTDrawingTests"),
        .testTarget(name: "OCCTFoundationTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTFoundationTests"),
        .testTarget(name: "OCCTGeom2dTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTGeom2dTests"),
        .testTarget(name: "OCCTIOTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTIOTests"),
        .testTarget(name: "OCCTIntegrationTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTIntegrationTests"),
        .testTarget(name: "OCCTMathTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTMathTests"),
        .testTarget(name: "OCCTMeshTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTMeshTests"),
        .testTarget(name: "OCCTMiscTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTMiscTests"),
        .testTarget(name: "OCCTModelingTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTModelingTests"),
        .testTarget(name: "OCCTShapeHealingTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTShapeHealingTests"),
        .testTarget(name: "OCCTStressTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTStressTests"),
        .testTarget(name: "OCCTSurfaceTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTSurfaceTests"),
        .testTarget(name: "OCCTThreadTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTThreadTests"),
        .testTarget(name: "OCCTTopologyGraphTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTTopologyGraphTests"),
        .testTarget(name: "OCCTTopologyTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTTopologyTests"),
        .testTarget(name: "OCCTXCAFTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTXCAFTests"),

        // Test executable
        .executableTarget(
            name: "OCCTTest",
            dependencies: ["OCCTSwift"],
            path: "Sources/OCCTTest",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
