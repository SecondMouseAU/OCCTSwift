// swift-tools-version: 6.0
import PackageDescription

// What valvegear would write today. A BRANCH dependency, because no release carries the wasm path.
let package = Package(
    name: "ValveGearProbe",
    dependencies: [
        .package(url: "https://github.com/SecondMouseAU/OCCTSwift.git", branch: "main")
    ],
    targets: [
        .executableTarget(name: "ValveGearProbe", dependencies: [.product(name: "OCCTSwift", package: "OCCTSwift")])
    ]
)
