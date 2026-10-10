import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: the first test used to nest its only assertion (`count > 0`) in `if let sphere` and
// `if let result`, and the second discarded its result with no assertion at all, so a nil
// result, or reflect lines computed along the wrong axes, passed both. They now pin what
// HLRAppli_ReflectLines produces for the same sphere and axes: the silhouette circle of radius
// 10 in the z = 0 plane, one edge, measured in
// Scripts/repro/766-drawing-reflect-1036-1059/transcript.txt.
@Suite("HLR ReflectLines Tests")
struct HLRReflectLinesTests {
    private func expectSilhouetteCircle(_ shape: Shape?, _ what: String) {
        guard let shape, let bb = shape.boundingBox else {
            Issue.record("\(what): no result")
            return
        }
        #expect(shape.subShapes(ofType: .edge).count == 1, "\(what): edge count")
        #expect(
            simd_length(bb.min - SIMD3(-10.0000001, -10.0000001, -1e-7)) < 1e-6
                && simd_length(bb.max - SIMD3(10.0000001, 10.0000001, 1e-7)) < 1e-6,
            "\(what): bounds \(bb.min) .. \(bb.max)")
    }

    @Test("reflect lines on sphere")
    func reflectLinesSphere() {
        guard let sphere = Shape.sphere(radius: 10) else {
            Issue.record("sphere fixture failed")
            return
        }
        expectSilhouetteCircle(
            sphere.reflectLines(
                normal: SIMD3(0, 0, 1),
                viewPoint: SIMD3(0, 0, 100),
                up: SIMD3(0, 1, 0)),
            "reflectLines")
    }

    @Test("reflect lines filtered by edge type")
    func reflectLinesFiltered() {
        guard let sphere = Shape.sphere(radius: 10) else {
            Issue.record("sphere fixture failed")
            return
        }
        // A sphere's reflect lines are all outline: the visible 3D outline is the same circle.
        expectSilhouetteCircle(
            sphere.reflectLinesFiltered(
                normal: SIMD3(0, 0, 1),
                viewPoint: SIMD3(0, 0, 100),
                up: SIMD3(0, 1, 0),
                edgeType: .outLine,
                visible: true, in3d: true),
            "reflectLinesFiltered")
    }
}
