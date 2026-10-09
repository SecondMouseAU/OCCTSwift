import Testing
import simd

@testable import OCCTSwift

@Suite("Loft Vertex Endpoints")
struct LoftVertexEndpointTests {
    @Test("Cone: circle lofted to vertex point")
    func coneFromCircle() {
        let circle = Wire.circle(radius: 5)!
        let cone = Shape.loft(
            profiles: [circle], solid: true, ruled: true,
            lastVertex: SIMD3(0, 0, 10))
        #expect(cone != nil)
        if let c = cone {
            #expect(c.isValid)
            #expect(c.volume! > 0)
        }
    }

    @Test("Bicone: vertex-circle-vertex")
    func bicone() {
        let circle = Wire.circle(radius: 10)!
        let bicone = Shape.loft(
            profiles: [circle], solid: true, ruled: true,
            firstVertex: SIMD3(0, 0, -20),
            lastVertex: SIMD3(0, 0, 20))
        #expect(bicone != nil)
    }

    @Test("Smooth cone tapering to point")
    func smoothCone() {
        let circle = Wire.circle(radius: 5)!
        let shape = Shape.loft(
            profiles: [circle], solid: true, ruled: false,
            lastVertex: SIMD3(0, 0, 10))
        #expect(shape != nil)
    }
}
