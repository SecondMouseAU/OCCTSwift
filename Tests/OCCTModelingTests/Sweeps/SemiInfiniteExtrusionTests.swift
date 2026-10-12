import Testing

@testable import OCCTSwift

@Suite("Semi-Infinite Extrusion")
struct SemiInfiniteExtrusionTests {
    @Test("Semi-infinite extrusion of face")
    func semiInfiniteExtrusion() throws {
        let rect = try #require(Wire.rectangle(width: 5, height: 5))
        let face = try #require(Shape.face(from: rect))
        let result = try #require(face.extrudedSemiInfinite(direction: SIMD3(0, 0, 1)))
        #expect(result.isValid)
        // Four walls and the 5 x 5 cap at z = 0 and the open end at the kernel's 1e100.
        #expect(result.shapeType == .solid)
        #expect(result.faces().count == 5)
        let bounds = try #require(result.boundingBox)
        #expect(abs(bounds.min.z) < 1e-5)
        #expect(bounds.max.z >= 1e99)
        #expect(abs(bounds.max.x - 2.5) < 1e-5 && abs(bounds.max.y - 2.5) < 1e-5)
    }

    @Test("Infinite (both directions) extrusion of face")
    func infiniteExtrusion() throws {
        let circle = try #require(Wire.circle(radius: 3))
        let face = try #require(Shape.face(from: circle))
        // The old direction was +x, which lies IN the plane of this face (its normal is z), so
        // the "prism" was a degenerate sliver of zero area (measured: area 0, bounding box
        // 2e-7 thick). Along the normal it is a real cylinder running both ways.
        let result = try #require(
            face.extrudedSemiInfinite(direction: SIMD3(0, 0, 1), infinite: true))
        // Infinite prisms are constructed successfully but fail BRepCheck validation
        // (infinite geometry is inherently unbounded). What is pinned instead is the geometry:
        // a solid running from z = -1e100 to 1e100 with radius 3.
        #expect(result.shapeType == .solid)
        let bounds = try #require(result.boundingBox)
        #expect(bounds.min.z <= -1e99 && bounds.max.z >= 1e99)
        #expect(abs(bounds.max.x - 3.0) < 1e-5 && abs(bounds.min.x + 3.0) < 1e-5)
        // One-sided control: the semi-infinite one starts at the section and runs one way.
        let semi = try #require(
            face.extrudedSemiInfinite(direction: SIMD3(0, 0, 1), infinite: false))
        let semiBounds = try #require(semi.boundingBox)
        #expect(abs(semiBounds.min.z) < 1e-5 && semiBounds.max.z >= 1e99)
    }

    @Test("Semi-infinite extrusion of wire")
    func semiInfiniteWireExtrusion() throws {
        let wire = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let wireShape = try #require(Shape.fromWire(wire))
        let result = try #require(wireShape.extrudedSemiInfinite(direction: SIMD3(0, 1, 0)))
        // A 10 mm wire extruded along +y is one half-strip: one face, x from 0 to 10, y from 0
        // to the kernel's 1e100, flat in z.
        #expect(result.faces().count == 1)
        let bounds = try #require(result.boundingBox)
        #expect(abs(bounds.min.x) < 1e-5 && abs(bounds.max.x - 10.0) < 1e-5)
        #expect(abs(bounds.min.y) < 1e-5 && bounds.max.y >= 1e99)
        #expect(abs(bounds.min.z) < 1e-5 && abs(bounds.max.z) < 1e-5)
    }
}
