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
