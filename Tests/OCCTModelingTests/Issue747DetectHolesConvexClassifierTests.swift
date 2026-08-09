import Testing
import Foundation
import simd
@testable import OCCTSwift

// #747: `detectHoles()` required every neighbor of a candidate face to connect via a concave
// edge. #723 replaced the hand-rolled convexity formula with OCCT's own `ChFi3d::DefineConnectType`
// and, correctly, that made the requirement unsatisfiable for either ordinary hole shape:
//
// - A through-hole's cylindrical wall has ZERO concave neighbors. At a hole's rim the solid
//   occupies the quarter-space outside the cylinder and below/above the opening face -- a 90
//   degree material angle, not the 270 that makes an edge concave. Both rims classify convex.
// - A blind hole's wall has exactly ONE concave neighbor out of two: the floor, not the rim where
//   it opens to the exterior.
//
// "All neighbors concave" can hold for neither, so `detectHoles()` reported zero for both --
// total non-detection of the two hole shapes anyone would actually drill.
//
// ## What replaces it
//
// A hole is not defined by its neighbors' convexity -- that only ever describes the rims where
// the hole meets other geometry, and a through-hole has no concave junction at all. What every
// hole's lateral wall shares, independent of depth, is its own intrinsic shape:
//
// 1. Cylindrical or conical (the two developable surface types a drilled/bored feature produces).
// 2. Closed in U by its own seam -- it wraps all the way around its axis, bounded only by rims in
//    V, not by extra edges along U (a partial revolve, e.g. an edge fillet, is not a hole).
// 3. Material lies radially OUTSIDE the wall, not inside it: the wall's own outward-pointing
//    normal (already corrected for face orientation) points back toward the axis. A boss or a
//    standalone solid cylinder is the mirror image of the same topology -- same surface type,
//    same closed-in-U shape, and (for a through-boss-like standalone cylinder) even the same
//    zero-concave-neighbor signature as a through-hole -- but its material fills the inside, so
//    its normal points away from the axis.
//
// See `AAG.detectHoles()`'s own doc comment in `FeatureRecognition.swift` for the full reasoning.
@Suite("AAG.detectHoles() finds holes under the correct convexity classifier (#747)")
struct Issue747DetectHolesConvexClassifierTests {

    // MARK: - The headline: the issue's own two fixtures

