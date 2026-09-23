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

    /// Every edge of a centred 10 x 20 x 30 box is an axis-aligned segment, so its box has extent
    /// along exactly one axis, and the twelve boxes together span the solid. The previous form
    /// asserted only `max.x >= min.x` on one edge, which the bridge's all-zero failure output
    /// satisfies. Values probed in `Scripts/repro/766-bndlib/transcript.txt`.
    @Test func edgeBounds() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("a 10 x 20 x 30 box builds")
            return
        }
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)

        var lo = SIMD3<Double>(repeating: .infinity)
        var hi = SIMD3<Double>(repeating: -.infinity)
        var extents: [Double] = []
        for edge in edges {
            let b = BndLib.edge(edge)
            let span = b.max - b.min
            let nonZero = [span.x, span.y, span.z].filter { abs($0) > 1e-9 }
            #expect(nonZero.count == 1, "an axis-aligned edge spans one axis, got \(span)")
            extents.append(contentsOf: nonZero)
            lo = simd_min(lo, b.min)
            hi = simd_max(hi, b.max)
        }
        #expect(extents.sorted() == [10, 10, 10, 10, 20, 20, 20, 20, 30, 30, 30, 30])
        #expect(lo == SIMD3(-5, -10, -15))
        #expect(hi == SIMD3(5, 10, 15))
    }

    @Test func faceBounds() {
        guard let sph = Shape.sphere(radius: 5) else {
            Issue.record("a radius-5 sphere builds")
            return
        }
        let faces = sph.subShapes(ofType: .face)
        #expect(faces.count == 1)
        guard let face = faces.first else {
            Issue.record("a sphere has one face")
            return
        }
        let b = BndLib.face(face)
        #expect(abs(b.min.x + 5) < 0.1)
        #expect(abs(b.max.x - 5) < 0.1)
    }
}
