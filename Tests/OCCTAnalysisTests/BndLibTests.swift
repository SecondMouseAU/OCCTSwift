import Foundation
import Testing
import simd

@testable import OCCTSwift

/// All six coordinates of an ``AnalyticBounds``, against the analytically derived box.
///
/// The `OCCTBndLib*` bridge functions return `void` and write their six out-parameters, so a
/// function that refuses (null handle) or catches leaves the caller's zeroed box untouched and
/// `BndLib` hands back `(0,0,0)-(0,0,0)`. `max >= min` is true of that box and of every box OCCT
/// can build, which is why the whole-box comparison is the assertion and not a per-axis ordering
/// one (#1922 to #1928, #1748 to #1753).
///
/// File-private, and duplicated in `BndLibExtraTests.swift` rather than shared on purpose: see
/// the copy there for why.
private func expectAnalyticBounds(
    _ b: AnalyticBounds, min: SIMD3<Double>, max: SIMD3<Double>, tolerance: Double = 1e-9,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        simd_distance(b.min, min) < tolerance, "min \(b.min), expected \(min)",
        sourceLocation: sourceLocation)
    #expect(
        simd_distance(b.max, max) < tolerance, "max \(b.max), expected \(max)",
        sourceLocation: sourceLocation)
}

/// Each box here is the analytic extent of the primitive at tolerance 0, derived from OCCT's own
/// parametrisation and confirmed against the kernel by `Scripts/repro/766-bndlib/`.
///
/// Every test used to pin at most two of the six coordinates, so a box translated along, or
/// swollen about, the unasserted axes satisfied them all.
@Suite("BndLib Analytic Bounding Tests")
struct BndLibTests {

    /// The segment from the origin to (10, 0, 0) has no extent off the x axis.
    @Test func lineSegmentBounds() {
        let b = BndLib.line(origin: .zero, direction: SIMD3(1, 0, 0), p1: 0, p2: 10)
        expectAnalyticBounds(b, min: SIMD3(0, 0, 0), max: SIMD3(10, 0, 0))
    }

    /// A radius-5 circle in the z = 0 plane: the box is its own square, flat in z.
    @Test func circleBounds() {
        let b = BndLib.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        expectAnalyticBounds(b, min: SIMD3(-5, -5, 0), max: SIMD3(5, 5, 0))
    }

    /// A radius-3 sphere at the origin: the cube of side 6 about the origin.
    @Test func sphereBounds() {
        let b = BndLib.sphere(center: .zero, radius: 3)
        expectAnalyticBounds(b, min: SIMD3(-3, -3, -3), max: SIMD3(3, 3, 3))
    }

    /// `BndLib::Add(gp_Cylinder, VMin, VMax, ...)` bounds the whole U range, so the radius-2
    /// cylinder from z = 0 to z = 10 gives a 4 x 4 x 10 box resting on the z = 0 plane.
    @Test func cylinderBounds() {
        let b = BndLib.cylinder(center: .zero, axis: SIMD3(0, 0, 1), radius: 2, vmin: 0, vmax: 10)
        expectAnalyticBounds(b, min: SIMD3(-2, -2, 0), max: SIMD3(2, 2, 10))
    }

    /// A torus of major radius 10 and minor radius 2 about the z axis reaches 12 in x and y and
    /// 2 in z. The old form pinned `max.x` and `max.z` only, so it could not see the box fail to
    /// close on the negative side.
    @Test func torusBounds() {
        let b = BndLib.torus(center: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2)
        expectAnalyticBounds(b, min: SIMD3(-12, -12, -2), max: SIMD3(12, 12, 2))
    }

    /// Every edge of a centred 10 x 20 x 30 box is an axis-aligned segment, so each edge's box
    /// has extent along exactly one axis, the twelve extents are four of each side length, and
    /// the twelve boxes together span the solid. The old form asserted `max.x >= min.x` on one
    /// edge, which the bridge's all-zero refusal output also satisfies.
    @Test func edgeBounds() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
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

    /// `BndLib_AddSurface::Add` at tolerance 0 works from the analytic `gp_Sphere` the face
    /// carries, so the one face of a radius-5 sphere measures to exactly the cube of side 10,
    /// with none of the 1e-7 shape tolerance `BRepBndLib::Add` would add (see
    /// `BRepBndLibTests.boundingBoxSphere`, which is the same sphere through the other entry
    /// point). The old form pinned the two x coordinates at 0.1 and left y and z unasserted.
    @Test func faceBounds() throws {
        let sph = try #require(Shape.sphere(radius: 5))
        let faces = sph.subShapes(ofType: .face)
        #expect(faces.count == 1)
        let face = try #require(faces.first)
        expectAnalyticBounds(BndLib.face(face), min: SIMD3(-5, -5, -5), max: SIMD3(5, 5, 5))
    }
}
