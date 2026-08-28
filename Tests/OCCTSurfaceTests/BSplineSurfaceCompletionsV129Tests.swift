import Testing

@testable import OCCTSwift

@Suite("BSplineSurface Completions v129")
struct BSplineSurfaceCompletionsV129Tests {

    @Test("SetWeightCol and SetWeightRow")
    func setWeightColRow() {
        // Create a BSpline surface from a sphere
        let sphere = Surface.sphere(center: .zero, radius: 5)
        if let bs = sphere?.toBSpline() {
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
            }
        }
    }

    @Test("IncrementUMultiplicity and IncrementVMultiplicity range")
    func incrementMultiplicity() {
        let sphere = Surface.sphere(center: .zero, radius: 5)
        if let bs = sphere?.toBSpline() {
            let nbUK = bs.bsplineSurface.nbUKnots
            let nbVK = bs.bsplineSurface.nbVKnots
            if nbUK >= 2 && nbVK >= 2 {
                let ok1 = bs.bsplineIncrementUMultiplicity(fromIndex: 1, toIndex: nbUK, step: 1)
                #expect(ok1)
                let ok2 = bs.bsplineIncrementVMultiplicity(fromIndex: 1, toIndex: nbVK, step: 1)
                #expect(ok2)
            }
        }
    }

    @Test("First/Last U/V KnotIndex")
    func knotIndices() {
        let sphere = Surface.sphere(center: .zero, radius: 5)
        if let bs = sphere?.toBSpline() {
            let firstU = bs.bsplineFirstUKnotIndex
            let lastU = bs.bsplineLastUKnotIndex
            let firstV = bs.bsplineFirstVKnotIndex
            let lastV = bs.bsplineLastVKnotIndex
            #expect(firstU >= 1)
            #expect(lastU >= firstU)
            #expect(firstV >= 1)
            #expect(lastV >= firstV)
        }
    }

    @Test("CheckAndSegment")
    func checkAndSegment() {
        let sphere = Surface.sphere(center: .zero, radius: 5)
        if let bs = sphere?.toBSpline() {
            // Segment within current bounds should succeed
            let ok = bs.bsplineCheckAndSegment(u1: 0.0, u2: 1.0, v1: 0.0, v2: 1.0)
            #expect(ok)
        }
    }
}
