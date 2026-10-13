import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Drop Small Edges")
struct DropSmallEdgesTests {
    @Test("Drop small edges on clean box")
    func cleanBoxNoChange() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = box.droppingSmallEdges(tolerance: 1e-6)
        #expect(result != nil)
        if let r = result {
            // Clean box should keep same topology
            #expect(r.edges().count == box.edges().count)
        }
    }

    @Test("Drop small edges with larger tolerance")
    func largerTolerance() throws {
        // A clean box has no edge under 0.001: topology and volume are unchanged.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.droppingSmallEdges(tolerance: 0.001))
        #expect(result.edgeCount == 12)
        #expect(result.faceCount == 6)
        #expect(abs(try #require(result.volume) - 1000) < 1e-6)

        // A pentagon with one 1e-4 side loses it at 0.001 and keeps it at 1e-6: five edges
        // become four, the surviving square is 10 x 10 (area 100.001, the sliver's triangle).
        let polygon = try #require(
            Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(10.0001, 10, 0),
                    SIMD3(0, 10, 0),
                ], closed: true))
        let face = try #require(Shape.face(from: polygon))
        #expect(face.edgeCount == 5)
        let dropped = try #require(face.droppingSmallEdges(tolerance: 0.001))
        #expect(dropped.edgeCount == 4)
        #expect(abs(try #require(dropped.surfaceArea) - 100.001) < 1e-6)
        let kept = try #require(face.droppingSmallEdges(tolerance: 1e-6))
        #expect(kept.edgeCount == 5)
        // The receiver is not edited in place.
        #expect(face.edgeCount == 5)
    }

    @Test("Drop small edges API callable")
    func apiCallable() throws {
        // The sphere's seam and two pole edges are not small: three edges survive at the
        // default 1e-7 tolerance, the surface area stays 100 pi, and the result is valid.
        let sphere = try #require(Shape.sphere(radius: 5))
        let result = try #require(sphere.droppingSmallEdges())
        #expect(result.isValid)
        #expect(result.faceCount == 1)
        #expect(result.edgeCount == 3)
        #expect(abs(try #require(result.surfaceArea) - 100 * .pi) < 1e-9)
        #expect(abs(try #require(result.volume) - 4.0 / 3.0 * .pi * 125) < 1e-9)
    }
}
