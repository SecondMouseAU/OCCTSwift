import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomInt IntSS")
struct GeomIntIntSSTests {
    @Test("Plane-cylinder intersection")
    func planeCylinderIntersection() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        guard let box = Shape.box(width: 30, height: 30, depth: 1) else { return }
        let cylFaces = cyl.subShapes(ofType: .face)
        let boxFaces = box.subShapes(ofType: .face)
        guard !cylFaces.isEmpty, !boxFaces.isEmpty else { return }
        // Try each pair until we find one with intersection curves
        for cf in cylFaces {
            for bf in boxFaces {
                if let result = Shape.surfaceSurfaceIntersection(face1: cf, face2: bf) {
                    if result.curveCount > 0 {
                        let curve = result.curve(1)
                        #expect(curve != nil)
                        return
                    }
                }
            }
        }
    }
}
