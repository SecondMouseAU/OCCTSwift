import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeEllipse Tests")
struct GCMakeEllipseTests {

    @Test func ellipseFromAxisAndRadii() {
        let e = Curve3D.gcEllipse(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }

    @Test func ellipseFromFullAx2() {
        let e = Curve3D.gcEllipse(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }
}

