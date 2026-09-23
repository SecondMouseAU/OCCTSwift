import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// Before #1981 both tests asserted only non-nil and `isValid`, so a face built over the wrong UV
// range or radius passed. Each is now pinned to the area BRepLib_MakeFace gives in
// Scripts/repro/766-topology-breplib-builders/transcript.txt.
@Suite("BRepLib MakeFace")
struct BRepLibMakeFaceTests {
    @Test("Face from plane with UV bounds")
    func faceFromPlane() throws {
        let face = try #require(
            Shape.faceFromPlane(
                origin: SIMD3(0, 0, 0),
                normal: SIMD3(0, 0, 1),
                uRange: 0...10,
                vRange: 0...10
            ))
        #expect(face.isValid)
        let area = try #require(face.surfaceArea)
        #expect(abs(area - 100) < 1e-9, "area \(area)")
    }

    @Test("Face from cylinder with UV bounds")
    func faceFromCylinder() throws {
        let face = try #require(
            Shape.faceFromCylinder(
                origin: SIMD3(0, 0, 0),
                axis: SIMD3(0, 0, 1),
                radius: 5,
                uRange: 0...(.pi),
                vRange: 0...10
            ))
        #expect(face.isValid)
        // Half a radius-5 cylinder, 10 tall: 5 * pi * 10.
        let area = try #require(face.surfaceArea)
        #expect(abs(area - 50 * .pi) < 1e-9, "area \(area)")
    }
}
