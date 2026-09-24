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
        // #1979: isValid alone passed a fillet of any radius. The fillet is the quarter circle of
        // radius 2 centred at (2, 2), so its length is pi, and edge1 is trimmed back to
        // (2, 0)-(10, 0). Values from ChFi2d_AnaFilletAlgo, Scripts/repro/766-geom2d-aht-axisplacement/.
        let r = try #require(result)
        #expect(r.fillet.isValid)
        #expect(r.edge1.isValid)
        #expect(r.edge2.isValid)
        let fillet = try #require(Edge(r.fillet))
        #expect(abs(fillet.length - Double.pi) < 1e-9)
        let trimmed1 = try #require(Edge(r.edge1))
        #expect(abs(trimmed1.length - 8.0) < 1e-9)
    }
}
