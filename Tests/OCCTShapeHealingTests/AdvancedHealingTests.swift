import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Advanced Healing Tests (v0.17.0)

@Suite("Advanced Healing Tests")
struct AdvancedHealingTests {

    @Test("Divide cylinder at C1")
    func divideCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        // A cylinder's lateral face is one smooth periodic surface, so nothing is below C1. Since
        // #2769 that no-op returns the input shape rather than nil.
        let divided = try #require(cyl.divided(at: .c1))
        #expect(divided.isValid)
        #expect(divided.isSame(as: cyl))
    }

    @Test("Direct faces on box")
    func directFacesBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.directFaces()
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Scale geometry by 2x")
    func scaleGeometry() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let originalVolume = box.volume ?? 0
        let scaled = box.scaledGeometry(factor: 2.0)
        #expect(scaled != nil)
        #expect(scaled!.isValid)
        let scaledVolume = scaled!.volume
        #expect(scaledVolume != nil)
        // Volume should be ~8x (2^3)
        #expect(abs(scaledVolume! - originalVolume * 8.0) < originalVolume * 0.1)
    }

    @Test("BSpline restriction on shape")
    func bsplineRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let restricted = box.bsplineRestriction()
        if let restricted = restricted {
            #expect(restricted.isValid)
        }
    }

    @Test("Convert to BSpline")
    func convertToBSpline() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let bspline = box.convertedToBSpline()
        #expect(bspline != nil)
        #expect(bspline!.isValid)
    }

    @Test("Swept to elementary on cylinder")
    func sweptToElementary() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.sweptToElementary()
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Sew disconnected faces")
    func sewFaces() {
        // Create a box and sew it - should return a valid shape
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.sewn(tolerance: 1e-6)
        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }

    @Test("Full upgrade pipeline")
    func upgradePipeline() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let upgraded = box.upgraded(tolerance: 1e-6)
        #expect(upgraded != nil)
        #expect(upgraded!.isValid)
    }
}
