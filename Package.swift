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

// Detect WASI platform - check multiple indicators for reliability
// 1. Explicit flag (most reliable): OCCTSWIFT_WASI=1
// 2. SWIFT_SDK env var (set by swift build --swift-sdk): contains "wasm" or "wasi"
// 3. SWIFT_PLATFORM env var: may contain "wasi" in some SwiftPM versions
// Note: Target triple inspection is not available in Package.swift context;
// SwiftPM does not expose the target triple to the manifest.
let isExplicitWASI = ProcessInfo.processInfo.environment["OCCTSWIFT_WASI"] == "1"
let swiftSDK = ProcessInfo.processInfo.environment["SWIFT_SDK"]
let swiftPlatform = ProcessInfo.processInfo.environment["SWIFT_PLATFORM"]
let isWASI = isExplicitWASI ||
    (swiftSDK != nil && (swiftSDK!.contains("wasm") || swiftSDK!.contains("wasi"))) ||
    (swiftPlatform != nil && swiftPlatform!.contains("wasi"))

// For WASI, we use a locally built static library (libOCCT-wasm.a), not an xcframework.
// For native platforms, we prefer the local xcframework if present, otherwise download the remote one.
let useLocalXCFramework: Bool = {
    if isWASI { return false } // WASI never uses xcframework
    if ProcessInfo.processInfo.environment["OCCTSWIFT_REMOTE"] == "1" { return false }
    if ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1" { return true }
    return FileManager.default.fileExists(atPath: occtPackageDir + "/Libraries/OCCT.xcframework/Info.plist")
}()

