import Testing
import simd

@testable import OCCTSwift

@Suite("BezierSurface Completions v129")
struct BezierSurfaceCompletionsV129Tests {

    // #766: all three tests used to build their surface as
    // `Surface.bezierFill(Curve3D.line(...), Curve3D.line(...))`. A line is not a Geom_BezierCurve,
    // so OCCTSurfaceBezierFill2 refuses it and returns nil, the `if let` skipped the body, and not
    // one expectation ever ran. They now fill between two degree-1 Bezier curves along the same
    // lines, a 2x2 surface with poles (0,0,0) (0,5,0) / (10,0,0) (10,5,0), and assert that the
    // surface exists. Expected pole and weight grids are Geom_BezierSurface's own after the same
    // edits, see Scripts/repro/766-bezier-surface-poles/.
    private func makeSurface() -> Surface? {
        guard let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]),
            let c2 = Curve3D.bezier(poles: [SIMD3(0, 5, 0), SIMD3(10, 5, 0)])
        else { return nil }
        return Surface.bezierFill(c1, c2)
    }

    private func samePoles(_ a: [SIMD3<Double>], _ b: [SIMD3<Double>]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { simd_length($0 - $1) < 1e-12 }
    }

    @Test("InsertPoleColBefore and InsertPoleRowBefore")
    func insertBefore() {
        let surf = makeSurface()
        #expect(surf != nil)
        if let surf {
            let nbU = surf.bezierNbUPoles
            let nbV = surf.bezierNbVPoles
            #expect(nbU == 2 && nbV == 2)
            let original = surf.bezierPoles
            let colPoles = (0..<nbU).map { i in SIMD3<Double>(Double(i), 2.5, 1.0) }
            // Index 1 is refused. Geom_BezierSurface.hxx documents only VIndex < 1 as out of
            // range, but InsertPoleColBefore(1) throws Standard_OutOfRange in the pinned kernel,
            // as does InsertPoleRowBefore(1); the bridge catches it. A kernel finding, not a
            // wrapper one: the probe reproduces it with no bridge involved.
            #expect(!surf.bezierInsertPoleColBefore(1, poles: colPoles))
            #expect(samePoles(surf.bezierPoles, original))
            // Before column 2: the new column lands in the middle of each row.
            let ok1 = surf.bezierInsertPoleColBefore(2, poles: colPoles)
            #expect(ok1)
            #expect(surf.bezierNbVPoles == nbV + 1)
            #expect(samePoles(surf.bezierPoles, [
                SIMD3(0, 0, 0), SIMD3(0, 2.5, 1), SIMD3(0, 5, 0),
                SIMD3(10, 0, 0), SIMD3(1, 2.5, 1), SIMD3(10, 5, 0),
            ]))
            let nbV2 = surf.bezierNbVPoles
            let rowPoles = (0..<nbV2).map { i in SIMD3<Double>(-1.0, Double(i), 0.5) }
            #expect(!surf.bezierInsertPoleRowBefore(1, poles: rowPoles))
            // Before row 2: the new row lands between the two original rows.
            let ok2 = surf.bezierInsertPoleRowBefore(2, poles: rowPoles)
            #expect(ok2)
            #expect(surf.bezierNbUPoles == nbU + 1)
            #expect(samePoles(surf.bezierPoles, [
                SIMD3(0, 0, 0), SIMD3(0, 2.5, 1), SIMD3(0, 5, 0),
                SIMD3(-1, 0, 0.5), SIMD3(-1, 1, 0.5), SIMD3(-1, 2, 0.5),
                SIMD3(10, 0, 0), SIMD3(1, 2.5, 1), SIMD3(10, 5, 0),
            ]))
        }
    }

    @Test("SetPoleCol and SetPoleRow without weights")
    func setPoleColRow() {
        let surf = makeSurface()
        #expect(surf != nil)
        if let surf {
            let nbU = surf.bezierNbUPoles
            let nbV = surf.bezierNbVPoles
            // Set pole column
            let colPoles = (0..<nbU).map { i in SIMD3<Double>(Double(i) * 2.0, 0.0, 0.0) }
            let ok1 = surf.bezierSetPoleCol(vIndex: 1, poles: colPoles)
            #expect(ok1)
            #expect(samePoles(surf.bezierPoles, [SIMD3(0, 0, 0), SIMD3(0, 5, 0), SIMD3(2, 0, 0), SIMD3(10, 5, 0)]))
            // Set pole row
            let rowPoles = (0..<nbV).map { i in SIMD3<Double>(0.0, Double(i) * 3.0, 0.0) }
            let ok2 = surf.bezierSetPoleRow(uIndex: 1, poles: rowPoles)
            #expect(ok2)
            #expect(samePoles(surf.bezierPoles, [SIMD3(0, 0, 0), SIMD3(0, 3, 0), SIMD3(2, 0, 0), SIMD3(10, 5, 0)]))
        }
    }

    @Test("SetWeightCol and SetWeightRow")
    func setWeightColRow() {
        // Create a rational Bezier surface by setting pole with weight
        let surf = makeSurface()
        #expect(surf != nil)
        if let surf {
            let nbU = surf.bezierNbUPoles
            let nbV = surf.bezierNbVPoles

            // Make it rational via SetPoleColWeights (existing API)
            let initPoles = (0..<nbU).map { i in SIMD3<Double>(Double(i), 0.0, 0.0) }
            let initWeights = [Double](repeating: 2.0, count: nbU)
            #expect(surf.bezierSetPoleColWeights(vIndex: 1, poles: initPoles, weights: initWeights))
            #expect(surf.bezierWeights == [2, 1, 2, 1])
            // Now set weight column
            let colWeights = [Double](repeating: 1.5, count: nbU)
            let ok1 = surf.bezierSetWeightCol(vIndex: 1, weights: colWeights)
            #expect(ok1)
            #expect(surf.bezierWeights == [1.5, 1, 1.5, 1])
            // Set weight row
            let rowWeights = [Double](repeating: 1.2, count: nbV)
            let ok2 = surf.bezierSetWeightRow(uIndex: 1, weights: rowWeights)
            #expect(ok2)
            #expect(surf.bezierWeights == [1.2, 1.2, 1.5, 1])
        }
    }
}
