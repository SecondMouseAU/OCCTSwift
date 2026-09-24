import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Face Surface Properties Tests (v0.18.0)

/// Every expected value below is the pinned kernel's own answer for the same input, measured by
/// `Scripts/repro/766-face-surface-properties/probe.mm` (transcript alongside it). Before #766 these
/// tests asserted only `!= nil`, `uMax > uMin`, a largest normal component above 0.99, or curvature
/// magnitudes, so a bridge that swapped u for v, dropped the face-orientation reversal, negated a
/// curvature or returned `kMax` as `kMin` passed all of them.
///
/// Geometry the values depend on: `Shape.box` is centred, so the 10-unit box spans -5...5 and its
/// `faces()[0]` is the x = -5 plane, stored REVERSED, with UV bounds [0, 10] x [-10, 0].
/// `Shape.sphere` and `Shape.cylinder` are OCCT's canonical primitives at the origin; the sphere's
/// UV midpoint (pi, 0) and the cylinder's lateral midpoint (pi, 5) both land on the -X side.
@Suite("Face Surface Properties Tests")
struct FaceSurfacePropertiesTests {

    /// `faces()[0]` of the centred 10-unit box, the x = -5 cap.
    private func boxXCap() -> Face? {
        Shape.box(width: 10, height: 10, depth: 10)?.faces().first
    }

    @Test("UV bounds of box face")
    func uvBoundsBoxFace() {
        guard let face = boxXCap() else {
            Issue.record("could not build the box x cap")
            return
        }
        guard let b = face.uvBounds else {
            Issue.record("a planar box face has UV bounds")
            return
        }
        // Probed: BRepTools::UVBounds gives u in [0, 10], v in [-10, 0] for this face.
        #expect(abs(b.uMin - 0) < 1e-9, "uMin: expected 0, got \(b.uMin)")
        #expect(abs(b.uMax - 10) < 1e-9, "uMax: expected 10, got \(b.uMax)")
        #expect(abs(b.vMin - (-10)) < 1e-9, "vMin: expected -10, got \(b.vMin)")
        #expect(abs(b.vMax - 0) < 1e-9, "vMax: expected 0, got \(b.vMax)")
    }

