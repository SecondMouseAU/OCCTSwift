import Testing
import simd
@testable import OCCTSwift

/// #620. Three layers disagreed about `drawMesh`'s minimum count, and the caller paid.
///
/// The doc comment and the `Sampling.gridTotal` guard both said 1; the bridge said 2 and returned
/// 0 for anything less, which the wrapper's `guard n == total` turned into `SurfaceGrid.empty`.
/// So `drawMesh(uCount: 1, vCount: 20)` — in range by its own documentation — came back empty,
/// indistinguishable from a surface that genuinely failed to sample.
///
/// Measured before choosing a side, because the doc was written asserting 1 works and somebody
/// believed it. `OCCTSurfaceDrawMesh` is not a mesher: no `BRepMesh`, no triangulation, no quad,
/// just a uniform walk of the parametric bounds calling `Geom_Surface::D0`, and a single `(u, v)`
/// is a valid OCCT evaluation. The 2 was the function's own divisor — `i / (uCount - 1)` divides
/// by zero at count 1 — and the resulting NaN parameter is worse than a throw, since `D0` does not
/// throw on NaN, it returns NaN coordinates. `OCCTSurfaceDrawGrid`, sampling the same bounds forty
/// lines above in the same file, had always spelled that divisor defensively. So the bridge was
/// the wrong layer, and the doc and the Swift guard were right.
///
/// The tests below therefore assert the *documented* contract: 1 is servable, and it is servable
/// with the same points the surface reports on its own.
@Suite("drawMesh honours its documented minimum of one sample per direction (#620)")
struct Issue620DrawMeshCountContractTests {

    static func sphere() -> Surface? { Surface.sphere(center: .zero, radius: 10) }

    static func isFinite(_ p: SIMD3<Double>) -> Bool {
        p.x.isFinite && p.y.isFinite && p.z.isFinite
    }

    // MARK: - The two reported requests

    @Test("uCount 1 returns a single V iso-row, not an empty grid")
    func singleURow() {
        guard let s = Self.sphere() else { return }
        let grid = s.drawMesh(uCount: 1, vCount: 20)

        // The defect: this was SurfaceGrid.empty.
        #expect(!grid.isEmpty)
        #expect(grid.uCount == 1)
        #expect(grid.vCount == 20)

        // Every point finite, i.e. the divisor did not go through 0/0.
        for v in 0..<grid.vCount {
            #expect(Self.isFinite(grid.at(u: 0, v: v)))
        }
    }

    @Test("vCount 1 returns a single U iso-row, not an empty grid")
    func singleVRow() {
        guard let s = Self.sphere() else { return }
        let grid = s.drawMesh(uCount: 20, vCount: 1)

        #expect(!grid.isEmpty)
        #expect(grid.uCount == 20)
        #expect(grid.vCount == 1)

        for u in 0..<grid.uCount {
            #expect(Self.isFinite(grid.at(u: u, v: 0)))
        }
    }

    // MARK: - The row is the right row

    /// Finiteness alone would pass on any arbitrary parameter. This pins *which* iso-row a
    /// one-sample direction means: the one at the domain minimum, cross-checked against the
    /// surface's own point evaluation rather than against another grid call.
    @Test("The single row sits at the domain minimum and matches point(atU:v:)")
    func singleRowSitsAtTheDomainMinimum() {
        guard let s = Self.sphere() else { return }
        let d = s.domain
        let vCount = 8
        let grid = s.drawMesh(uCount: 1, vCount: vCount)
        guard grid.vCount == vCount else {
            #expect(Bool(false), "expected \(vCount) V samples, got \(grid.vCount)")
            return
        }

        for j in 0..<vCount {
            let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(vCount - 1)
            let expected = s.point(atU: d.uMin, v: v)
            let got = grid.at(u: 0, v: j)
            #expect(simd_distance(got, expected) < 1e-9)
        }
    }

