import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_Poly")
struct PolyhedralDistanceTests {
    @Test("Polyhedral distance between two shapes")
    func polyDist() throws {
        let s1 = try #require(Shape.sphere(radius: 5.0))
        _ = s1.mesh(linearDeflection: 0.1)
        let s2 = try #require(Shape.sphere(radius: 5.0)?.translated(by: SIMD3(20, 0, 0)))
        _ = s2.mesh(linearDeflection: 0.1)
        let result = try #require(s1.polyhedralDistance(to: s2))
        // Spheres centered 20 apart, each radius 5 → distance ~10
        #expect(result.distance > 8.0)
        #expect(result.distance < 12.0)
    }
}
