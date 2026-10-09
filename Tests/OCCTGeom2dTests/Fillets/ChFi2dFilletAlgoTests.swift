import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d FilletAlgo Tests")
struct ChFi2dFilletAlgoTests {
    @Test("Iterative 2D fillet between two line edges")
    func filletBetweenLines() throws {
        // #1979: isValid and `resultCount >= 1` passed a fillet of any radius. ChFi2d_FilletAlgo
        // gives one solution, a radius-2 quarter circle (length pi), and trims both edges back
        // to length 8 (Scripts/repro/766-geom2d-chfi2d-compbezier/).
        // Two edges meeting at origin
        let e1 = try #require(Wire.line(from: .zero, to: SIMD3(10, 0, 0)).flatMap { Shape.fromWire($0) })
        let e2 = try #require(Wire.line(from: .zero, to: SIMD3(0, 10, 0)).flatMap { Shape.fromWire($0) })
        let r = try #require(Shape.filletAlgo(edge1: e1, edge2: e2, radius: 2.0))
        #expect(r.fillet.isValid)
        #expect(r.resultCount == 1)
        let fillet = try #require(Edge(r.fillet))
        #expect(abs(fillet.length - Double.pi) < 1e-9)
        let t1 = try #require(Edge(r.edge1))
        let t2 = try #require(Edge(r.edge2))
        #expect(abs(t1.length - 8) < 1e-9)
        #expect(abs(t2.length - 8) < 1e-9)
    }
}
