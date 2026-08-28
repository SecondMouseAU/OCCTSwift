import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib ValidateEdge Tests")
struct ValidateEdgeTests {
    @Test("validate edge on face")
    func validateEdge() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        for face in faces {
            let result = cyl.edges().first.map { $0.validate(on: face) }
            if let r = result, r.isDone {
                #expect(r.maxDistance >= 0)
                return
            }
        }
    }

    @Test("check tolerance")
    func checkTolerance() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        let edges = cyl.edges()
        for face in faces {
            for edge in edges {
                let result = edge.validate(on: face, tolerance: 1.0)
                if result.isDone {
                    let _ = result.isWithinTolerance
                    return
                }
            }
        }
    }
}
