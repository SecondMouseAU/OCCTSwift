// swift-tools-version: 6.1
//
// #2048's consumer: the stand-in for #1689's JavaScriptKit application.
//
// It reaches the stub the way that application would reach OCCTSwift, as a package dependency,
// and the ONLY thing that varies between the cases is how. `STUB_PACKAGE_URL` names a git
// repository and takes the versioned path, which is the one SwiftPM refuses `.unsafeFlags` on;
// `STUB_PACKAGE_PATH` names a directory and takes the path-dependency path, which it does not.
//
// Nothing here carries a build setting of any kind. That is the point: whatever the wasm build
// needs has to arrive from the dependency's own safe settings or from the toolset, because a
// consumer of a published package has nowhere else to put it.
import Foundation
import PackageDescription

let env = ProcessInfo.processInfo.environment

let dependency: Package.Dependency = {
    if let url = env["STUB_PACKAGE_URL"], !url.isEmpty {
        return .package(url: url, from: "1.0.0")
    }
    guard let path = env["STUB_PACKAGE_PATH"], !path.isEmpty else {
        fatalError("Set STUB_PACKAGE_URL or STUB_PACKAGE_PATH. Build this through ../run.sh.")
    }
    return .package(path: path)
}()

let package = Package(
    name: "consumer",
    dependencies: [dependency],
    targets: [
        .executableTarget(
            name: "consumer",
            dependencies: [.product(name: "StubOCCT", package: "StubOCCT")]
        ),
    ]
)
