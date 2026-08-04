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
// CWD-relative "Libraries/…" check fails and falls back to the URL, making every local consumer
// download + extract its own 1.3 GB copy. Resolving against `#filePath` lets a path-dep consumer find
// OCCTSwift's in-place (gitignored) `Libraries/OCCT.xcframework` and SHARE the single copy. A URL
// consumer clones OCCTSwift into .build/checkouts (no `Libraries/`), so this still falls back to the
// remote zip there.
//
// ⚠️ Package.resolved FOOTGUN (#260): a consumer that reaches OCCTSwift via a LOCAL PATH dep (or a
// local-path SPM mirror) turns it into a *local package*, which SPM does NOT pin, so the occtswift
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
    // v1.15.18 rebuild: OCCT 8.0.0p1 + carried patches 0001-0016.
    //
    // NOTE: this URL is one kernel behind the source tree. Scripts/build-occt.sh now builds OCCT
    // V8_0_1, which absorbed ten of those patches (0001-0009 and 0013; their files are deleted,
    // their writeups kept in Scripts/patches/README.md under "Retired patches"). The eleven that
    // survive are 0010 (Intf_Interference O(1) tangent-zone lookup + checkpointed breaker, #319),
    // 0011 (XCAFDoc_ShapeTool::OwnAutoNamingScope per-instance override, #341/#363), 0012
    // (XCAFApp_Application::GetApplication/TDocStd_Application::Resources lazy-init races +
    // CDF_Directory/Resource_Manager/CDF_Application map synchronization, #344), 0014
    // (PCDM_StorageDriver/PCDM_Reader driver-instance reentrancy mutex, #349), 0015
    // (CDM_Application::myMetaDataLookUpTable + CDM_MetaData field mutexes, #353), 0016
    // (Resource_Manager::Debug atomic + Storage_Schema::ICurrentData per-instance, #374), 0017
    // (null ReShape context in ComposeShell/WireDivide, #484), 0018 (GCPnts degenerate count +
    // duplicate end point, #555), 0019 (AdvApp2Var Jacobi maxima workspace slot, #522), 0020
    // (BRepFeat_MakeCylindricalHole tool-part selection, #532), and 0021 (CPnts adaptive
    // arc-length integration, #603).
    //
    // Pinned to the v2.0.0-kernel.1 PRE-RELEASE: upstream V8_0_1 plus the eleven patches listed
    // above. This is a kernel-only pre-release, not a library release, and it exists so ci.yml
    // builds the same kernel this branch's tests are written against.
    //
    // Until it was published, ci.yml resolved v1.15.18 (V8_0_0_p1 + patches 0001-0016) while the
    // branch built V8_0_1 + 0010-0021, so every test asserting a newer patch's fix failed in CI
    // indistinguishably from a real regression: seven suites were red for that reason alone (#585),
    // and each correctness fix added more. Reading kernel-integration.yml instead of ci.yml was the
    // documented workaround; pinning a real asset removes the need for one.
    //
    // The RELEASE commit re-points this pair at the final v2.0.0 asset and the pre-release can then
    // be deleted (#512). Bump BOTH url and checksum whenever the xcframework is rebuilt, or
    // URL-resolving consumers silently keep the previous kernel while local sibling builds get the
    // new one.
    : .binaryTarget(
        name: "OCCT",
        url: "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v2.0.0-kernel.1/OCCT.xcframework.zip",
        checksum: "1f1e5cd95eb10b2098b2aa5d7bedcb973c44d8575477a9457e35f5a0d84cf217"
    )

