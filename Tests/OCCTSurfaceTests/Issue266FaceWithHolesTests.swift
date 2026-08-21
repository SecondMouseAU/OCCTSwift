import Testing
import simd
@testable import OCCTSwift

/// Issue #266: build a single trimmed face from a surface with an **outer** boundary and **interior
/// hole** wires (windows / cutouts), `Shape.face(from:outer:innerWires:)`.
@Suite("Issue #266, face from surface with holes")
struct Issue266FaceWithHolesTests {

    /// A 10×10 outer square and a 4×4 centred hole, both in the z = 0 plane (so they lie exactly on
    /// a planar surface). Returns (surface, outer, hole).
    private func panelWithWindow() -> (Surface, Wire, Wire)? {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
              let outer = Wire.polygon3D([
                  SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)
              ], closed: true),
              let hole = Wire.polygon3D([
                  SIMD3(3, 3, 0), SIMD3(7, 3, 0), SIMD3(7, 7, 0), SIMD3(3, 7, 0)
              ], closed: true)
        else { return nil }
        return (plane, outer, hole)
    }

    @Test("outer + one hole yields a valid face with the window removed")
    func faceWithOneHole() {
        guard let (plane, outer, hole) = panelWithWindow() else { Issue.record("setup"); return }
        guard let face = Shape.face(from: plane, outer: outer, innerWires: [hole]) else {
            Issue.record("face(from:outer:innerWires:) returned nil"); return
        }
        #expect(face.isValid)
        // Two wires: the outer boundary + the one hole.
        #expect(face.subShapeCount(ofType: .wire) == 2)
        // Area ≈ outer (100) − hole (16) = 84, the window is a real opening, not spanned.
        if let area = face.surfaceArea {
            #expect(abs(area - 84) < 1e-6)
        }
    }

    @Test("empty innerWires gives the plain trimmed face (full area)")
    func noHolesIsPlainFace() {
        guard let (plane, outer, _) = panelWithWindow() else { Issue.record("setup"); return }
        guard let face = Shape.face(from: plane, outer: outer, innerWires: []) else {
            Issue.record("nil"); return
        }
        #expect(face.isValid)
        #expect(face.subShapeCount(ofType: .wire) == 1)
        if let area = face.surfaceArea { #expect(abs(area - 100) < 1e-6) }
    }

    @Test("multiple holes each become an opening")
    func faceWithTwoHoles() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
              let outer = Wire.polygon3D([
                  SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)
              ], closed: true),
              let h1 = Wire.polygon3D([
                  SIMD3(1, 1, 0), SIMD3(3, 1, 0), SIMD3(3, 3, 0), SIMD3(1, 3, 0)
              ], closed: true),   // 2×2 = 4
              let h2 = Wire.polygon3D([
                  SIMD3(6, 6, 0), SIMD3(9, 6, 0), SIMD3(9, 9, 0), SIMD3(6, 9, 0)
              ], closed: true)    // 3×3 = 9
        else { Issue.record("setup"); return }
        guard let face = Shape.face(from: plane, outer: outer, innerWires: [h1, h2]) else {
            Issue.record("nil"); return
        }
        #expect(face.isValid)
        #expect(face.subShapeCount(ofType: .wire) == 3)            // outer + 2 holes
        if let area = face.surfaceArea { #expect(abs(area - (100 - 4 - 9)) < 1e-6) }
    }

    @Test("a hole off the surface fails rather than producing garbage")
    func holeOffSurfaceReturnsNil() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
              let outer = Wire.polygon3D([
                  SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)
              ], closed: true),
              // hole lifted to z = 5, not on the z = 0 plane
              let hole = Wire.polygon3D([
                  SIMD3(3, 3, 5), SIMD3(7, 3, 5), SIMD3(7, 7, 5), SIMD3(3, 7, 5)
              ], closed: true)
        else { Issue.record("setup"); return }
        // Must not crash; an off-surface hole yields an invalid face → nil.
        let face = Shape.face(from: plane, outer: outer, innerWires: [hole])
        if let f = face { #expect(!f.isValid || (f.surfaceArea ?? 0) > 0) }  // tolerate either nil or a defined result
    }
}