    @Test("Evaluate point on box face at UV center")
    func evaluatePointOnBoxFace() {
        guard let face = boxXCap(), let bounds = face.uvBounds else {
            Issue.record("could not build the box x cap or read its UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        guard let pt = face.point(atU: uMid, v: vMid) else {
            Issue.record("a planar face evaluates at its own UV centre")
            return
        }
        // The UV centre of the x = -5 cap is the centre of that cap.
        #expect(abs(pt.x - (-5)) < 1e-9, "x: expected -5, got \(pt.x)")
        #expect(abs(pt.y) < 1e-9, "y: expected 0, got \(pt.y)")
        #expect(abs(pt.z) < 1e-9, "z: expected 0, got \(pt.z)")
    }

    @Test("Normal at UV on box face is axis-aligned")
    func normalAtUVBoxFace() {
        guard let face = boxXCap(), let bounds = face.uvBounds else {
            Issue.record("could not build the box x cap or read its UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        guard let n = face.normal(atU: uMid, v: vMid) else {
            Issue.record("a planar face has a normal at its UV centre")
            return
        }
        // The face is REVERSED, so the outward normal is the surface normal flipped: -X.
        // The old `max(|n|) > 0.99` accepted +X too, i.e. a bridge ignoring orientation.
        #expect(abs(n.x - (-1)) < 1e-9, "x: expected -1 (outward from the x = -5 cap), got \(n.x)")
        #expect(abs(n.y) < 1e-9, "y: expected 0, got \(n.y)")
        #expect(abs(n.z) < 1e-9, "z: expected 0, got \(n.z)")
    }

    @Test("Gaussian curvature of plane face is zero")
    func gaussianCurvaturePlane() {
        guard let face = boxXCap(), let bounds = face.uvBounds else {
            Issue.record("could not build the box x cap or read its UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        guard let gc = face.gaussianCurvature(atU: uMid, v: vMid) else {
            Issue.record("curvature is defined on a plane")
            return
        }
        #expect(abs(gc) < 1e-10, "expected 0, got \(gc)")
    }

    @Test("Gaussian curvature of sphere is 1/r²")
    func gaussianCurvatureSphere() {
        let radius = 5.0
        guard let face = Shape.sphere(radius: radius)?.faces().first, let bounds = face.uvBounds
        else {
            Issue.record("could not build the sphere face or read its UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        guard let gc = face.gaussianCurvature(atU: uMid, v: vMid) else {
            Issue.record("curvature is defined on a sphere away from its poles")
            return
        }
        // Probed: 0.040000000000000008. Gaussian curvature is sign-free for a sphere.
        let expected = 1.0 / (radius * radius)
        #expect(abs(gc - expected) < 1e-12, "expected \(expected), got \(gc)")
    }

    @Test("Mean curvature of sphere is 1/r")
    func meanCurvatureSphere() {
        let radius = 5.0
        guard let face = Shape.sphere(radius: radius)?.faces().first, let bounds = face.uvBounds
        else {
            Issue.record("could not build the sphere face or read its UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        guard let mc = face.meanCurvature(atU: uMid, v: vMid) else {
            Issue.record("curvature is defined on a sphere away from its poles")
            return
        }
        // Mean curvature is signed. OCCT's sphere normal points outward and the surface bends
        // away from it, so the kernel reports -1/r (probed: -0.20000000000000001). The old
        // `abs(abs(mc) - 1/r)` accepted a bridge that negated it.
        let expected = -1.0 / radius
        #expect(abs(mc - expected) < 1e-12, "expected \(expected), got \(mc)")
    }

    @Test("Principal curvatures of cylinder")
    func principalCurvaturesCylinder() {
        let radius = 5.0
        guard let cyl = Shape.cylinder(radius: radius, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        guard let face = cyl.faces().first(where: { $0.surfaceType == .cylinder }) else {
            Issue.record("a cylinder has a cylindrical face")
            return
        }
        guard let bounds = face.uvBounds else {
            Issue.record("the lateral face has UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        guard let pc = face.principalCurvatures(atU: uMid, v: vMid) else {
            Issue.record("curvature is defined on a cylinder")
            return
        }
        // Signed, per #1437: the circumferential curvature is -1/r and is the minimum, the axial
        // curvature is 0 and is the maximum. The old test compared min/max of the magnitudes,
        // which also passed with kMin and kMax exchanged.
        #expect(abs(pc.kMin - (-1.0 / radius)) < 1e-12, "kMin: expected -0.2, got \(pc.kMin)")
        #expect(abs(pc.kMax) < 1e-12, "kMax: expected 0, got \(pc.kMax)")
    }

    /// #1437: `OCCTFaceGetPrincipalCurvatures` paired `dirMin`/`dirMax` with the wrong OCCT
    /// output, exactly transposed (`GeomLProp_SLProps::CurvatureDirections(gp_Dir& MaxD, gp_Dir&
    /// MinD)` takes the MAXIMUM direction first). `principalCurvaturesCylinder` above only ever
    /// asserted the magnitudes, never the directions, so the swap went uncaught.
    ///
    /// The fix makes `kMin`/`dirMin` and `kMax`/`dirMax` internally consistent (each direction
    /// paired with its own curvature value), which is the property this test actually checks,
    /// **not** a fixed claim about which of `dirMin`/`dirMax` is axial. A first version of this
    /// test assumed `dirMin` is always axial, reasoning that axial curvature (0) is numerically
    /// smaller than circumferential (~1/r). That assumption is wrong: `MinCurvature()`/
    /// `MaxCurvature()` are signed, and a ground-truth probe against the pinned kernel
    /// (`BRepPrimAPI_MakeCylinder`'s own lateral face, r=5) shows the circumferential curvature
    /// comes back **negative** (-0.2) under OCCT's chosen normal convention, making it the true
    /// minimum, with axial (exactly 0) the true maximum: the reverse of the naive assumption.
    /// So this test locates the axial/circumferential pair by curvature magnitude instead of by
    /// position, and confirms each pairing is self-consistent (whichever curvature is ~0 has the
    /// ~Z direction; whichever is ~1/r has the in-plane direction), which is exactly what the
    /// swap being fixed makes true and what being transposed would make false.
    @Test("Principal curvature directions of cylinder are not transposed")
    func principalCurvatureDirectionsCylinderNotTransposed() throws {
        let radius = 5.0
        let cyl = try #require(Shape.cylinder(radius: radius, height: 10))
        let cylFace = try #require(cyl.faces().first { $0.surfaceType == .cylinder })
        let bounds = try #require(cylFace.uvBounds)
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let pc = try #require(cylFace.principalCurvatures(atU: uMid, v: vMid))

        // Identify the axial pair by curvature magnitude (~0), not by min/max position.
        let (axialCurv, axialDir, circumCurv, circumDir): (Double, SIMD3<Double>, Double, SIMD3<Double>) =
            abs(pc.kMin) < abs(pc.kMax)
            ? (pc.kMin, pc.dirMin, pc.kMax, pc.dirMax)
            : (pc.kMax, pc.dirMax, pc.kMin, pc.dirMin)

        #expect(abs(axialCurv) < 1e-6, "the near-zero curvature should be axial, got \(axialCurv)")
        #expect(
            abs(abs(axialDir.z) - 1.0) < 1e-6,
            "the direction paired with the near-zero curvature should be axial (|z| ~ 1), got \(axialDir)"
        )
        #expect(
            abs(abs(circumCurv) - 1.0 / radius) < 1e-6,
            "the other curvature should be circumferential (~1/r), got \(circumCurv)"
        )
        #expect(
            abs(circumDir.z) < 1e-6,
            "the direction paired with the circumferential curvature should lie in the XY plane (z ~ 0), got \(circumDir)"
        )
    }

    @Test("Surface type detection")
    func surfaceTypeDetection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let cyl = Shape.cylinder(radius: 5, height: 10)
        else {
            Issue.record("could not build the box or the cylinder")
            return
        }
        // Every one of a box's six faces is planar, not just faces()[0].
        let boxTypes = box.faces().map(\.surfaceType)
        #expect(boxTypes == Array(repeating: .plane, count: 6), "got \(boxTypes)")

        // Probed face order: the lateral cylinder, then the top and bottom planes. The old
        // test only asked whether any face was a cylinder.
        let cylTypes = cyl.faces().map(\.surfaceType)
        #expect(cylTypes == [.cylinder, .plane, .plane], "got \(cylTypes)")
    }

    @Test("Face area of box face")
    func faceAreaBox() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let areas = box.faces().map { $0.area() }
        #expect(areas.count == 6, "a box has six faces, got \(areas.count)")

        // Probed, per face in faces() order: the two x caps are 20x30, the two y caps 10x30,
        // the two z caps 10x20. Checking each face, not only the sum, pins which is which.
        let expected: [Double] = [600, 600, 300, 300, 200, 200]
        if areas.count == expected.count {
            for (i, (got, want)) in zip(areas, expected).enumerated() {
                #expect(abs(got - want) < 1e-9, "face \(i): expected \(want), got \(got)")
            }
        }
        let total = areas.reduce(0, +)
        #expect(abs(total - 2200.0) < 1e-9, "2*(10*20 + 10*30 + 20*30) = 2200, got \(total)")
    }
}
