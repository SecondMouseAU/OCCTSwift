import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: every test here asserted only that a drawing (or an edge category) was non-nil, so a
// polygonal projection along the wrong direction, or of a mesh at the wrong deflection, passed
// them all. They now pin what BRepMesh_IncrementalMesh + HLRBRep_PolyAlgo produce for the same
// shape, view and deflection (Shape.box is centred on the origin), measured in
// Scripts/repro/766-drawing-pointproj-polyhlr/transcript.txt. Edge counts on curved shapes are
// mesh-segment counts, fixed for the pinned kernel's mesher.
@Suite("Polygon-Based HLR")
struct PolyHLRTests {
    private func expectEdges(
        _ shape: Shape?, count: Int, min: SIMD2<Double>, max: SIMD2<Double>, _ what: String
    ) {
        guard let shape, let bb = shape.boundingBox else {
            Issue.record("\(what): no edges")
            return
        }
        #expect(shape.edges().count == count, "\(what): \(shape.edges().count) edges")
        #expect(
            simd_length(SIMD2(bb.min.x, bb.min.y) - min) < 1e-6
                && simd_length(SIMD2(bb.max.x, bb.max.y) - max) < 1e-6,
            "\(what): extent \(bb.min) .. \(bb.max)")
    }

    @Test("Fast top view of box produces edges")
    func fastTopViewBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.fastTopView(of: box)
        else {
            Issue.record("fast top view unavailable")
            return
        }
        expectEdges(
            drawing.visibleEdges, count: 4,
            min: SIMD2(-5.0000001, -5.0000001), max: SIMD2(5.0000001, 5.0000001), "visible")
    }

    @Test("Fast isometric view of box")
    func fastIsometricBox() {
        guard let box = Shape.box(width: 20, height: 10, depth: 5),
            let drawing = Drawing.fastIsometricView(of: box)
        else {
            Issue.record("fast isometric view unavailable")
            return
        }
        expectEdges(
            drawing.visibleEdges, count: 9,
            min: SIMD2(-8.83883486, -9.18558664), max: SIMD2(8.83883486, 9.18558664), "visible")
        expectEdges(
            drawing.hiddenEdges, count: 3,
            min: SIMD2(-8.83883486, -7.14434518), max: SIMD2(8.83883486, 9.18558664), "hidden")
    }

    @Test("Fast projection of cylinder")
    func fastProjectCylinder() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let drawing = Drawing.projectFast(cyl, direction: SIMD3(1, 0, 0))
        else {
            Issue.record("fast projection unavailable")
            return
        }
        // Side on: the cylinder is a 10 x 10 rectangle; its two silhouette lines are outline.
        expectEdges(
            drawing.visibleEdges, count: 76,
            min: SIMD2(-1e-7, -5.0000001), max: SIMD2(10.0000001, 5.0000001), "visible")
        expectEdges(
            drawing.outlineEdges, count: 4,
            min: SIMD2(-1e-7, -5.0000001), max: SIMD2(10.0000001, 5.0000001), "outline")
    }

    @Test("Fast projection has hidden edges")
    func fastHiddenEdges() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(width: 5, height: 5, depth: 20),
            let fused = box1.union(box2),
            let drawing = Drawing.projectFast(fused, direction: SIMD3(0, 1, 0))
        else {
            Issue.record("fused fixture or projection unavailable")
            return
        }
        expectEdges(
            drawing.visibleEdges, count: 10,
            min: SIMD2(-10.0000001, -5.0000001), max: SIMD2(10.0000001, 5.0000001), "visible")
        expectEdges(
            drawing.hiddenEdges, count: 14,
            min: SIMD2(-10.0000001, -5.0000001), max: SIMD2(10.0000001, 5.0000001), "hidden")
    }

    @Test("Fast vs exact projection both succeed")
    func fastVsExact() {
        guard let sphere = Shape.sphere(radius: 10),
            let exact = Drawing.topView(of: sphere),
            let fast = Drawing.fastTopView(of: sphere)
        else {
            Issue.record("a projection was nil")
            return
        }
        // The exact outline is the one true circle; the polygonal one is 197 mesh segments whose
        // extent falls just inside it on the side the mesh does not touch.
        expectEdges(
            exact.visibleEdges, count: 1,
            min: SIMD2(-10.0000001, -10.0000001), max: SIMD2(10.0000001, 10.0000001), "exact")
        expectEdges(
            fast.visibleEdges, count: 197,
            min: SIMD2(-9.99879073, -10.0000001), max: SIMD2(10.0000001, 10.0000001), "fast")
    }

    @Test("Custom deflection affects result")
    func customDeflection() {
        guard let sphere = Shape.sphere(radius: 10),
            let coarse = Drawing.projectFast(sphere, direction: SIMD3(0, 0, 1), deflection: 1.0),
            let fine = Drawing.projectFast(sphere, direction: SIMD3(0, 0, 1), deflection: 0.001)
        else {
            Issue.record("a projection was nil")
            return
        }
        // Deflection 1 gives a 35-segment outline, 0.001 a 631-segment one hugging the circle.
        expectEdges(
            coarse.visibleEdges, count: 35,
            min: SIMD2(-9.96194708, -9.96194708), max: SIMD2(10.0000001, 9.96194708), "coarse")
        expectEdges(
            fine.visibleEdges, count: 631,
            min: SIMD2(-9.9998781, -9.9998781), max: SIMD2(10.0000001, 9.9998781), "fine")
    }
}
