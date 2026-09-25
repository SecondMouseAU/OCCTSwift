import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `GeomFill_CoonsAlgPatch::Value(U, V)` sampled all four boundaries at `V`, where `bound[0]` and
/// `bound[2]` are the U-direction sides (#1515). For any boundary set whose V-direction sides are
/// straight, the result was independent of `U` entirely and the surface collapsed onto the
/// `u == v` diagonal. Samples with `u == v` were coincidentally correct, which is why it read as a
/// valid surface rather than as an obvious failure.
///
/// Carried patch `0034` fixes it, and the pinned asset carries it from `v4.0.0-kernel.1` onward.
///
/// **This test could not be written before that repin**, and `Package.swift` said so: it asserts
/// the correct surface, and `ci.yml`'s `build-and-test` resolved the unpatched asset, where every
/// off-diagonal sample is still wrong. Whoever repinned was the one who could add it.
///
/// `Shape.coonsAlgPatch` is the only caller of `Value()` anywhere in this package or the kernel;
/// `GeomFill_ConstrainedFilling` evaluates through `Eval()` and was never affected.
@Suite("Issue1515 Coons patch samples the U boundaries at U")
struct Issue1515CoonsPatchUParameter {

    /// A flat 10 x 10 square, whose four sides are all straight. The correct Coons patch over it is
    /// the bilinear surface, so every sample has a closed form to check against rather than a
    /// reference captured from the same code under test.
    private static let side = 10.0

    private static func edge(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Shape? {
        guard let wire = Wire.line(from: a, to: b),
            let shape = Shape.fromWire(wire),
            let first = shape.edges().first
        else { return nil }
        return Shape.fromEdge(first)
    }

    private static func squarePatch(evalU: Int, evalV: Int) -> [SIMD3<Double>]? {
        let s = side
        let p00 = SIMD3<Double>(0, 0, 0)
        let p10 = SIMD3<Double>(s, 0, 0)
        let p11 = SIMD3<Double>(s, s, 0)
        let p01 = SIMD3<Double>(0, s, 0)
        // bound[0] and bound[2] are the U-direction sides, per GeomFill_ConstrainedFilling's
        // convention and the bridge's own ordering.
        guard let e0 = edge(p00, p10), let e1 = edge(p10, p11),
            let e2 = edge(p01, p11), let e3 = edge(p00, p01)
        else { return nil }
        return Shape.coonsAlgPatch(
            edge1: e0, edge2: e1, edge3: e2, edge4: e3, evalU: evalU, evalV: evalV)
    }

    @Test("every sample is the bilinear point, not its diagonal collapse")
    func everySampleIsBilinear() {
        let n = 5
        guard let grid = Self.squarePatch(evalU: n, evalV: n) else {
            Issue.record("patch nil")
            return
        }
        #expect(grid.count == n * n)
        for i in 0..<n {
            for j in 0..<n {
                let u = Double(i) / Double(n - 1)
                let v = Double(j) / Double(n - 1)
                let got = grid[i * n + j]
                let want = SIMD3<Double>(Self.side * u, Self.side * v, 0)
                #expect(
                    simd_distance(got, want) < 1e-9,
                    "u=\(u) v=\(v): got \(got), expected the bilinear \(want)")
            }
        }
    }

    /// The defect's own signature, stated directly rather than inferred from the sweep above.
    ///
    /// Sampling the U sides at V made the whole result a function of V alone, so the two
    /// off-diagonal corners both landed on the diagonal: `(u:1, v:0)` read `(0, 0, 0)` and
    /// `(u:0, v:1)` read `(10, 10, 0)`. Both are corners of the square, which is exactly why the
    /// output still looked like a surface.
    @Test("the off-diagonal corners are not the diagonal's corners")
    func offDiagonalCornersAreDistinct() {
        guard let grid = Self.squarePatch(evalU: 2, evalV: 2) else {
            Issue.record("patch nil")
            return
        }
        // evalU = evalV = 2 puts u and v on {0, 1} exactly, so these are the four corners.
        let u0v0 = grid[0], u0v1 = grid[1], u1v0 = grid[2], u1v1 = grid[3]
        #expect(simd_distance(u0v0, SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(u1v1, SIMD3(Self.side, Self.side, 0)) < 1e-9)
        // The two that the collapse folded onto the diagonal.
        #expect(
            simd_distance(u1v0, SIMD3(Self.side, 0, 0)) < 1e-9,
            "u=1, v=0 collapsed onto the diagonal, which is #1515 unfixed")
        #expect(
            simd_distance(u0v1, SIMD3(0, Self.side, 0)) < 1e-9,
            "u=0, v=1 collapsed onto the diagonal, which is #1515 unfixed")
    }

    /// The property that holds for any boundary set, not only this square: the surface must depend
    /// on U. Kept separate because it survives a reparametrisation that would move the closed-form
    /// values above.
    @Test("holding v fixed and varying u moves the point")
    func theSurfaceDependsOnU() {
        let n = 4
        guard let grid = Self.squarePatch(evalU: n, evalV: n) else {
            Issue.record("patch nil")
            return
        }
        for j in 0..<n {
            let column = (0..<n).map { grid[$0 * n + j] }
            let spread = (1..<n).map { simd_distance(column[$0], column[0]) }.max() ?? 0
            #expect(spread > 1e-6, "v index \(j): every u gave the same point, so Value ignores U")
        }
    }
}
