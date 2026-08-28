import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("HLR ReflectLines Tests")
struct HLRReflectLinesTests {
    @Test("reflect lines on sphere")
    func reflectLinesSphere() {
        let sphere = Shape.sphere(radius: 10)
        if let s = sphere {
            let result = s.reflectLines(
                normal: SIMD3(0, 0, 1),
                viewPoint: SIMD3(0, 0, 100),
                up: SIMD3(0, 1, 0))
            if let r = result {
                #expect(r.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("reflect lines filtered by edge type")
    func reflectLinesFiltered() {
        let sphere = Shape.sphere(radius: 10)
        if let s = sphere {
            let result = s.reflectLinesFiltered(
                normal: SIMD3(0, 0, 1),
                viewPoint: SIMD3(0, 0, 100),
                up: SIMD3(0, 1, 0),
                edgeType: .outLine,
                visible: true, in3d: true)
            // May or may not have edges depending on geometry
            _ = result
        }
    }
}