// OCCTBridge is 16 Objective-C++ files / ~62K lines wrapping the OCCT header tree; SwiftPM recompiles
// it from source on every consumer of OCCTSwift (#339 measured 51.6s wall / 186.5s CPU per rebuild in
// one path-dependency consumer worktree, on top of the ecosystem's shared-xcframework setup; see
// Scripts/build-occtbridge.sh). Default stays SOURCE (unchanged behaviour, and the correct choice for
// this repo's own dev loop, since every release edits Sources/OCCTBridge/src/*.mm directly, and a stale
// prebuilt binary would silently mask those edits). Set OCCTSWIFT_BRIDGE_PREBUILT=1 to opt into the
// prebuilt binaryTarget instead: local Libraries/OCCTBridge.xcframework (built via
// Scripts/build-occtbridge.sh) if present, else the matching release asset. Prebuilt only covers the
// same core slices as OCCT.xcframework (macOS, iOS device, iOS simulator, see Scripts/build-occt.sh);
// visionOS/tvOS consumers must leave the env var unset (source build) or rebuild the prebuilt locally
// with BUILD_ALL_PLATFORMS=1.
// DISABLED FOR THE v2.0.0 LINE. The prebuilt path is switched off here rather than deleted: nearly
// every issue in the 2.0.0 queue edits Sources/OCCTBridge/src/*.mm, and a prebuilt binary that
// predates the edit links silently and reports a pass for code that was never compiled. The 8.0.1
// absorb hit exactly that: the shared prebuilt predated the #656 null-pcurve guard while
// OCCTSWIFT_BRIDGE_PREBUILT=1 was set in the environment, so the default path would have linked a
// guard-less bridge against a kernel whose OCCT#1402 had started returning null, which is the
// combination that SIGSEGVs. Paying ~50s per rebuild is the cheaper side of that trade.
//
// To restore (release commit, once the bridge stops changing every PR): delete the `false &&` and
// bump the url:/checksum: below to a freshly built asset.
let useBridgePrebuilt = false
    && ProcessInfo.processInfo.environment["OCCTSWIFT_BRIDGE_PREBUILT"] == "1"
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
        url: "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v1.17.0/OCCTBridge.xcframework.zip",
        checksum: "d9eab319f0dfad49b83d1776f1c0a74310c0ddb12a7ed391fe0a0b260778091b"
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
            // every consumer build inherited ~684 -Wdeprecated-declarations from our .mm files,
            // drowning out real warnings downstream (issue #281).
            //
            // OCCT_NO_DEPRECATED is OCCT's own opt-out (Standard_Macro.hxx), so this silences
            // exactly OCCT's deprecation attributes and nothing else. It is scoped to this
            // target, and it is a `.define` rather than `.unsafeFlags` deliberately: unsafeFlags
            // is rejected by SwiftPM for any package consumed as a dependency, which would break
            // every downstream consumer.
            //
            // This buys quiet, not absolution: the legacy spellings are still deprecated and
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
        // (the OCCTSWIFT_BRIDGE_PREBUILT path above) has no "dependencies" of its own to propagate.
        // Without this, the final link would silently drop libOCCT-*.a whenever OCCTBridge is prebuilt.
        .target(
            name: "OCCTSwift",
            dependencies: ["OCCTBridge", "OCCT"],
            path: "Sources/OCCTSwift",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // Objective-C++ bridge to OCCT, source or prebuilt; see OCCTSWIFT_BRIDGE_PREBUILT above.
        occtBridgeTarget,

        // OCCT binary framework - auto-selects local or remote
        occtTarget,

        // Tests, split into per-domain targets so editing/compiling one domain
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
        // `Fixtures/` holds .brep files read straight from the source tree via `#filePath`, not
        // through `Bundle.module`, so they are neither build inputs nor resources to copy. Without
        // this exclude SwiftPM reports them as unhandled on every build of this package as the ROOT
        // package (our dev loop and CI, plus anyone building a clone of OCCTSwift directly). It does
        // NOT reach consumers: SwiftPM builds no test targets for a non-root package, so a new
        // fixture directory under any other Tests/OCCT<Domain>Tests/ needs its own exclude here to
        // keep our own builds quiet (#440).
        .testTarget(name: "OCCTStressTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTStressTests",
                    exclude: ["Fixtures"]),
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
