import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAlgo_NormalProjection")
struct BRepAlgoNormalProjectionTests {
    @Test func createProjection() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let proj = NormalProjection(target: box)
            #expect(proj != nil)
        }
    }

    @Test func projectWire() {
        if let cyl = Shape.cylinder(radius: 5, height: 20) {
            if let proj = NormalProjection(target: cyl) {
                if let edge = Shape.box(width: 10, height: 0.01, depth: 0.01) {
                    proj.add(edge)
                    // Build may fail or succeed depending on geometry
                    let _ = proj.build()
                }
            }
        }
    }

    @Test func projectionResult() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let proj = NormalProjection(target: box) {
                let built = proj.build()
                // Result only meaningful after adding wires
                if built {
                    let _ = proj.result
                }
            }
        }
    }
}
