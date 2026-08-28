import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeHyperbola Tests")
struct GCMakeHyperbolaTests {

    @Test func hyperbolaFromAxisAndRadii() {
        let h = Curve3D.gcHyperbola(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 5)
        #expect(h != nil)
    }
}

