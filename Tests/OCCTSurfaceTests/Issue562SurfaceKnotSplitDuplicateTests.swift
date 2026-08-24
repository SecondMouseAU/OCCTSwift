import Testing
import simd

@testable import OCCTSwift

/// #562: `GeomConvert_BSplineSurfaceKnotSplitting` was wrapped twice, by `Surface.knotSplitting`
/// and by the v0.105.0 `bsplineKnotSplitsU`/`bsplineKnotSplitsV`/`bsplineKnotSplitValues` trio.
/// The trio carried one thing the canonical call did not: the raw knot-table indices, where the
/// canonical call reported only the parameters it had converted them into. So the canonical result
/// now carries the indices too, and the trio forwards to it, one analyzer construction per query
/// instead of the three `bsplineKnotSplitValues` needed.
@Suite("Surface knot-splitting duplicates (#562)")
struct Issue562SurfaceKnotSplitDuplicateTests {

    private func bsplineSphere() -> Surface? {
        Surface.sphere(center: .zero, radius: 5)?.toBSpline()
    }

    /// The indices are the analyzer's own output and the parameters are `UKnot`/`VKnot` of them,
    /// so this identity is what makes the deprecated trio's index form redundant rather than lost.
    @Test("Split indices resolve through the knot table to exactly the split parameters")
    func indicesResolveToParams() throws {
        let surface = try #require(bsplineSphere())
        for continuity: ParametricContinuity in ParametricContinuity.allCases {
            let result = surface.knotSplitting(uContinuity: continuity, vContinuity: continuity)
            #expect(result.uSplitIndices.count == result.uSplitCount, "u count at \(continuity)")
            #expect(result.vSplitIndices.count == result.vSplitCount, "v count at \(continuity)")
            #expect(
                result.uSplitIndices.map { surface.bsplineUKnot(index: $0) } == result.uSplitParams,
                "u indices at \(continuity)")
            #expect(
                result.vSplitIndices.map { surface.bsplineVKnot(index: $0) } == result.vSplitParams,
                "v indices at \(continuity)")
        }
    }

    /// Indices are 1-based into the surface's own knot table, and the first and last knots are
    /// always split points, so the set always brackets the whole table. Absolute bounds, checked
    /// against the knot table rather than against the other spelling.
    @Test("Indices are 1-based and bracket the surface's own knot table")
    func indicesAreOneBasedAndBracketing() throws {
        let surface = try #require(bsplineSphere())
        let uKnots = surface.bsplineUKnots()
        let vKnots = surface.bsplineVKnots()
        let result = surface.knotSplitting(uContinuity: .c1, vContinuity: .c1)

        #expect(result.uSplitIndices.first == 1)
        #expect(result.uSplitIndices.last == uKnots.count)
        #expect(result.vSplitIndices.first == 1)
        #expect(result.vSplitIndices.last == vKnots.count)
        #expect(result.uSplitIndices == result.uSplitIndices.sorted())
        #expect(result.vSplitIndices == result.vSplitIndices.sorted())
    }

    /// The question the deprecated trio structurally could not ask: one continuity per parametric
    /// direction. Each direction's answer must depend on its own continuity and not the other's.
    @Test("U and V answer their own continuity independently")
    func directionsAreIndependent() throws {
        let surface = try #require(bsplineSphere())
        let both = surface.knotSplitting(uContinuity: .c3, vContinuity: .c3)
        let uOnly = surface.knotSplitting(uContinuity: .c3, vContinuity: .c0)
        let vOnly = surface.knotSplitting(uContinuity: .c0, vContinuity: .c3)
        let neither = surface.knotSplitting(uContinuity: .c0, vContinuity: .c0)

        #expect(uOnly.uSplitCount == both.uSplitCount)
        #expect(uOnly.vSplitCount == neither.vSplitCount)
        #expect(vOnly.vSplitCount == both.vSplitCount)
        #expect(vOnly.uSplitCount == neither.uSplitCount)
        // .c0 short-circuits to the two bracketing knots, so this is a real difference to detect.
        #expect(neither.uSplitCount == 2)
        #expect(neither.vSplitCount == 2)
        #expect(both.uSplitCount > 2)
    }

    /// A plane is not a BSpline surface, so `knotSplitting()` reports nothing rather than crashing
    /// on the buffers it was about to size from a count it never got.
    @Test("A non-BSpline surface reports no splits at all")
    func nonBSplineSurface() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let result = plane.knotSplitting()
        #expect(result.uSplitCount == 0)
        #expect(result.uSplitIndices.isEmpty)
        #expect(result.vSplitIndices.isEmpty)
    }
}
