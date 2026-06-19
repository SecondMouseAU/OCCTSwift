import Testing
import simd
@testable import OCCTSwift

/// Issue #244 — why the reproducer surface produced "invalid" (un-meshable) output, in detail.
///
/// `Surface.fromPointGrid` wraps `GeomAPI_PointsToBSplineSurface`, a least-squares B-spline fit
/// through the grid. The bug was passing `degMax: 8` (the default) for a **7×7** grid. The chain:
///
/// 1. **Under-determined high-degree fit → oscillation.** A B-spline of degree _d_ needs ≥ _d_+1
///    samples per direction to be well-posed; degree 8 with only 7 samples leaves the fit with more
///    freedom than data pins down. The least-squares solution is then free to swing between the
///    sparse nodes — the classic Runge phenomenon for high-degree approximation of few points. The
///    surface passes *through/near* the 49 grid points but **overshoots wildly between them**, with
///    large local curvature and, in the worst regions, **folds/self-overlaps in 3D**.
///
/// 2. **`isValid == true` anyway.** `BRepCheck` (and `Shape.isValid`/`isValidSolid`) validate
///    *topology* and *per-element tolerances* — pcurves exist, the wire is closed, edges are
///    same-parameter, etc. They do **not** measure global geometric quality, oscillation, or
///    self-overlap. So the rippling face reports valid, which is what made the bug confusing.
///
/// 3. **`BRepMesh` never converges.** `BRepMesh_IncrementalMesh` tessellates by *adaptive
///    refinement*: subdivide until every facet is within `linearDeflection` (chord distance to the
///    true surface) and `angularDeflection` (normal deviation). On a surface that ripples below the
///    chord tolerance *everywhere*, the deflection criterion is never satisfied, so it keeps
///    subdividing; the oscillating fit also has wildly varying parametric speed (near-zero Jacobian
///    in folded regions), which defeats the refinement's termination heuristics. The result is a
///    non-terminating subdivision loop — an in-process hang that no signal/`try`/`UserBreak`
///    deadline reliably interrupts (BRepMesh doesn't poll progress during this work).
///
/// **Fix (prevention):** clamp the fit degree to `min(uCount, vCount) − 1`. The fit becomes
/// well-posed (enough samples for the degree), the surface stops oscillating, and `BRepMesh`
/// converges normally. There is no "valid partial mesh" to recover from the pathological surface —
/// the only sound output is to not build it. These tests lock that in.
@Suite("Issue #244 — fromPointGrid degree clamp keeps surfaces meshable")
struct Issue244PointGridDegreeTests {

    static func grid(_ n: Int) -> [SIMD3<Double>] {
        var pts = [SIMD3<Double>]()
        for v in 0..<n { for u in 0..<n {
            pts.append(SIMD3(Double(u), Double(v), 2 * sin(1.3 * Double(u)) * cos(1.1 * Double(v))))
        }}
        return pts
    }

    /// A 7×7 grid asked for degree 8 still builds a valid face and meshes promptly (the degree is
    /// clamped to 6 internally rather than over-fitting).
    @Test("7×7 grid with degMax 8 builds a valid, quickly-meshable face")
    func sevenBySevenDegree8() {
        guard let surf = Surface.fromPointGrid(points: Self.grid(7), uCount: 7, vCount: 7,
                                               degMin: 3, degMax: 8, continuity: 2, tolerance: 1e-3),
              let face = surf.toFace() else { Issue.record("build/toFace"); return }
        #expect(face.isValid)
        let mesh = face.mesh(linearDeflection: 0.1, angularDeflection: 0.3)
        #expect(mesh != nil)
        #expect((mesh?.triangleCount ?? 0) > 0)
    }

    /// Clamp must not break small grids (degree clamps down toward degMin) or under-2 grids (nil).
    @Test("Clamp is well-behaved across grid sizes")
    func clampAcrossSizes() {
        for n in [4, 5, 7] {
            guard let s = Surface.fromPointGrid(points: Self.grid(n), uCount: n, vCount: n, degMax: 8),
                  let f = s.toFace() else { Issue.record("grid \(n)"); continue }
            #expect(f.mesh(linearDeflection: 0.1) != nil)
        }
        // Degenerate grid dimension → nil (guard).
        #expect(Surface.fromPointGrid(points: [SIMD3(0,0,0), SIMD3(1,0,0)], uCount: 2, vCount: 1) == nil)
    }
}
