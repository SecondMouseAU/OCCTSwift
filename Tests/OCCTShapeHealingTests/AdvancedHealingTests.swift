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

    // #766: `divided(at:)` answers nil for two different reasons, `Perform()` returning false ("no
    // divisions needed") and a bridge failure (a caught OCCT exception, or a bridge that returns
    // nothing), so `== nil` on its own could not tell the kernel's answer from a failure. Two
    // things separate them. No exception was caught while the cylinder call ran, so its nil is not
    // an error. And the same call on a face that does need dividing, the C0 B-spline face of
    // Issue #438 (4 faces at C1, measured against the kernel in
    // Scripts/repro/766-healing-advanced/), returns a shape, so nil is not what the bridge says to
    // everything.
    @Test("Divide cylinder at C1")
    func divideCylinder() throws {
        // ShapeUpgrade_ShapeDivideContinuity finds nothing below C1 on a primitive cylinder:
        // Perform() returns false, which the bridge reports as nil ("no divisions needed").
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let (divided, diagnostics) = OCCTDiagnostics.capturing { cyl.divided(at: .c1) }
        #expect(divided == nil)
        #expect(diagnostics.isEmpty, "the nil must be Perform() false, not a caught exception")
        let kinked = try #require(kinkedSurfaceFace())
        let control = try #require(kinked.divided(at: .c1, tolerance: 1e-4))
        #expect(control.faceCount == 4)
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

    /// The fixture of `Issue438DivideContinuityUnificationTests.kinkedSurfaceFace`: a cubic B-spline
    /// surface with a multiplicity-3 interior knot in both U and V, so it is genuinely C0 there and
    /// a C1 divider has something to divide.
    private func kinkedSurfaceFace() -> Shape? {
        let degree = 3
        let interiorKnots = 4
        let bumpAt = 2
        let bumpMult = 3
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(i == bumpAt ? bumpMult : 1))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))
        let poleCount = Int(mults.reduce(0, +)) - degree - 1
        guard
            let surface = Surface.bspline(
                poles: (0..<poleCount).map { u in
                    (0..<poleCount).map { v in
                        SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3) * 0.5)
                    }
                },
                knotsU: knots, multiplicitiesU: mults,
                knotsV: knots, multiplicitiesV: mults,
                degreeU: degree, degreeV: degree)
        else { return nil }
        let bounds = surface.domain
        return Shape.face(
            from: surface, uRange: bounds.uMin...bounds.uMax, vRange: bounds.vMin...bounds.vMax)
    }
}
