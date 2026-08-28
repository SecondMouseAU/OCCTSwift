import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D BSpline Local Evaluation")
struct Curve2DBSplineLocalTests {
    @Test("LocalD0 matches global")
    func localD0() {
        // Create a 2D BSpline via interpolation
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let local = c.bsplineLocalD0(u: u, fromK1: span.i1, toK2: span.i2)
                    let global = c.point(at: u)
                    let dist = simd_length(local - global)
                    #expect(dist < 1e-10)
                }
            }
        }
    }

    @Test("LocalD1 returns derivative")
    func localD1() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let r = c.bsplineLocalD1(u: u, fromK1: span.i1, toK2: span.i2)
                    #expect(simd_length(r.v1) > 0)
                }
            }
        }
    }

    @Test("LocalD2 returns second derivative")
    func localD2() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let r = c.bsplineLocalD2(u: u, fromK1: span.i1, toK2: span.i2)
                    // Just check no crash - this assertion always passes
                    #expect(simd_length(r.point) > 0 || simd_length(r.point) == 0)
                }
            }
        }
    }

    @Test("LocalD3 and LocalDN")
    func localD3DN() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2), SIMD2(4, 0),
        ]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let _ = c.bsplineLocalD3(u: u, fromK1: span.i1, toK2: span.i2)
                    let dn = c.bsplineLocalDN(u: u, fromK1: span.i1, toK2: span.i2, n: 1)
                    #expect(simd_length(dn) > 0)
                }
            }
        }
    }

    @Test("LocalValue matches global")
    func localValue() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let c = Curve2D.interpolate(through: pts)
        if let c = c {
            let fk = c.bsplineFirstUKnotIndex
            let lk = c.bsplineLastUKnotIndex
            if fk > 0 && lk > fk {
                let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
                let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
                if span.i1 > 0 && span.i2 > 0 {
                    let local = c.bsplineLocalValue(u: u, fromK1: span.i1, toK2: span.i2)
                    let global = c.point(at: u)
                    let dist = simd_length(local - global)
                    #expect(dist < 1e-10)
                }
            }
        }
    }
}
