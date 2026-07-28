import Testing
import simd
@testable import OCCTSwift

/// #403: `Surface.knotSplitting` used to report only `uSplitCount`/`vSplitCount` even though
/// the underlying `GeomConvert_BSplineSurfaceKnotSplitting` analyzer always computed the split
/// *locations* too (`USplitValue`/`VSplitValue`) -- strictly weaker than its `Curve3D`/
/// `LawFunction` siblings, which both surface real parameter values. `uSplitParams`/
/// `vSplitParams` are additive fields on `KnotSplitResult`, so the existing count fields and
/// the function's signature are unchanged.
@Suite("Surface knot splitting parameters (#403)")
struct Issue403SurfaceKnotSplitParamsTests {

    /// Trimmed cylinder converted to BSpline -- bounded, so the conversion succeeds, and
    /// periodic in U, which guarantees more than the two bracketing splits in that direction.
    private func bsplineCylinder() throws -> Surface {
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        return try #require(trimCyl.toBSpline())
    }

    @Test("Param array lengths match their own counts")
    func paramCountsMatchSplitCounts() throws {
        let bspline = try bsplineCylinder()
        let result = bspline.knotSplitting(uContinuity: 0, vContinuity: 0)

        #expect(result.uSplitParams.count == result.uSplitCount)
        #expect(result.vSplitParams.count == result.vSplitCount)
        #expect(result.uSplitCount >= 1)
        #expect(result.vSplitCount >= 1)
    }

    @Test("Params are ascending and bracketed by the surface's own U/V domain")
    func paramsMatchDomain() throws {
        let bspline = try bsplineCylinder()
        let result = bspline.knotSplitting(uContinuity: 0, vContinuity: 0)
        let domain = bspline.domain

        if let uFirst = result.uSplitParams.first, let uLast = result.uSplitParams.last {
            #expect(abs(uFirst - domain.uMin) < 1e-6)
            #expect(abs(uLast - domain.uMax) < 1e-6)
        }
        if let vFirst = result.vSplitParams.first, let vLast = result.vSplitParams.last {
            #expect(abs(vFirst - domain.vMin) < 1e-6)
            #expect(abs(vLast - domain.vMax) < 1e-6)
        }
        #expect(zip(result.uSplitParams, result.uSplitParams.dropFirst()).allSatisfy { $0 < $1 })
        #expect(zip(result.vSplitParams, result.vSplitParams.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Non-BSpline surface returns empty params, not a crash")
    func nonBSplineSurfaceReturnsEmpty() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let result = plane.knotSplitting(uContinuity: 0, vContinuity: 0)
        #expect(result.uSplitCount == 0)
        #expect(result.vSplitCount == 0)
        #expect(result.uSplitParams.isEmpty)
        #expect(result.vSplitParams.isEmpty)
    }
}
