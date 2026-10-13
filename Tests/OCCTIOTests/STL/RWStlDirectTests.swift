import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.100.0 Tests

@Suite("RWStl Direct STL I/O Tests")
struct RWStlDirectTests {

    /// A path of this test's own in the temp directory.
    private func tempPath(_ stem: String) -> String {
        NSTemporaryDirectory() + "occt_rwstl_\(stem)_\(UUID()).stl"
    }

    /// The triangle count a binary STL file declares in its header (bytes 80 to 83), which the
    /// format fixes as little-endian whatever the host is.
    private func declaredTriangles(_ data: Data) -> Int {
        let raw = data.subdata(in: 80..<84).withUnsafeBytes { $0.load(as: UInt32.self) }
        return Int(UInt32(littleEndian: raw))
    }

    @Test func writeBinarySTL() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let path = tempPath("binary")
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(box.writeSTLBinary(to: path))

        // Binary STL: 80 bytes of header, a uint32 triangle count, then 50 bytes per triangle. A
        // box is two triangles per face, so 12.
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(declaredTriangles(data) == 12)
        #expect(data.count == 84 + 12 * 50)
    }

    @Test func writeAsciiSTL() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let path = tempPath("ascii")
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(box.writeSTLAscii(to: path))

        let text = try String(contentsOfFile: path, encoding: .ascii)
        #expect(text.hasPrefix("solid"))
        #expect(text.components(separatedBy: "facet normal").count - 1 == 12)
        #expect(text.components(separatedBy: "vertex ").count - 1 == 36)
        #expect(text.contains("endsolid"))
    }

    @Test func readSTL() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let path = tempPath("read")
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(box.writeSTLBinary(to: path))

        // readSTL returns one face carrying the triangulation, not a solid, so "valid by BRep
        // standards" is not the claim: the face spans the box that was written.
        let shape = try #require(Shape.readSTL(from: path))
        #expect(shape.shapeType == .face)
        let bounds = try #require(shape.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-5, -5, -5)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(5, 5, 5)) < 1e-5)

        // The ASCII form reads back as the same face.
        let asciiPath = tempPath("read_ascii")
        defer { try? FileManager.default.removeItem(atPath: asciiPath) }
        #expect(box.writeSTLAscii(to: asciiPath))
        let fromAscii = try #require(Shape.readSTL(from: asciiPath))
        #expect(fromAscii.shapeType == .face)
        let asciiBounds = try #require(fromAscii.bounds)
        #expect(vectorDistance(asciiBounds.min, SIMD3(-5, -5, -5)) < 1e-5)
        #expect(vectorDistance(asciiBounds.max, SIMD3(5, 5, 5)) < 1e-5)

        // A file that is not there is nil, not an empty face.
        #expect(Shape.readSTL(from: tempPath("missing")) == nil)
    }

    /// Transforms of a triangulation-only face have to move it (#3388).
    ///
    /// The face `readSTL` returns has no surface, and a transform of it used to answer the
    /// input's own TShape with its bounds unchanged, because `BRepBuilderAPI_Transform` only
    /// rebuilds a face through its surface. The box and the compound `loadSTL` returns are the
    /// controls that already moved.
    @Test func transformsMoveTriangulationOnlyFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let path = tempPath("transform")
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(box.writeSTLBinary(to: path))
        let face = try #require(Shape.readSTL(from: path))
        #expect(face.shapeType == .face)

        func expectBounds(
            _ shape: Shape?, _ lo: SIMD3<Double>, _ hi: SIMD3<Double>, _ label: String
        ) throws {
            let b = try #require(shape?.bounds, "\(label): no bounds")
            #expect(vectorDistance(b.min, lo) < 1e-5, "\(label): min \(b.min)")
            #expect(vectorDistance(b.max, hi) < 1e-5, "\(label): max \(b.max)")
        }

        try expectBounds(
            face.translated(by: SIMD3(100, 0, 0)), SIMD3(95, -5, -5), SIMD3(105, 5, 5), "translated"
        )
        try expectBounds(
            face.scaled(by: 2), SIMD3(-10, -10, -10), SIMD3(10, 10, 10), "scaled")
        try expectBounds(
            face.scaledAboutPoint(SIMD3(10, 0, 0), factor: 2),
            SIMD3(-20, -10, -10), SIMD3(0, 10, 10), "scaledAboutPoint")
        try expectBounds(
            face.translated(from: SIMD3(0, 0, 0), to: SIMD3(0, 50, 0)),
            SIMD3(-5, 45, -5), SIMD3(5, 55, 5), "translated(from:to:)")
        try expectBounds(
            face.mirrored(planeNormal: SIMD3(1, 0, 0), planeOrigin: SIMD3(10, 0, 0)),
            SIMD3(15, -5, -5), SIMD3(25, 5, 5), "mirrored")
        try expectBounds(
            face.mirroredAboutPoint(SIMD3(10, 0, 0)),
            SIMD3(15, -5, -5), SIMD3(25, 5, 5), "mirroredAboutPoint")

        // A rotation of an off-centre face: x 15...25 turned a quarter about z lands on y 15...25.
        let offPath = tempPath("transform_off")
        defer { try? FileManager.default.removeItem(atPath: offPath) }
        let off = try #require(box.translated(by: SIMD3(20, 0, 0)))
        #expect(off.writeSTLBinary(to: offPath))
        let offFace = try #require(Shape.readSTL(from: offPath))
        try expectBounds(
            offFace.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 2),
            SIMD3(-5, 15, -5), SIMD3(5, 25, 5), "rotated")

        // The input is left where it was.
        let moved = try #require(face.translated(by: SIMD3(100, 0, 0)))
        #expect(moved.shapeType == .face)
        let original = try #require(face.bounds)
        #expect(vectorDistance(original.min, SIMD3(-5, -5, -5)) < 1e-5)

        // Controls: a box, and the compound loadSTL returns, moved before as well.
        try expectBounds(
            box.translated(by: SIMD3(100, 0, 0)), SIMD3(95, -5, -5), SIMD3(105, 5, 5), "box")
        let compound = try Shape.loadSTL(from: URL(fileURLWithPath: path))
        try expectBounds(
            compound.translated(by: SIMD3(100, 0, 0)), SIMD3(95, -5, -5), SIMD3(105, 5, 5),
            "loadSTL compound")
    }

    /// A compound that mixes a triangulation-only face with a box moves both parts (#3388).
    ///
    /// The helper takes the `BRepBuilderAPI_Transform` path for the box and places only the bare
    /// face by location, so a scale or a mirror is not written into the location of the box's
    /// faces. Every part of the compound must land where a transform of it alone does.
    @Test func transformsMoveMixedCompound() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let path = tempPath("transform_mixed")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let off = try #require(box.translated(by: SIMD3(20, 0, 0)))
        #expect(off.writeSTLBinary(to: path))
        let bare = try #require(Shape.readSTL(from: path))
        let mixed = try #require(Shape.compound([box, bare]))
        let faceCount = mixed.faces().count
        #expect(faceCount == 7)

        func expectBounds(
            _ shape: Shape?, _ lo: SIMD3<Double>, _ hi: SIMD3<Double>, _ label: String
        ) throws {
            let b = try #require(shape?.bounds, "\(label): no bounds")
            #expect(vectorDistance(b.min, lo) < 1e-5, "\(label): min \(b.min)")
            #expect(vectorDistance(b.max, hi) < 1e-5, "\(label): max \(b.max)")
        }

        // Box x -5...5 and bare face x 15...25: together x -5...25.
        try expectBounds(mixed, SIMD3(-5, -5, -5), SIMD3(25, 5, 5), "mixed")
        try expectBounds(
            mixed.translated(by: SIMD3(100, 0, 0)), SIMD3(95, -5, -5), SIMD3(125, 5, 5),
            "translated")
        let scaled = try #require(mixed.scaled(by: 2))
        try expectBounds(scaled, SIMD3(-10, -10, -10), SIMD3(50, 10, 10), "scaled")
        #expect(scaled.faces().count == faceCount)
        try expectBounds(
            mixed.mirrored(planeNormal: SIMD3(1, 0, 0), planeOrigin: SIMD3(0, 0, 0)),
            SIMD3(-25, -5, -5), SIMD3(5, 5, 5), "mirrored")

        // The box part of the scaled compound is a solid of eight times the volume.
        let solid = try #require(scaled.solids.first)
        #expect(abs((solid.volume ?? 0) - 8000) < 1e-3)
    }

    @Test func roundTripBinarySTL() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let path = tempPath("round")
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(sphere.writeSTLBinary(to: path))

        // 516 triangles at the default deflection on the pinned kernel (wasm-sensitive count).
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(declaredTriangles(data) == 516)
        #expect(data.count == 84 + declaredTriangles(data) * 50)

        // The read-back face spans the sphere: the poles are on the z axis, so z is exact, and
        // the mesh's vertices sit on the sphere so no extent exceeds the radius or falls far
        // short of it.
        let read = try #require(Shape.readSTL(from: path))
        #expect(read.shapeType == .face)
        let bounds = try #require(read.bounds)
        #expect(abs(bounds.max.z - 5) < 1e-5)
        #expect(abs(bounds.min.z + 5) < 1e-5)
        for extent in [bounds.min.x, bounds.min.y, bounds.max.x, bounds.max.y] {
            #expect(abs(extent) <= 5 + 1e-5)
            #expect(abs(extent) > 4.9)
        }
    }
}
