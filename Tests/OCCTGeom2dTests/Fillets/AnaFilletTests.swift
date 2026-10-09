import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d_AnaFilletAlgo")
struct AnaFilletTests {
    @Test("Analytical fillet between two edges in XY plane")
    func anaFillet() throws {
        // Create two line edges sharing a vertex at origin
        let wire1 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let wire2 = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(0, 10, 0)))
        let edge1 = try #require(Shape.fromWire(wire1))
        let edge2 = try #require(Shape.fromWire(wire2))
        let result = Shape.anaFillet(
            edge1: edge1,
            edge2: edge2,
            planeOrigin: SIMD3(0, 0, 0),
            planeNormal: SIMD3(0, 0, 1),
            radius: 2.0
        )
        #expect(result != nil)
        if let r = result {
            #expect(r.fillet.isValid)
            #expect(r.edge1.isValid)
            #expect(r.edge2.isValid)
        }
    }
}