    /// The same row, reached the other way: row 0 of a multi-row grid is also the `uMin` row, and
    /// its V samples are spaced identically. A one-row grid must agree with it point for point.
    @Test("A one-row grid equals row 0 of a many-row grid")
    func oneRowEqualsRowZeroOfAManyRowGrid() {
        guard let s = Self.sphere() else { return }
        let vCount = 12
        let one = s.drawMesh(uCount: 1, vCount: vCount)
        let many = s.drawMesh(uCount: 6, vCount: vCount)
        guard one.vCount == vCount, many.vCount == vCount, many.uCount == 6 else {
            #expect(Bool(false), "grids not served: \(one.uCount)x\(one.vCount), \(many.uCount)x\(many.vCount)")
            return
        }

        for j in 0..<vCount {
            #expect(simd_distance(one.at(u: 0, v: j), many.at(u: 0, v: j)) < 1e-9)
        }
    }

    @Test("A 1x1 grid is one point, at the domain corner")
    func oneByOneIsASinglePoint() {
        guard let s = Self.sphere() else { return }
        let grid = s.drawMesh(uCount: 1, vCount: 1)
        #expect(!grid.isEmpty)
        #expect(grid.uCount == 1)
        #expect(grid.vCount == 1)

        let d = s.domain
        #expect(simd_distance(grid.at(u: 0, v: 0), s.point(atU: d.uMin, v: d.vMin)) < 1e-9)
    }

    /// An unbounded surface takes the bridge's infinite-bounds clamp before the divisor, so it
    /// exercises a different pair of endpoints. It must still serve one row.
    @Test("A surface with infinite bounds also serves a one-sample direction")
    func infiniteBoundsSurfaceServesOneRow() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else { return }
        let grid = plane.drawMesh(uCount: 1, vCount: 5)
        #expect(!grid.isEmpty)
        #expect(grid.uCount == 1)
        #expect(grid.vCount == 5)
        for v in 0..<grid.vCount {
            #expect(Self.isFinite(grid.at(u: 0, v: v)))
        }
    }

    // MARK: - The bound moved to 1, it did not disappear

    /// #558's bounds are still in force. Lowering the minimum to 1 must not readmit 0, a negative,
    /// or a product past the ceiling — those stay rejected at the Swift boundary, before any
    /// allocation, and rejection is still the documented empty grid.
    @Test("Counts below 1 and products past the ceiling are still rejected")
    func belowOneAndPastTheCeilingStillRejected() {
        guard let s = Self.sphere() else { return }

        #expect(s.drawMesh(uCount: 0, vCount: 20).isEmpty)
        #expect(s.drawMesh(uCount: 20, vCount: 0).isEmpty)
        #expect(s.drawMesh(uCount: -1, vCount: 20).isEmpty)
        #expect(s.drawMesh(uCount: 20, vCount: -1).isEmpty)
        // Two negatives multiply to a plausible positive total; each factor is checked on its own.
        #expect(s.drawMesh(uCount: -1, vCount: -1).isEmpty)
        // Past Sampling.maximumSampleCount as a product, with both factors individually in range.
        #expect(s.drawMesh(uCount: 5000, vCount: 2001).isEmpty)
        #expect(s.drawMesh(uCount: Int.max, vCount: Int.max).isEmpty)
    }

    // MARK: - The sibling site keeps its 2

    /// `OCCTSurfaceCreateBezier` carries a visually identical `uCount < 2 || vCount < 2`, but that
    /// one is the kernel's rule, not a divisor: a Bezier's degree is poles - 1 and must be >= 1, so
    /// `Geom_BezierSurface` raises on a single-pole direction. Measured against the kernel, and
    /// pinned here so the two look-alike guards are not "made consistent" in some later sweep.
    @Test("Bezier keeps its minimum of two poles per direction, which is OCCT's own")
    func bezierKeepsItsTwoPoleMinimum() {
        // One pole in U: rejected.
        #expect(Surface.bezier(poles: [[SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 2, 0)]]) == nil)
        // One pole in V: rejected.
        #expect(Surface.bezier(poles: [[SIMD3(0, 0, 0)], [SIMD3(1, 0, 0)]]) == nil)
        // The smallest legal patch: accepted.
        #expect(Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
        ]) != nil)
    }
}
