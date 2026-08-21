// swift-tools-version: 6.0
import PackageDescription

// A dependency-free reproducer for #1057: no OCCTSwift, no OCCTBridge, no OCCT.xcframework, and
// nothing from outside the toolchain.
//
// Five targets, in the order the narrowing went:
//   Nothing       an empty library, because a test target needs something to depend on
//   TupleGridTests the swift-testing grid, one @Suite per element type
//   Driver         a resilient module holding the generic drivers MinimalRepro calls across it
//   MinimalRepro   the same crash reached without swift-testing, in 22 stages
//   Smallest       the narrowing, 64 variants, importing nothing at all
let package = Package(
    name: "TupleGrid",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "Nothing"),
        // Built with library evolution, matching how Testing.framework ships in the toolchain: a
        // resilient module passes generic values indirectly, which is a different code path from
        // the same generic compiled alongside its caller.
        .target(
            name: "Driver",
            swiftSettings: [.unsafeFlags(["-enable-library-evolution"])]
        ),
        .executableTarget(name: "MinimalRepro", dependencies: ["Driver"]),
        .executableTarget(name: "Smallest"),
        .testTarget(name: "TupleGridTests", dependencies: ["Nothing"]),
    ]
)
