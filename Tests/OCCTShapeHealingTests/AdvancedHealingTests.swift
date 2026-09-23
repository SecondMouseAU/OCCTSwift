import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Advanced Healing Tests (v0.17.0)

// #766: every expected value below is the kernel's own answer to the same call, from
// Scripts/repro/766-healing-advanced/probe.mm (transcript.txt beside it). Before #766 two of
// these could not fail: divideCylinder asserted only inside `if let` on a result the kernel
// never produces, and the rest asserted non-nil and valid on operations that hand a box back
// unchanged, so a bridge that skipped the operation read as green.

/// Faces per surface kind, for pinning what a ShapeCustom pass did to each face.
private func surfaceKinds(_ shape: Shape) -> [Surface.SurfaceType: Int] {
    var counts: [Surface.SurfaceType: Int] = [:]
    for face in shape.faces() { counts[face.surfaceType, default: 0] += 1 }
    return counts
}

@Suite("Advanced Healing Tests")
struct AdvancedHealingTests {

    @Test("Divide cylinder at C1")
    func divideCylinder() throws {
        // ShapeUpgrade_ShapeDivideContinuity finds nothing below C1 on a primitive cylinder:
        // Perform() returns false, which the bridge reports as nil ("no divisions needed").
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.divided(at: .c1) == nil)
    }

    @Test("Direct faces on box")
    func directFacesBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(box.directFaces())
        #expect(r.isValid)
        #expect(surfaceKinds(r) == [.plane: 6])
        #expect(abs((r.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("Scale geometry by 2x")
    func scaleGeometry() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let scaled = try #require(box.scaledGeometry(factor: 2.0))
        #expect(scaled.isValid)
        // Kernel: ShapeCustom::ScaleShape(box, 2) has volume 8000.000000000.
        #expect(abs((scaled.volume ?? 0) - 8000) < 1e-6)
    }

    @Test("BSpline restriction on shape")
    func bsplineRestriction() throws {
        // Planes are not approximated (ShapeCustom_RestrictionParameters::ConvertPlane is off),
        // so the kernel returns the box's six planes and its volume unchanged.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let restricted = try #require(box.bsplineRestriction())
        #expect(restricted.isValid)
        #expect(surfaceKinds(restricted) == [.plane: 6])
        #expect(abs((restricted.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("Convert to BSpline")
    func convertToBSpline() throws {
        // planeMode is false in the bridge, so planes stay planes (kernel: plane=6).
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let bspline = try #require(box.convertedToBSpline())
        #expect(bspline.isValid)
        #expect(surfaceKinds(bspline) == [.plane: 6])
    }

    @Test("Swept to elementary on cylinder")
    func sweptToElementary() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let r = try #require(cyl.sweptToElementary())
        #expect(r.isValid)
        #expect(surfaceKinds(r) == [.plane: 2, .cylinder: 1])
        #expect(abs((r.volume ?? 0) - 785.398163397) < 1e-6)
    }

    @Test("Sew disconnected faces")
    func sewFaces() throws {
        // Sewing yields a closed shell (kernel: type=3); the bridge then makes it a solid.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sewn = try #require(box.sewn(tolerance: 1e-6))
        #expect(sewn.isValid)
        #expect(sewn.shapeType == .solid)
        #expect(abs((sewn.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("Full upgrade pipeline")
    func upgradePipeline() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let upgraded = try #require(box.upgraded(tolerance: 1e-6))
        #expect(upgraded.isValid)
        #expect(upgraded.shapeType == .solid)
        #expect(abs((upgraded.volume ?? 0) - 1000) < 1e-9)
    }
}
