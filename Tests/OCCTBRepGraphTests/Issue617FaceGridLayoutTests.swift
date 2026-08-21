import Testing
import Foundation
import simd
@testable import OCCTSwift

/// #617: `BRepGraph.FaceGridSample` handed back flat position / normal / curvature buffers that
/// the bridge wrote **V-major** (`iv * uSamples + iu`), while #486 had already declared U-major
/// (`occtSurfaceGridIndex`, `iu * vSamples + iv`) THE surface-grid layout of this codebase and
/// given `SurfaceGrid` / `SurfaceGridD1` an `.at(u:v:)` accessor for it. `FaceGridSample`
/// documented no layout and offered no accessor, so the only guidance a caller had was the
/// convention that was wrong for this one type.
///
/// #617's own report crosses two different mistakes here, so state the model carefully, getting
/// this arithmetic wrong is the exact failure the fix exists to prevent, and `handRolledIndexArithmetic`
/// below asserts every claim in this paragraph:
///
///   - A caller reading the U-major index off a transposed buffer **never traps**, at any aspect
///     ratio. `u * vSamples + v` is a bijection onto `0..<uSamples * vSamples`, so at both 3x10
///     and 10x3 it lands on exactly the last valid slot at worst (29 of 30). Every such read is a
///     silent wrong answer: a position, normal or curvature attributed to the wrong place on the
///     face, no diagnostic. That is what the pre-#617 write produced.
///   - The out-of-range trap needs a *different* slip, striding by the wrong count
///     (`u * uSamples + v`). That one does split by aspect ratio: in range and quietly wrong at
///     3x10 (15 of 30), past the end at 10x3 (92 of 30).
///
/// So "silently wrong" and "traps" are not the two aspect ratios of one expression; they are two
/// expressions, one of which never traps at all. `at(u:v:)` retires both by owning the index.
///
/// Fixed by writing the bridge buffer U-major through the shared `occtSurfaceGridIndex`, so the
/// codebase has one rule, plus a `FaceGridSample.at(u:v:)` that resolves it through the shared
/// Swift-side `surfaceGridIndex`. No consumer depended on the V-major order: every in-repo and
/// ecosystem caller either sampled a square grid and mapped the arrays element-wise, or reduced
/// them order-independently (a mean position/normal signature).
@Suite("Issue 617: FaceGridSample U-major layout")
struct Issue617FaceGridLayoutTests {

