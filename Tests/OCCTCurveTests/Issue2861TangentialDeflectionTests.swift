import Testing
import simd

@testable import OCCTSwift

/// #2861 finding 4: `GCPnts_TangentialDeflection::initialize` states its precondition,
/// `theCurvatureDeflection >= Precision::Confusion() && theAngularDeflection >=
/// Precision::Angular()`, as a `Standard_ConstructionError_Raise_if` in a template defined in the
/// `.cxx`, so the pinned Release kernel compiles it to nothing. Without it the sampler subdivides
/// until an internal million-point cap stops it: measured on a half-circle edge,
/// `curvatureDeflection: 0` reported `NbPoints() == 1000001` where a valid request gives 33, and the
/// bridge's 10,000-point truncation then handed Swift 1.00% of the arc with no error signal.
///
/// The refusal is an empty result, which is what these entry points already return for a null handle
/// or an unusable capacity. Each test also asserts the in-range sampling, so a guard that refuses
/// everything fails too.
///
/// `OCCTGCPntsTangentialDeflectionCurve`, the standalone-curve twin, carries the same guard but has
/// no Swift caller today, so it is exercised only through the bridge's own C API.
@Suite("#2861 — tangential deflection bounds")
struct Issue2861TangentialDeflectionTests {

    private func curvedEdge() -> Edge? {
        Shape.sphere(radius: 10)?.edges().first
    }

    @Test("Edge.tangentialDeflectionPoints samples with valid deflections and refuses tiny ones")
    func edgeSampling() {
        guard let edge = curvedEdge() else {
            Issue.record("could not take a curved edge off a sphere")
            return
        }
        let good = edge.tangentialDeflectionPoints()
        #expect(good.count >= 2)
        // A valid request needs nothing like the 10,000-point ceiling, so a count at the ceiling is
        // the visible symptom of the missing check.
        #expect(good.count < 1000)
        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be written
        // at all (swiftlang/swift#91639, see CLAUDE.md).
        for curvature in [0.0, 1e-12, -1.0, Double.nan] {
            #expect(
                edge.tangentialDeflectionPoints(curvatureDeflection: curvature).isEmpty,
                "curvatureDeflection: \(curvature) returned points")
        }
        for angular in [0.0, -1.0, Double.nan] {
            #expect(
                edge.tangentialDeflectionPoints(angularDeflection: angular).isEmpty,
                "angularDeflection: \(angular) returned points")
        }
    }

    @Test("Curve3D.drawAdaptive samples with valid deflections and refuses tiny ones")
    func curve3DDrawAdaptive() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10) else {
            Issue.record("Curve3D.circle returned nil")
            return
        }
        let good = circle.drawAdaptive()
        #expect(good.count >= 2)
        #expect(good.count < 1000)
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
