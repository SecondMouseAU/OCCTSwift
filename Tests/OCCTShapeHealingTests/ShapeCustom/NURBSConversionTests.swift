import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("NURBS Conversion")
struct NURBSConversionTests {
    @Test("Convert box to NURBS")
    func convertBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let nurbs = box.convertedToNURBS()
        #expect(nurbs != nil)
        #expect(nurbs!.isValid)
    }

    @Test("Convert sphere to NURBS")
    func convertSphere() {
        let sphere = Shape.sphere(radius: 5)!
        let nurbs = sphere.convertedToNURBS()
        #expect(nurbs != nil)
        #expect(nurbs!.isValid)
    }

    @Test("Convert filleted box to NURBS")
    func convertFilleted() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1)!
        let nurbs = filleted.convertedToNURBS()
        #expect(nurbs != nil)
        #expect(nurbs!.isValid)
    }
}
