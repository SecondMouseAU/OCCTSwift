// swift-tools-version: 6.0
//
// The smallest package that proves the pinned wasm toolchain works: one Swift target calling one
// C++ target across a flat C surface, which is the shape OCCTSwift itself has. Kept out of the
// root package on purpose, so it builds for wasm without OCCT anywhere near it.
//
// Build and run it through Scripts/install-wasm-toolchain.sh --verify, or by hand:
//
//   export TOOLCHAINS=swift
//   export WASI_SDK_PREFIX=<repo>/Libraries/wasi-sdk-34.0-arm64-macos
//   swift build --swift-sdk swift-6.4.0-RELEASE_wasm --triple wasm32-unknown-wasip1
//   wasmkit run .build/out/Products/Debug-webassembly-wasm32/wasmprobe.wasm
//
// See Scripts/repro/2169/README.md for what each setting below is compensating for.

import Foundation
import PackageDescription

/// Reads one `KEY=value` line out of `Scripts/wasm-toolchain-versions.txt`.
///
/// The manifest reads the pins rather than restating them, so a toolchain bump does not leave a
/// stale copy here that still builds and quietly disagrees with everything else.
///
/// **Editing a pin does not reach the next build on its own.** SwiftPM caches the compiled
/// manifest against `Package.swift`, not against the files the manifest reads, and `rm -rf .build`
/// does not clear that cache. After changing a value read here, `touch Package.swift`.
///
/// Measured: with `WASM_CXX_EH_FLAGS` cut down to a bare `-fwasm-exceptions`, the rebuild was a
/// 0.26s no-op and the module still ran clean. One `touch Package.swift` later, the same edit
/// produced `Illegal opcode: [6]` at offset 0x282. A reviewer re-running this package's negative
/// cases hit the stale build first and nearly concluded the second flag was unjustified.
func pin(_ key: String) -> String {
    let pinsFile = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // .../standalone
        .deletingLastPathComponent()  // .../2169
        .deletingLastPathComponent()  // .../repro
        .deletingLastPathComponent()  // .../Scripts
        .appendingPathComponent("wasm-toolchain-versions.txt")
    guard let text = try? String(contentsOf: pinsFile, encoding: .utf8) else {
        fatalError("cannot read \(pinsFile.path)")
    }
    for line in text.split(separator: "\n") where line.hasPrefix("\(key)=") {
        return String(line.dropFirst(key.count + 1))
    }
    fatalError("\(pinsFile.path) has no '\(key)' line")
}

/// The wasi-sdk install, which supplies the exception-enabled C++ runtime the Swift SDK's sysroot
/// does not carry. `Scripts/install-wasm-toolchain.sh` exports it; a manual build must too.
///
/// Unset is refused rather than defaulted. An empty prefix builds the link path
/// `/share/wasi-sysroot/...` from the filesystem root, which exists nowhere and surfaces as a pile
/// of undefined `__cxa_*` symbols rather than as the one missing variable.
guard let wasiSDKPrefix = ProcessInfo.processInfo.environment["WASI_SDK_PREFIX"],
      !wasiSDKPrefix.isEmpty
else {
    fatalError("""
        WASI_SDK_PREFIX is not set, and this package builds only for wasm.
        Build it through Scripts/install-wasm-toolchain.sh --verify, which sets it, or export it \
        to a wasi-sdk install of the pinned version.
        """)
}
let exceptionLibraries = "\(wasiSDKPrefix)/share/wasi-sysroot/lib/wasm32-wasip1/eh"

let package = Package(
    name: "wasmprobe",
    targets: [
        .target(
            name: "WasmProbeCxx",
            cxxSettings: [
                .unsafeFlags(pin("WASM_CXX_EH_FLAGS").split(separator: " ").map(String.init),
                             .when(platforms: [.wasi]))
            ]
        ),
        .executableTarget(
            name: "wasmprobe",
            dependencies: ["WasmProbeCxx"],
            linkerSettings: [
                .unsafeFlags(["-L\(exceptionLibraries)",
                              "-Xlinker", "-lc++abi",
                              "-Xlinker", "-lunwind"],
                             .when(platforms: [.wasi]))
            ]
        ),
    ]
)
