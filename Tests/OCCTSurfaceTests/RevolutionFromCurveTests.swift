import Testing
import simd

@testable import OCCTSwift

@Suite("Revolution from Curve")
struct RevolutionFromCurveTests {
    @Test("Revolve segment into cylinder")
    func revolveSegment() {
        // Segment at x=5 from z=0 to z=10, revolve around Z axis → cylinder
        let seg = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10))!
        let solid = Shape.revolution(meridian: seg)
        #expect(solid != nil)
    }

    @Test("Revolve circle into torus-like shape")
    func revolveCircle() {
        // Circle at (10,0,0) in XZ plane, revolve around Z axis → torus
        let circle = Curve3D.circle(center: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 3)!
        let solid = Shape.revolution(meridian: circle)
        #expect(solid != nil)
    }

    @Test("Partial revolution")
    func partialRevolution() {
        let seg = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10))!
        let solid = Shape.revolution(meridian: seg, angle: .pi / 2)
        #expect(solid != nil)
    }
}
