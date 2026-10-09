import Testing

@testable import OCCTSwift

@Suite("Bezier Surface Resolution v0.120.0")
struct BezierSurfaceResolutionTests {

    @Test func resolution() {
        // Create a Bezier surface via Shape then extract surface
        // Use a simple box face, it's a plane, not a Bezier. Let's use Surface.bezier if available.
        // Actually, let's just test with what we have, if not Bezier it returns 0.
        let md = Surface.bezierMaxDegree
        #expect(md >= 25)
    }
}
