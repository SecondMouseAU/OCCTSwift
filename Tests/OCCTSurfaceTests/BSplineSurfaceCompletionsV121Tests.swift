import Testing
import simd

@testable import OCCTSwift

// =============================================================================
// MARK: - v0.121.0: BSpline completions, FilletBuilder, ChamferBuilder
// =============================================================================

@Suite("BSplineSurface Completions v121")
struct BSplineSurfaceCompletionsV121Tests {

    /// Helper: create a simple 4x4 BSpline surface
    private func makeBSplineSurface() -> Surface? {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(3, 0, 0), SIMD3(7, 0, 0), SIMD3(10, 0, 0)],
            [SIMD3(0, 3, 1), SIMD3(3, 3, 2), SIMD3(7, 3, 2), SIMD3(10, 3, 1)],
            [SIMD3(0, 7, 1), SIMD3(3, 7, 2), SIMD3(7, 7, 2), SIMD3(10, 7, 1)],
            [SIMD3(0, 10, 0), SIMD3(3, 10, 0), SIMD3(7, 10, 0), SIMD3(10, 10, 0)],
        ]
        return Surface.bspline(
            poles: poles,
            knotsU: [0, 1], multiplicitiesU: [4, 4],
            knotsV: [0, 1], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3)
    }

    @Test("SetUNotPeriodic / SetVNotPeriodic")
    func setNotPeriodic() {
        if let surf = makeBSplineSurface() {
            // Non-periodic surface, calling SetNotPeriodic is a no-op but should succeed
            let r1 = surf.bsplineSetUNotPeriodic()
            let r2 = surf.bsplineSetVNotPeriodic()
            #expect(r1)
            #expect(r2)
        }
    }

    @Test("IncreaseUMultiplicity / IncreaseVMultiplicity")
    func increaseMultiplicity() {
        if let surf = makeBSplineSurface() {
            // Insert a knot first so we have interior knots to increase
            let inserted = surf.bsplineInsertUKnots([0.5], multiplicities: [1])
            #expect(inserted)
            // Now increase multiplicity of the new knot (index 2)
            let r = surf.bsplineIncreaseUMultiplicity(index: 2, multiplicity: 2)
            #expect(r)
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
            // Evaluate at (0.5, 0.5), should be close to target
            let p = surf.point(atU: 0.5, v: 0.5)
            #expect(abs(p.x - target.x) < 1.0)
            #expect(abs(p.y - target.y) < 1.0)
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
        }
    }

    @Test("SetUOrigin / SetVOrigin fail on non-periodic")
    func setOriginNonPeriodic() {
        if let surf = makeBSplineSurface() {
            // SetOrigin only works on periodic surfaces, should fail gracefully
            let r1 = surf.bsplineSetUOrigin(index: 1)
            #expect(!r1)
            let r2 = surf.bsplineSetVOrigin(index: 1)
            #expect(!r2)
        }
    }
}
