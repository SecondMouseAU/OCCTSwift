import Testing
import simd
@testable import OCCTSwift

/// #266 follow-up: ShapeAnalysis_Surface extras (UVFromIso / Singularity-detail / ProjectDegenerated
/// / domain-restricted projection) and BRepGProp_Face integration introspection.
@Suite("Issue #266 follow-up — surface analysis extras")
struct Issue266FaceAnalysisFollowupTests {

    @Test("UVFromIso refines (u,v) for a point on a cylinder")
    func uvFromIsoOnCylinder() {
        guard let cyl = Surface.cylindricalSurface(radius: 5) else { Issue.record("surface"); return }
        // A point on the cylinder (radius 5, axis Z) at angle ~0, height 3.
        guard let r = cyl.uvFromIso(SIMD3(5, 0, 3), precision: 1e-6) else {
            Issue.record("uvFromIso nil"); return
        }
        #expect(r.gap < 1e-3)                 // the point lies on the surface
        #expect(abs(r.v - 3) < 1e-6)          // v is the height
    }

    @Test("singularity detail at a cone apex")
    func coneSingularity() {
        guard let cone = Surface.cone(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
                                      radius: 5, semiAngle: 0.5) else { Issue.record("cone"); return }
        #expect(cone.singularityCount() >= 1)        // a cone has a degenerate apex
        guard let s = cone.singularity(0) else { Issue.record("singularity(0) nil"); return }
        // The apex sits on the axis (x ≈ y ≈ 0); the iso-line collapses to it.
        #expect(abs(s.point.x) < 1e-6)
        #expect(abs(s.point.y) < 1e-6)
        #expect(simd_distance(s.firstUV, s.lastUV) > 0)   // a real degenerate iso, not a point
    }

    @Test("out-of-range singularity index returns nil")
    func singularityOutOfRange() {
        guard let cone = Surface.cone(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
                                      radius: 5, semiAngle: 0.5) else { Issue.record("cone"); return }
        #expect(cone.singularity(99) == nil)
    }

    @Test("domain-restricted projection lands inside the domain")
    func projectInDomain() {
        guard let cyl = Surface.cylindricalSurface(radius: 5) else { Issue.record("surface"); return }
        guard let r = cyl.projectPoint(SIMD3(5, 0, 2), uDomain: 0...(.pi), vDomain: 0...10) else {
            Issue.record("projectPoint(domain) nil"); return
        }
        #expect(r.gap < 1e-3)
        #expect(r.uv.y >= -1e-6 && r.uv.y <= 10 + 1e-6)   // v within the requested domain
    }

    @Test("BRepGProp_Face integration orders + U knots on a planar face")
    func integrationIntrospection() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
              let outer = Wire.polygon3D([
                  SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)
              ], closed: true),
              let face = Shape.face(from: plane, outer: outer, innerWires: []) else {
            Issue.record("face setup"); return
        }
        // Orders are defined (planar ⇒ small/zero), and the U-knot span covers at least [uMin,uMax].
        #expect(face.faceIntegrationOrders != nil)
        let knots = face.faceIntegrationKnotsU()
        #expect(knots.count >= 2)
        if knots.count >= 2 { #expect(knots.first! <= knots.last!) }
    }

    // A 10×10 planar face on z=0.
    private func planarFace() -> Shape? {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
              let outer = Wire.polygon3D([
                  SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)
              ], closed: true) else { return nil }
        return Shape.face(from: plane, outer: outer, innerWires: [])
    }

    @Test("tangent plane is two-sided: TangentU and TangentV both defined and independent")
    func faceTangentUandV() {
        guard let face = planarFace() else { Issue.record("setup"); return }
        guard let tu = face.faceLPropTangentU(u: 5, v: 5),
              let tv = face.faceLPropTangentV(u: 5, v: 5) else {
            Issue.record("tangent nil"); return
        }
        // On a plane the two tangents span the plane — not parallel.
        let cross = simd_cross(tu, tv)
        #expect(simd_length(cross) > 0.5)   // ~unit (orthonormal axes) ⇒ well clear of parallel
    }

    @Test("BRepGProp_Face V knots + surface-integration params")
    func vKnotsAndSurfaceIntegration() {
        guard let face = planarFace() else { Issue.record("setup"); return }
        #expect(face.faceIntegrationKnotsV().count >= 1)
        guard let si = face.faceSurfaceIntegration() else { Issue.record("surfaceIntegration nil"); return }
        #expect(si.order >= 1)          // some Gauss order
        #expect(si.uSubs >= 1)
        #expect(si.vSubs >= 1)
    }

    @Test("BRepGProp_Face boundary integration on a face edge")
    func boundaryIntegration() {
        guard let face = planarFace() else { Issue.record("setup"); return }
        guard let bi = face.faceBoundaryIntegration(edgeIndex: 0) else {
            Issue.record("boundaryIntegration nil"); return
        }
        #expect(bi.order >= 1)
        #expect(bi.subs >= 1)
        #expect(bi.knots.count >= 1)
        // An out-of-range edge index fails cleanly.
        #expect(face.faceBoundaryIntegration(edgeIndex: 99) == nil)
    }

    @Test("FaceFixer tolerance clamps run without crashing")
    func faceFixerTolerances() {
        guard let face = planarFace(), let fixer = FaceFixer(face: face) else { Issue.record("setup"); return }
        fixer.setMinTolerance(1e-7)
        fixer.setMaxTolerance(1e-2)
        fixer.perform()
        if let r = fixer.result { #expect(r.isValid) }
    }
}
