// swift-tools-version: 6.1
//
// #2048's stub: OCCTSwift's target shape with none of OCCT in it.
//
// Three targets in the same relationship the real package has, so that whatever SwiftPM does to
// this package it does to OCCTSwift for the same reasons:
//
//   StubKernel  = OCCTSwift's `OCCT` target. `path: "Libraries"`, one empty `dummy.c`, a header
//                 search path into a prebuilt header tree, and a `.linkedLibrary` naming a static
//                 archive that is NOT in the package sources.
//   StubBridge  = Sources/OCCTBridge. C++ over a flat C surface, an outermost `catch (...)`, a
//                 `std::mutex` the wasip1 libc++ does not declare, and a `getpid()` call.
//   StubSjLj    = the setjmp/longjmp OCCT reaches through OCC_CATCH_SIGNALS (#2172, #2188).
//   StubOCCT    = Sources/OCCTSwift. The Swift surface a JavaScriptKit application imports.
//
// Every setting below is one SwiftPM accepts in a package consumed as a versioned dependency,
// EXCEPT when STUB_UNSAFE_FLAGS=1, which is case 1 of the matrix and exists to be refused.
//
// Build it through ../run.sh. Every invocation passes `--manifest-cache none`, because SwiftPM
// keys that cache on the CONTENT of Package.swift and this manifest reads its environment.
import Foundation
import PackageDescription

/// WASI detection, deliberately spelled the way `Package.swift` spells it, so that "does the
/// consumer's environment reach a dependency's manifest at all" is measured rather than assumed.
let isWASI = ProcessInfo.processInfo.environment["STUB_WASI"] == "1"

/// Case 1: emit an `.unsafeFlags` the way the WASI path does today.
let useUnsafeFlags = ProcessInfo.processInfo.environment["STUB_UNSAFE_FLAGS"] == "1"

/// Case 3 against case 4: supply the threading shim by a plain guarded `#include` from the bridge
/// source, which needs only a `.define` and a `.headerSearchPath`, both safe.
let shimViaInclude = ProcessInfo.processInfo.environment["STUB_SHIM_VIA_INCLUDE"] == "1"

/// setjmp/longjmp is its own gap with its own flag, and clang REFUSES to compile a `setjmp` for
/// wasm without `-mllvm -wasm-enable-sjlj`. That refusal is loud, so the target is included only
/// in the cases whose subject it is, rather than failing every earlier case before it reaches its
/// own measurement.
let withSjLj = ProcessInfo.processInfo.environment["STUB_SJLJ"] == "1"

var bridgeCXX: [CXXSetting] = [
    .headerSearchPath("../../Libraries/stub-headers-wasm"),
    .headerSearchPath("../../shims"),
    .define("_WASI_EMULATED_GETPID", .when(platforms: [.wasi])),
]
if shimViaInclude {
    bridgeCXX.append(.define("STUB_SHIM_VIA_INCLUDE", .when(platforms: [.wasi])))
}
if useUnsafeFlags {
    bridgeCXX.append(.unsafeFlags(["-include", "../../shims/wasi-std-threading.hpp"],
                                  .when(platforms: [.wasi])))
}

// Order matters: wasm-ld resolves archives in the order it meets them, so the kernel archive
// has to precede the runtimes that satisfy its undefined symbols.
var bridgeLink: [LinkerSetting] = [
    .linkedLibrary("STUBKERNEL-wasm", .when(platforms: [.wasi])),
    .linkedLibrary("c++"),
    // The exception-enabled C++ runtime from wasi-sdk's lib/wasm32-wasip1/eh. The library NAMES
    // are safe; the `-L` that finds them is not expressible at all and comes from the toolset.
    .linkedLibrary("c++abi", .when(platforms: [.wasi])),
    .linkedLibrary("unwind", .when(platforms: [.wasi])),
    // Wasm SjLj support routines, for the __wasm_setjmp/__wasm_longjmp that
    // `-mllvm -wasm-enable-sjlj` emits.
    .linkedLibrary("setjmp", .when(platforms: [.wasi])),
    // Implied by _WASI_EMULATED_GETPID above. In the sysroot's default library directory, so it
    // needs no -L of its own.
    .linkedLibrary("wasi-emulated-getpid", .when(platforms: [.wasi])),
]
if useUnsafeFlags {
    bridgeLink.append(.unsafeFlags(["-L", "../../Libraries"], .when(platforms: [.wasi])))
}

let package = Package(
    name: "StubOCCT",
    products: [
        .library(name: "StubOCCT", targets: ["StubOCCT"]),
    ],
    targets: [
        .target(
            name: "StubKernel",
            path: "Libraries",
            sources: ["dummy.c"],
            cxxSettings: [.headerSearchPath("stub-headers-wasm")]
        ),
        .target(
            name: "StubBridge",
            dependencies: ["StubKernel"],
            path: "Sources/StubBridge",
            publicHeadersPath: "include",
            cxxSettings: bridgeCXX,
            linkerSettings: bridgeLink
        ),
        .target(
            name: "StubOCCT",
            dependencies: withSjLj ? ["StubBridge", "StubSjLj"] : ["StubBridge"],
            path: "Sources/StubOCCT"
        ),
    ]
)

if withSjLj {
    package.targets.append(
        .target(name: "StubSjLj", path: "Sources/StubSjLj", publicHeadersPath: "include")
    )
}

// `isWASI` is read so that the manifest fails loudly if the consumer's environment did NOT reach
// it, rather than silently building the native shape for a wasm triple, which is exactly the
// failure mode OCCTSwift's own detection would have.
if !isWASI && ProcessInfo.processInfo.environment["STUB_EXPECT_WASI"] == "1" {
    fatalError("STUB_WASI did not reach the dependency's manifest.")
}
