import Testing
import simd
@testable import OCCTSwift

/// Issue #484: `Face.fixed(tolerance:)` was the fourth `ShapeFix_Face` construction in the bridge
/// and the only one the #317 pass missed — it built a bare `ShapeFix_Face` with no
/// `SetContext(new ShapeBuild_ReShape)`, leaving it exposed to the #317 mechanism
/// (`FixPeriodicDegenerated` null-dereferencing `Context()`) on any unpatched kernel, and silently
/// skipping the context-dependent fixes on a patched one. The only #317 regression test
/// (`Issue317PeriodicConicalSingleWireTests`) covers `Shape.face(from:boundary:)`, a different call
/// site.
///
/// These tests pin both halves: the #317 crash shape now goes through `Face.fixed(tolerance:)`, and
/// ordinary faces must be unaffected by the added context (the real risk of the change).
@Suite("Issue #484 — Face.fixed(tolerance:) gets a ReShape context")
struct Issue484FaceFixContextTests {

    /// The #317 shape — a single closed periodic curve belting a cone's full period — driven through
    /// the `Face.fixed(tolerance:)` call site rather than `Shape.face(from:boundary:)`.
    @Test("Face.fixed on a periodic conical single-wire face survives and stays valid")
    func periodicConicalFaceSurvivesFaceFix() {
        let ringPoints: [SIMD3<Double>] = (0..<8).map { i in
            let angle = 2 * Double.pi * Double(i) / 8
            return SIMD3(0.14 * cos(angle), 4.0 + 0.14 * sin(angle), -9.6)
        }
        guard let curve = Curve3D.interpolate(points: ringPoints, closed: true) else {
            Issue.record("interpolate"); return
        }
        guard let edgeShape = Shape.edgeFromCurve(curve), let edge = Edge(edgeShape) else {
            Issue.record("edgeFromCurve"); return
        }
        guard let wire = Wire.wireFromEdges([edge]) else {
            Issue.record("wireFromEdges"); return
        }
        guard let cone = Surface.cone(origin: SIMD3(0, 4.0, -9.1), axis: SIMD3(0, 0.09, -1.0),
                                      radius: 0, semiAngle: 0.35) else {
            Issue.record("cone"); return
        }
        guard let faceShape = Shape.face(from: cone, boundary: wire) else {
            Issue.record("face(from:boundary:)"); return
        }
        guard let face = faceShape.faces().first else {
            Issue.record("no face in the healed shape"); return
        }

        // The call site under test. Before the fix this ran with a null Context(), which is the
        // #317 null-deref on any kernel without Scripts/patches/0005.
        guard let fixed = face.fixed(tolerance: 1e-6) else {
            Issue.record("Face.fixed returned nil"); return
        }
        #expect(fixed.isValid)
        #expect(fixed.faces().count == 1)
    }

    /// A conical face whose sole wire belts the full period, built through
    /// `Surface.toFace(uvBoundary:)` — the one face factory that applies no healing at all, so the
    /// face reaches `Face.fixed(tolerance:)` in its raw state.
    @Test("Face.fixed on an unhealed full-period conical UV face returns a face")
    func unhealedPeriodicConicalUVFaceSurvivesFaceFix() {
        guard let cone = Surface.cone(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
                                      radius: 2.0, semiAngle: 0.4636476) else {
            Issue.record("cone"); return
        }
        let belt: [SIMD2<Double>] = (0..<8).map { SIMD2(2 * Double.pi * Double($0) / 8, 3.0) }
        guard let faceShape = cone.toFace(uvBoundary: belt) else {
            Issue.record("toFace(uvBoundary:)"); return
        }
        guard let face = faceShape.faces().first else {
            Issue.record("no face"); return
        }
        // No validity claim: this input is degenerate by construction (one wire belting a cone's
        // period, no apex edge). What matters is that the call completes and returns a face.
        guard let fixed = face.fixed(tolerance: 1e-6) else {
            Issue.record("Face.fixed returned nil"); return
        }
        #expect(fixed.faces().count == 1)
    }

    /// The context is added unconditionally, so the guard against regression is that ordinary,
    /// already-well-formed faces come back unchanged and valid.
    @Test("Face.fixed leaves well-formed box faces valid")
    func wellFormedBoxFacesUnaffected() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("box"); return
        }
        let faces = box.faces()
        #expect(faces.count == 6)
        for face in faces {
            guard let fixed = face.fixed(tolerance: 1e-6) else {
                Issue.record("Face.fixed returned nil for a box face"); continue
            }
            #expect(fixed.isValid)
            #expect(fixed.faces().count == 1)
        }
    }

    /// Same guard for an analytic curved face, where a seam is involved.
    @Test("Face.fixed leaves cylinder faces valid")
    func cylinderFacesUnaffected() {
        guard let cyl = Shape.cylinder(radius: 5, height: 12) else {
            Issue.record("cylinder"); return
        }
        for face in cyl.faces() {
            guard let fixed = face.fixed(tolerance: 1e-6) else {
                Issue.record("Face.fixed returned nil for a cylinder face"); continue
            }
            #expect(fixed.isValid)
        }
    }
}
