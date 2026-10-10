import Testing

@testable import OCCTSwift

/// #2861 finding 4, the 2D half: `OCCTCurve2DDrawAdaptive` reaches the same
/// `GCPnts_TangentialDeflection` whose deflection precondition the pinned Release kernel compiles
/// out.
///
/// The refusal is an empty result, which is what this entry point already returns for a null
/// curve or a capacity of zero.
@Suite("#2861: Curve2D.drawAdaptive deflection bounds")
struct Issue2861Curve2DDrawAdaptiveTests {

    @Test("drawAdaptive samples with valid deflections and refuses tiny ones")
    func drawAdaptiveBounds() {
        guard let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 10) else {
            Issue.record("Curve2D.circle returned nil")
            return
        }
        let good = circle.drawAdaptive()
        #expect(good.count >= 2)
        #expect(good.count < 1000)
        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be written
        // at all (swiftlang/swift#91639, see CLAUDE.md).
        for chordal in [0.0, 1e-12, -1.0, Double.nan] {
            #expect(
                circle.drawAdaptive(chordalDeflection: chordal).isEmpty,
                "chordalDeflection: \(chordal) returned points")
        }
        for angular in [0.0, -1.0, Double.nan] {
            #expect(
                circle.drawAdaptive(angularDeflection: angular).isEmpty,
                "angularDeflection: \(angular) returned points")
        }
    }
}
