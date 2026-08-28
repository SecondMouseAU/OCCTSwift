import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D BSpline Knot Queries")
struct Curve2DBSplineKnotQueryTests {
    @Test("FirstUKnotIndex and LastUKnotIndex")
    func knotIndices() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            #expect(fk > 0)
            #expect(lk >= fk)
        }
    }

    @Test("Knot value by index")
    func knotValue() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            // Index 1 is always valid for a BSpline with knots
            let k = c.bsplineKnot(index: 1)
            #expect(k.isFinite)
        }
    }

    @Test("KnotDistribution")
    func knotDistribution() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let d = c.bsplineKnotDistribution
            #expect(d >= 0 && d <= 3)
        }
    }

    @Test("Multiplicity by index")
    func multiplicity() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let m = c.bsplineMultiplicity(index: 1)
            #expect(m > 0)
        }
    }

    @Test("GetMultiplicities bulk")
    func multiplicities() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let mults = c.bsplineMultiplicities
            #expect(mults.count > 0)
            if let first = mults.first {
                #expect(first > 0)
            }
        }
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let sp = c.bsplineStartPoint
            let ep = c.bsplineEndPoint
            #expect(abs(sp.x - 0) < 1e-6)
            #expect(abs(sp.y - 0) < 1e-6)
            #expect(abs(ep.x - 2) < 1e-6)
            #expect(abs(ep.y - 0) < 1e-6)
        }
    }

    @Test("GetPoles bulk")
    func poles() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let poles = c.bsplinePoles
            let count = c.poleCount ?? 0
            #expect(poles.count == count)
        }
    }

    @Test("IsClosed and IsPeriodic")
    func closedPeriodic() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            #expect(!c.bsplineIsClosed)
            #expect(!c.bsplineIsPeriodic)
        }
    }

    @Test("Continuity and IsCN")
    func continuity() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let cont = c.bsplineContinuity
            #expect(cont >= 0)
            #expect(c.bsplineIsCN(0))
        }
    }
}
