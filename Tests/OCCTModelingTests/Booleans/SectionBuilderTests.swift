import Testing

@testable import OCCTSwift

// #3332: every test here read `if let builder`, `if let result` and `#expect(result.isValid)`, so a
// builder that returned an empty compound passed, and two of the fixtures did not intersect in
// anything worth checking:
//   sectionTwoShapes     box [-5,5]^3 against box [5,15] x [5,15] x [0,10] touch along ONE edge
//                        (x = 5, y = 5, z in [0, 5]); the section is that single 5 mm edge
//   sectionInit          the plane z = 5 is coplanar with the box's own top face
//   sectionFromShapesCtor a radius-5 sphere inscribed in a 10 mm box touches it at six points
//                        only, so the section has NO edges (measured 0)
// The fixtures below intersect properly, and every section is pinned by its edges.
@Suite("SectionBuilder")
struct SectionBuilderTests {

    // The axis (0 x, 1 y, 2 z) a planar face is thin along and its coordinate there, for a face
    // of an axis-aligned box.
    private func planeOf(_ face: Shape?) throws -> (axis: Int, value: Double) {
        let plane = try #require(face)
        let bounds = try #require(plane.bounds)
        for axis in 0..<3 where bounds.max[axis] - bounds.min[axis] < 1e-3 {
            return (axis, (bounds.min[axis] + bounds.max[axis]) / 2)
        }
        Issue.record("not a coordinate-plane face: \(bounds)")
        return (-1, 0)
    }

    private func edgeLengths(_ shape: Shape) -> [Double] {
        shape.edges().map { $0.length }.sorted()
    }

    @Test("Section builder with two shapes")
    func sectionTwoShapes() throws {
        // Two 10 mm cubes, [0,10]^3 and [5,15] x [5,15] x [0,10]. Their surfaces meet along a
        // closed polyline of 10 edges: the two 10 mm verticals where each cube's face crosses
        // the other's, and eight 5 mm edges along the top and bottom faces.
        let box1 = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10))
        let builder = try #require(SectionBuilder(shape1: box1, shape2: box2))
        builder.setApproximation(true)
        builder.computePCurveOn1(true)
        builder.computePCurveOn2(true)
        let result = try #require(builder.build())
        #expect(result.isValid)
        let lengths = edgeLengths(result)
        #expect(lengths.count == 10)
        #expect(lengths.filter { abs($0 - 10) < 1e-6 }.count == 2)
        #expect(lengths.filter { abs($0 - 5) < 1e-6 }.count == 8)

        // The two 10 mm edges are the ones with ancestor faces: the vertical at (10, 5) lies on
        // box1's x = 10 face and box2's y = 5 face; the vertical at (5, 10) on box1's y = 10
        // face and box2's x = 5 face. (The other eight edges report none, measured.)
        var seen: [(Int, Double, Int, Double)] = []
        for edge in result.subShapes(ofType: .edge) {
            guard let length = edge.edges().first?.length, abs(length - 10) < 1e-6 else {
                continue
            }
            let on1 = try planeOf(builder.ancestorFaceOn1(edge: edge))
            let on2 = try planeOf(builder.ancestorFaceOn2(edge: edge))
            seen.append((on1.axis, on1.value, on2.axis, on2.value))
        }
        #expect(seen.count == 2)
        let wanted: [(Int, Double, Int, Double)] = [(0, 10, 1, 5), (1, 10, 0, 5)]
        for w in wanted {
            #expect(
                seen.contains {
                    $0.0 == w.0 && abs($0.1 - w.1) < 1e-6 && $0.2 == w.2 && abs($0.3 - w.3) < 1e-6
                },
                "ancestors \(w)")
        }
    }

    @Test("Section builder with Init1/Init2")
    func sectionInit() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(SectionBuilder())
        builder.init1(shape: box)
        builder.init2(plane: 0, 0, 1, -2)  // a x + b y + c z + d = 0: the plane z = 2

        let result = try #require(builder.build())
        #expect(result.isValid)
        // The cut of a 10 mm cube by z = 2 is its 10 x 10 square outline: four 10 mm edges at z = 2.
        #expect(edgeLengths(result).count == 4)
        for length in edgeLengths(result) { #expect(abs(length - 10) < 1e-6) }
        let bounds = try #require(result.bounds)
        #expect(abs(bounds.min.z - 2) < 1e-3 && abs(bounds.max.z - 2) < 1e-3)
        #expect(abs(bounds.min.x + 5) < 1e-3 && abs(bounds.max.x - 5) < 1e-3)

        // A plane that misses the cube has no section at all.
        let miss = try #require(SectionBuilder())
        miss.init1(shape: box)
        miss.init2(plane: 0, 0, 1, -20)
        let none = try #require(miss.build())
        #expect(none.edges().isEmpty)
    }

    @Test("Section builder with surface")
    func sectionWithSurface() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let plane = try #require(Surface.plane(origin: SIMD3(2, 0, 0), normal: SIMD3(1, 0, 0)))
        let builder = try #require(SectionBuilder())
        builder.init1(shape: box)
        builder.init2(surface: plane)
        builder.setApproximation(false)

        let result = try #require(builder.build())
        #expect(result.isValid)
        // The plane x = 2 cuts the cube in its 10 x 10 outline: four 10 mm edges at x = 2.
        #expect(edgeLengths(result).count == 4)
        for length in edgeLengths(result) { #expect(abs(length - 10) < 1e-6) }
        let bounds = try #require(result.bounds)
        #expect(abs(bounds.min.x - 2) < 1e-3 && abs(bounds.max.x - 2) < 1e-3)
        #expect(abs(bounds.min.y + 5) < 1e-3 && abs(bounds.max.y - 5) < 1e-3)
        #expect(abs(bounds.min.z + 5) < 1e-3 && abs(bounds.max.z - 5) < 1e-3)
    }

    @Test("Section builder from shapes constructor")
    func sectionFromShapesCtor() throws {
        // A radius-7 sphere pokes through each face of the 10 mm cube in a circle of radius
        // sqrt(7^2 - 5^2) = sqrt(24) that fits inside the face, so the section is six full
        // circles: 6 * 2 pi sqrt(24) = 184.687 (one circle is split by the sphere's seam: 7 edges).
        let sphere = try #require(Shape.sphere(radius: 7))
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(SectionBuilder(shape1: sphere, shape2: box))
        let result = try #require(builder.build())
        #expect(result.isValid)
        let total = edgeLengths(result).reduce(0, +)
        #expect(abs(total - 6 * 2 * Double.pi * 24.0.squareRoot()) < 1e-3)
        #expect(edgeLengths(result).count == 7)
    }
}
