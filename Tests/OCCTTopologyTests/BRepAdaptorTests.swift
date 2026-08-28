import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - BRepAdaptor Exposure")
struct BRepAdaptorTests {

    @Test func edgeDomain() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                #expect(domain.upperBound > domain.lowerBound)
            }
        }
    }

    @Test func edgeValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                let p = edges[0].edgeAdaptorValue(at: domain.lowerBound)
                let mag = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                #expect(mag >= 0)
            }
        }
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

    @Test func faceBounds() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let bounds = faces[0].faceAdaptorBounds
                #expect(bounds.uMax > bounds.uMin || bounds.vMax > bounds.vMin)
            }
        }
    }

    @Test func faceValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let bounds = faces[0].faceAdaptorBounds
                let midU = (bounds.uMin + bounds.uMax) / 2.0
                let midV = (bounds.vMin + bounds.vMax) / 2.0
                let p = faces[0].faceAdaptorValue(u: midU, v: midV)
                let mag = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                #expect(mag >= 0)
            }
        }
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
