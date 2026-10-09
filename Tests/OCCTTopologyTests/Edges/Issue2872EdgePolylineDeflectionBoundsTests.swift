import Testing
import simd

@testable import OCCTSwift

/// #2872: `DiscretizeEdgeInto` (`Sources/OCCTBridge/src/OCCTBridge_Mesh.mm`) hands a caller-
/// supplied deflection to `GCPnts_TangentialDeflection`, whose own precondition on the pair,
/// `theCurvatureDeflection >= Precision::Confusion() && theAngularDeflection >=
/// Precision::Angular()`, is a `Standard_ConstructionError_Raise_if` in the `.cxx` and so is
/// compiled out of the pinned Release kernel (`okf/policies/occt-validation-is-compiled-out.md`).
///
/// PR #2870 guarded the four `GCPnts_TangentialDeflection` entry points in the Curve3D and Geom2d
/// bridge files; these two sit in `OCCTBridge_Mesh.mm`, which that PR did not own.
///
/// Without the guard the sampler subdivides until an internal million-point cap stops it, and the
/// bridge's `maxPoints` truncation then returns the leading fraction of the edge as if it were a
/// sampling of the whole: a fabricated measurement rather than a crash, which is why every case
/// here asserts a refusal value and not merely "does not crash".
///
/// The refusals are the ones each entry point already gives for a null shape or an unusable
/// capacity: `nil` from ``Shape/edgePolyline(at:deflection:maxPoints:)`` and an empty array from
/// ``Shape/allEdgePolylinesIndexed(deflection:maxPointsPerEdge:)``. Each test also asserts the
/// in-range sampling, so a guard that refuses everything fails too.
@Suite("#2872: edge polyline deflection bounds")
struct Issue2872EdgePolylineDeflectionBoundsTests {

    /// A full circle, so the sampler has real curvature to subdivide against.
    ///
    /// A straight edge needs two points at any deflection and would hide the defect entirely.
    private func circleEdgeShape() -> Shape? {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)
        else { return nil }
        return Shape.edgeFromCurve(circle)
    }

    /// Below `Precision::Confusion()` (1e-7) the request is out of bounds. `1e-9` is the case that
    /// matters most: it is a plausible "I want it fine" value, it is not obviously degenerate, and
    /// before the guard it returned a full `maxPoints` buffer covering a sliver of the circle.
    private let refusedDeflections: [Double] = [0.0, 1e-12, 1e-9, -1.0, Double.nan]

    @Test("edgePolyline samples in range and refuses a deflection under the kernel's own bound")
    func edgePolylineBounds() throws {
        let shape = try #require(circleEdgeShape())

        let good = try #require(shape.edgePolyline(at: 0, deflection: 0.1, maxPoints: 4000))
        #expect(good.count >= 2)
        // A valid request on a radius-10 circle needs nothing like the capacity; a count at the
        // ceiling is the visible symptom of the missing check.
        #expect(good.count < 1000)

        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be
        // written at all (swiftlang/swift#91639, see CLAUDE.md).
        for deflection in refusedDeflections {
            #expect(
                shape.edgePolyline(at: 0, deflection: deflection, maxPoints: 4000) == nil,
                "deflection: \(deflection) returned a polyline")
        }
    }

    @Test("allEdgePolylinesIndexed samples in range and refuses the same deflections")
    func allEdgePolylinesBounds() throws {
        let shape = try #require(circleEdgeShape())

        let good = shape.allEdgePolylinesIndexed(deflection: 0.1, maxPointsPerEdge: 4000)
        #expect(good.count == 1)
        if let first = good.first {
            #expect(first.points.count >= 2)
            #expect(first.points.count < 1000)
        }

        for deflection in refusedDeflections {
            #expect(
                shape.allEdgePolylinesIndexed(deflection: deflection, maxPointsPerEdge: 4000)
                    .isEmpty,
                "deflection: \(deflection) returned polylines")
        }
    }
}
