import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// Shape.box is centred, so the 10-cube spans -5...5 on every axis, and subShapes(ofType:)
// follows TopExp::MapShapes order: edge 1 runs (-5,-5,-5) to (-5,-5,5) over [0, 10], and face 1
// is the x = -5 plane with u in [0, 10] and v in [-10, 0]. Every pinned value below is what
// BRepAdaptor gives in Scripts/repro/766-topology-bintools-brepadaptor/transcript.txt.
//
// Before #1981 four of these tests could not fail: edgeDomain asserted only upper > lower,
// edgeValue and faceValue asserted |p| >= 0, and faceBounds accepted either direction being
// non-empty. Each is now pinned to the kernel's value.
@Suite("v0.115.0 - BRepAdaptor Exposure")
struct BRepAdaptorTests {

    @Test func edgeDomain() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        try #require(edges.count == 12)
        let domain = edges[0].edgeAdaptorDomain
        #expect(abs(domain.lowerBound) < 1e-12)
        #expect(abs(domain.upperBound - 10) < 1e-12, "domain \(domain)")
    }

    @Test func edgeValue() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        try #require(edges.count == 12)
        let domain = edges[0].edgeAdaptorDomain
        let p = edges[0].edgeAdaptorValue(at: domain.lowerBound)
        #expect(simd_distance(p, SIMD3(-5, -5, -5)) < 1e-12, "start point \(p)")
        let q = edges[0].edgeAdaptorValue(at: domain.upperBound)
        #expect(simd_distance(q, SIMD3(-5, -5, 5)) < 1e-12, "end point \(q)")
    }

    @Test func edgeCurveType() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let curveType = edges[0].edgeAdaptorCurveType
                #expect(curveType == 0)  // Line for box edges
            }
        }
    }

    @Test func faceBounds() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6)
        let b = faces[0].faceAdaptorBounds
        #expect(abs(b.uMin) < 1e-12 && abs(b.uMax - 10) < 1e-12, "u \(b.uMin)...\(b.uMax)")
        #expect(abs(b.vMin + 10) < 1e-12 && abs(b.vMax) < 1e-12, "v \(b.vMin)...\(b.vMax)")
    }

    @Test func faceValue() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6)
        let bounds = faces[0].faceAdaptorBounds
        let midU = (bounds.uMin + bounds.uMax) / 2.0
        let midV = (bounds.vMin + bounds.vMax) / 2.0
        let p = faces[0].faceAdaptorValue(u: midU, v: midV)
        #expect(simd_distance(p, SIMD3(-5, 0, 0)) < 1e-12, "face centre \(p)")
    }

    @Test func faceSurfaceType() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let surfType = faces[0].faceAdaptorSurfaceType
                #expect(surfType == 0)  // Plane for box faces
            }
        }
    }
}
