import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Adaptor3d IsoCurve")
struct Adaptor3dIsoCurveTests {
    @Test("U-iso points on cylinder face")
    func uIsoOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Find the cylindrical face
        for face in faces {
            let pts = face.uIsoCurvePoints(u: 0, count: 5)
            // Check for valid points (not all zero)
            if pts.contains(where: { simd_length($0) > 1 }) {
                #expect(pts.count == 5)
                return
            }
        }
    }

    @Test("V-iso points on cylinder face")
    func vIsoOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        for face in faces {
            let pts = face.vIsoCurvePoints(v: 10, count: 10)
            if pts.contains(where: { simd_length($0) > 1 }) {
                #expect(pts.count == 10)
                return
            }
        }
    }

    @Test("U-iso curve edge from face")
    func uIsoCurveEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        for face in faces {
            if let edge = face.uIsoCurveEdge(u: 0, vMin: 0, vMax: 10) {
                #expect(edge.shapeType == .edge)
                return
            }
        }
    }

    @Test("V-iso curve edge from face")
    func vIsoCurveEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        for face in faces {
            if let edge = face.vIsoCurveEdge(v: 10, uMin: 0, uMax: .pi) {
                #expect(edge.shapeType == .edge)
                return
            }
        }
    }
}
