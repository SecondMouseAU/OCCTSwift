// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

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
let isWASI =
    isExplicitWASI
    || (swiftSDK != nil && (swiftSDK!.contains("wasm") || swiftSDK!.contains("wasi")))
    || (swiftPlatform != nil && swiftPlatform!.contains("wasi"))

// For WASI, we use a locally built static library (libOCCT-wasm.a), not an xcframework.
// For native platforms, we prefer the local xcframework if present, otherwise download the remote one.
let useLocalXCFramework: Bool = {
    if isWASI { return false }  // WASI never uses xcframework
    if ProcessInfo.processInfo.environment["OCCTSWIFT_REMOTE"] == "1" { return false }
    if ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1" { return true }
    return FileManager.default.fileExists(
        atPath: occtPackageDir + "/Libraries/OCCT.xcframework/Info.plist")
}()

// OCCT V8.0.1 plus the forty-one carried patches are documented in Scripts/patches/README.md
// (patch list, verification status, and CI coverage gaps for maintainers).
let occtTarget: Target =
    isWASI
    // WASI: Use locally built static library from Scripts/build-occt-wasm.sh
    // The library and headers are at Libraries/libOCCT-wasm.a and Libraries/occt-headers-wasm/
    // The `path: "Libraries"` sets the base for headerSearchPath("occt-headers-wasm") -> Libraries/occt-headers-wasm/
    // dummy.c is required by SwiftPM (targets must have at least one source file), and
    // include/ is required too: SwiftPM refuses to LOAD a package whose target has no
    // public-headers directory ("public headers (\"include\") directory path for 'OCCT' is
    // invalid or not contained in the target"). Both are force-added past the `Libraries/` line
    // in .gitignore, so a consumer's checkout has them.
    //
    // NO .unsafeFlags HERE, and none anywhere on this path. SwiftPM refuses to build any package
    // that has them once it is resolved by VERSION, which is how an application consumes a
    // published package; path and branch dependencies are exempt, a version requirement is not.
    // Measured, with Scripts/repro/2048/run.sh. Everything that has no safe spelling, which is
    // the -L for this archive, the exception flags and the SjLj flag, comes from a toolset the
    // consumer passes to `swift build`; `Scripts/make-wasi-toolset.py` writes one.
    ? .target(
        name: "OCCT",
        path: "Libraries",
        sources: ["dummy.c"],  // Required by SwiftPM; file can be empty
        cxxSettings: [
            .headerSearchPath("occt-headers-wasm"),
            .define("OCCT_NO_DEPRECATED"),
        ],
        linkerSettings: [
            // The NAME is a safe setting; the -L that finds libOCCT-wasm.a is not expressible at
            // all and is the toolset's job.
            .linkedLibrary("OCCT-wasm")
        ]
    )
    : useLocalXCFramework
        // Local xcframework for native development
        ? .binaryTarget(
            name: "OCCT",
            path: "Libraries/OCCT.xcframework"
        )
        // OCCT V8_0_1 + the thirty-nine carried patches listed below.
        //
        // Scripts/build-occt.sh builds V8_0_1, which absorbed ten of the previously carried patches (0001-0009 and 0013; their files are deleted,
        // their writeups kept in Scripts/patches/README.md under "Retired patches"). The thirty-nine that
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
        //   0028  GeomPlate_BuildPlateSurface's uninitialised G0/G1/G2 errors                #1018
        //   0029  XCAFDoc_Datum reads the datum point's X from the annotation plane's array  #1022
        //   0030  TopoDS_TShape::myState non-atomic flag-mutation data race                  #1154
        //   0031  BSplCLib_Cache/BSplSLib_Cache mutable evaluation state, unsynchronized     #1153
        //         (watch OCCT#1076: would rename these to BSplCLib_CacheGrid/BSplSLib_CacheGrid
        //         and keep the identical race, so retarget this patch if it merges, don't drop it)
        //   0033  Interface_Static's shared STEP/IGES parameter table, recursive mutex       #1157
        //         (a partial fix, deliberately: closes the memory-safety hole, does not make two
        //         concurrent operations setting DIFFERENT values for the SAME named parameter
        //         produce correct output; see the patch's own doc comment)
        //   0034  GeomFill_CoonsAlgPatch::Value samples bound[0]/bound[2] at V, not U        #1515
        //   0036  IFSelect_WorkSession's errhand recursion sentinel is per-instance          #1403
        //   0037  STEPControl_ActorRead's NM_DETECTED non-manifold flag is per-instance      #2061
        //   0038  Interface_CheckTool's errh error-handling sentinel is per-instance         #1403
        //   0039  Interface_FileReaderData's Param() memo cache is per-instance              #1403
        //   0040  STEP/IGES controller one-time-init flags are thread-safe                   #1403
        //   0041  XSControl_Controller's listad and Interface_InterfaceModel's atemp locked  #1403
        //   0042  ShapeAnalysis::GetFaceUVBounds raises instead of dereferencing a null       #2773
        //         surface on a face that is both surface-less and edgeless
        //   0043  BRepGProp_Gauss::convert keeps the by-plane mass instead of zeroing it      #2827
        //         (the by-plane BRepGProp_Vinert overloads returned a fabricated 0.0; pinned by
        //         v4.0.0-kernel.3, and Face.volumeInertia(planeNormal:) now returns a measurement)
        //   0044  Extrema_ExtSS::Points / Extrema_ExtCS::Points bound against the point       #2840
        //         sequence rather than against NbExt(). Carried 2026-09-30, pinned by
        //         v4.0.0-kernel.4, which is the first asset to hold it
        //   0045  Geom2d_BezierCurve and Geom_BezierCurve InsertPoleAfter accept MaxDegree()    #2875
        //         + 1 poles, the bound the constructors and Increase() already use. Half is
        //         inert in a Release kernel: the 2d site is a _Raise_if that No_Exception
        //         empties, so OCCTCurve2DBezierInsertPoleAfter's guard is still the only 2d
        //         bound and is KEPT, with its bound moved to match (#3013)
        //   0046  math_Uzawa sizes Errinit by RowNumber(), not ColNumber(): 100 constraints    #2860
        //         in 2 unknowns was a deterministic SIGSEGV
        //   0047  BRepMesh_IncrementalMesh::initParameters refuses NaN. All five bounds        #2879
        //         tests were spelled value < bound, which NaN defeats. Both bridge guards     #2900
        //         are KEPT, the ordinary 0042 and 0044 exception
        //   0048  BRepGProp's by-plane overloads measure about the plane the caller named,     #2873
        //         not its mirror through the origin, at five sites across two classes.
        //         OCCTBRepGPropVinertPlane's compensating mirror was DELETED in the same
        //         change that pinned this, because the two together are wrong again (#3015)
        //   0050  GProp_SelGProps::Perform(gp_Cone) drops the spurious cos(semiAngle) from     #2992
        //         the lateral area
        //   0051  GProp_VelGProps::Perform(gp_Cone) computes the frustum volume instead of     #2992
        //         one carrying a spurious sin a that collapsed to zero at the cylinder limit
        //   0052  Geom_BezierSurface.hxx's rational-axis prose matches its own example         #2991
        //         matrix and its implementation
        //
        // This list said "fifteen" above a list of eleven until the release check ran, which is the
        // #585 failure shape in miniature: `ls Scripts/patches/*.patch | wc -l` agreed with the count
        // while the enumeration next to it did not.
        //
        // WHAT IS VERIFIED PRESENT IN THE PINNED ASSET, AND WHAT IS NOT. This paragraph opened "ALL
        // SEVENTEEN ARE VERIFIED PRESENT" and described a seventeen-patch asset. It went stale at the
        // v4.0.0-kernel.1 repin, which took the pinned set to twenty-nine, and #2190 is what caught
        // it. The per-patch verdict is no longer kept here by hand. Run:
        //
        //     python3 Scripts/check-pinned-asset-patches.py --require-asset
        //
        // It derives from each patch's own text a header line, a string literal, a thread_local
        // wrapper symbol or a name the patch introduces, then looks for it in all three slices. On
        // this asset it answers 16 confirmed, 13 not derivable, 0 absent, in about seven seconds. It
        // also looks for the RETIRED patches, which is what nothing did before #2190. THAT is the step
        // to run at a repin, before trusting any sentence in this block.
        //
        // The parts of the old breakdown that survive, because they say what the script cannot:
        //
        //   - Fifteen patches touch a shipped .hxx, and the xcframework ships the patched header
        //     verbatim, so every line they add is matchable line for line: 303 added lines, 0 missing.
        //     That is the one rule decisive in both directions, and it covers just over half the set.
        //   - One (0026) is .cxx-only but adds a distinctive string literal, so it is verified
        //     directly in the binary: the message it throws appears in BRepOffsetAPI_ThruSections's
        //     object file in each of the three slice archives (libOCCT-macos.a, libOCCT-ios.a,
        //     libOCCT-sim.a).
        //   - Thirteen reach the binary leaving nothing a symbol table or a byte search can see. A
        //     changed comparison, a reordered argument or a guard clause adds no name. 0033 is the
        //     sharpest case: it adds `std::recursive_mutex& StaticsMutex()` and that name is in NO
        //     symbol table in this asset, because libc++'s recursive_mutex constructor is constexpr,
        //     so the function-local static needs no guard variable and the accessor inlines away at
        //     -O2. The patch IS in the binary (Interface_Static.cxx.o holds the undefined references
        //     to recursive_mutex::lock() that vanilla V8_0_1 has no reason to hold). Absence of a name
        //     is not absence of a patch, which is why those thirteen get a bucket, not a verdict.
        // And the BEHAVIOURAL evidence, which answers a different question from the symbol evidence
        // above: whether a test exercises the fix, not whether the code is in the binary.
        //
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
        // Pinned to the v4.0.0-kernel.4 pre-release asset: upstream V8_0_1 plus the thirty-nine patches listed above,
        // and nothing else. That was NOT true of v4.0.0-kernel.1, which carried two patches that are
        // not in Scripts/patches/ at all, so read the next paragraph before treating any older asset's
        // enumeration as its contents.
        //
        // ===================================================================================
        // THE v4.0.0-kernel.1 ASSET CARRIED THIRTY-ONE PATCHES. THE TREE CARRIED TWENTY-NINE. (#2190)
        // ===================================================================================
        //
        // The two extras are retired patches that were deleted from Scripts/patches/ but never
        // reverted out of the shared Libraries/occt-src tree the asset was built from:
        //
        //   0032-TopOpeBRepBuild-KPart-merge-globals-thread-local-1371.patch  retired 2026-09-02
        //   0034-LocOpe_SplitDrafts-trim-infinite-pipe-curves-1393.patch      retired 2026-09-08
        //
        // build-occt.sh's patch loop ONLY APPLIES; it never reverts, and it refuses to reset a dirty
        // occt-src on purpose, so that an investigation's probe is not destroyed silently. A retired
        // patch's edits therefore survive in a working tree until somebody reverts them by hand. Nobody
        // did, and the 2026-09-22 build picked them up. Verified by symbol, not inferred: the kernel.1
        // asset held `TrimInfinite(...)` in LocOpe_SplitDrafts.cxx.o and `thread-local wrapper routine for
        // GLOBAL_*` in the three TopOpeBRepBuild objects, in all three slices.
        //
        // BOTH WERE INERT, which is why this was documented rather than rebuilt out. LocOpe_SplitDrafts
        // has no caller anywhere: Shape.splitDrafts was removed in v4.0.0 and upstream deleted the
        // class in OCCT#1442. thread_local versus static is identical single-threaded, and the twelve
        // globals 0032 touches are unreachable from this bridge's call surface, measured by #1371's own
        // probe. Nothing a consumer can call behaves differently.
        //
        // THAT DIVERGENCE IS CLOSED. The two strays above belonged to the v4.0.0-kernel.1 asset. The
        // pin below is now v4.0.0-kernel.4, built from a tree whose only modifications are the carried
        // patches, so neither is present: step 1 of "Shipping a rebuild" computes zero modified files
        // that no carried patch explains, over 92 as of 2026-10-03 (v4.0.0-kernel.3 computed the same
        // over 79, and v4.0.0-kernel.2 over 78, before 0043 added its one). The two ACKNOWLEDGED rows in
        // check-pinned-asset-patches.py stay keyed on v4.0.0-kernel.1 and so expire on their own here,
        // which is what they were built to do; if a later asset repeats either stray the finding comes
        // back rather than staying suppressed.
        //
        // The asset holds thirty-nine and Scripts/patches/ holds forty-one, so 0053 and 0054 are the
        // two untested patches, written up where the counts are, above.
        // If you rebuild and the checksum does not match the value below, that is a real difference to
        // investigate rather than an expected one, which is the opposite of what this paragraph said
        // while kernel.1 was pinned.
        //
        // CLAUDE.md: "A divergence with a written reason is expected; one without is a finding." This
        // is the written reason. Scripts/check-pinned-asset-patches.py carries the same two rows in
        // its ACKNOWLEDGED table, keyed on the tag v4.0.0-kernel.1, so the acknowledgement expires
        // automatically at the next repin and the finding comes back if the next asset repeats it.
        //
        // (A previous version of this paragraph said the asset was "byte-identical to the
        // v3.0.0-kernel.1 pre-release asset, which is why `checksum:` below did NOT change when `url:`
        // did". THAT WAS FALSE. The checksum changed at 64b2aec7, from 77df5a0a... to da14acb1...,
        // which `git log -L266,266:Package.swift` shows in one command. It was a leftover from the
        // previous pin and it is deleted rather than corrected, because nothing needs saying about a
        // reuse that did not happen. The v2.0.0 release DID reuse its kernel.3 zip unchanged, and that
        // is still recorded further down, where it is a true statement about a different release.)
        //
        // This is NOT the same file as the v2.0.0 asset it replaces: that one carried
        // fifteen, and 0026 (#905) and 0027 (#913) had landed in Scripts/patches/ since without ever
        // reaching a built kernel, so both were exercised by no CI job at all. That is the #585 shape,
        // and it is why the count check at the top of this comment is worth the ten seconds.
        //
        // IT IS TRUE AGAIN RIGHT NOW, DELIBERATELY, AND WIDER THAN IT WAS: this paragraph said
        // "twenty-one"/"those four" through 0031; it went stale the moment 0032 (#1371) landed without
        // updating it, the exact #807-shaped failure ("gate agrees, the prose beside it doesn't") this
        // repo's own CLAUDE.md warns about, caught and corrected here rather than repeated a third time
        // at 0033. IT WENT STALE AGAIN, and is corrected again, rather than left to repeat once more:
        // 0032 is RETIRED as of 2026-09-02, dropped rather than carried or upstreamed, because OCCT's
        // own master already fixes the identical twelve globals through a strictly better mechanism
        // (per-instance member fields, not thread_local duplication) in #1505 (merged 2026-08-25) and
        // #1509 (merged 2026-08-28), both by maintainer dpasukhi, #1509 also fixing GLOBAL_faces2d,
        // which this project's own investigation left uninvestigated. See Scripts/patches/README.md's
        // retired 0032 entry and CLAUDE.md's "Carrying OCCT source patches" section for the process
        // change this prompted: check upstream's own recent activity before opening a new investigation
        // in the caching/mutable-state space, not after landing a patch that turns out to duplicate
        // work already days old. IT WENT STALE A THIRD TIME, at 0035, and this correction is a
        // RETRACTION rather than a bookkeeping fix: 0035 (a backport of upstream #1259's last line)
        // landed 2026-09-19 and was RETIRED 2026-09-20 because it reintroduced #280, silently dropping
        // a face from every STEP write that follows an XDE read. The entry removed from the list below
        // called it "nearly inert, because the constructor pre-populates what it would write". That was
        // wrong: InitializeMissingParameters is also the REPAIR that re-sets DirectFaces on an actor a
        // STEPCAFControl_Reader has left with empty OperationsFlags, which is #280's exact mechanism.
        // kernel-integration.yml caught it on main. See Scripts/patches/README.md's retired 0035 entry.
        // Scripts/patches/ holds forty-one patches and the pinned asset holds thirty-nine of them,
        // enumerated above. `ls Scripts/patches/*.patch | wc -l` answers 41 against a list of 39.
        // The pinned asset lacks two of them, and this is the written divergence. The
        // v4.0.0-kernel.4 rebuild closed the divergence that 0044 had opened and that 0045
        // through 0052 widened, so the rows for 0044 through 0052 below are kept as the record
        // of what each patch does and which bridge mitigation it does or does not retire, and
        // 0053 and 0054 are the two rows about patches the asset does not carry:
        //
        //   0044  Extrema_ExtSS::Points / Extrema_ExtCS::Points bound against the point       #2840
        //         sequence rather than against NbExt(), which counts mySqDist and so counts
        //         the parallel branch's distance-with-no-point. Carried 2026-09-30 and built
        //         into v4.0.0-kernel.4. Until then it was NOT built, deliberately, because
        //         unlike 0043 it left NOTHING exposed to a Swift caller. OCCTSurfaceExtrema gained an IsParallel() gate with #2831, and
        //         OCCTExtremaExtSSPoint, OCCTExtremaExtCSPoint and OCCTCurve3DDistanceToSurface
        //         were already gated, so no bridge entry point can reach the faulting read.
        //         Until it was pinned it was in NO required check: build-and-test resolved the
        //         asset without it. kernel-integration.yml built it from source on the PR that
        //         added it, which proved it applied, compiled and regressed nothing, and nothing
        //         more.
        //         Measured before and after by override-link in Scripts/repro/2840/.
        //         DO NOT RETIRE THOSE BRIDGE GATES NOW THAT THIS IS PINNED. The rule in
        //         okf/policies/pinned-kernel-patch-check.md retires a mitigation its patch
        //         supersedes, and this is the 0042-shaped exception: patched, the kernel raises
        //         Standard_OutOfRange for the same input the gate refuses, so both answer nil
        //         and the gate is redundant rather than wrong, it still covers anyone pinning an
        //         older asset, and it is also the deliberate API decision that a parallel pair is
        //         a refusal rather than a distance with no points (a SemVer change, still open).
        //
        //   0045  Geom2d_BezierCurve::InsertPoleAfter and Geom_BezierCurve::InsertPoleAfter      #2875
        //         refuse at MaxDegree() poles, where both constructors and Increase() allow
        //         MaxDegree() + 1. Carried 2026-10-02 and built into v4.0.0-kernel.4. Half of it is inert in a
        //         Release kernel anyway: the 2d site is a Standard_ConstructionError_Raise_if,
        //         which No_Exception empties, so the shipped 2d class has no bound at all and
        //         the bridge's own guard is what enforces one. The 3d site is a literal throw
        //         and does move, from 25 poles to 26, measured in
        //         Scripts/repro/2875-bezier-insertpole-bound/.
        //         DO NOT RETIRE OCCTCurve2DBezierInsertPoleAfter'S GUARD NOW THAT THIS IS PINNED:
        //         it is the only check the 2d class has in this build, patched or not. Its bound
        //         moved from >= to > at the repin, to match the 3d class (#3013).
        //
        //   0046  math_Uzawa sizes Errinit by Cont.ColNumber() and writes it by row, so any     #2860
        //         overdetermined system overruns it: 4 constraints in 2 unknowns returns a
        //         wrong answer, 100 in 2 is a deterministic SIGSEGV. Carried 2026-10-02 and built
        //         into v4.0.0-kernel.4; until then the fault was in the pinned kernel and
        //         OCCTMathUzawa's nConstraints > nVars guard was the only thing between a Swift
        //         caller and it.
        //         DO NOT RETIRE THAT GUARD NOW THAT THIS IS PINNED: patched, the kernel answers a
        //         correctly sized initial error for an overdetermined system, which is a
        //         behaviour change the Swift surface has not decided to expose, and the guard
        //         still covers anyone pinning an older asset. Measured before and after in
        //         Scripts/repro/2860-uzawa-errinit-dimension/.
        //
        //   0047  BRepMesh_IncrementalMesh::initParameters refuses a NaN parameter: all five    #2879
        //         of its tests are spelled `value < bound`, which NaN defeats, so the two that  #2900
        //         throw do not throw and the three that substitute do not substitute. Carried
        //         2026-10-02 for the OCCT 8.0.2 rebuild. It leaves nothing exposed to a Swift
        //         caller: occtValidMeshDeflection and occtValidMeshAngle already refuse the same
        //         input at every bridge site, so the kernel never sees it from here.
        //         KEEP BOTH BRIDGE GUARDS NOW THAT THIS IS PINNED. Same shape as 0042 and 0044: with
        //         the patch the kernel throws Standard_NumericError for the same input the guards
        //         refuse, so both answer the site's refusal and the guards are redundant rather
        //         than wrong, and they still cover anyone pinning an older asset or the wasm one.
        //
        //   0048  The by-plane BRepGProp_Vinert and BRepGProp_VinertGK overloads measure about    #2873
        //         the plane the caller passed rather than its mirror through the origin: the
        //         stored fourth coefficient carried the wrong sign, which also made loc cancel
        //         out instead of re-basing. Carried 2026-10-02 for the OCCT 8.0.2 rebuild.
        //         THIS ONE WAS THE OPPOSITE CASE AND THE v4.0.0-kernel.4 REPIN ACTED ON IT (#3015).
        //         OCCTBRepGPropVinertPlane did not guard an input, it COMPENSATED: it built the
        //         gp_Pln mirrored through the origin so that the unpatched kernel answered about
        //         the plane the Swift caller asked for. A kernel carrying 0048 with that mirror
        //         still in place measures about the mirrored plane again, and
        //         BRepGPropVinertTests' two sign assertions failed on #3014 for that reason. The
        //         repin deleted the mirror and dropped the "pass -d" note from
        //         Face.volumeInertia(planeNormal:planeDistance:) and
        //         docs/reference/Shape-HLR-Geom.md, in the same change. Until then the mirror was
        //         correct and had to stay, because CI resolves the pinned asset.
        //
        //   0050  GProp_SelGProps::Perform(gp_Cone) drops the spurious cos(semiAngle) from the      #2992
        //         lateral area, and
        //   0051  GProp_VelGProps::Perform(gp_Cone) returns the frustum volume instead of a         #2992
        //         quantity carrying a spurious sin(a), which collapsed to zero at the cylinder
        //         limit the same class answers exactly. Carried 2026-10-02 and built
        //         into v4.0.0-kernel.4, the rebuild that took them the same night. UNLIKE 0044,
        //         both left a value a CALLER READS wrong on the asset pinned before it, through
        //         GeometryProperties.coneSurfaceArea and .coneVolume, which is 0043's situation
        //         rather than 0044's, and is why neither was held for 8.0.2. No bridge-side
        //         mitigation was added, deliberately: correcting the factor in the bridge would
        //         have to be retired at the repin and would double-correct a patched kernel in
        //         the window between. Both derivations were re-checked against the closed form
        //         and the cylinder limit and measured by override-link in Scripts/repro/2992/.
        //         The two classes have NO caller anywhere in Libraries/occt-src, which is why
        //         those two arbiters are the ones used; see okf/policies/follow-occt-callers.md.
        //   0052  Geom_BezierSurface.hxx's IsURational/IsVRational prose corrected to match its    #2991
        //         own example matrix and the implementation. A header comment, so it changes no
        //         binary and leaves nothing exposed; it is listed here only because it is carried,
        //         like the rows above.
        //
        //   0053  BRepOffset_MakeOffset::BuildOffsetByArc registers the offset faces as roots   #3003
        //         by walking a DataMap hashed on TShape addresses, so every arc-join offset
        //         (MakeOffsetShape, MakeThickSolid) returns its faces in an order that changes
        //         between processes and between builds in one, and the volume summed over them
        //         moves in its last digits. Carried 2026-10-03 and NOT built. No crash and nothing
        //         a bridge guard could cover: the effect is a face order and the last place of a
        //         sum, which three lines of two #766 probes show and carry a `tolerance`
        //         declaration for until this is pinned. It also fixes one outcome per input where
        //         the outcome depends on the root order: the fuse of two boxes with its coplanar
        //         faces left split returns IsDone() with a null shape in about half of the processes
        //         (9 to 13 of 20 over three censuses) and, patched, in all of them. Measured before and after by override-link in
        //         Scripts/repro/3003-offset-roots-hash-order/.
        //
        //   0054  ChFi3d_Builder::StartSol, on an obstacle whose neighbour face holds no edge     #2881
        //         to follow, returns false but leaves HC as an empty BRepAdaptor_Curve2d with
        //         c1obstacle still set, so the caller takes the obstacle path and the SurfRst
        //         walk dereferences a null curve: a SIGSEGV inside BRepFilletAPI_MakeFillet::Build
        //         that no bridge catch (...) can reach (upstream OCCT#1568). Carried 2026-10-05
        //         and NOT built. Eight of the 42 edges of the reporter's model crash at radius 1.5
        //         and nowhere else; patched they report IsDone() == false, as 1.4999999 does.
        //         Nothing a bridge guard can cover, which is why it is carried. Measured before
        //         and after by override-link in Scripts/repro/occt1568-fillet-opposite-edge/.
        //
        // 0043 (#2827, BRepGProp_Gauss keeps the by-plane mass) was the one outstanding before it,
        // and it went the other way, which is the comparison worth keeping beside 0044: carried
        // 2026-09-29 unbuilt, because OCCT 8.0.2 was days out and there is a standing hold on repinning
        // until it lands, then built and pinned the same day by v4.0.0-kernel.3 once the cost of
        // shipping a fabricated 0.0 through Face.volumeInertia(planeNormal:planeDistance:) for that
        // window was weighed against the rebuild. It is live in the binary, not merely applied to
        // source: building against the new asset makes #2827's own regression fail at the same lines
        // and values as CI's independent kernel-integration build, which is the check that separates
        // "the patch is in the tree" from "the fix reaches a consumer".
        //
        // PR #2776's bridge guard is kept rather than retired with the repin, which is a deliberate
        // exception to the rule in okf/policies/pinned-kernel-patch-check.md that a repin retires the
        // mitigation its patch supersedes. That rule exists because a guard outliving its fix turns a
        // working call into a refusal, and this one does not: with 0042 the kernel raises
        // Standard_NullObject for the same input the guard refuses, so both answer nil and the guard is
        // redundant rather than wrong. It also still earns its place for anyone pinning an older asset.
        // The two RETIRED patches the v4.0.0-kernel.1 asset also
        // held are a separate quantity and are not counted here, because this count is the carried
        // set against the enumeration, which is what check-inventory-prose.py reads. Thirty-one
        // patches were in THAT asset; twenty-nine of them were ours to carry. Collapsing those two
        // numbers into one is how #2190 stayed invisible.
        //
        // That is new as of v4.0.0-kernel.1 and it is the point of the rebuild. Twelve patches
        // (0028-0031, 0033, 0034, 0036-0041) had been on disk and in NO CI job, because ci.yml's
        // build-and-test resolves this asset rather than building from source. A patch the asset
        // lacked reached no consumer and was exercised by nothing except the kernel-integration.yml
        // run of the PR that added it, which proves a patch applies, compiles and regresses nothing,
        // and cannot prove the fix works.
        //
        // Three of the twelve were live consumer exposure rather than bookkeeping: 0029 an uncatchable
        // SIGSEGV through Document.datums, 0030 and 0031 data races silent without TSan for anyone
        // sharing a TShape or a curve adaptor across threads. 0034 was a wrong single-threaded answer
        // reachable from Shape.coonsAlgPatch. All four now ship.
        //
        // KEEP THIS PARAGRAPH TRUE. If a patch is added and the asset is not rebuilt, the count above
        // stops matching and check-inventory-prose.py fails, which is what it is for (#1408). The fix
        // is a rebuild or a written divergence paragraph, never a hand-edited number. And a count that
        // keeps matching is not the same as an asset that matches: check-inventory-prose.py compares
        // this prose against the tree and reads no binary at all, which is exactly how the two extras
        // above went unnoticed. Scripts/check-pinned-asset-patches.py is the half that reads the
        // binary, and it belongs to the repin step, not to this paragraph.
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
        // Remote binary xcframework for native platforms
        : .binaryTarget(
            name: "OCCT",
            url:
                "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v4.0.0-kernel.4/OCCT.xcframework.zip",
            checksum: "4ebd78b698f834b34f178af36d7c1abd28d47752d38d659f59580a243b56f555"
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
let useBridgePrebuilt =
    false
    && ProcessInfo.processInfo.environment["OCCTSWIFT_BRIDGE_PREBUILT"] == "1"
let useBridgeLocalBinary =
    useBridgePrebuilt
    && FileManager.default.fileExists(
        atPath: occtPackageDir + "/Libraries/OCCTBridge.xcframework/Info.plist")

let occtBridgeTarget: Target =
    useBridgeLocalBinary
    ? .binaryTarget(
        name: "OCCTBridge",
        path: "Libraries/OCCTBridge.xcframework"
    )
    : useBridgePrebuilt
        // Bump BOTH url and checksum whenever Scripts/build-occtbridge.sh output changes, matching
        // the OCCT.xcframework convention above.
        ? .binaryTarget(
            name: "OCCTBridge",
            url:
                "https://github.com/SecondMouseAU/OCCTSwift/releases/download/v1.17.0/OCCTBridge.xcframework.zip",
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
                    // Compile the bridge as C++, not Objective-C++ (#2256). The 74 files in
                    // Sources/OCCTBridge/src carry a .mm extension and contain no Objective-C at all;
                    // measured across every one of them, zero @interface, @implementation,
                    // @autoreleasepool, @try, NSString, NSObject, NSArray and zero [[... alloc]. On this
                    // triple the extension is not merely inaccurate, it is fatal: the pinned clang
                    // CRASHES in WebAssembly instruction selection on a plain C++ try/catch in an
                    // Objective-C++ translation unit under -fwasm-exceptions, because clang gives such
                    // a unit the Objective-C++ personality function, the wasm EH lowering only handles
                    // the C++ one, and what survives to the selector cannot be selected. Building
                    // without the exception flags is not an alternative: that is exactly #2171's
                    // silent failure, where every outermost catch (...) stops firing with no
                    // diagnostic. Scripts/repro/2256 measures all of it, including the case where a
                    // real bridge file catches an OCCT raise on wasm with this setting and loses the
                    // catch without the flags.
                    //
                    // WHERE IT LIVES NOW. #2256 had to leave this as a `.unsafeFlags` here while
                    // #2048 was open. It is now in the consumer-side toolset that
                    // `Scripts/make-wasi-toolset.py` writes, as cxxCompiler.extraCLIOptions, because
                    // .unsafeFlags is the exact thing this path must not carry: SwiftPM refuses them
                    // for a dependency resolved by version, which is how #1689's consumer consumes
                    // this package. The toolset placement is also measured BETTER: under the
                    // deprecated `--build-system native` a cxxSettings `-x c++` reaches .c sources in
                    // the same target, while the toolset's does not.
                    // Use WASI-built OCCT headers
                    // Relative to this target's own path, Sources/OCCTBridge/src, which is what
                    // SwiftPM resolves headerSearchPath against. It is two levels up because the
                    // target's sources sit in a `src` subdirectory; moving them would break this, and
                    // SwiftPM offers no package-root-relative form.
                    .headerSearchPath("../../Libraries/occt-headers-wasm"),
                    // The threading shim, for a bridge source that includes it by name under an
                    // `#if defined(__wasi__)` guard. A guarded `#include` needs no build setting of
                    // any kind, which is why it is preferred over the `-include` flag
                    // Scripts/build-occt-wasm.sh uses for OCCT's own sources: a flag would have to
                    // come from the toolset, and a consumer who forgets it gets six errors naming
                    // std::mutex. Both mechanisms were measured to work, in
                    // Scripts/repro/2048/run.sh cases 4 and 8.
                    .headerSearchPath("../../Scripts/wasm-shims"),
                    .define("OCCT_AVAILABLE", to: "1"),
                    .define("OCCT_NO_DEPRECATED"),
                    // __wasi__ is NOT defined here: clang predefines it for this triple, measured
                    // with `clang -target wasm32-unknown-wasip1 -dM -E`, in both C and C++.
                    //
                    // Neither is _WASI_EMULATED_PROCESS_CLOCKS or _WASI_EMULATED_GETPID.
                    // Scripts/build-occt-wasm.sh passes NO emulation define (docs/WASI_GUARD_SITES.md,
                    // "CMake flags: none are passed"), and defining one here would compile the same
                    // OCCT headers under a different macro set from the archive this links against.
                    // #2179 measured the specific harm for the process clocks: the define is what
                    // broke wasi-osd-chronometer.patch, and guarding the include removed the need.
                ],
                linkerSettings: [
                    // Library NAMES are a safe setting and stay in the manifest. The -L directories
                    // that find them are not expressible at all and come from the toolset.
                    // Measured in Scripts/repro/2048/run.sh case 4: of these, only -lunwind and the
                    // kernel archive need a -L. libsetjmp.a and libwasi-emulated-getpid.a are in the
                    // Swift SDK's own WASI.sdk, which is already the link's sysroot, and libc++abi.a
                    // is there too but is the NO-EXCEPTIONS flavour, so the toolset's -L into
                    // wasi-sdk's lib/wasm32-wasip1/eh has to precede the sysroot rather than merely
                    // be present.
                    // Deliberately repeated from the OCCT target, which also declares it. A review
                    // suggested removing it here on the grounds that SwiftPM propagates a dependency's
                    // linker settings. That may well be so, and a duplicate `-l` is a no-op to the
                    // linker either way, but it cannot be checked until `libOCCT-wasm.a` exists, which
                    // is #2174. Dropping it on an untested assumption trades a harmless duplicate for
                    // an `undefined symbol` at the end of a full link. Revisit once #2174 lands.
                    .linkedLibrary("OCCT-wasm"),
                    .linkedLibrary("c++"),
                    .linkedLibrary("c++abi"),
                    .linkedLibrary("unwind"),
                    // -fwasm-exceptions does nothing for setjmp. OCCT's own CMake defines
                    // OCC_CONVERT_SIGNALS, so OCC_CATCH_SIGNALS expands to a real setjmp inside OCCT
                    // and six TKernel objects reference __wasm_setjmp (#2172, #2188).
                    .linkedLibrary("setjmp"),
                    // OSD_Directory::BuildTemporary() and OSD_Process::ProcessId() both call getpid(),
                    // which wasi-libc declares and does not define (docs/WASI_GUARD_SITES.md). The
                    // define is deliberately absent above; the library is what the link needs.
                    .linkedLibrary("wasi-emulated-getpid"),
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
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/macos-arm64/Headers",
                        .when(platforms: [.macOS])),
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/ios-arm64/Headers",
                        .when(platforms: [.iOS])),
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/ios-arm64-simulator/Headers",
                        .when(platforms: [.iOS])),
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/xros-arm64/Headers",
                        .when(platforms: [.visionOS])),
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/xros-arm64-simulator/Headers",
                        .when(platforms: [.visionOS])),
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/tvos-arm64/Headers",
                        .when(platforms: [.tvOS])),
                    .headerSearchPath(
                        "../../Libraries/OCCT.xcframework/tvos-arm64-simulator/Headers",
                        .when(platforms: [.tvOS])),
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
                    .define("OCCT_NO_DEPRECATED"),
                ],
                linkerSettings: [
                    .linkedLibrary("c++")
                ]
            )