    /// A Bezier patch on an asymmetric 4x3 pole grid: non-periodic (so no parameter wraps onto
    /// another sample), curved in both directions (so normals and curvatures vary too), and
    /// deliberately *not* symmetric under swapping u and v, the point (u, v) and the point
    /// (v, u) must be far apart or a transposed read could pass by accident.
    private func asymmetricPatch() -> Surface? {
        Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 4, 3), SIMD3(0, 8, 0)],
            [SIMD3(7, 0, 5), SIMD3(7, 4, 11), SIMD3(7, 8, 4)],
            [SIMD3(14, 0, 2), SIMD3(14, 4, 9), SIMD3(14, 8, 1)],
            [SIMD3(21, 0, 0), SIMD3(21, 4, 6), SIMD3(21, 8, 3)],
        ])
    }

    /// Build the single-face shape, its graph, and the UV bounds the bridge itself samples over
    /// (`BRepTools::UVBounds`, mirrored by `Face.uvBounds`).
    ///
    /// Every failure here records an issue rather than returning a bare `nil`. A suite whose only
    /// job is catching a layout regression must not be able to go green by failing to build its
    /// own fixture: with a silent `guard ... else { return }` at each call site, breaking
    /// `asymmetricPatch()` alone turns all 7 tests green while asserting nothing.
    private func fixture() -> (surface: Surface, graph: BRepGraph,
                               uMin: Double, uMax: Double, vMin: Double, vMax: Double)? {
        guard let surface = asymmetricPatch() else {
            Issue.record("fixture: Surface.bezier returned nil for the asymmetric patch")
            return nil
        }
        guard let shape = surface.toFace() else {
            Issue.record("fixture: Surface.toFace returned nil")
            return nil
        }
        guard let face = shape.faces().first else {
            Issue.record("fixture: the face shape exposed no Face")
            return nil
        }
        guard let bounds = face.uvBounds else {
            Issue.record("fixture: Face.uvBounds returned nil")
            return nil
        }
        guard let graph = BRepGraph(shape: shape) else {
            Issue.record("fixture: BRepGraph(shape:) returned nil")
            return nil
        }
        guard graph.faceCount == 1 else {
            Issue.record("fixture: expected exactly 1 face, got \(graph.faceCount); the grid tests address faceIndex 0 and rely on it being the patch")
            return nil
        }
        return (surface, graph, bounds.uMin, bounds.uMax, bounds.vMin, bounds.vMax)
    }

    /// `sampleFaceUVGrid` returning nil is a failure too, never a reason to skip quietly.
    private func requireSample(_ graph: BRepGraph, _ uSamples: Int, _ vSamples: Int)
        -> BRepGraph.FaceGridSample? {
        guard let sample = graph.sampleFaceUVGrid(
            faceIndex: 0, uSamples: uSamples, vSamples: vSamples) else {
            Issue.record("sampleFaceUVGrid returned nil for \(uSamples)x\(vSamples)")
            return nil
        }
        return sample
    }

    /// Every `.at(u:v:)` position must equal a direct `Surface.point(atU:v:)` evaluation at the
    /// parameters that grid slot stands for. Run on **both** aspect ratios: the pre-#617 buffer
    /// was silently transposed at each of them, and a square grid alone would not distinguish a
    /// stride mistake from a correct read.
    private func checkGrid(uSamples: Int, vSamples: Int) {
        guard let f = fixture(),
              let sample = requireSample(f.graph, uSamples, vSamples) else { return }

        #expect(sample.uSamples == uSamples)
        #expect(sample.vSamples == vSamples)
        #expect(sample.positions.count == uSamples * vSamples)
        #expect(sample.normals.count == uSamples * vSamples)
        #expect(sample.gaussianCurvatures.count == uSamples * vSamples)
        #expect(sample.meanCurvatures.count == uSamples * vSamples)

        let uStep = uSamples > 1 ? (f.uMax - f.uMin) / Double(uSamples - 1) : 0
        let vStep = vSamples > 1 ? (f.vMax - f.vMin) / Double(vSamples - 1) : 0

        for iu in 0..<uSamples {
            for iv in 0..<vSamples {
                let u = f.uMin + Double(iu) * uStep
                let v = f.vMin + Double(iv) * vStep
                let expected = f.surface.point(atU: u, v: v)
                let got = sample.at(u: iu, v: iv).position
                let d = simd_distance(got, expected)
                #expect(d < 1e-9,
                        "\(uSamples)x\(vSamples) at (u: \(iu), v: \(iv)) gave \(got), expected \(expected) at (\(u), \(v)), off by \(d)")
            }
        }
    }

    @Test("10x3 (uSamples > vSamples): .at(u:v:) matches direct evaluation")
    func tallGridMatchesDirectEvaluation() {
        checkGrid(uSamples: 10, vSamples: 3)
    }

    @Test("3x10 (uSamples < vSamples): .at(u:v:) matches direct evaluation")
    func wideGridMatchesDirectEvaluation() {
        checkGrid(uSamples: 3, vSamples: 10)
    }

    /// The transposition-catching property stated on its own, independent of the fix's index
    /// arithmetic: reading a 3x10 grid with the buffer's *old* V-major formula must land on a
    /// materially different point of the face. If this fails, the fixture surface is too
    /// symmetric and the two tests above could pass while transposed.
    @Test("The fixture patch actually distinguishes U from V")
    func transposedReadIsMateriallyDifferent() {
        guard let f = fixture(),
              let sample = requireSample(f.graph, 3, 10) else { return }

        var maxDrift = 0.0
        for iu in 0..<3 {
            for iv in 0..<10 {
                let vMajor = iv * 3 + iu           // the pre-#617 write order
                let uMajor = iu * 10 + iv          // the layout #486 declared
                guard vMajor != uMajor,
                      vMajor < sample.positions.count else { continue }
                maxDrift = max(maxDrift,
                               simd_distance(sample.positions[vMajor], sample.positions[uMajor]))
            }
        }
        // The patch spans 21 in X and 8 in Y; a transposed read is nowhere near a rounding error.
        #expect(maxDrift > 1.0,
                "transposed reads differ by at most \(maxDrift); fixture is too symmetric to distinguish U-major from V-major")
    }

    /// `.at(u:v:)` is the accessor #486 gave `SurfaceGrid`, so it must agree with the flat arrays
    /// on the documented index, not just with the geometry. Also pins normals and curvatures to
    /// the same slot as positions, since all four buffers share one layout.
    @Test("at(u:v:) reads the documented U-major slot of all four buffers")
    func accessorAgreesWithDocumentedIndex() {
        guard let f = fixture(),
              let sample = requireSample(f.graph, 10, 3) else { return }

        for iu in 0..<10 {
            for iv in 0..<3 {
                let i = iu * sample.vSamples + iv
                let s = sample.at(u: iu, v: iv)
                #expect(s.position == sample.positions[i])
                #expect(s.normal == sample.normals[i])
                #expect(s.gaussianCurvature == sample.gaussianCurvatures[i])
                #expect(s.meanCurvature == sample.meanCurvatures[i])
            }
        }
    }

    /// Normals sampled on a curved patch must be the surface's own normal at that (u, v), up to
    /// sign (OCCT orients against the face). A transposed buffer fails this on a patch whose
    /// normal actually turns, which is why the fixture is curved in both directions rather than
    /// planar.
    @Test("Normals land on the same U-major slot as positions")
    func normalsMatchDirectEvaluationPerSlot() {
        guard let f = fixture(),
              let sample = requireSample(f.graph, 10, 3) else { return }

        let uStep = (f.uMax - f.uMin) / 9
        let vStep = (f.vMax - f.vMin) / 2

        for iu in 0..<10 {
            for iv in 0..<3 {
                let u = f.uMin + Double(iu) * uStep
                let v = f.vMin + Double(iv) * vStep
                let d = f.surface.d1(atU: u, v: v)
                let cross = simd_cross(d.du, d.dv)
                let len = simd_length(cross)
                guard len > 1e-9 else { continue }
                let expected = cross / len
                let got = sample.at(u: iu, v: iv).normal
                guard simd_length(got) > 0.5 else { continue }  // undefined normal, skip
                #expect(abs(simd_dot(got, expected)) > 0.999_999,
                        "normal at (u: \(iu), v: \(iv)) is \(got), expected ±\(expected)")
            }
        }
    }

    /// The other face of #617: the hand-rolled read that traps rather than lying quietly.
    ///
    /// #617's prose and its code snippet disagree on which expression that is, so the arithmetic
    /// is pinned here. The layout-conforming stride (`u * vSamples + v`) is *always* inside a
    /// `uSamples * vSamples` buffer, at either aspect ratio, so on its own it can only ever be
    /// silently transposed. The out-of-range trap needs the other plausible slip, using the wrong
    /// count as the stride (`u * uSamples + v`), and that one splits exactly the way the issue
    /// describes: in range and quietly wrong at 3x10, past the end at 10x3.
    ///
    /// `at(u:v:)` retires both by owning the index, which is why this test asserts on the
    /// arithmetic rather than provoking a real trap (a trap would take the test runner down).
    @Test("Both hand-rolled slips are pinned: one silently in range, one past the end")
    func handRolledIndexArithmetic() {
        // 3x10: the wrong-stride read stays inside the buffer, so it is a silent wrong answer.
        let wideCount = 3 * 10
        let wideWorstWrongStride = (3 - 1) * 3 + (10 - 1)          // u * uSamples + v
        #expect(wideWorstWrongStride < wideCount)
        let wideWorstRightStride = (3 - 1) * 10 + (10 - 1)         // u * vSamples + v
        #expect(wideWorstRightStride == wideCount - 1)

        // 10x3: the same wrong-stride read runs off the end and traps.
        let tallCount = 10 * 3
        let tallWorstWrongStride = (10 - 1) * 10 + (3 - 1)         // u * uSamples + v
        #expect(tallWorstWrongStride >= tallCount)
        let tallWorstRightStride = (10 - 1) * 3 + (3 - 1)          // u * vSamples + v
        #expect(tallWorstRightStride == tallCount - 1)

        // And `at(u:v:)` is a bijection onto 0..<count at both aspect ratios, so no caller
        // following the accessor can land off the end or read the same slot twice.
        for (uS, vS) in [(10, 3), (3, 10)] {
            var seen = Set<Int>()
            for u in 0..<uS {
                for v in 0..<vS { seen.insert(surfaceGridIndex(u: u, v: v, vCount: vS)) }
            }
            #expect(seen.count == uS * vS)
            #expect(seen.min() == 0)
            #expect(seen.max() == uS * vS - 1)
        }
    }

    /// A 1x1 grid and a square grid still work, the fix changes an index, not the sample set.
    @Test("Degenerate and square grids are unaffected")
    func squareAndSingleGridsStillWork() {
        guard let f = fixture() else { return }

        if let one = f.graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 1, vSamples: 1) {
            #expect(one.positions.count == 1)
            #expect(one.at(u: 0, v: 0).position == one.positions[0])
        } else {
            Issue.record("1x1 sample returned nil")
        }

        if let square = f.graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 4, vSamples: 4) {
            #expect(square.positions.count == 16)
            let uStep = (f.uMax - f.uMin) / 3
            let vStep = (f.vMax - f.vMin) / 3
            for iu in 0..<4 {
                for iv in 0..<4 {
                    let expected = f.surface.point(atU: f.uMin + Double(iu) * uStep,
                                                   v: f.vMin + Double(iv) * vStep)
                    #expect(simd_distance(square.at(u: iu, v: iv).position, expected) < 1e-9)
                }
            }
        } else {
            Issue.record("4x4 sample returned nil")
        }
    }
}
