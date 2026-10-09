// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: "probe3130",
    platforms: [.macOS(.v12)],
    dependencies: [.package(name: "OCCTSwift", path: "../../..")],
    targets: [
        .executableTarget(
            name: "probe",
            dependencies: [.product(name: "OCCTSwift", package: "OCCTSwift")],
            swiftSettings: [.swiftLanguageMode(.v5)])
    ])
