import Testing
import simd

@testable import OCCTSwift

@Suite("v0.126.0, Bezier Surface completions")
struct BezierSurfaceCompletionsTests {
    @Test("InsertPoleColAfter and RemovePoleCol")
    func insertRemoveCol() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 2, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1), SIMD3(1, 2, 0)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            let origVPoles = s.bezierNbVPoles
            // Insert column after col 1, need NbUPoles (2) points
            let newCol = [SIMD3<Double>(0, 0.5, 0.5), SIMD3(1, 0.5, 0.5)]
            let ok = s.bezierInsertPoleColAfter(1, poles: newCol)
            #expect(ok)
            #expect(s.bezierNbVPoles == origVPoles + 1)
            // Remove the column we just inserted
            let ok2 = s.bezierRemovePoleCol(2)
            #expect(ok2)
            #expect(s.bezierNbVPoles == origVPoles)
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
        if let s = s {
            let origUPoles = s.bezierNbUPoles
            // Insert row after row 1, need NbVPoles (2) points
            let newRow = [SIMD3<Double>(0.5, 0, 0.5), SIMD3(0.5, 1, 0.5)]
            let ok = s.bezierInsertPoleRowAfter(1, poles: newRow)
            #expect(ok)
            #expect(s.bezierNbUPoles == origUPoles + 1)
            // Remove the row we just inserted
            let ok2 = s.bezierRemovePoleRow(2)
            #expect(ok2)
            #expect(s.bezierNbUPoles == origUPoles)
        }
    }

    @Test("IncreaseDegree")
    func increaseDegree() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            let origUDeg = s.bezierUDegree
            let origVDeg = s.bezierVDegree
            let ok = s.bezierIncreaseDegree(uDeg: origUDeg + 1, vDeg: origVDeg + 1)
            #expect(ok)
            #expect(s.bezierUDegree == origUDeg + 1)
            #expect(s.bezierVDegree == origVDeg + 1)
        }
    }

    @Test("UReverse and VReverse")
    func reverse() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            #expect(s.bezierUReverse())
            #expect(s.bezierVReverse())
        }
    }
}