// The `simd` module, on WASI only (#2175).
//
// 196 of the 230 files in Sources/OCCTSwift open with `import simd`, and on
// wasm32-unknown-wasip1 that is `error: no such module 'simd'`, which stops the entire Swift
// layer before any of it is type-checked. Apple's simd is part of the Apple SDKs and there is no
// wasm build of it.
//
// A target NAMED `simd`, reachable only when isWASI, answers that without editing any of the 196
// files and without changing a single byte of what an Apple build compiles: `import simd` still
// resolves to Apple's there, because this target is not in the graph at all. The alternative,
// 196 `#if canImport(simd)` edits, is a mechanical diff through nearly every file in the package
// and would still need the definitions this module carries.
//
// What it defines is what Sources/OCCTSwift measurably uses and no more; see the file's own
// header for the counts. It re-exports the platform C library for the same reason Apple's module
// does, measured rather than assumed (#2793), so a file whose only import is `simd` gets `cos` and
// `atan2` in scope on both platforms.
let wasiCompatTargets: [Target] =
    isWASI
    ? [
        .target(
            name: "simd",
            path: "Sources/WASICompat/simd",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
    : []

// OCCTPlatform is unconditional: it is the one target that knows which platform this is, and every
// file in the Swift layer imports it instead of Foundation. See Sources/OCCTPlatform/Platform.swift.
let swiftLayerDependencies: [Target.Dependency] =
    isWASI
    ? ["OCCTBridge", "OCCT", "OCCTPlatform", "simd"]
    : ["OCCTBridge", "OCCT", "OCCTPlatform"]

// Per-domain test targets that cannot exist on wasm32-unknown-wasip1 at all (#2793, emptied by
// #2928).
//
// EVERY DOMAIN TARGET RUNS FOR WASM. #2793 excluded five of the eighteen whole, deliberately coarse
// for a first increment, and #2928 measured what each exclusion was actually avoiding. The
// measurements are in `Scripts/repro/2928/`, and two of the five reasons recorded here were not true
// of the platform at all:
//
//   `NSLock` and `ProcessInfo` COMPILE for this triple. The wasm SDK ships the whole
//   swift-corelibs-foundation, not only FoundationEssentials; `Sources/OCCTPlatform/PlatformLock.swift`
//   avoids `NSLock` because the shipped LIBRARY cannot afford full Foundation's 10 MB of
//   internationalisation data (#2761), which is a module-size constraint and not an availability
//   one, and a test target has no size budget. `OCCTIOTests` went out over `NSLock`, 46 files for a
//   type that was there, and needed no edit of any kind to come back.
//
//   `OCCTThreadTests` IS NOT A SUITE ABOUT CONCURRENCY. The note here read "28 files whose subject
//   is concurrency" and the target's subject is SCREW THREADS: M8 fasteners, thread forms,
//   designation parsing, helical sweeps, V-profiles. Six of its 28 files are about CPU threads, and
//   those six are excluded below. The name is right for the contents and was wrong for the reason.
//
// What genuinely does not exist on this target is `DispatchQueue`, `DispatchGroup` and
// `DispatchSemaphore`, `autoreleasepool`, and the host-OS facilities `getrusage`, `statvfs`,
// `getpwuid`, `gethostname` and `uname`. Those are handled file by file below, and `autoreleasepool`
// by a shim. A sixth reason surfaced only on the build and was on no list: a bare `import Darwin` in
// `OCCTFoundationTests/Issue1442DiskUnicodeOSDUtilitiesTests.swift`, for two `free` calls, now the
// same per-platform conditional `Sources/OCCTPlatform/Platform.swift` uses. It is not a concurrency
// primitive, so the survey that found the others could not have found it; the build did.
//
// The empty set is kept rather than deleted because it is the mechanism for a target that someday
// cannot build at all, and because an empty one is the measurement.
let wasmUnportableTestTargets: Set<String> = []

// Individual test files no wasm suite builds or runs, and why (#2793, narrowed by #2928).
//
// NOTHING HERE IS EXCLUDED FOR A TRAP, and that is #2894's result rather than an accident. Four
// files and one whole target used to be, because the suites ran under wasmkit 0.3.1, which does not
// unwind a C++ exception through several frames: measured on one module file byte for byte, a throw
// Node catches reaches `std::terminate` there. The suites run under Node now, with the browser's own
// WASI shim, and `OCCTIntegrationTests`, the two evolved files, the two TObj files and the
// variable-fillet file all pass. #2894, #2895 and #2897 were that interpreter, not this port.
//
// NOTHING HERE IS EXCLUDED FOR `Int32` EITHER, which is #2928's result. Five files spelled an input
// past `Int32.max`, which `Int` cannot hold where it is 32 bits. That input is a run-time OVERFLOW
// TRAP and not a compile error, measured (`Scripts/repro/2928/run-overflow.sh`), and a trap ends the
// module, so excluding the file was the only way to keep the suite reporting. All five now build the
// case rather than naming it: a `pastInt32` that is `nil` where `Int` is 32 bits, so the one
// assertion that cannot exist is absent and the rest of the file runs. `.enabled(if:)` was the
// alternative and `Scripts/repro/2928/trait-measurement.md` records why it is the weaker one here.
//
// What is left is the eighteen files below, for four reasons, and all four are properties of the
// platform or of the harness rather than of the code under test:
//
//   TWO CALL `Shape.isSelfIntersecting(hardTimeout:)`, which is `#if !os(WASI)` because its
//   contract is a hard wall-clock deadline and needs a second thread to run the check on while the
//   caller waits (#2760). #2928 narrowed this from four files to two. `Issue446Unify...` and
//   `Issue598PipeShell...` called it INCIDENTALLY, inside tests about input mutation and about
//   Frenet mode, and each now reads the verdict through a three-line platform helper that uses
//   `isSelfIntersecting(timeout: 0)` on wasm: the same bridge call with the same `0`, so the
//   no-watchdog property #1054 needs is kept and only the wall-clock escape is lost.
//   `Issue208SelfIntersectionTests` and `Issue772SelfIntersectionAnalysisTests` are ABOUT
//   self-intersection analysis and stay out. The old note here said excluding them "loses nothing
//   that could have run", and that is not quite true: three of `Issue208`'s eight tests use the
//   portable `isSelfIntersecting()`, and one of the other five is about the 0.001 s deadline itself,
//   which no wasm spelling has. Splitting those three out is the remaining narrowing and is worth
//   less than the file split it costs.
//
//   NINE ARE ABOUT CONCURRENCY ITSELF, and have no meaning on a target with one thread rather than
//   failing on it (#2169). They are what is left of four whole-target exclusions:
//   `StressConcurrencyTests` is the one file in `OCCTStressTests` that runs work across
//   cores; `SerialLockThreadSafetyTests` and `ConstructionContextConcurrencyTests` were lifted out of
//   `OCCTFoundationTests.swift` and `OCCTMiscTests.swift` by #2928 for this purpose, because those
//   two files' other 157 and 79 tests had nothing to do with locks or with races. Each of the three
//   states at the top of the file why it is not portable and should not be made portable, and in
//   every case it is that a detector which cannot fail is worse than one that does not run.
//   `OCCTThreadTests` contributes six of its 28 files, listed by name below.
//
//   SEVEN READ A `.brep` FIXTURE OUT OF THE SOURCE TREE, which the module cannot see. That one is a
//   harness limitation and not a platform one, it is #3026, and the per-target note below says why
//   those seven are excluded rather than listed as known failures.
//
//   ONE COMPARES AN OCCT READING AGAINST THE HOST OS, which wasi-libc cannot be asked.
//   `HostOSCrossCheckTests` holds the six suites that bracket an OCCT reading with `getrusage`,
//   `statvfs`, `getpwuid`, `gethostname`, `uname` or `inet_pton`, five lifted out of
//   `OCCTFoundationTests.swift` and one out of `Issue1442DiskUnicodeOSDUtilitiesTests.swift`, whose
//   other four tests need no host oracle and run. These are not weakened to `>= 0` so that they build
//   here: `>= 0` is the assertion #1987 removed from five of them, because a bridge returning 0
//   passes it.
//
// `autoreleasepool` genuinely does not exist here and is NOT in this list, which is the one place a
// shim was the right answer: its single call site makes a `Document` die at the end of a loop
// iteration, which plain ARC already does on a target with no Objective-C runtime to pool anything
// in, so `Tests/OCCTMiscTests/WASIAutoreleasepoolShim.swift` declares the no-op and says why at
// length.
//
// `GCPntsSamplerBoundsTests` also used to be excluded, because one of its two tests PASSED after
// 422 seconds under wasmkit. Under Node it takes 27.8 s and its sibling 24.6 s, where before only
// one of the two finished inside the window at all, so that exclusion went with the runtime too. It
// is still the slowest thing in the suites by a wide margin, and for a real reason: an ellipse with
// a 1e9 aspect ratio walked for arc length against 16 measured overshoot counts.
let wasmExcludedTestFiles: [String: [String]] = [
    "OCCTFoundationTests": [
        "HostOSCrossCheckTests.swift",
        "SerialLockThreadSafetyTests.swift",
    ],
    "OCCTMiscTests": ["ConstructionContextConcurrencyTests.swift"],
    "OCCTModelingTests": ["Issue208SelfIntersectionTests.swift"],
    "OCCTShapeHealingTests": ["Issue772SelfIntersectionAnalysisTests.swift"],
    // One concurrency file, plus the seven that read a `.brep` out of `Fixtures/` by `#filePath`.
    // `#filePath` is an absolute HOST path baked in at compile time, and the suites run against an
    // in-memory filesystem whose only preopens are `/tmp` and `/work`, so every one of those tests
    // fails with `.importFailed`, 56 recorded issues with no second cause among them. Excluded
    // rather than listed, for two reasons: the tests never reach the kernel guard they are named
    // for (#2746, #2773, #2777, #2789, #2790, #2881), so a known-failure line would record a property of
    // the harness under the name of a guard; and the five guard suites reuse test names
    // deliberately, which the known-failure list cannot tell apart. Teaching
    // `wasm-test-node-runner.mjs` to preopen the fixture directories is the fix, and is #3026.
    // `StressUnifySameDomainNullPCurveTests` is the one of the original six that was lifted into a
    // file of its own, because its fixture test was one of 60 in `StressNullInvalidTests.swift`.
    // `Issue2881FilletObstacleTests` is the seventh: its control test loads the reporter's model, so
    // on wasm it would fail with `.importFailed` and prove nothing about the fillet.
    "OCCTStressTests": [
        "Issue2881FilletObstacleTests.swift",
        "StressAnalyzerSurfacelessFaceGuardTests.swift",
        "StressBRepCheckInContextGuardTests.swift",
        "StressConcurrencyTests.swift",
        "StressIgesExportSurfacelessFaceGuardTests.swift",
        "StressShapeCustomSurfacelessFaceGuardTests.swift",
        "StressShapeDivideSurfacelessFaceGuardTests.swift",
        "StressUnifySameDomainNullPCurveTests.swift",
    ],
    // The six files of 28 whose subject is CPU threads rather than screw threads. Measured:
    // `grep -ln 'Dispatch\|NSLock\|withTaskGroup\|Thread\.' Tests/OCCTThreadTests/*.swift` returns
    // exactly these, and the other 22 are fastener geometry.
    "OCCTThreadTests": [
        "Issue1404TObjApplicationThreadSafetyTests.swift",
        "Issue298FilletThreadSafetyTests.swift",
        "Issue341MeshCafThreadSafetyTests.swift",
        "Issue359STEPThreadSafetyTests.swift",
        "Issue361SharedSingletonThreadSafetyTests.swift",
        "Issue367FuseMultiThreadSafetyTests.swift",
    ],
]

// Drop the test targets wasm cannot build, and give the ones it can the `simd` stand-in.
//
// The dependency is declared here rather than left to resolve itself. Measured: `import simd` in a
// test file already compiles for wasm WITHOUT this, because every target shares one build-products
// directory and `simd` is always in it (OCCTSwift depends on it). That is module visibility by
// accident of layout, it is not a declared edge, and it would break the first time the layout or
// the dependency changed. 1,179 of the 1,428 test files import `simd`.
func adjustedForWASM(_ target: Target) -> Target? {
    guard isWASI, target.type == .test else { return target }
    guard !wasmUnportableTestTargets.contains(target.name) else { return nil }
    // `Target` IS A CLASS, so these mutate the object the array literal above already holds and
    // there is nothing to copy or reassign. Worth stating because the first version of this function
    // wrote `var target = target` out of struct habit, and the compiler's
    // "variable 'target' was never mutated" warning is what gave the reference semantics away.
    target.dependencies.append("simd")
    if let excluded = wasmExcludedTestFiles[target.name] {
        target.exclude += excluded
    }
    return target
}

let package = Package(
    name: "OCCTSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .visionOS(.v1),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "OCCTSwift",
            targets: ["OCCTSwift"]
        )
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
            dependencies: swiftLayerDependencies,
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
        .testTarget(
            name: "OCCTAnalysisTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTAnalysisTests"),
        .testTarget(
            name: "OCCTCurveTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTCurveTests"),
        .testTarget(
            name: "OCCTDrawingTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTDrawingTests"),
        .testTarget(
            name: "OCCTFoundationTests", dependencies: ["OCCTSwift"],
            path: "Tests/OCCTFoundationTests"),
        .testTarget(
            name: "OCCTGeom2dTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTGeom2dTests"),
        .testTarget(name: "OCCTIOTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTIOTests"),
        .testTarget(
            name: "OCCTIntegrationTests", dependencies: ["OCCTSwift"],
            path: "Tests/OCCTIntegrationTests"),
        .testTarget(
            name: "OCCTMathTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTMathTests"),
        .testTarget(
            name: "OCCTMeshTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTMeshTests"),
        .testTarget(
            name: "OCCTMiscTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTMiscTests"),
        // OCCTBridge added alongside OCCTSwift (#761 review) so
        // Issue761SharedEdgeCountCapTests can call OCCTFaceGetSharedEdges/
        // OCCTFaceGetSharedEdgeCount directly, to pin the invariant that the two only ever
        // disagree on count because of the maxEdges buffer, never because of the underlying
        // face-pair edge comparison -- not observable through AAG's own Swift API, which always
        // sizes its buffer from the true count now.
        .testTarget(
            name: "OCCTModelingTests", dependencies: ["OCCTSwift", "OCCTBridge"],
            path: "Tests/OCCTModelingTests"),
        // OCCTBridge added (#1491) so a regression test can call OCCTShapeDivideByNumber directly
        // with distinct nbU/nbV: Shape.dividedByNumber(_:), the only Swift call site, always passes
        // nbV=1, so proving the per-axis fix needs the raw C entry point, not the Swift wrapper.
        .testTarget(
            name: "OCCTShapeHealingTests", dependencies: ["OCCTSwift", "OCCTBridge"],
            path: "Tests/OCCTShapeHealingTests"),
        // `Fixtures/` holds .brep files read straight from the source tree via `#filePath`, not
        // through `Bundle.module`, so they are neither build inputs nor resources to copy. Without
        // this exclude SwiftPM reports them as unhandled on every build of this package as the ROOT
        // package (our dev loop and CI, plus anyone building a clone of OCCTSwift directly). It does
        // NOT reach consumers: SwiftPM builds no test targets for a non-root package, so a new
        // fixture directory under any other Tests/OCCT<Domain>Tests/ needs its own exclude here to
        // keep our own builds quiet (#440).
        .testTarget(
            name: "OCCTStressTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTStressTests",
            exclude: ["Fixtures"]),
        .testTarget(
            name: "OCCTSurfaceTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTSurfaceTests"),
        .testTarget(
            name: "OCCTThreadTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTThreadTests"),
        .testTarget(
            name: "OCCTBRepGraphTests", dependencies: ["OCCTSwift"],
            path: "Tests/OCCTBRepGraphTests"),
        .testTarget(
            name: "OCCTTopologyTests", dependencies: ["OCCTSwift", "OCCTBridge"],
            path: "Tests/OCCTTopologyTests"),
        .testTarget(
            name: "OCCTXCAFTests", dependencies: ["OCCTSwift"], path: "Tests/OCCTXCAFTests"),

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
        // The single home for every platform conditional in this package: which Foundation and
        // which C library, re-exported so no other file needs an `#if`. #2761.
        .target(
            name: "OCCTPlatform",
            path: "Sources/OCCTPlatform",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        .executableTarget(
            name: "Harnesses",
            dependencies: ["OCCTSwift", "RunnerCore"],
            path: "Scripts/repro/harnesses",
            // Two harnesses cannot exist on wasm32-unknown-wasip1, and they are EXCLUDED here
            // rather than wrapped in `#if !os(WASI)` in their own files. Both time work against a
            // wall clock with `DispatchTime`, and #772's also calls
            // `Shape.isSelfIntersecting(hardTimeout:)`, which is `#if !os(WASI)` as of #2175
            // because its contract needs a second thread the non-threads target does not have
            // (#2760). Neither would mean anything on a single-threaded module under an
            // interpreter: it would be timing the interpreter.
            //
            // Excluded and not guarded because wrapping a whole file in `#if` makes swift-format
            // demand the entire body be reindented one level, which turned a 28-line change into a
            // 1,400-line reformat when it was tried. HarnessRunner.swift's registry carries the one
            // `#if` that is genuinely needed, since the list has to agree with which entries exist.
            //
            // The first wasm CI job (#2269) is what surfaced this at all: #2175 guarded the library
            // and nothing built this target for wasm, because that spike consumed OCCTSwift through
            // a separate package.
            exclude: isWASI
                ? ["AnalyzeSelfIntersectionTiming.swift", "PocketEnclosureTiming.swift"]
                : [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ].compactMap(adjustedForWASM) + wasiCompatTargets,
    cxxLanguageStandard: .cxx17
)
