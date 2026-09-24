import Foundation
import Testing
import simd

@testable import OCCTSwift

// Each test pins the iso curve to the values Adaptor3d_IsoCurve and Geom_Surface::UIso/VIso give
// for the same face (Scripts/repro/766-curve-adaptor-approx/transcript.txt). The earlier versions
// looped over every face, returned early when nothing matched, and checked only a point count or
// a shape type, so an iso curve taken in the wrong direction, or on the wrong face, passed (#766).

/// The lateral face of `Shape.cylinder(radius: 10, height: 20)`: the one whose surface is a
/// cylinder (GeomAbs_Cylinder = 1). Its surface is the infinite Geom_CylindricalSurface, axis Z,
/// with u = 0 on +X.
private func lateralFace() -> Shape? {
    Shape.cylinder(radius: 10, height: 20)?.subShapes(ofType: .face)
        .first { $0.faceAdaptorSurfaceType == 1 }
}

@Suite("Adaptor3d IsoCurve")
struct Adaptor3dIsoCurveTests {
    @Test("U-iso points on cylinder face")
    func uIsoOnCylinder() {
        guard let face = lateralFace() else {
            Issue.record("no cylindrical face on Shape.cylinder")
            return
        }
        // The u = 0 generator, x = 10, y = 0; its infinite v range is clamped to +-1e6.
        let pts = face.uIsoCurvePoints(u: 0, count: 5)
        let z: [Double] = [-1e6, -5e5, 0, 5e5, 1e6]
        #expect(pts.count == 5)
        for (p, zk) in zip(pts, z) {
            #expect(abs(p.x - 10) < 1e-9)
            #expect(abs(p.y) < 1e-9)
            #expect(abs(p.z - zk) < 1e-6)
        }
    }

    @Test("V-iso points on cylinder face")
    func vIsoOnCylinder() {
        guard let face = lateralFace() else {
            Issue.record("no cylindrical face on Shape.cylinder")
            return
        }
        // The v = 10 parallel: a radius-10 circle at z = 10, sampled over u in [0, 2pi].
        let pts = face.vIsoCurvePoints(v: 10, count: 10)
        #expect(pts.count == 10)
        for (i, p) in pts.enumerated() {
            let u = 2 * Double.pi * Double(i) / 9
            #expect(abs(p.x - 10 * cos(u)) < 1e-9)
            #expect(abs(p.y - 10 * sin(u)) < 1e-9)
            #expect(abs(p.z - 10) < 1e-9)
        }
    }

    @Test("U-iso curve edge from face")
    func uIsoCurveEdge() {
        guard let face = lateralFace(), let edge = face.uIsoCurveEdge(u: 0, vMin: 0, vMax: 10)
        else {
            Issue.record("no u-iso edge from the lateral face")
            return
        }
        #expect(edge.shapeType == .edge)
        // A straight generator (GeomAbs_Line = 0) from (10, 0, 0) to (10, 0, 10).
        #expect(edge.edgeAdaptorCurveType == 0)
        #expect(abs(edge.edgeArcLength - 10) < 1e-9)
        guard let c = edge.extractEdgeCurve3D() else {
            Issue.record("u-iso edge carries no 3D curve")
            return
        }
        #expect(simd_distance(c.curve.point(at: c.first), SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(c.curve.point(at: c.last), SIMD3(10, 0, 10)) < 1e-9)
    }

    @Test("V-iso curve edge from face")
    func vIsoCurveEdge() {
        guard let face = lateralFace(), let edge = face.vIsoCurveEdge(v: 10, uMin: 0, uMax: .pi)
        else {
            Issue.record("no v-iso edge from the lateral face")
            return
        }
        #expect(edge.shapeType == .edge)
        // Half of the z = 10 parallel (GeomAbs_Circle = 1): length 10 pi, (10, 0, 10) to (-10, 0, 10).
        #expect(edge.edgeAdaptorCurveType == 1)
        #expect(abs(edge.edgeArcLength - 10 * Double.pi) < 1e-9)
        guard let c = edge.extractEdgeCurve3D() else {
            Issue.record("v-iso edge carries no 3D curve")
            return
        }
        #expect(simd_distance(c.curve.point(at: c.first), SIMD3(10, 0, 10)) < 1e-9)
        #expect(simd_distance(c.curve.point(at: c.last), SIMD3(-10, 0, 10)) < 1e-9)
    }
}
