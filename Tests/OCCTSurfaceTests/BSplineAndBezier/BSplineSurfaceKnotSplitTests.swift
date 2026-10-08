import Testing

@testable import OCCTSwift

@Suite("BSplineSurface KnotSplitting Tests")
struct BSplineSurfaceKnotSplitTests {

    @Test func knotSplitsU() {
        // Create a sphere surface and convert to BSpline
        if let sphere = Surface.sphere(center: .zero, radius: 5) {
            if let bsp = sphere.toBSpline() {
                // #562: was bsplineKnotSplitsU, now deprecated onto this one analyzer call.
                let n = bsp.knotSplitting(uContinuity: .c0, vContinuity: .c0).uSplitCount
                #expect(n >= 0)
            }
        }
    }
}
