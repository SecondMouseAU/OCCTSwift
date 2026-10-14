import Foundation
import Testing

@testable import OCCTSwift

/// #3297 and #3298: two answers the kernel gives where blends meet exactly, both `BRepCheck`-valid,
/// so the validity guard of #3200 passes them.
///
/// - #3297: `Shape.chamfered(distance:)` on a cube at `d == edge / 2` answered the unchanged cube.
/// - #3298: both rims of a cylinder at `r == R == H / 2` answered two solids, twice the volume.
///
/// A correct build is not reachable at the tie (the kernel decides it with a tolerance comparison,
/// builds the step below and declines the step above), so the contract is nil, and the step below
/// still builds. Measured through raw `BRepFilletAPI_MakeFillet` and `MakeChamfer` as well, so the
/// guard sits behind the bridge's result predicate, not in front of the call.
@Suite("Exact-half blends answer nil, not a wrong valid shape")
struct BlendExactHalfSanityTests {

    private func cube(_ edge: Double) throws -> Shape {
        try #require(Shape.box(width: edge, height: edge, depth: edge))
    }

    private func cylinder() throws -> Shape {
        try #require(Shape.cylinder(radius: 5, height: 10))
    }

    private func rims(_ cylinder: Shape) -> [Edge] {
        cylinder.edges().filter { $0.isCircle }
    }

    // MARK: - The chamfer of a cube at d = edge / 2 (the unchanged cube)

    @Test("a cube chamfered at half its edge is nil, never the unchanged cube")
    func cubeChamferAtHalfEdge() throws {
        // Edges 1, 3, 5, 6, 10 and 20 gave the input back; 2, 4, 8 and 100 were declined.
        for edge in [1.0, 3.0, 5.0, 6.0, 10.0, 20.0] {
            let c = try cube(edge)
            let result = c.chamfered(distance: edge / 2)
            #expect(result == nil, "edge \(edge): the tie must not answer the input")
        }
    }

    @Test("a cube chamfered one step below half its edge still builds the right solid")
    func cubeChamferBelowHalfEdge() throws {
        let c = try cube(10)
        let result = try #require(c.chamfered(distance: 4.9999))
        #expect(result.isValid)
        #expect(result.solidCount == 1)
        // The octahedron |x| + |y| + |z| <= d is 4/3 d^3 = 166.67.
        let volume = try #require(result.volume)
        #expect(abs(volume - 166.67) < 0.1)
    }

    @Test("a chamfer that does remove material is untouched at a small distance")
    func cubeChamferSmallDistance() throws {
        let c = try cube(10)
        let result = try #require(c.chamfered(distance: 1))
        #expect(result.isValid)
        #expect(result.faces().count == 26)
    }

    @Test("ChamferBuilder agrees with Shape.chamfered at the tie")
    func builderCubeChamferAtHalfEdge() throws {
        let c = try cube(10)
        let builder = try #require(ChamferBuilder(shape: c))
        for e in c.edges() { builder.addEdge(e, distance: 5) }
        #expect(builder.build() == nil)
    }

    // MARK: - Both rims of a cylinder at r = R = H / 2 (two solids)

    @Test("both rims of a cylinder filleted at r = R = H / 2 is nil, never two solids")
    func cylinderFilletBothRimsAtTie() throws {
        let cyl = try cylinder()
        let both = rims(cyl)
        #expect(both.count == 2)
        #expect(cyl.filleted(edges: both, radius: 5) == nil)
    }

    @Test("both rims filleted one step below the tie is one solid")
    func cylinderFilletBothRimsBelowTie() throws {
        let cyl = try cylinder()
        let result = try #require(cyl.filleted(edges: rims(cyl), radius: 4.9))
        #expect(result.isValid)
        #expect(result.solidCount == 1)
        let volume = try #require(result.volume)
        #expect(abs(volume - 532.52) < 0.1)
    }

    @Test("one rim at r = R is a hemispherical cap, one solid, not refused")
    func cylinderFilletOneRimAtRadius() throws {
        let cyl = try cylinder()
        let one = try #require(rims(cyl).first)
        let result = try #require(cyl.filleted(edges: [one], radius: 5))
        #expect(result.isValid)
        #expect(result.solidCount == 1)
        let volume = try #require(result.volume)
        #expect(abs(volume - 654.50) < 0.1)
    }

    @Test("both rims chamfered at d = 5 is nil through Shape and through the builders")
    func cylinderChamferBothRimsAtTie() throws {
        let cyl = try cylinder()
        let chamferBuilder = try #require(ChamferBuilder(shape: cyl))
        for e in rims(cyl) { chamferBuilder.addEdge(e, distance: 5) }
        #expect(chamferBuilder.build() == nil)

        let filletBuilder = try #require(FilletBuilder(shape: cyl))
        for e in rims(cyl) { filletBuilder.addEdge(e, radius: 5) }
        #expect(filletBuilder.build() == nil)
    }

    // MARK: - A blend may add material: the volume is not bounded, only the solid count is

    @Test("a fillet on a concave edge adds material and is not refused")
    func concaveFilletAddsMaterial() throws {
        let base = try #require(Shape.box(origin: .zero, width: 20, height: 10, depth: 5))
        let post = try #require(Shape.box(origin: SIMD3(0, 0, 5), width: 5, height: 10, depth: 10))
        let tee = try #require(base.union(post))
        // The inner edge: along y, where the post's side face (x = 5) meets the base top (z = 5).
        let inner = tee.edges().filter {
            guard let b = $0.bounds else { return false }
            return abs(b.min.x - 5) < 1e-6 && abs(b.max.x - 5) < 1e-6
                && abs(b.min.z - 5) < 1e-6 && abs(b.max.z - 5) < 1e-6
        }
        try #require(inner.count == 1)
        let before = try #require(tee.volume)
        let result = try #require(tee.filleted(edges: inner, radius: 1))
        #expect(result.isValid)
        #expect(result.solidCount == 1)
        let after = try #require(result.volume)
        #expect(after > before, "a concave fillet fills the corner, so the volume grows")
    }
}
