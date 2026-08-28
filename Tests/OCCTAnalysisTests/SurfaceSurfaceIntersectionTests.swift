import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface-Surface Intersection")
struct SurfaceSurfaceIntersectionTests {
    @Test("Two planes intersect in a line")
    func twoPlanes() {
        let p1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let p2 = Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0))!
        let curves = p1.intersections(with: p2)
        #expect(curves.count >= 1)
    }
}
