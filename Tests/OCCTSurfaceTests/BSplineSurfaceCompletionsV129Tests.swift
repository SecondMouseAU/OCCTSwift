import Testing

@testable import OCCTSwift

@Suite("BSplineSurface Completions v129")
struct BSplineSurfaceCompletionsV129Tests {

    // #766: each test sat inside `if let bs` (and two inside a further size check), and three
    // asserted only the returned Bool, so an edit that did nothing passed. The sphere's BSpline
    // form is 6x5 rational poles on [0, 2 pi] x [-pi/2, pi/2], U knots all x2 and V knots
    // x3/x2/x3, which is already the maximum multiplicity at degree 2. Values are
    // Geom_BSplineSurface's own, see Scripts/repro/766-bspline-surface-completions/.
    private func sphereBSpline() -> Surface? {
        let bs = Surface.sphere(center: .zero, radius: 5)?.toBSpline()
        #expect(bs != nil, "sphere BSpline")
        return bs
    }

    @Test("SetWeightCol and SetWeightRow")
    func setWeightColRow() {
        if let bs = sphereBSpline() {
            let nbU = bs.bsplineSurface.nbUPoles
            let nbV = bs.bsplineSurface.nbVPoles
            if nbU > 0 && nbV > 0 {
                // Set weight column: all weights = 1.0
                let colWeights = [Double](repeating: 1.0, count: nbU)
                let ok1 = bs.bsplineSetWeightCol(vIndex: 1, weights: colWeights)
                #expect(ok1)

                let rowWeights = [Double](repeating: 1.0, count: nbV)
                let ok2 = bs.bsplineSetWeightRow(uIndex: 1, weights: rowWeights)
                #expect(ok2)
                // Column 1 was (1, 0.5, 1, 0.5, 1, 0.5) and row 1 (1, 0.7071, 1, 0.7071, 1).
                #expect((1...nbU).allSatisfy { bs.bsplineWeight(uIndex: $0, vIndex: 1) == 1 })
                #expect((1...nbV).allSatisfy { bs.bsplineWeight(uIndex: 1, vIndex: $0) == 1 })
                #expect(bs.bsplineWeight(uIndex: 2, vIndex: 2) == 0.35355339059327379)
            }
        }
    }

    @Test("IncrementUMultiplicity and IncrementVMultiplicity range")
    func incrementMultiplicity() {
        if let bs = sphereBSpline() {
            let nbUK = bs.bsplineSurface.nbUKnots
            let nbVK = bs.bsplineSurface.nbVKnots
            if nbUK >= 2 && nbVK >= 2 {
                let ok1 = bs.bsplineIncrementUMultiplicity(fromIndex: 1, toIndex: nbUK, step: 1)
                #expect(ok1)
                let ok2 = bs.bsplineIncrementVMultiplicity(fromIndex: 1, toIndex: nbVK, step: 1)
                #expect(ok2)
                // Every knot is already at the degree-2 maximum, so the kernel caps the step
                // and nothing changes.
                #expect(bs.bsplineUMultiplicities == [2, 2, 2, 2])
                #expect(bs.bsplineVMultiplicities == [3, 2, 3])
            }
        }
        // Where there is room the step lands: an inserted simple knot of the cubic fixture.
        let cubic = makeExplicitPoleBSplineSurface()
        #expect(cubic != nil)
        if let cubic {
            #expect(cubic.bsplineInsertUKnots([0.5], multiplicities: [1]))
            #expect(cubic.bsplineIncrementUMultiplicity(fromIndex: 2, toIndex: 2, step: 1))
            #expect(cubic.bsplineUMultiplicities == [4, 2, 4])
            #expect(cubic.bsplineInsertVKnots([0.5], multiplicities: [1]))
            #expect(cubic.bsplineIncrementVMultiplicity(fromIndex: 2, toIndex: 2, step: 1))
            #expect(cubic.bsplineVMultiplicities == [4, 2, 4])
        }
    }

    @Test("First/Last U/V KnotIndex")
    func knotIndices() {
        if let bs = sphereBSpline() {
            let firstU = bs.bsplineFirstUKnotIndex
            let lastU = bs.bsplineLastUKnotIndex
            let firstV = bs.bsplineFirstVKnotIndex
            let lastV = bs.bsplineLastVKnotIndex
            #expect(firstU == 1)
            #expect(lastU == 4)
            #expect(firstV == 1)
            #expect(lastV == 3)
        }
    }

    @Test("CheckAndSegment")
    func checkAndSegment() {
        if let bs = sphereBSpline() {
            // Segment within current bounds should succeed, and the bounds become the segment.
            let ok = bs.bsplineCheckAndSegment(u1: 0.0, u2: 1.0, v1: 0.0, v2: 1.0)
            #expect(ok)
            let b = bs.bsplineBounds
            #expect(b.u1 == 0 && b.u2 == 1 && b.v1 == 0 && b.v2 == 1)
        }
    }
}
