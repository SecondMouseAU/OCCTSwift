import Testing
import simd

@testable import OCCTSwift

@Suite("Revolution from Curve")
struct RevolutionFromCurveTests {

    // #766: all three asserted only non-nil. Each now pins BRepPrimAPI_MakeRevolution's volume
    // (Scripts/repro/766-projection-trim-revolution-section/). KERNEL OBSERVATION: revolving the XZ-plane circle gives a solid whose
    // BRepGProp volume is NEGATIVE (-1776.53, the torus 2 pi^2 * 10 * 9 with reversed orientation),
    // which `Shape.volume` turns into nil; that nil and the area are pinned.
    @Test("Revolve segment into cylinder")
    func revolveSegment() {
        // Segment at x=5 from z=0 to z=10, revolve around Z axis → cylinder
        let seg = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10))!
        let solid = Shape.revolution(meridian: seg)
        #expect(solid != nil)
        // pi * 5^2 * 10
        #expect(abs((solid?.volume ?? 0) - 785.39816339744823) < 1e-6)
    }

    @Test("Revolve circle into torus-like shape")
    func revolveCircle() {
        // Circle at (10,0,0) in XZ plane, revolve around Z axis → torus
        let circle = Curve3D.circle(center: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 3)!
        let solid = Shape.revolution(meridian: circle)
        #expect(solid != nil)
        // The kernel's solid is inside out (BRepGProp volume -1776.53), and Shape.volume reports
        // a negative volume as nil, so a caller asking this torus for its volume gets nil.
        #expect(solid?.volume == nil)
        #expect(abs((solid?.surfaceArea ?? 0) - 1184.3525281307232) < 1e-6)
    }

    @Test("Partial revolution")
    func partialRevolution() {
        let seg = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10))!
        let solid = Shape.revolution(meridian: seg, angle: .pi / 2)
        #expect(solid != nil)
        // A quarter of the full cylinder.
        #expect(abs((solid?.volume ?? 0) - 196.34954084936206) < 1e-6)
    }
}
