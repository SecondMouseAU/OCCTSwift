// swift-tools-version: 6.1
// The Swift-side cross-check of the fillet / chamfer comb: the same cases as cprobe, through the public API and the #3200 guard.
// Build with the kernel under test in ../../../../Libraries/OCCT.xcframework:
//   env -u OCCTSWIFT_BRIDGE_PREBUILT OCCTSWIFT_LOCAL=1 swift build -c release
import PackageDescription

let package = Package(
    name: "combswift",
    platforms: [.macOS(.v12)],
    dependencies: [.package(path: "../../../..")],
    targets: [
        .executableTarget(
            name: "combswift",
            dependencies: [.product(name: "OCCTSwift", package: "fix-fillet-comb-chamfer")],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ])
