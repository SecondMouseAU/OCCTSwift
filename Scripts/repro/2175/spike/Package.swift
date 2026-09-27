// swift-tools-version: 6.1
//
// The #2175 spike consumer: a Swift executable over the OCCTSwift public API, built for
// wasm32-unknown-wasip1 and run under the pinned wasmkit.
//
// It is a SEPARATE package rather than a target in OCCTSwift's own manifest, because that is the
// shape #1689's consumer has: an application that declares OCCTSwift as a dependency and builds
// only the `OCCTSwift` product. Building OCCTSwift as the ROOT package would also plan its
// eighteen test targets and three executables for wasm, none of which this gate is about.
//
// The dependency is by PATH, which is what a branch under development allows. #2048 measured that
// the `.unsafeFlags` refusal is a property of a VERSION requirement rather than of the platform,
// so a path dependency proves nothing about that rule; what makes the versioned form viable is
// that neither this manifest nor OCCTSwift's carries an `.unsafeFlags` on the WASI path at all.
// See Scripts/repro/2175/README.md, "What a versioned consumer still needs".
import PackageDescription

let package = Package(
    name: "OCCTWasmSpike",
    products: [
        .executable(name: "OCCTWasmSpike", targets: ["OCCTWasmSpike"])
    ],
    dependencies: [
        // `name:` is what makes this work in any checkout. A path dependency takes its package
        // IDENTITY from the directory name, so in a worktree called `OCCTSwift-wasm-2175` the
        // product reference would have to name that directory, and the spike would build in one
        // checkout and nowhere else. Naming the package here fixes the identity at `OCCTSwift`
        // whatever the directory is called.
        .package(name: "OCCTSwift", path: "../../../..")
    ],
    targets: [
        .executableTarget(
            name: "OCCTWasmSpike",
            dependencies: [.product(name: "OCCTSwift", package: "OCCTSwift")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
