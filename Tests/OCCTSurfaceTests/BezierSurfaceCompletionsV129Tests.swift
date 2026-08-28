import Testing
import simd

@testable import OCCTSwift

@Suite("BezierSurface Completions v129")
struct BezierSurfaceCompletionsV129Tests {

    @Test("InsertPoleColBefore and InsertPoleRowBefore")
    func insertBefore() {
        // Create a simple Bezier surface
        let c1 = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        let c2 = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0))
        if let s1 = c1, let s2 = c2, let surf = Surface.bezierFill(s1, s2) {
            let nbU = surf.bezierNbUPoles
            let nbV = surf.bezierNbVPoles
            // Insert a pole column before column 1
            let colPoles = (0..<nbU).map { i in SIMD3<Double>(Double(i), 2.5, 1.0) }
            let ok1 = surf.bezierInsertPoleColBefore(1, poles: colPoles)
            #expect(ok1)
            #expect(surf.bezierNbVPoles == nbV + 1)

            // Insert a pole row before row 1
            let nbV2 = surf.bezierNbVPoles
            let rowPoles = (0..<nbV2).map { i in SIMD3<Double>(-1.0, Double(i), 0.5) }
            let ok2 = surf.bezierInsertPoleRowBefore(1, poles: rowPoles)
            #expect(ok2)
            #expect(surf.bezierNbUPoles == nbU + 1)
        }
    }

    @Test("SetPoleCol and SetPoleRow without weights")
    func setPoleColRow() {
        let c1 = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        let c2 = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0))
        if let s1 = c1, let s2 = c2, let surf = Surface.bezierFill(s1, s2) {
            let nbU = surf.bezierNbUPoles
            let nbV = surf.bezierNbVPoles
            // Set pole column
            let colPoles = (0..<nbU).map { i in SIMD3<Double>(Double(i) * 2.0, 0.0, 0.0) }
            let ok1 = surf.bezierSetPoleCol(vIndex: 1, poles: colPoles)
            #expect(ok1)

            // Set pole row
            let rowPoles = (0..<nbV).map { i in SIMD3<Double>(0.0, Double(i) * 3.0, 0.0) }
            let ok2 = surf.bezierSetPoleRow(uIndex: 1, poles: rowPoles)
            #expect(ok2)
        }
    }

    @Test("SetWeightCol and SetWeightRow")
    func setWeightColRow() {
        // Create a rational Bezier surface by setting pole with weight
        let c1 = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        let c2 = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0))
        if let s1 = c1, let s2 = c2, let surf = Surface.bezierFill(s1, s2) {
            let nbU = surf.bezierNbUPoles
            let nbV = surf.bezierNbVPoles

            // Make it rational via SetPoleColWeights (existing API)
            let initPoles = (0..<nbU).map { i in SIMD3<Double>(Double(i), 0.0, 0.0) }
            let initWeights = [Double](repeating: 2.0, count: nbU)
            let _ = surf.bezierSetPoleColWeights(vIndex: 1, poles: initPoles, weights: initWeights)

            // Now set weight column
            let colWeights = [Double](repeating: 1.5, count: nbU)
            let ok1 = surf.bezierSetWeightCol(vIndex: 1, weights: colWeights)
            #expect(ok1)

            // Set weight row
            let rowWeights = [Double](repeating: 1.2, count: nbV)
            let ok2 = surf.bezierSetWeightRow(uIndex: 1, weights: rowWeights)
            #expect(ok2)
        }
    }
}
