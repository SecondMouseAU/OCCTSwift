import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BinTools Shape I/O Tests")
struct BinToolsTests {
    /// Before #1981 this went red on a writer emitting a null shape only because that stream is
    /// under 10 bytes; a writer serialising the wrong solid passed. The read-back is now pinned
    /// to the box: volume 6000, six faces.
    @Test func writeAndReadBinaryData() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let data = try #require(box.toBinaryData())
        #expect(data.count > 10)
        let readShape = try #require(Shape.fromBinaryData(data))
        #expect(readShape.isValid)
        #expect(readShape.faces().count == 6)
        let volume = try #require(readShape.volume)
        #expect(abs(volume - 6000) < 1e-9, "round-tripped volume \(volume)")
    }

    /// Before #1981 this asserted only `ok` and, inside `if let`, `isValid`: a writer that
    /// serialised a null shape still returned true, and the failed read skipped the check.
    /// The read-back must now be the 10x20x30 box itself, volume 6000 with six faces, which
    /// BinTools_ShapeWriter/Reader give in `Scripts/repro/766-topology-bintools-brepadaptor/`.
    @Test func writeAndReadBinaryFile() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            "test_v85_bin_\(UUID().uuidString).brep")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(box.writeBinary(to: url))
        let readShape = try #require(Shape.loadBinary(from: url))
        #expect(readShape.isValid)
        #expect(readShape.faces().count == 6)
        let volume = try #require(readShape.volume)
        #expect(abs(volume - 6000) < 1e-9, "round-tripped volume \(volume)")
    }

    /// Before #1981 every check sat inside `if let` on the write and the read, so a writer that
    /// produced a null shape skipped the only assertion. Kernel: volume 4/3 pi 5^3, one face.
    @Test func sphereRoundtrip() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let data = try #require(sphere.toBinaryData())
        let readShape = try #require(Shape.fromBinaryData(data))
        #expect(readShape.isValid)
        #expect(readShape.faces().count == 1)
        let volume = try #require(readShape.volume)
        #expect(abs(volume - 523.59877559829897) < 1e-9, "round-tripped volume \(volume)")
    }
}
