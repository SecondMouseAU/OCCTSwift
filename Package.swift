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
    // OCCT V8_0_1 + the seventeen carried patches listed below.
    //
    // Scripts/build-occt.sh builds V8_0_1, which absorbed ten of the previously carried patches (0001-0009 and 0013; their files are deleted,
    // their writeups kept in Scripts/patches/README.md under "Retired patches"). The seventeen that
    // survive, all present in Scripts/patches/, are:
    //
    //   0010  Intf_Interference O(1) tangent-zone lookup + checkpointed breaker            #319
    //   0011  XCAFDoc_ShapeTool::OwnAutoNamingScope per-instance override             #341/#363
    //   0012  GetApplication/Resources lazy-init races + CDF_Directory/Resource_Manager
    //         /CDF_Application map synchronization                                         #344
    //   0014  PCDM_StorageDriver/PCDM_Reader driver-instance reentrancy mutex              #349
    //   0015  CDM_Application::myMetaDataLookUpTable + CDM_MetaData field mutexes          #353
    //   0016  Resource_Manager::Debug atomic + Storage_Schema per-instance scratch    #374/#518
    //   0017  null ReShape context in ComposeShell/WireDivide                              #484
    //   0018  GCPnts degenerate count + duplicate end point                                #555
    //   0019  AdvApp2Var Jacobi maxima workspace slot                                      #522
    //   0020  BRepFeat_MakeCylindricalHole tool-part selection                             #532
    //   0021  CPnts adaptive arc-length integration                                        #603
    //   0022  ChFi2d_Builder::AddChamfer connexion error check                             #705
    //   0023  GeomTools_Curve2dSet/SurfaceSet null-handle guard                            #643
    //   0024  Extrema_ExtCC::Points bound against mypoints                                 #636
    //   0025  GeomFill_Sweep reports the achieved conversion error                         #597
    //   0026  BRepOffsetAPI_ThruSections refuses an uncappable non-planar extremity        #905
    //   0027  ThruSections CreateSmoothed section-edge-count guard                         #913
    //
    // This list said "fifteen" above a list of eleven until the release check ran, which is the
    // #585 failure shape in miniature: `ls Scripts/patches/*.patch | wc -l` agreed with the count
    // while the enumeration next to it did not.
    //
    // ALL SEVENTEEN ARE VERIFIED PRESENT IN THE PINNED ASSET, measured rather than assumed:
    //
    //   - Eight (0010, 0011, 0012, 0014, 0015, 0016, 0021, 0024) touch a shipped .hxx. Every line
    //     each patch adds to a header was matched, line for line, against the header inside the
    //     built asset: 210 added lines, 0 missing.
    //   - One (0026) is .cxx-only but adds a distinctive string literal, so it was verified
    //     directly in the binary: the message it throws appears exactly once in each of the three
    //     slice archives (libOCCT-macos.a, libOCCT-ios.a, libOCCT-sim.a).
    //   - One (0027) is .cxx-only and adds NO string literal, signalling through myStatus instead,
    //     so nothing in the binary can be grepped for it. It is verified behaviourally by
    //     StressBuilderLifecycleTests.mismatchedSectionEdgeCountWithoutCheckFailsCleanly, which is
    //     gated on OCCTSWIFT_LOCAL=1 (PR #915 review, finding 1) precisely because it needs a
    //     locally built kernel. IT DOES NOT RUN IN ci.yml, which resolves this asset rather than
    //     building from source, so a green build-and-test is NOT evidence for 0027. Re-verify it
    //     with `OCCTSWIFT_LOCAL=1 swift test --filter StressBuilderLifecycle` against a local
    //     build, and check the log says the test STARTED rather than was skipped. That wording is
    //     measured, not cautious: the same suite reports "5614 tests" either way. Against a local
    //     kernel the log reads `started` then `passed after 66.774 seconds`; against the downloaded
    //     asset it reads `skipped`, and the headline total does not move. A green run and a correct
    //     total are both blind to this, so the per-test line is the only signal.
    //   - Five (0017, 0019, 0020, 0022, 0025) are .cxx-only and carry their own Swift regression
    //     suites (Issue484*, Issue522*, Issue532*, Issue568*, and the #597 case in
    //     OCCTSurfaceTests). ci.yml's build-and-test resolves this asset, not a local build, so a
    //     green run is behavioural proof those five reached the binary.
    //   - Two (0018, 0023) are exercised by NO test, and cannot be: the bridge stops the defect
    //     before OCCT sees it. Sampling.requested(_:atLeast: 2) rejects the point count 0018
    //     guards against, and OCCTGeomToolsCurve2dSetWrite/SurfaceSetWrite null-check every array
    //     element before Add(). Both are carried for upstream, deliberately unreachable here.
    //     They are the only two patches in the tree with no CI coverage of any kind, which is
    //     worth knowing before trusting "the fix is in the kernel" about either.
    //
    // Pinned to the v3.0.0 RELEASE asset: upstream V8_0_1 plus the seventeen patches listed above.
    // Byte-identical to the v3.0.0-kernel.1 pre-release asset, which is why `checksum:` below did
    // NOT change when `url:` did; the release commit re-uploaded the same zip. Same shape v2.0.0
    // used with its own kernel.3 asset. This is NOT the same file as the v2.0.0 asset it replaces: that one carried
    // fifteen, and 0026 (#905) and 0027 (#913) had landed in Scripts/patches/ since without ever
    // reaching a built kernel, so both were exercised by no CI job at all. That is the #585 shape,
    // and it is why the count check at the top of this comment is worth the ten seconds.
    //
    // IT IS TRUE AGAIN RIGHT NOW, DELIBERATELY. Scripts/patches/ holds NINETEEN patches; the pinned
    // asset holds the seventeen enumerated above. `ls Scripts/patches/*.patch | wc -l` answers 19
    // against a list of 17, and those two are the difference:
    //
    //   0028  GeomPlate_BuildPlateSurface's uninitialised G0/G1/G2 errors                #1018
    //   0029  XCAFDoc_Datum reads the datum point's X from the annotation plane's array  #1022
    //
    // What that difference means is narrower than "untested", and the narrowing is worth having.
    // ci.yml's build-and-test resolves this asset, so it never sees either patch. But
    // kernel-integration.yml triggers on `Scripts/patches/**`, builds V8_0_1 plus every carried
    // patch from source, and runs the full swift test against that binary, so the PR that ADDS a
    // patch does get it built and the suite run against it. What that proves is that the patch
    // applies, compiles, and regresses nothing; it cannot prove either fix works, because neither
    // has a Swift-reachable assertion. And it does not run on any later PR that leaves
    // Scripts/patches/ alone, which is nearly all of them. Do not read this as "check
    // kernel-integration.yml instead of ci.yml": that advice is what #585 discredited.
    //
    // They differ in what a rebuild would buy. 0028 fixes nothing observable in this repo:
    // OCCTGeomPlateErrors, the one bridge reader of those three accessors, was deleted by #999 (PR #1015),
    // and BRepFill_Filling's own forwarding of them is unreachable on the affected branch, so only
    // the upstream GTests cover it either way. 0029 is the opposite: it is an uncatchable SIGSEGV
    // on OCCTDocumentGetDatumInfo, reachable through Document.datums for any OCAF document whose
    // datum carries a point without an annotation plane, so until a rebuilt asset ships it nothing
    // protects a consumer. See Scripts/patches/README.md's 0028 and 0029 entries.
    //
    // The v3.0.0 RELEASE commit re-points this pair again, at the release asset. Until then every
    // commit pins v3.0.0-kernel.1, so do NOT delete that pre-release afterwards: deleting it takes its
    // asset with it and makes this window unbuildable from a clean checkout.
    //
    // Until it was published, ci.yml resolved v1.15.18 (V8_0_0_p1 + patches 0001-0016) while the
    // branch built V8_0_1 + 0010-0021, so every test asserting a newer patch's fix failed in CI
    // indistinguishably from a real regression: seven suites were red for that reason alone (#585),
    // and each correctness fix added more. Reading kernel-integration.yml instead of ci.yml was the
    // documented workaround; pinning a real asset removes the need for one.
    //
    // The RELEASE commit re-points this pair at the final v2.0.0 asset (#512). Do NOT delete the
    // pre-release afterwards: every commit in the v2.0.0 window pins it, so deleting it takes its
    // asset with it and makes those commits unbuildable from a clean checkout, which breaks
    // git bisect and any historical re-measurement.
    //
    // SEQUENCING. SwiftPM resolves `url:` at build time, so a URL pointing at an asset that is not
    // uploaded yet fails every build, and a wrong checksum is not the only way that happens: a
    // correct checksum against a 404 fails just the same, which is how the kernel.3 asset was once
    // published under the wrong filename and passed a checksum check while resolving to nothing.
    //
    // The order below is the one that works FOR THE RELEASE TAG. An earlier draft of this comment
    // put "create the release" first, which cannot be right there: the tag has to point at the
    // commit that carries the swapped URL, so the commit must exist before the release is cut.
    //
    // IT DOES NOT APPLY TO A KERNEL PRE-RELEASE, where it is circular: you cannot pin a URL that
    // does not exist yet, and you cannot cut the release from a commit that does not exist yet.
    // Every kernel pre-release in this repo resolves that the only way it can, by publishing the
    // asset first and landing the pin after, so its tag points at a commit pinning the PREVIOUS
    // asset. Measured, not assumed:
    //
    //     v2.0.0-kernel.1  -> tree pins v1.15.18
    //     v2.0.0-kernel.2  -> tree pins v2.0.0-kernel.1
    //     v2.0.0-kernel.3  -> tree pins v2.0.0-kernel.2
    //     v3.0.0-kernel.1  -> tree pins v2.0.0
    //     v2.0.0 (RELEASE) -> tree pins v2.0.0   <- only the release tag is self-consistent
    //
    // So a pre-release tag whose tree pins its predecessor is CORRECT and must not be "fixed" by
    // re-pointing it. That correction was proposed during the v3.0.0-kernel.1 rebuild on the strength of
    // the paragraph above, and the history is what refuted it.
    //
    //   1. commit the `url:` change and push it
    //   2. gh release create <tag> --target <that commit> with OCCT.xcframework.zip attached, so
    //      tag, release and asset land together
    //   3. confirm the asset RESOLVES (curl -fsIL the download URL), not merely that its checksum
    //      matches, and re-run anything that built in the gap
    //
    // There is a window between 1 and 2 where the URL 404s. It is unavoidable and it is short; what
    // matters is checking step 3 rather than assuming.
    //
    // `checksum:` does NOT change between the kernel.N pre-release and the release when the asset
    // is the identical file. That is what v2.0.0 did, and it is re-verifiable today: the v2.0.0 and
    // v2.0.0-kernel.3 assets are both 149,133,257 bytes, and downloading the v2.0.0 one hashes to
    // 8da567699b0ed1fcd0033373d64c2ee97052c57ee2dffe3091d6d55addc41f2a, the value BOTH commits
    // pinned. The release commit re-uploaded kernel.3's zip unchanged and swapped only `url:`.
    // Expect to do the same at the v3.0.0 release with the v3.0.0-kernel.1 asset.
    // Bump BOTH url and checksum whenever the xcframework is rebuilt, or
    // URL-resolving consumers silently keep the previous kernel while local sibling builds get the
    // new one.
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
