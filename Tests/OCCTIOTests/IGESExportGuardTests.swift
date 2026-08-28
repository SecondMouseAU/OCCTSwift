import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("SEGV Guards, IGES export validation")
struct IGESExportGuardTests {

    @Test func validShapeExportsSuccessfully() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("igs")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try Exporter.writeIGES(shape: box, to: tmpURL)
        #expect(FileManager.default.fileExists(atPath: tmpURL.path))
    }
}