    /// The issue's own blind-hole construction, byte for byte. Before the fix this reported
    /// zero holes because the wall's two neighbors (floor: concave, rim: convex) never satisfy
    /// "all concave".
    @Test("a blind cylindrical hole reports exactly one hole")
    func blindHoleReportsExactlyOneHole() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20))
        let cut = try #require(box.subtracting(tool))

        let holes = cut.buildAAG().detectHoles()
        #expect(holes.count == 1)
        guard let hole = holes.first else { return }
        #expect(abs(hole.radius - 4.0) < 1e-4)
        #expect(abs(hole.depth - 10.0) < 1e-4)
    }

    /// The issue's own through-hole construction. Before the fix this reported zero holes
    /// because the wall's two neighbors are BOTH convex -- "all concave" can never hold for a
    /// through-hole, by construction, independent of geometry.
    @Test("a through cylindrical hole reports exactly one hole")
    func throughHoleReportsExactlyOneHole() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: SIMD3(0, 0, -15), direction: SIMD3(0, 0, 1), radius: 4, height: 30))
        let cut = try #require(box.subtracting(tool))

        let holes = cut.buildAAG().detectHoles()
        #expect(holes.count == 1)
        guard let hole = holes.first else { return }
        #expect(abs(hole.radius - 4.0) < 1e-4)
        #expect(abs(hole.depth - 20.0) < 1e-4)
    }

    // MARK: - The ground-truth table row: through-hole plate at several thicknesses

    /// The exact fixture `Issue703EdgeConvexityOrderTests.throughHoleHasNoConcaveEdges` pins as
    /// "zero concave edges" -- the fixture whose own ground truth is the reason "all neighbors
    /// concave" can never identify this shape as a hole. One physical hole at every thickness.
    @Test("a through-hole plate reports one hole at several thicknesses",
          arguments: [20.0, 40.0, 60.0, 120.0])
    func throughHolePlateAcrossThicknesses(thickness: Double) throws {
        let plate = try #require(Shape.box(width: 50, height: 50, depth: thickness))
        let drill = try #require(Shape.cylinder(
            at: SIMD3(0, 0, -thickness / 2 - 5), direction: SIMD3(0, 0, 1),
            radius: 10, height: thickness + 10))
        let drilled = try #require(plate.subtracting(drill))

        let holes = drilled.buildAAG().detectHoles()
        let label: Comment = "thickness=\(thickness)"
        #expect(holes.count == 1, label)
        guard let hole = holes.first else { return }
        #expect(abs(hole.radius - 10.0) < 1e-4, label)
        #expect(abs(hole.depth - thickness) < 1e-4, label)
    }

    // MARK: - False positives a weaker criterion would produce

    /// A round boss (a cylinder fused onto a box, sticking up) has the SAME topological
    /// signature as a blind hole -- its wall's two neighbors are one concave (base rim), one
    /// convex (top cap rim) -- but it is not a hole: the boss's material fills the inside of
    /// the cylinder. Only the material-side (radial normal direction) check tells them apart.
    @Test("a round boss is not reported as a hole")
    func roundBossIsNotAHole() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let boss = try #require(Shape.cylinder(at: SIMD3(0, 0, 10), direction: SIMD3(0, 0, 1), radius: 4, height: 5))
        let fused = try #require(box.union(boss))

        #expect(fused.buildAAG().detectHoles().isEmpty)
    }

    /// A standalone solid cylinder's lateral wall has ZERO concave neighbors, same as a
    /// through-hole -- this is the sharpest possible counter-example to "closed cylindrical
    /// face, no concave neighbors implies hole": the topology (surface type, closed in U,
    /// neighbor convexity) is identical to a genuine through-hole, and only the material-side
    /// check distinguishes a bore (void inside) from a solid peg (material inside).
    @Test("a standalone solid cylinder is not reported as a hole")
    func standaloneCylinderIsNotAHole() throws {
        let cylinder = try #require(Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20))
        #expect(cylinder.buildAAG().detectHoles().isEmpty)
    }

    /// A fillet on a CONCAVE interior corner (here, a vertical wall-to-wall corner of a square
    /// pocket) is deliberately the sharper counter-example, not a fillet on an ordinary convex
    /// box edge: measured directly, its material-side sign matches a genuine hole's (material
    /// lies radially outside the fillet's own cylindrical patch, same as a bore), so it clears
    /// the material-side check on its own. Only the fillet's own U extent -- one quarter turn
    /// (~pi/2), not a full 2*pi -- is what excludes it. A convex-edge fillet would ALSO be
    /// excluded, but by the material-side check instead, silently proving nothing about "closed
    /// in U" specifically (confirmed by removing that guard in isolation: the convex-edge
    /// fixture still passed, while this one flipped to reporting a false hole at exactly the
    /// fillet's own radius).
    @Test("a filleted concave interior corner is not reported as a hole")
    func filletedConcaveCornerIsNotAHole() throws {
        let box = try #require(Shape.box(width: 30, height: 30, depth: 30))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 5), width: 10, height: 10, depth: 11))
        let pocketed = try #require(box.subtracting(pocketTool))

        // The pocket tool's footprint is (-5...5, -5...5) at z in [5, 16], so its four vertical
        // wall-to-wall corners sit at (x, y) = (+-5, +-5). Find one geometrically rather than by
        // a fixed edge index, which is not stable across OCCT's own edge enumeration order.
        let verticalEdges = pocketed.edges(parallelTo: SIMD3(0, 0, 1))
        let cornerEdge = verticalEdges.first { edge in
            guard let p = edge.point(at: 0.5) else { return false }
            return abs(abs(p.x) - 5) < 1e-3 && abs(abs(p.y) - 5) < 1e-3 && p.z > 5 && p.z < 16
        }
        let edge = try #require(cornerEdge, "could not find the pocket's vertical corner edge")

        let builder = try #require(FilletBuilder(shape: pocketed))
        builder.addEdge(edge, radius: 1.0)
        let filleted = try #require(builder.build())

        #expect(filleted.buildAAG().detectHoles().isEmpty)
    }

    // MARK: - The material-side discriminator, isolated on one shape

    /// A pipe: the SAME axis, the SAME closed-in-U cylindrical shape, on both its inner and
    /// outer wall -- differing only in which side is material. The inner wall is a genuine
    /// through-hole (material lies radially outside it, the pipe's own wall thickness); the
    /// outer wall is not (material lies radially inside it, same as a solid cylinder's wall).
    /// This isolates the discriminator #747 turns on: everything else about the two faces
    /// (surface type, closed-in-U, axis) is identical.
    @Test("a pipe's inner bore is a hole, its outer wall is not")
    func pipeInnerBoreIsAHoleOuterWallIsNot() throws {
        let outer = try #require(Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 10, height: 30))
        let inner = try #require(Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 6, height: 30))
        let pipe = try #require(outer.subtracting(inner))

        let holes = pipe.buildAAG().detectHoles()
        #expect(holes.count == 1)
        guard let hole = holes.first else { return }
        #expect(abs(hole.radius - 6.0) < 1e-4)
        #expect(abs(hole.depth - 30.0) < 1e-4)
    }

    // MARK: - Axis generality: the fix reads the wall's own axis, not an assumed vertical one

    /// A through-hole bored along X rather than Z. The previous implementation inferred
    /// "circular" from a Z-implicit bounding-box aspect ratio (X/Y as the circular dimensions,
    /// Z as depth), which is wrong for any non-vertical hole: here the true circular dimensions
    /// are Y/Z (~8 units) and the true depth is along X (~20 units), the opposite of what that
    /// heuristic assumed. Reading the wall's actual axis (`Face.primaryAxis`) gets this right
    /// regardless of orientation.
    @Test("a through-hole bored on a horizontal (X) axis is detected")
    func horizontalHoleIsDetected() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: SIMD3(-15, 0, 0), direction: SIMD3(1, 0, 0), radius: 4, height: 30))
        let cut = try #require(box.subtracting(tool))

        let holes = cut.buildAAG().detectHoles()
        #expect(holes.count == 1)
        guard let hole = holes.first else { return }
        #expect(abs(hole.radius - 4.0) < 1e-4)
        #expect(abs(hole.depth - 20.0) < 1e-4)
    }

    // MARK: - Non-regression: shapes with no cylindrical/conical face at all

    /// A plain box has no cylindrical or conical face whatsoever, so there is no candidate in
    /// the first place; the new criterion must not manufacture one.
    @Test("a plain box has no holes")
    func plainBoxHasNoHoles() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.buildAAG().detectHoles().isEmpty)
    }

    /// A square (rectangular) pocket's walls are planar, not cylindrical -- a different feature
    /// family entirely. `detectHoles()` must not report anything for it, independent of what
    /// `detectPockets()` reports for the same shape.
    @Test("a square pocket has no holes")
    func squarePocketHasNoHoles() throws {
        let box = try #require(Shape.box(width: 30, height: 30, depth: 30))
        let pocket = try #require(Shape.box(origin: SIMD3(-5, -5, 5), width: 10, height: 10, depth: 11))
        let pocketed = try #require(box.subtracting(pocket))

        #expect(pocketed.buildAAG().detectHoles().isEmpty)
    }
}
