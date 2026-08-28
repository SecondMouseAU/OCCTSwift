import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("projectWire with Wire, Issue #47") struct ProjectWireWithWireTests {
    @Test("projectWire accepts Wire directly")
    func projectWireFromWire() {
        let wire = Wire.circle(radius: 5)
        let target = Shape.box(width: 20, height: 20, depth: 20)
        if let wire, let target {
            let result = Shape.projectWire(wire, onto: target, direction: SIMD3(0, 0, 1))
            // Projection may or may not succeed depending on geometry
            _ = result
        }
    }

    @Test("projectWireConical accepts Wire directly")
    func projectWireConicalFromWire() {
        let wire = Wire.circle(radius: 3)
        let target = Shape.box(width: 20, height: 20, depth: 20)
        if let wire, let target {
            let result = Shape.projectWireConical(wire, onto: target, eye: SIMD3(0, 0, 50))
            _ = result
        }
    }
}
