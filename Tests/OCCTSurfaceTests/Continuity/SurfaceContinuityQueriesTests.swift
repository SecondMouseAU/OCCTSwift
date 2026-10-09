import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Continuity Queries v0.120.0")
struct SurfaceContinuityQueriesTests {

    // #766: every test sat inside `if let s = makePlane()`, so a nil plane passed, and four
    // checked only non-nil, `isFinite`, or `>= 25`. They now pin the kernel's answers on the same
    // GC_MakePlane z = 0 plane, see Scripts/repro/766-surface-continuity/.
    func makePlane() -> Surface? {
        let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(s != nil, "plane")
        return s
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
            // Reversing U maps (3, 4) to (-3, 4, 0).
            if let rev { #expect(rev.point(atU: 3, v: 4) == SIMD3(-3, 4, 0)) }
        }
    }

    @Test func vReversed() {
        if let s = makePlane() {
            let rev = s.vReversed()
            #expect(rev != nil)
            if let rev { #expect(rev.point(atU: 3, v: 4) == SIMD3(3, -4, 0)) }
        }
    }

    @Test func uReversedParameter() {
        if let s = makePlane() {
            let rp = s.uReversedParameter(0.5)
            // Was `isFinite`. A plane's reversed parameter is -u.
            #expect(rp == -0.5)
        }
    }

    @Test func vReversedParameter() {
        if let s = makePlane() {
            let rp = s.vReversedParameter(0.5)
            #expect(rp == -0.5)
        }
    }

    @Test func bezierMaxDegree() {
        let md = Surface.bezierMaxDegree
        #expect(md == 25)
    }

    @Test func bsplineMaxDegree() {
        let md = Surface.bsplineMaxDegree
        #expect(md == 25)
    }
}
