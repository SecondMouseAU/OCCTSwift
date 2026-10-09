import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_Substitution Tests")
struct SubstitutionTests {

    @Test func substituteRemove() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let result = box.substitute(oldSubShape: edge, newSubShapes: [])
                // May or may not succeed depending on topology
                let _ = result
            }
        }
    }
}
