import Testing
import simd

@testable import OCCTSwift

// =============================================================================
// MARK: - v0.121.0: BSpline completions, FilletBuilder, ChamferBuilder
// =============================================================================

@Suite("BSplineSurface Completions v121")
struct BSplineSurfaceCompletionsV121Tests {

    // The fixture (an explicit, hand-written 4x4 pole grid) lives in
    // `SurfaceTestFixtures.swift` as `makeExplicitPoleBSplineSurface()`; see #1254.
    private func makeBSplineSurface() -> Surface? {
        let s = makeExplicitPoleBSplineSurface()
        // #766: every test used `if let surf = makeBSplineSurface()`, so a nil fixture passed
        // silently; this records an issue instead. Values below are Geom_BSplineSurface's own
        // after the same edit, see Scripts/repro/766-bspline-surface-completions/.
        #expect(s != nil, "fixture surface")
        return s
    }

    @Test("SetUNotPeriodic / SetVNotPeriodic")
    func setNotPeriodic() {
        if let surf = makeBSplineSurface() {
            // Non-periodic surface, calling SetNotPeriodic is a no-op but should succeed
            let before = surf.point(atU: 0.3, v: 0.7)
            let r1 = surf.bsplineSetUNotPeriodic()
            let r2 = surf.bsplineSetVNotPeriodic()
            #expect(r1)
            #expect(r2)
            // A no-op on a non-periodic surface: still non-periodic, geometry untouched.
            #expect(!surf.isUPeriodic && !surf.isVPeriodic)
            #expect(simd_length(surf.point(atU: 0.3, v: 0.7) - before) == 0)
            #expect(simd_length(before - SIMD3(7.084, 2.916, 1.0269)) < 1e-12)
        }
    }

    @Test("IncreaseUMultiplicity / IncreaseVMultiplicity")
    func increaseMultiplicity() {
        if let surf = makeBSplineSurface() {
            // Insert a knot first so we have interior knots to increase
            let inserted = surf.bsplineInsertUKnots([0.5], multiplicities: [1])
            #expect(inserted)
            // Now increase multiplicity of the new knot (index 2)
            #expect(surf.bsplineUMultiplicities == [4, 1, 4])
            let r = surf.bsplineIncreaseUMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
            #expect(surf.bsplineUMultiplicities == [4, 2, 4])
        }
    }

    // #815: `bsplineIncreaseVMultiplicity` had no test anywhere in the tree; its U twin
    // (immediately above) does.
    @Test("IncreaseVMultiplicity")
    func increaseVMultiplicity() {
        if let surf = makeBSplineSurface() {
            let inserted = surf.bsplineInsertVKnots([0.5], multiplicities: [1])
            #expect(inserted)
            let r = surf.bsplineIncreaseVMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
            #expect(surf.bsplineVMultiplicities == [4, 2, 4])
            #expect(surf.bsplineUMultiplicities == [4, 4])
        }
    }

    // #815: the single-index setters had no test anywhere in the tree, only the batch
    // `bsplineInsertUKnots`/`bsplineInsertVKnots` (below) did.
    @Test("SetUKnot / SetVKnot single index")
    func setKnot() {
        if let surf = makeBSplineSurface() {
            let r1 = surf.bsplineSetUKnot(index: 1, value: -1.0)
            #expect(r1)
            let r2 = surf.bsplineSetVKnot(index: 1, value: -1.0)
            #expect(r2)
            let uKnots = surf.bsplineUKnots()
            let vKnots = surf.bsplineVKnots()
            #expect(abs((uKnots.first ?? 0) - (-1.0)) < 1e-9)
            #expect(abs((vKnots.first ?? 0) - (-1.0)) < 1e-9)
        }
    }

    @Test("InsertUKnots / InsertVKnots batch")
    func insertKnotsBatch() {
        if let surf = makeBSplineSurface() {
            let r1 = surf.bsplineInsertUKnots([0.25, 0.75], multiplicities: [1, 1])
            #expect(r1)
            let nuk = surf.bsplineSurface.nbUKnots
            #expect(nuk == 4)  // original 2 + 2 new

            let r2 = surf.bsplineInsertVKnots([0.5], multiplicities: [1])
            #expect(r2)
            let nvk = surf.bsplineSurface.nbVKnots
            #expect(nvk == 3)  // original 2 + 1 new
            #expect(surf.bsplineUKnots() == [0, 0.25, 0.75, 1])
            #expect(surf.bsplineVKnots() == [0, 0.5, 1])
        }
    }

    @Test("MovePoint on BSpline surface")
    func movePoint() {
        if let surf = makeBSplineSurface() {
            let target = SIMD3<Double>(5, 5, 10)
            let r = surf.bsplineMovePoint(
                u: 0.5, v: 0.5, to: target,
                uPoleRange: 1...4, vPoleRange: 1...4)
            #expect(r)
            // GeomLib's MovePoint puts S(0.5, 0.5) on the target (z = 9.9999999999999982 in the
            // kernel); the old check tested x and y to within 1.0 and never looked at z.
            let p = surf.point(atU: 0.5, v: 0.5)
            #expect(simd_length(p - target) < 1e-9)
            // and the rest of the surface follows the kernel's pole update
            #expect(simd_length(surf.point(atU: 0.2, v: 0.2) - SIMD3(1.904, 1.904, 7.1359567567567552)) < 1e-9)
        }
    }

    @Test("SetPoleCol and SetPoleRow")
    func setPoleColRow() {
        if let surf = makeBSplineSurface() {
            // Set column 1 (vIndex=1) to new values, 4 poles for NbUPoles=4
            let newCol: [SIMD3<Double>] = [
                SIMD3(0, 0, 5), SIMD3(0, 3, 5), SIMD3(0, 7, 5), SIMD3(0, 10, 5),
            ]
            let r1 = surf.bsplineSetPoleCol(vIndex: 1, poles: newCol)
            #expect(r1)

            // Set row 1 (uIndex=1) to new values, 4 poles for NbVPoles=4
            let newRow: [SIMD3<Double>] = [
                SIMD3(0, 0, 3), SIMD3(3, 0, 3), SIMD3(7, 0, 3), SIMD3(10, 0, 3),
            ]
            let r2 = surf.bsplineSetPoleRow(uIndex: 1, poles: newRow)
            #expect(r2)
            // Column 1 keeps newCol except its first pole, which row 1 then overwrote.
            let bs = surf.bsplineSurface
            #expect((1...4).map { bs.pole(uIndex: $0, vIndex: 1) } == [newRow[0]] + newCol.dropFirst())
            #expect((1...4).map { bs.pole(uIndex: 1, vIndex: $0) } == newRow)
        }
    }

    @Test("SetUOrigin / SetVOrigin fail on non-periodic")
    func setOriginNonPeriodic() {
        if let surf = makeBSplineSurface() {
            // SetOrigin only works on periodic surfaces: the kernel throws "surface is not U
            // periodic" (and V), and the bridge turns that into false.
            let r1 = surf.bsplineSetUOrigin(index: 1)
            #expect(!r1)
            let r2 = surf.bsplineSetVOrigin(index: 1)
            #expect(!r2)
        }
    }
}
