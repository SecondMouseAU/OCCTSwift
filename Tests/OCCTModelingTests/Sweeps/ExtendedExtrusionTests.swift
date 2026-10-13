import Testing

@testable import OCCTSwift

// MARK: - Sweep & Distance Gap Fixes

@Suite("Extended Extrusion")
struct ExtendedExtrusionTests {
    @Test func extrudeFaceByVector() throws {
        // Extrude a face (not a solid) to create a solid
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: wire))
        let extruded = try #require(face.extruded(by: SIMD3(0, 0, 20)))
        #expect(extruded.isValid)
        // 10 x 10 x 20, six faces, 2 * (100 + 200 + 200) = 1000 of area, from z = 0 to 20.
        #expect(extruded.shapeType == .solid)
        #expect(extruded.faces().count == 6)
        #expect(abs((extruded.volume ?? -1) - 2000.0) < 1e-6)
        #expect(abs((extruded.surfaceArea ?? -1) - 1000.0) < 1e-6)
        let bounds = try #require(extruded.boundingBox)
        #expect(abs(bounds.min.z) < 1e-5 && abs(bounds.max.z - 20.0) < 1e-5)
    }

    @Test func extrudeEdgeByVector() throws {
        // #204: the previous body wrapped a Wire's handle in a Shape
        // (`Shape(handle: wire.handle)`), double-owning the C++ handle, both the
        // Wire and the Shape freed it on scope exit → double-free → SIGSEGV. That
        // block was dead code (the resulting `face` was never used). Removed.
        let rect = try #require(Wire.rectangle(width: 5, height: 5))
        let face = try #require(Shape.face(from: rect))
        let semi = try #require(face.extrudedInfinite(direction: SIMD3(0, 0, 1), infinite: false))
        // A semi-infinite prism: four walls and the cap, running from z = 0 to the kernel's
        // 1e100 "infinite" (volume and area of such a shape are not meaningful numbers).
        #expect(semi.shapeType == .solid)
        #expect(semi.faces().count == 5)
        let bounds = try #require(semi.boundingBox)
        #expect(abs(bounds.min.z) < 1e-5)
        #expect(bounds.max.z >= 1e99)
        #expect(abs(bounds.max.x - 2.5) < 1e-5 && abs(bounds.min.x + 2.5) < 1e-5)
        // And `infinite: true` runs both ways: no cap, four walls, z from -1e100.
        let both = try #require(face.extrudedInfinite(direction: SIMD3(0, 0, 1), infinite: true))
        #expect(both.faces().count == 4)
        let bothBounds = try #require(both.boundingBox)
        #expect(bothBounds.min.z <= -1e99 && bothBounds.max.z >= 1e99)
    }
}
