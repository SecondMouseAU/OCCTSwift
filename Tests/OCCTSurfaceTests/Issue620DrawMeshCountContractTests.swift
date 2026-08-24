import Testing
import simd

@testable import OCCTSwift

/// #620. Three layers disagreed about `drawMesh`'s minimum count, and the caller paid.
///
/// The doc comment and the `Sampling.gridTotal` guard both said 1; the bridge said 2 and returned
/// 0 for anything less, which the wrapper's `guard n == total` turned into `SurfaceGrid.empty`.
/// So `drawMesh(uCount: 1, vCount: 20)`, in range by its own documentation, came back empty,
/// indistinguishable from a surface that genuinely failed to sample.
///
/// Measured before choosing a side, because the doc was written asserting 1 works and somebody
/// believed it. `OCCTSurfaceDrawMesh` is not a mesher: no `BRepMesh`, no triangulation, no quad,
/// just a uniform walk of the sampled range calling `Geom_Surface::D0`, and a single `(u, v)` is
/// a valid OCCT evaluation. The 2 was the function's own divisor, `i / (uCount - 1)` divides by
/// zero at count 1, and the resulting NaN parameter is worse than a throw, since `D0` does not
/// throw on NaN, it returns NaN coordinates. Every other member of the same U-major grid family
/// already accepted 1 (`OCCTSurfaceDrawGrid` guards no count at all, `EvaluateGrid` and
/// `EvaluateGridD1` guard `<= 0`), so `drawMesh` was the sole outlier. The bridge was the wrong
/// layer; the doc and the Swift guard were right.
///
/// Two things these tests are careful about, both learned from review:
///
/// - **No unguarded `.at(u:v:)`.** It is a `precondition`, so on an empty grid it traps the whole
///   target with a signal instead of failing. Swift Testing does not short-circuit, so a count
///   assertion above does not protect a subscript below; every read here is behind a `guard`.
/// - **The single row sits at the low end of the *sampled range*, not at `domain.uMin`.** The
///   bridge clamps infinite bounds to ±100 before sampling, so those two coincide only for a
///   bounded surface. Asserting `domain.uMin` on a sphere and calling it the contract is how #620
///   happened in the first place: a claim true of the fixture in front of you and false in
///   general. `singleRowOnAnUnboundedSurfaceSitsAtTheClamp` pins the other half.
@Suite("drawMesh honours its documented minimum of one sample per direction (#620)")
struct Issue620DrawMeshCountContractTests {

    /// The bridge's own infinite-bounds clamp (`OCCTBridge_Surface.mm`): anything beyond ±1e6
    /// becomes ±100, and that happens before the sampling parameters are derived.
    static let clamp = 100.0

    static func isFinite(_ p: SIMD3<Double>) -> Bool {
        p.x.isFinite && p.y.isFinite && p.z.isFinite
    }

    // MARK: - The two reported requests

    @Test("uCount 1 returns a single V iso-row, not an empty grid")
    func singleURow() {
        guard let s = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture nil")
            return
        }
        let grid = s.drawMesh(uCount: 1, vCount: 20)

        // The defect: this was SurfaceGrid.empty.
        #expect(!grid.isEmpty)
        guard grid.uCount == 1, grid.vCount == 20 else {
            Issue.record("expected a 1x20 grid, got \(grid.uCount)x\(grid.vCount)")
            return
        }

