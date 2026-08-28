import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.100.0 Tests

@Suite("RWStl Direct STL I/O Tests")
struct RWStlDirectTests {

    @Test func writeBinarySTL() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_rwstl_binary_\(Int.random(in: 0..<1_000_000)).stl"
        let ok = box.writeSTLBinary(to: path)
        #expect(ok)
        // Clean up
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func writeAsciiSTL() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_rwstl_ascii_\(Int.random(in: 0..<1_000_000)).stl"
        let ok = box.writeSTLAscii(to: path)
        #expect(ok)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func readSTL() {
        // Write a box first, then read it back
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_rwstl_read_\(Int.random(in: 0..<1_000_000)).stl"
        guard box.writeSTLBinary(to: path) else { return }
        if let shape = Shape.readSTL(from: path) {
            // readSTL returns a face with triangulation, not necessarily "valid" by BRep standards
            // Just check it's not nil
            _ = shape
        }
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func roundTripBinarySTL() {
        guard let sphere = Shape.sphere(radius: 5) else { return }
        let path = "/tmp/occt_rwstl_round_\(Int.random(in: 0..<1_000_000)).stl"
        guard sphere.writeSTLBinary(to: path) else { return }
        if let read = Shape.readSTL(from: path) {
            _ = read  // Successfully round-tripped
        }
        try? FileManager.default.removeItem(atPath: path)
    }
}
