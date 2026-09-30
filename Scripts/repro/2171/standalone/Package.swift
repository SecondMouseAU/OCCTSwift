// swift-tools-version: 6.0
//
// #2171's exception spike. The shape is #2169's verification package (a Swift target calling C++
// over a flat C surface) with the parts that make OCCT's error contract hard added back: a failure
// hierarchy raised through a static entry point and caught by base reference, a stack object whose
// destructor has to run during the unwind, a translation unit deliberately compiled WITHOUT the
// exception flags, and setjmp/longjmp alongside them.
//
// Build and run it through Scripts/repro/2171/run.sh, which resolves the flags and passes
// --manifest-cache none. By hand:
//
//   export TOOLCHAINS=swift
//   export WASI_SDK_PREFIX=<a wasi-sdk 34.0 install>
//   export PROBE_CXX_EH_FLAGS="-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false"
//   swift build --manifest-cache none --swift-sdk swift-6.4.0-RELEASE_wasm \
//       --triple wasm32-unknown-wasip1
//
// `--manifest-cache none` is load-bearing, not caution. SwiftPM keys its manifest cache on the
// CONTENT of Package.swift, so neither an edit to a file this manifest reads nor an edit to a
// variable it reads from the environment reaches the next build, and `touch Package.swift` does
// not help either, because touching changes the mtime and not the hash. Measured in
// Scripts/repro/2171/README.md.
import Foundation
import PackageDescription

/// The wasm C++ exception flags, supplied by run.sh from the pinned toolchain file.
///
/// Read from the environment rather than restated, so this package cannot drift away from
/// `Scripts/wasm-toolchain-versions.txt` and keep passing on flags nothing else uses.
guard let ehFlagsValue = ProcessInfo.processInfo.environment["PROBE_CXX_EH_FLAGS"],
      !ehFlagsValue.isEmpty
else {
    fatalError("PROBE_CXX_EH_FLAGS is not set. Build this through Scripts/repro/2171/run.sh.")
}
let ehFlags = ehFlagsValue.split(separator: " ").map(String.init)

/// The wasi-sdk install, for its exception-enabled `libc++abi` and `libunwind`. The Swift SDK's
/// bundled WASI sysroot carries the no-exceptions flavour and no `__cxa_throw`, so a throwing
/// target compiles against its headers and then fails to link. See #2169.
guard let wasiSDKPrefix = ProcessInfo.processInfo.environment["WASI_SDK_PREFIX"],
      !wasiSDKPrefix.isEmpty
else {
    fatalError("WASI_SDK_PREFIX is not set. Build this through Scripts/repro/2171/run.sh.")
}
let exceptionLibraries = "\(wasiSDKPrefix)/share/wasi-sysroot/lib/wasm32-wasip1/eh"

let ehSettings: [CXXSetting] = [.unsafeFlags(ehFlags, .when(platforms: [.wasi]))]
let linkSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(exceptionLibraries)", "-Xlinker", "-lc++abi", "-Xlinker", "-lunwind",
                  // setjmp/longjmp are not in wasip1's libc. wasi-sdk puts the Wasm SjLj
                  // support routines in a separate libsetjmp, which OCCT's OSD_signal and
                  // OSD_ThreadPool will need on the link line.
                  "-Xlinker", "-lsetjmp"],
                 .when(platforms: [.wasi]))
]

let package = Package(
    name: "probe",
    targets: [
        // Stands in for TKernel: raises, and holds refcounted objects across the raise.
        .target(name: "ProbeKernel", cxxSettings: ehSettings),
        // Stands in for an OCCT translation unit whose CMake never received the flags.
        // Its absence from `cxxSettings` is the measurement.
        .target(name: "ProbeMiddleNoEH", dependencies: ["ProbeKernel"]),
        // setjmp/longjmp beside the exception flags, which is #2047's unverified claim.
        // -mllvm -wasm-enable-sjlj is separate from the exception flags and is what turns a
        // setjmp/longjmp pair into the __wasm_setjmp / __wasm_longjmp that libsetjmp defines.
        // Without it clang emits plain calls to setjmp and longjmp, warns about nothing, and the
        // link fails on two undefined symbols.
        .target(name: "ProbeSetjmp",
                cSettings: [.unsafeFlags(ehFlags + ["-mllvm", "-wasm-enable-sjlj"],
                                         .when(platforms: [.wasi]))]),
        // Stands in for Sources/OCCTBridge: catches at a flat C boundary, returns sentinels.
        .target(
            name: "ProbeBridge",
            dependencies: ["ProbeKernel", "ProbeMiddleNoEH", "ProbeSetjmp"],
            cxxSettings: ehSettings
        ),
        .executableTarget(name: "probe", dependencies: ["ProbeBridge"], linkerSettings: linkSettings),
        .executableTarget(name: "probe-uncaught", dependencies: ["ProbeBridge"],
                          linkerSettings: linkSettings),
    ]
)
