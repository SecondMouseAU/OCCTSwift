import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Continuity Queries v0.120.0")
struct SurfaceContinuityQueriesTests {

    func makePlane() -> Surface? {
        Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
    }

    @Test func isCNu() {
        if let s = makePlane() {
            #expect(s.isCNu(0))
            #expect(s.isCNu(1))
            #expect(s.isCNu(2))
        }
    }

    @Test func isCNv() {
        if let s = makePlane() {
            #expect(s.isCNv(0))
            #expect(s.isCNv(1))
            #expect(s.isCNv(2))
        }
    }

    @Test func uReversed() {
        if let s = makePlane() {
            let rev = s.uReversed()
            #expect(rev != nil)
        }
    }

    @Test func vReversed() {
        if let s = makePlane() {
            let rev = s.vReversed()
            #expect(rev != nil)
        }
    }

    @Test func uReversedParameter() {
        if let s = makePlane() {
            let rp = s.uReversedParameter(0.5)
            // Just verify it returns a finite value
            #expect(rp.isFinite)
        }
    }

    @Test func vReversedParameter() {
        if let s = makePlane() {
            let rp = s.vReversedParameter(0.5)
            #expect(rp.isFinite)
        }
    }

    @Test func bezierMaxDegree() {
        let md = Surface.bezierMaxDegree
        #expect(md >= 25)
    }

    @Test func bsplineMaxDegree() {
        let md = Surface.bsplineMaxDegree
        #expect(md >= 25)
    }
}