// OCCT V8.0.1 plus the seventeen carried patches are documented in Scripts/patches/README.md
// (patch list, verification status, and CI coverage gaps for maintainers).
let occtTarget: Target = isWASI
    // WASI: Use locally built static library from Scripts/build-occt-wasm.sh
    // The library and headers are at Libraries/libOCCT-wasm.a and Libraries/occt-headers-wasm/
    // The `path: "Libraries"` sets the base for headerSearchPath("occt-headers-wasm") -> Libraries/occt-headers-wasm/
    // dummy.c is required by SwiftPM (targets must have at least one source file)
    ? .target(
        name: "OCCT",
        path: "Libraries",
        sources: ["dummy.c"], // Required by SwiftPM; file can be empty
        cxxSettings: [
            .headerSearchPath("occt-headers-wasm"),
            .define("__wasi__"),
            .define("OCCT_NO_DEPRECATED"),
            .define("_WASI_EMULATED_PROCESS_CLOCKS"),
            .define("_WASI_EMULATED_GETPID"),
        ],
        linkerSettings: [
            .linkedLibrary("OCCT-wasm"), // links libOCCT-wasm.a from Libraries/
            // Build directory is .build/<config>/OCCT.build/, so ../../Libraries reaches package root
            .unsafeFlags(["-L", "../../Libraries"])
        ]
    )
    : useLocalXCFramework
        // Local xcframework for native development
        ? .binaryTarget(
            name: "OCCT",
            path: "Libraries/OCCT.xcframework"
        )
        // Remote binary xcframework for native platforms
        : .binaryTarget(
            name: "OCCT",
            url: "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v3.0.0/OCCT.xcframework.zip",
            checksum: "77df5a0ae860b0f947353ff6eabf0ab25eb810ef0ce135b56bc60ff1e3e52ef2"
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
//
// REVIEWED AT THE v2.0.0 RELEASE COMMIT, and left disabled. The condition is "once the bridge stops
// changing every PR", and it has not been met: passes 2a through 5d (#382-#392) are duplication
// audits over the same `Sources/OCCTBridge/src/*.mm` this switch exists to protect, so the next
// phase edits the bridge as heavily as this one did. The url:/checksum: below therefore still name
// the v1.17.0 asset and are unreachable dead code, which is safe while `false &&` stands and is a
// trap the moment anyone deletes it without also rebuilding. Whoever restores this path bumps both,
// or links a bridge that predates two years of edits.
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
    : isWASI
        // WASI: Build from source with WASI-specific settings
        ? .target(
            name: "OCCTBridge",
            dependencies: ["OCCT"],
            path: "Sources/OCCTBridge",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                // Use WASI-built OCCT headers
                .headerSearchPath("../../Libraries/occt-headers-wasm"),
                .define("OCCT_AVAILABLE", to: "1"),
                .define("OCCT_NO_DEPRECATED"),
                .define("__wasi__"),
                // WASI doesn't have full POSIX; guard Foundation imports in headers
                .define("_WASI_EMULATED_PROCESS_CLOCKS"),
                .define("_WASI_EMULATED_GETPID"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("OCCT-wasm"),
                .unsafeFlags(["-L", "../../Libraries"])
            ]
        )
        // Native platforms: source build with XCFramework header search paths
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
        //
        // DO NOT ADD .interoperabilityMode(.Cxx) HERE without replacing what it silently removes.
        // These swiftSettings carry no C++ interop, so `import OCCTBridge` makes the compiler build
        // that clang module in OBJECTIVE-C mode on every source-path `swift build`, which is the
        // only thing enforcing that no public bridge header pulls a consumer into C++. Source-path,
        // not every build: under OCCTSWIFT_BRIDGE_PREBUILT=1 the bridge is a binaryTarget and
        // include/ is not compiled at all, so an edited public header goes unchecked there. That
        // path is switched off above and CI never takes it, which is what makes the guarantee hold
        // where it counts, and is a second reason not to restore it casually.
        //
        // It protects consumers, and NOT because the bridge is unreachable to them. OCCTBridge is
        // a target rather than a product, which reads like a wall and is not one: #967 measured a
        // consumer Swift target writing `import OCCTBridge` and a consumer .m writing
        // `#import "OCCTBridge.h"`, and both compile, link and run
        // (Scripts/repro/967-consumer-compile/bridge-reach.txt). Two earlier drafts of this comment
        // asserted the opposite, each time narrower and each time still wrong, which is the reason
        // it is spelled out here rather than summarised.
        //
        // What actually does the work is that SwiftPM recompiles THIS target from source in every
        // consumer, so the module is built there too, on their toolchain, in Objective-C mode. A
        // C++ include reaching Sources/OCCTBridge/include/ therefore breaks their build as well as
        // ours, and #967 is what that looks like from the outside: `'type_traits' file not found`
        // inside OCCT's own headers. Note the reach cuts both ways: a consumer that turns on C++
        // interop and imports OCCTBridge is a second route into these headers as C++.
        //
        // Measured, not asserted: adding `#include <Standard_Std.hxx>` to OCCTBridge.h fails
        // `swift build` here with "could not build Objective-C module 'OCCTBridge'". Turning
        // interop on compiles those headers as C++ instead, so the failure would move out of our
        // build and into theirs. Transcript and reasoning in Scripts/repro/967-consumer-compile/.
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
        // OCCTBridge added alongside OCCTSwift (#761 review) so
        // Issue761SharedEdgeCountCapTests can call OCCTFaceGetSharedEdges/
        // OCCTFaceGetSharedEdgeCount directly, to pin the invariant that the two only ever
        // disagree on count because of the maxEdges buffer, never because of the underlying
        // face-pair edge comparison -- not observable through AAG's own Swift API, which always
        // sizes its buffer from the true count now.
        .testTarget(name: "OCCTModelingTests", dependencies: ["OCCTSwift", "OCCTBridge"], path: "Tests/OCCTModelingTests"),
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
        .testTarget(name: "OCCTTopologyTests", dependencies: ["OCCTSwift", "OCCTBridge"], path: "Tests/OCCTTopologyTests"),
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

        // Shared dispatch logic for every "one executable target, many named entries" shared
        // target below (Censuses, Harnesses): the registry type and the list/all/run-by-name
        // switch, factored out after #772 review found Harnesses had reproduced Censuses' own
        // dispatch code almost line for line instead of sharing it. A plain library target, not
        // an executable: both executables below declare it as a dependency. Its own directory
        // holds only this one Swift file, so it needs no `exclude:` either.
        .target(
            name: "RunnerCore",
            path: "Scripts/repro/runner-core",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // #694: one shared executable target for every cluster census docs/v2.0.0-plan.md's
        // census-once rule asks for, replacing the one-target-per-cluster `ClusterACensus`
        // (#664 was the first). `swift run Censuses <cluster>` (or `all`, or no argument to list).
        // Source lives under Scripts/repro/censuses/, not Scripts/repro/<cluster-dir>/: a cluster's
        // own repro directory keeps its README and any static cross-check script (neither is Swift
        // source SwiftPM needs to see), so renaming that directory no longer touches the manifest
        // at all, the whole point, since #694 was raised because renaming
        // Scripts/repro/cluster-a-subshape-enumeration/ broke `swift build`/`swift test`
        // repo-wide with "error: invalid custom path". No `exclude:` is needed here because every
        // file this target's own directory holds is Swift source; a second `exclude:` list to
        // maintain was #694's other objection to one target per cluster.
        .executableTarget(
            name: "Censuses",
            dependencies: ["OCCTSwift", "RunnerCore"],
            path: "Scripts/repro/censuses",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // One shared executable target for ad hoc measurement harnesses backing an
        // issue-specific decision, the timing/perf sibling of Censuses just above and built on
        // the same #694 reasoning: a manifest path into a per-issue repro directory couples
        // `swift build` to a directory name that does get renamed, and a second `exclude:` list
        // per harness is a second thing to maintain. `swift run Harnesses <name>` (or `all`, or
        // no argument to list); see HarnessRunner.swift for the registry and RunnerCore's
        // GenericRunner for the dispatch logic it shares with Censuses. Source lives under
        // Scripts/repro/harnesses/, not Scripts/repro/<issue-dir>/: an issue's own repro
        // directory keeps only its README and captured output (neither is Swift source SwiftPM
        // needs to see), so no `exclude:` is needed here at all.
        .executableTarget(
            name: "Harnesses",
            dependencies: ["OCCTSwift", "RunnerCore"],
            path: "Scripts/repro/harnesses",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)