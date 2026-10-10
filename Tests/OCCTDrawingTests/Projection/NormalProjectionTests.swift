import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: both tests used to assert only that a projection came back (plus `isValid`), and
// force-unwrapped the line inside the call. Returning the unprojected line passed both. They now
// pin what BRepOffsetAPI_NormalProjection produces with the same parameters: the line pushed out
// along the sphere's normals onto its surface, split into two edges at the sphere's seam, measured
// in Scripts/repro/766-drawing-length-normalproj/transcript.txt.
@Suite("Normal Projection")
struct NormalProjectionTests {
    private func expectProjection(
        _ projected: Shape?, min: SIMD3<Double>, max: SIMD3<Double>, _ what: String
    ) {
        guard let projected, let bb = projected.boundingBox else {
            Issue.record("\(what): no projection")
            return
        }
        #expect(projected.isValid)
        #expect(projected.edges().count == 2, "\(what): \(projected.edges().count) edges")
        #expect(
            simd_length(bb.min - min) < 1e-6 && simd_length(bb.max - max) < 1e-6,
            "\(what): bounds \(bb.min) .. \(bb.max)")
    }

    @Test("Project line onto sphere near surface")
    func projectOnSphere() {
        // Line near the sphere surface (x=8, within radius 10)
        // Normal projection projects along surface normals, works when
        // the wire is near or outside the surface, not deep inside
        guard let sphere = Shape.sphere(radius: 10),
            let line = Wire.line(from: SIMD3(8, -2, 0), to: SIMD3(8, 2, 0)).flatMap({
                Shape.fromWire($0)
            })
        else {
            Issue.record("fixture failed")
            return
        }
        expectProjection(
            sphere.normalProjection(of: line),
            min: SIMD3(9.70142485, -2.4253564, -1.46871406e-07),
            max: SIMD3(10.0000001, 2.4253564, 1.46871406e-07), "inside")
    }

    @Test("Project line outside sphere")
    func projectOutsideSphere() {
        // Line fully outside the sphere
        guard let sphere = Shape.sphere(radius: 10),
            let line = Wire.line(from: SIMD3(15, -5, 0), to: SIMD3(15, 5, 0)).flatMap({
                Shape.fromWire($0)
            })
        else {
            Issue.record("fixture failed")
            return
        }
        expectProjection(
            sphere.normalProjection(of: line),
            min: SIMD3(9.48683264, -3.162278, -3.40436912e-07),
            max: SIMD3(10.0000003, 3.162278, 3.40436912e-07), "outside")
    }
}
