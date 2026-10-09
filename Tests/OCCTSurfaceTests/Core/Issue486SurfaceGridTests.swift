import Testing
import simd

@testable import OCCTSwift

/// #486: the batch grid-evaluation family had three generations per type and the two Surface
/// spellings wrote opposite UV layouts, `OCCTSurfaceEvaluateGrid` v-major and
/// `OCCTGridEvalSurfaceD0` u-major, both header comments calling their own layout "row-major".
///
/// The pre-existing tests could not have caught it: the since-removed `gridEvalD0`/`gridEvalD1`
/// coverage used asymmetric grids but only asserted counts and rough magnitudes, never a specific
/// `(u, v)` against an independent evaluator, the check `evalGridAsymmetricMatchesDirectEvaluation`
/// had done for `evaluateGrid` since #404. These pin the layout on every surviving surface entry
/// point.
@Suite("Issue 486: surface grid layout")
struct Issue486SurfaceGridTests {

    /// Asymmetric grid: a square one cannot tell u-major from v-major apart.
    private static let uParams = [0.0, 0.4, 1.1, 2.0, 3.5]
    private static let vParams = [-1.2, 0.0, 1.2]

    @Test("evaluateGridD1 indexes each (u, v) at its own parameter, not transposed")
    func evaluateGridD1MatchesDirectEvaluation() {
        guard let sphere = Surface.sphere(center: .zero, radius: 5) else { return }
        let u = Self.uParams
        let v = Self.vParams
        let grid = sphere.evaluateGridD1(uParameters: u, vParameters: v)
        #expect(grid.uCount == u.count)
        #expect(grid.vCount == v.count)
        guard !grid.isEmpty else { return }

        for iu in 0..<u.count {
            for iv in 0..<v.count {
                let expected = sphere.evalD1(u: u[iu], v: v[iv])
                let actual = grid.at(u: iu, v: iv)
                #expect(simd_length(actual.point - expected.point) < 1e-6)
                #expect(simd_length(actual.d1u - expected.d1u) < 1e-6)
                #expect(simd_length(actual.d1v - expected.d1v) < 1e-6)
            }
        }
    }

    @Test("evaluateGrid and evaluateGridD1 agree point-for-point under .at(u:v:)")
    func evaluateGridAndD1Agree() {
        guard let sphere = Surface.sphere(center: .zero, radius: 5) else { return }
        let u = Self.uParams
        let v = Self.vParams
        let d0 = sphere.evaluateGrid(uParameters: u, vParameters: v)
        let d1 = sphere.evaluateGridD1(uParameters: u, vParameters: v)
        #expect(d0.uCount == d1.uCount)
        #expect(d0.vCount == d1.vCount)
        guard !d0.isEmpty, !d1.isEmpty else { return }

        for iu in 0..<u.count {
            for iv in 0..<v.count {
                #expect(simd_length(d0.at(u: iu, v: iv) - d1.at(u: iu, v: iv).point) < 1e-9)
            }
        }
    }

    @Test("drawMesh, evaluateGrid and evaluateGridD1 all read U-major")
    func drawMeshSharesTheGridLayout() {
        guard let sphere = Surface.sphere(center: .zero, radius: 5) else { return }
        let uCount = 5
        let vCount = 3
        let mesh = sphere.drawMesh(uCount: uCount, vCount: vCount)

        var (uMin, uMax, vMin, vMax) = sphere.domain
        if uMin < -1e6 { uMin = -100 }
        if uMax > 1e6 { uMax = 100 }
        if vMin < -1e6 { vMin = -100 }
        if vMax > 1e6 { vMax = 100 }
        let u = (0..<uCount).map { uMin + (uMax - uMin) * Double($0) / Double(uCount - 1) }
        let v = (0..<vCount).map { vMin + (vMax - vMin) * Double($0) / Double(vCount - 1) }

        let d1 = sphere.evaluateGridD1(uParameters: u, vParameters: v)
        guard !mesh.isEmpty, !d1.isEmpty else { return }
        for iu in 0..<uCount {
            for iv in 0..<vCount {
                #expect(simd_length(mesh.at(u: iu, v: iv) - d1.at(u: iu, v: iv).point) < 1e-6)
            }
        }
    }

    @Test("empty parameter arrays give an empty grid, not a grid of zeroes")
    func emptyParametersGiveEmptyGrid() {
        guard let sphere = Surface.sphere(center: .zero, radius: 5) else { return }
        #expect(sphere.evaluateGrid(uParameters: [], vParameters: [0.0]).isEmpty)
        #expect(sphere.evaluateGrid(uParameters: [0.0], vParameters: []).isEmpty)
        #expect(sphere.evaluateGridD1(uParameters: [], vParameters: [0.0]).isEmpty)
        #expect(sphere.evaluateGridD1(uParameters: [0.0], vParameters: []).isEmpty)
    }
}
