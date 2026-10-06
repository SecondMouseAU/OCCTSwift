// swift-tools-version: 6.1
//
// #3079's probe: a SEPARATE package depending on OCCTSwift by path, so it adds nothing to the
// root manifest. Build and run it through ../run.sh (one case per process).
import PackageDescription

let package = Package(
    name: "probe",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "OCCTSwift", path: "../../../..")],
    targets: [
        .executableTarget(
            name: "probe",
            dependencies: [.product(name: "OCCTSwift", package: "OCCTSwift")],
            swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
