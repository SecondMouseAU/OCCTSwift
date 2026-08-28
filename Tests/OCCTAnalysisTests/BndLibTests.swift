import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BndLib Analytic Bounding Tests")
struct BndLibTests {

    @Test func lineSegmentBounds() {
        let b = BndLib.line(origin: .zero, direction: SIMD3(1, 0, 0), p1: 0, p2: 10)
        #expect(abs(b.min.x) < 1e-6)
        #expect(abs(b.max.x - 10) < 1e-6)
    }

    @Test func circleBounds() {
        let b = BndLib.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        #expect(abs(b.min.x + 5) < 1e-6)
        #expect(abs(b.max.x - 5) < 1e-6)
    }

    @Test func sphereBounds() {
        let b = BndLib.sphere(center: .zero, radius: 3)
        #expect(abs(b.min.x + 3) < 1e-6)
        #expect(abs(b.max.z - 3) < 1e-6)
    }

    @Test func cylinderBounds() {
        let b = BndLib.cylinder(center: .zero, axis: SIMD3(0, 0, 1), radius: 2, vmin: 0, vmax: 10)
        #expect(abs(b.min.z) < 1e-6)
        #expect(abs(b.max.z - 10) < 1e-6)
    }

    @Test func torusBounds() {
        let b = BndLib.torus(center: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2)
        #expect(abs(b.max.x - 12) < 1e-6)
        #expect(abs(b.max.z - 2) < 1e-6)
    }

    @Test func edgeBounds() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let b = BndLib.edge(edge)
                #expect(b.max.x >= b.min.x)
            }
        }
    }

    @Test func faceBounds() {
        if let sph = Shape.sphere(radius: 5) {
            let faces = sph.subShapes(ofType: .face)
            if let face = faces.first {
                let b = BndLib.face(face)
                #expect(abs(b.min.x + 5) < 0.1)
                #expect(abs(b.max.x - 5) < 0.1)
            }
        }
    }
}
