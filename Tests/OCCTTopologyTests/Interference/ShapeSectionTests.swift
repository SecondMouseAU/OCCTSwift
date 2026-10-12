import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.34.0. OCCT Test Suite Audit Round 3

@Suite("Shape-to-Shape Section")
struct ShapeSectionTests {
    @Test("Section of two intersecting boxes")
    func sectionTwoBoxes() throws {
        // [-5,5]^3 against the same cube shifted to x, y in [0,10]. The boundaries meet in the
        // two vertical lines at (5,0) and (0,5) (length 10 each) and, because the top and bottom
        // faces are coplanar, in the 5-unit edges that outline the overlapped square on each
        // of them: 8 of those. Total 10 edges, 60 units of length, 8 vertices.
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 5, 0)))
        let result = try #require(box1.section(box2))
        let edges = result.edges()
        #expect(edges.count == 10)
        #expect(result.uniqueVertexCount == 8)
        let lengths = edges.map(\.length).sorted()
        #expect(lengths.filter { abs($0 - 10) < 1e-9 }.count == 2)
        #expect(lengths.filter { abs($0 - 5) < 1e-9 }.count == 8)
        #expect(abs(lengths.reduce(0, +) - 60) < 1e-9)
    }

    @Test("Section of box and cylinder")
    func sectionBoxCylinder() throws {
        // The cylinder (axis z, z in [0,20], r = 3) pierces the box's top face (z = 5): the
        // only boundary crossing is the circle of radius 3 on that face, length 6 pi. The
        // cylinder's base at z = 0 is inside the box, so it contributes nothing.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let cyl = try #require(Shape.cylinder(radius: 3, height: 20))
        let result = try #require(box.section(cyl))
        let edges = result.edges()
        #expect(edges.count == 1)
        if let circle = edges.first {
            #expect(circle.isCircle)
            #expect(abs(circle.length - 6 * .pi) < 1e-9)
            let b = try #require(circle.bounds)
            #expect(abs(b.min.z - 5) < 1e-6)
            #expect(abs(b.max.z - 5) < 1e-6)
            #expect(abs(b.max.x - 3) < 1e-6)
        }
    }

    @Test("Section of non-intersecting shapes returns empty")
    func sectionNoIntersection() throws {
        let box1 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let box2 = try #require(
            Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(100, 100, 100)))
        // The kernel answers a valid compound with nothing in it, not nil.
        let result = try #require(box1.section(box2))
        #expect(result.shapeType == .compound)
        #expect(result.edges().isEmpty)
        #expect(result.uniqueVertexCount == 0)
    }

    @Test("Section of sphere and plane")
    func sectionSpherePlane() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        // A 20x20 slab 0.001 thick, centred on z = 0: its two faces at z = +-0.0005 each cut the
        // sphere in a circle of radius sqrt(25 - 0.0005^2) = 4.999999975.
        let plane = try #require(Shape.box(width: 20, height: 20, depth: 0.001))
        let result = try #require(sphere.section(plane))
        let edges = result.edges()
        #expect(edges.count == 2)
        let radius = (25 - 0.0005 * 0.0005).squareRoot()
        var heights: [Double] = []
        for edge in edges {
            #expect(edge.isCircle)
            #expect(abs(edge.length - 2 * .pi * radius) < 1e-6)
            let b = try #require(edge.bounds)
            heights.append((b.min.z + b.max.z) / 2)
        }
        heights.sort()
        if heights.count == 2 {
            #expect(abs(heights[0] + 0.0005) < 1e-6)
            #expect(abs(heights[1] - 0.0005) < 1e-6)
        }
    }
}