        // Every point finite, i.e. the divisor did not go through 0/0.
        for v in 0..<grid.vCount {
            #expect(Self.isFinite(grid.at(u: 0, v: v)))
        }
    }

    @Test("vCount 1 returns a single U iso-row, not an empty grid")
    func singleVRow() {
        guard let s = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture nil")
            return
        }
        let grid = s.drawMesh(uCount: 20, vCount: 1)

        #expect(!grid.isEmpty)
        guard grid.uCount == 20, grid.vCount == 1 else {
            Issue.record("expected a 20x1 grid, got \(grid.uCount)x\(grid.vCount)")
            return
        }

        for u in 0..<grid.uCount {
            #expect(Self.isFinite(grid.at(u: u, v: 0)))
        }
    }

    // MARK: - The row is the right row

    /// Finiteness alone would pass on any arbitrary parameter. This pins *which* iso-row a
    /// one-sample direction means on a **bounded** surface, where the sampled range is the domain,
    /// cross-checked against the surface's own point evaluation rather than another grid call.
    @Test("On a bounded surface the single row sits at domain.uMin")
    func singleRowOnABoundedSurfaceSitsAtDomainMin() {
        guard let s = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture nil")
            return
        }
        let d = s.domain
        // A sphere is bounded, so the clamp cannot have moved either end.
        #expect(abs(d.uMin) < 1e6 && abs(d.uMax) < 1e6)

        let vCount = 8
        let grid = s.drawMesh(uCount: 1, vCount: vCount)
        guard grid.uCount == 1, grid.vCount == vCount else {
            Issue.record("expected a 1x\(vCount) grid, got \(grid.uCount)x\(grid.vCount)")
            return
        }

        for j in 0..<vCount {
            let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(vCount - 1)
            let expected = s.point(atU: d.uMin, v: v)
            #expect(simd_distance(grid.at(u: 0, v: j), expected) < 1e-9)
        }
    }

    /// The other half of the contract, and the half the first version of this suite got wrong.
    ///
    /// A plane is unbounded, so `domain.uMin` is about -2e100 while the bridge clamps to -100
    /// *before* deriving parameters. The single row therefore sits at the clamp, nowhere near
    /// `domain.uMin`. Checking only finiteness here (as this suite first did) passes under either
    /// reading and so cannot tell the doc it is wrong.
    @Test("On an unbounded surface the single row sits at the clamp, not at domain.uMin")
    func singleRowOnAnUnboundedSurfaceSitsAtTheClamp() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture nil")
            return
        }
        let d = plane.domain
        // The premise: this surface really is unbounded, so domain and sampled range differ.
        #expect(d.uMin < -1e6)

        let vCount = 5
        let grid = plane.drawMesh(uCount: 1, vCount: vCount)
        guard grid.uCount == 1, grid.vCount == vCount else {
            Issue.record("expected a 1x\(vCount) grid, got \(grid.uCount)x\(grid.vCount)")
            return
        }

        // This plane's parametrisation is (u, v) -> (u, v, 0), so the row's x IS its u parameter.
        for j in 0..<vCount {
            let p = grid.at(u: 0, v: j)
            #expect(Self.isFinite(p))
            #expect(abs(p.x - (-Self.clamp)) < 1e-9)
        }

        // And the row spans the clamped V range, not 2e100 of it.
        let first = grid.at(u: 0, v: 0)
        let last = grid.at(u: 0, v: vCount - 1)
        #expect(abs(first.y - (-Self.clamp)) < 1e-9)
        #expect(abs(last.y - Self.clamp) < 1e-9)
    }

    /// The same row, reached the other way: row 0 of a multi-row grid is also the low-end row, and
    /// its V samples are spaced identically. A one-row grid must agree with it point for point.
    @Test("A one-row grid equals row 0 of a many-row grid")
    func oneRowEqualsRowZeroOfAManyRowGrid() {
        guard let s = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture nil")
            return
        }
        let vCount = 12
        let one = s.drawMesh(uCount: 1, vCount: vCount)
        let many = s.drawMesh(uCount: 6, vCount: vCount)
        guard one.uCount == 1, one.vCount == vCount,
            many.uCount == 6, many.vCount == vCount
        else {
            Issue.record(
                "grids not served: \(one.uCount)x\(one.vCount), \(many.uCount)x\(many.vCount)")
            return
        }

        for j in 0..<vCount {
            #expect(simd_distance(one.at(u: 0, v: j), many.at(u: 0, v: j)) < 1e-9)
        }
    }

    @Test("A 1x1 grid is one point, at the sampled-range corner")
    func oneByOneIsASinglePoint() {
        guard let s = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture nil")
            return
        }
        let grid = s.drawMesh(uCount: 1, vCount: 1)
        #expect(!grid.isEmpty)
        // `.at` is a precondition, not an optional: reading it on an empty grid traps the whole
        // test target with a signal and no run summary. Never subscript before this guard, the
        // first version of this test did, and the regression it exists to catch killed the target
        // instead of reporting a failure.
        guard grid.uCount == 1, grid.vCount == 1 else {
            Issue.record("expected a 1x1 grid, got \(grid.uCount)x\(grid.vCount)")
            return
        }

        let d = s.domain
        #expect(simd_distance(grid.at(u: 0, v: 0), s.point(atU: d.uMin, v: d.vMin)) < 1e-9)
    }

    // MARK: - The bound moved to 1, it did not disappear

    /// #558's bounds are still in force. Lowering the minimum to 1 must not readmit 0, a negative,
    /// or a product past the ceiling, those stay rejected at the Swift boundary, before any
    /// allocation, and rejection is still the documented empty grid.
    @Test("Counts below 1 and products past the ceiling are still rejected")
    func belowOneAndPastTheCeilingStillRejected() {
        guard let s = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture nil")
            return
        }

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
    /// `Geom_BezierSurface` raises on a single-pole direction (measured against the pinned kernel;
    /// the precondition is not elided in this build).
    ///
    /// **Scope, stated exactly:** this pins the *public* contract, not the bridge guard. Relaxing
    /// the bridge's `< 2` on its own leaves this test passing, because `Surface.bezier` guards
    /// `>= 2` in Swift and never reaches the bridge, and even if it did, OCCT would throw and
    /// `catch (...)` would return `nullptr`, so the observable answer is `nil` either way. What
    /// holds the bridge guard in place is the comment at that site plus the kernel's own
    /// precondition; no black-box test can separate the two layers here. Said plainly because the
    /// earlier version of this comment claimed protection this test does not provide.
    @Test("Bezier keeps its minimum of two poles per direction, which is OCCT's own")
    func bezierKeepsItsTwoPoleMinimum() {
        // One pole in U: rejected.
        #expect(Surface.bezier(poles: [[SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 2, 0)]]) == nil)
        // One pole in V: rejected.
        #expect(Surface.bezier(poles: [[SIMD3(0, 0, 0)], [SIMD3(1, 0, 0)]]) == nil)
        // One pole in both: rejected.
        #expect(Surface.bezier(poles: [[SIMD3(0, 0, 0)]]) == nil)
        // The smallest legal patch: accepted.
        #expect(
            Surface.bezier(poles: [
                [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
                [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
            ]) != nil)
    }
}
