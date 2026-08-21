// #1057, the form sent upstream. Compile and run it on its own, no package needed:
//
//     swiftc upstream-repro.swift -o upstream-repro && ./upstream-repro
//
// Expected: exits 0.
// Measured on Swift 6.3.3 (swiftlang-6.3.3.1.3), Xcode 26.6, macOS 26.6.1, arm64:
//
//     freed pointer was not the last allocation
//
// Debug only. Adding -O makes it clean.
//
// The file must be named main.swift for `swift run` inside a package; swiftc accepts top-level
// code in any single file compiled on its own.

actor Iso {}
let iso = Iso()

func outer(_ a: (String, SIMD3<Double>)) async throws {
    func local(_ a: (String, SIMD3<Double>), _: isolated (any Actor)? = iso) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

try await outer(("+X", SIMD3(1, 0, 0)))
print("clean")
