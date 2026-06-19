import Testing
import simd
@testable import OCCTSwift

/// Issue #244: `Surface.fromPointGrid` with `degMax` higher than the grid supports (e.g. the default
/// `degMax: 8` on a 7×7 grid) over-parameterises the B-spline fit — it can oscillate/self-overlap in
/// 3D, producing a topologically-valid-but-geometrically-rippling face that makes `BRepMesh` (an
/// in-process, uninterruptible loop) never converge. The fix clamps the fit degree to the grid size
/// (`degree ≤ min(uCount, vCount) − 1`), keeping the surface well-posed so it meshes normally.
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
