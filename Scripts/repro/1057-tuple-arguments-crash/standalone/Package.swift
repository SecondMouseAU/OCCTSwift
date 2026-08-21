// swift-tools-version: 6.0
import PackageDescription

// A dependency-free reproducer for #1057. One empty library target and one test target; no
// OCCTSwift, no OCCTBridge, no OCCT.xcframework. Everything the grid needs is in
// Tests/TupleGridTests/TupleGridTests.swift.
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
