import Testing
import simd

@testable import OCCTSwift

@Suite("v0.126.0, Bezier Surface completions")
struct BezierSurfaceCompletionsTests {

    // #766: every test here was wrapped in `if let s`, so a nil surface passed silently, and
    // checked only the Bool and the pole count, so an edit that landed in the wrong column, or did
    // nothing, passed. The pole grids below are what Geom_BezierSurface reports after the same
    // edit, see Scripts/repro/766-bezier-surface-poles/. `bezierPoles` is row-major: u rows,
    // v columns.

    private func samePoles(_ a: [SIMD3<Double>], _ b: [SIMD3<Double>]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { simd_length($0 - $1) < 1e-12 }
    }
    @Test("InsertPoleColAfter and RemovePoleCol")
    func insertRemoveCol() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 2, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1), SIMD3(1, 2, 0)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            let original = s.bezierPoles
            let origVPoles = s.bezierNbVPoles
            // Insert column after col 1, need NbUPoles (2) points
            let newCol = [SIMD3<Double>(0, 0.5, 0.5), SIMD3(1, 0.5, 0.5)]
            let ok = s.bezierInsertPoleColAfter(1, poles: newCol)
            #expect(ok)
            #expect(s.bezierNbVPoles == origVPoles + 1)
            // The new column is column 2 of 4 in each row.
            let inserted: [SIMD3<Double>] = [
                SIMD3(0, 0, 0), SIMD3(0, 0.5, 0.5), SIMD3(0, 1, 0), SIMD3(0, 2, 0),
                SIMD3(1, 0, 0), SIMD3(1, 0.5, 0.5), SIMD3(1, 1, 1), SIMD3(1, 2, 0),
            ]
            #expect(samePoles(s.bezierPoles, inserted))
            // Remove the column we just inserted
            let ok2 = s.bezierRemovePoleCol(2)
            #expect(ok2)
            #expect(s.bezierNbVPoles == origVPoles)
            #expect(samePoles(s.bezierPoles, original))
        }
    }

    @Test("InsertPoleRowAfter and RemovePoleRow")
    func insertRemoveRow() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
            [SIMD3(2, 0, 0), SIMD3(2, 1, 0)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            let original = s.bezierPoles
            let origUPoles = s.bezierNbUPoles
            // Insert row after row 1, need NbVPoles (2) points
            let newRow = [SIMD3<Double>(0.5, 0, 0.5), SIMD3(0.5, 1, 0.5)]
            let ok = s.bezierInsertPoleRowAfter(1, poles: newRow)
            #expect(ok)
            #expect(s.bezierNbUPoles == origUPoles + 1)
            // The new row is row 2 of 4.
            let inserted: [SIMD3<Double>] = [
                SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0.5, 0, 0.5), SIMD3(0.5, 1, 0.5),
                SIMD3(1, 0, 0), SIMD3(1, 1, 1), SIMD3(2, 0, 0), SIMD3(2, 1, 0),
            ]
            #expect(samePoles(s.bezierPoles, inserted))
            // Remove the row we just inserted
            let ok2 = s.bezierRemovePoleRow(2)
            #expect(ok2)
            #expect(s.bezierNbUPoles == origUPoles)
            #expect(samePoles(s.bezierPoles, original))
        }
    }

    @Test("IncreaseDegree")
    func increaseDegree() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            let origUDeg = s.bezierUDegree
            let origVDeg = s.bezierVDegree
            let before = s.point(atU: 0.3, v: 0.7)
            let ok = s.bezierIncreaseDegree(uDeg: origUDeg + 1, vDeg: origVDeg + 1)
            #expect(ok)
            #expect(s.bezierUDegree == origUDeg + 1)
            #expect(s.bezierVDegree == origVDeg + 1)
            // Degree elevation keeps the geometry: the kernel moves (0.3, 0.7) by 2.8e-17.
            #expect(simd_length(s.point(atU: 0.3, v: 0.7) - before) < 1e-12)
        }
    }

    @Test("UReverse and VReverse")
    func reverse() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            #expect(s.bezierUReverse())
            #expect(samePoles(s.bezierPoles, [SIMD3(1, 0, 0), SIMD3(1, 1, 1), SIMD3(0, 0, 0), SIMD3(0, 1, 0)]))
            #expect(s.bezierVReverse())
            #expect(samePoles(s.bezierPoles, [SIMD3(1, 1, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 0)]))
        }
    }
}
