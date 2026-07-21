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
//
// ⚠️ Package.resolved FOOTGUN (#260): a consumer that reaches OCCTSwift via a LOCAL PATH dep (or a
// local-path SPM mirror) turns it into a *local package*, which SPM does NOT pin — so the occtswift
// pin (and its transitive OCCT-family pins) is silently dropped from the consumer's Package.resolved
// on every build. Do NOT commit that churn: the committed Package.resolved must be the URL-pinned one
// produced with NO local sibling present (i.e. on CI / a fresh clone). See docs/guides/sharing-the-xcframework.md.
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
    // v1.15.1 rebuild: OCCT 8.0.0p1 + our carried patches — 0001 (ShapeFix_Face guard, #263),
    // 0002 (backport of upstream OCCT#1334, #280), 0003 (fillet TopOpeBRep thread_local, #298),
    // 0004 (ShapeAnalysis_FreeBounds owires init, #310), 0005 (ShapeFix_Face null-Context guard
    // in FixPeriodicDegenerated, #317), 0006 (BRepGProp_EdgeTool adaptor NbPoles, #318), 0007
    // (ShapeAnalysis_FreeBounds lwire reset, #323), 0008 (Geom_BSplineCurve O(1)
    // PeriodicNormalization, #323), 0009 (StepData_StepWriter split oversized string, #323), and
    // 0010 (Intf_Interference O(1) tangent-zone lookup + checkpointed breaker, #319).
    // Bump BOTH url and checksum whenever the xcframework is rebuilt, or URL-resolving consumers
    // silently keep the previous kernel while local sibling builds get the new one.
    : .binaryTarget(
        name: "OCCT",
        url: "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v1.15.1/OCCT.xcframework.zip",
        checksum: "b1c967f90ea45a74ba97893ce78297d8c2dee516024f9c79f80b16b388ece2c1"
    )

// OCCTBridge is 16 Objective-C++ files / ~62K lines wrapping the OCCT header tree; SwiftPM recompiles
// it from source on every consumer of OCCTSwift (#339 measured 51.6s wall / 186.5s CPU per rebuild in
// one path-dependency consumer worktree, on top of the ecosystem's shared-xcframework setup — see
// Scripts/build-occtbridge.sh). Default stays SOURCE (unchanged behaviour, and the correct choice for
// this repo's own dev loop — every release edits Sources/OCCTBridge/src/*.mm directly, and a stale
// prebuilt binary would silently mask those edits). Set OCCTSWIFT_BRIDGE_PREBUILT=1 to opt into the
// prebuilt binaryTarget instead: local Libraries/OCCTBridge.xcframework (built via
// Scripts/build-occtbridge.sh) if present, else the matching release asset. Prebuilt only covers the
// same core slices as OCCT.xcframework (macOS, iOS device, iOS simulator, see Scripts/build-occt.sh);
// visionOS/tvOS consumers must leave the env var unset (source build) or rebuild the prebuilt locally
// with BUILD_ALL_PLATFORMS=1.
let useBridgePrebuilt = ProcessInfo.processInfo.environment["OCCTSWIFT_BRIDGE_PREBUILT"] == "1"
let useBridgeLocalBinary = useBridgePrebuilt
    && FileManager.default.fileExists(atPath: occtPackageDir + "/Libraries/OCCTBridge.xcframework/Info.plist")

let occtBridgeTarget: Target = useBridgeLocalBinary
    ? .binaryTarget(
        name: "OCCTBridge",
        path: "Libraries/OCCTBridge.xcframework"
    )
    : useBridgePrebuilt
    // Bump BOTH url and checksum whenever Scripts/build-occtbridge.sh output changes, matching
    // the OCCT.xcframework convention above.
    ? .binaryTarget(
        name: "OCCTBridge",
        url: "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v1.15.3/OCCTBridge.xcframework.zip",
        checksum: "ed5147e9efa954a27ed1f87563d9332ac80f7c88614064022ec5248f0f6ffb82"
    )
    : .target(
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
            .define("OCCT_AVAILABLE", to: "1"),
            // OCCT 8.0 deprecates its own legacy spellings (Standard_True/Standard_Real,
            // TopTools_* map/list typedefs, TColStd_Array1Of*, …) in favour of native C++ types
            // and explicit NCollection_* templates. This bridge still uses the legacy names, so
            // every consumer build inherited ~684 -Wdeprecated-declarations from our .mm files —
            // drowning out real warnings downstream (issue #281).
            //
            // OCCT_NO_DEPRECATED is OCCT's own opt-out (Standard_Macro.hxx), so this silences
            // exactly OCCT's deprecation attributes and nothing else. It is scoped to this
            // target, and it is a `.define` rather than `.unsafeFlags` deliberately: unsafeFlags
            // is rejected by SwiftPM for any package consumed as a dependency, which would break
            // every downstream consumer.
            //
            // This buys quiet, not absolution — the legacy spellings are still deprecated and
            // will eventually be removed upstream. Migrating the call sites is tracked in #281.
            .define("OCCT_NO_DEPRECATED")
        ],
        linkerSettings: [
            .linkedLibrary("c++")
        ]
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
        //
        // Depends on OCCT directly (not just transitively via OCCTBridge) because a binaryTarget
        // (the OCCTSWIFT_BRIDGE_PREBUILT path above) has no "dependencies" of its own to propagate —
        // without this, the final link would silently drop libOCCT-*.a whenever OCCTBridge is prebuilt.
        .target(
            name: "OCCTSwift",
            dependencies: ["OCCTBridge", "OCCT"],
            path: "Sources/OCCTSwift",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // Objective-C++ bridge to OCCT — source or prebuilt, see OCCTSWIFT_BRIDGE_PREBUILT above.
        occtBridgeTarget,

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
        .testTarget(name: "OCCTBRepGraphTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTBRepGraphTests"),
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
