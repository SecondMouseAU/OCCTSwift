import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Multi-face STL export completeness (#1225)")
struct Issue1225MultiFaceSTLExportTests {

    /// Proves #1225: a binary STL export must include every face, not just the first.
    ///
    /// A 10x10x10 box has 6 planar faces; at the default 0.1 deflection each face meshes to
    /// exactly 2 triangles (a flat rectangle needs no refinement), so a complete export has at
    /// least 12 triangles. Before the fix, `OCCTShapeWriteSTLBinary`/`OCCTShapeWriteSTLAscii`
    /// `return`ed inside the `TopExp_Explorer` face loop on the FIRST face with a non-null
    /// triangulation, silently discarding the other 5 faces while still reporting `true`. STL is a
    /// flat triangle soup with no face boundaries, so the round trip through `Shape.readSTL` is the
    /// only way to observe what actually landed in the file: it always comes back as one face
    /// wrapping whatever triangulation `RWStl::ReadFile` found there.
    @Test func binarySTLWritesEveryFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_1225_binary_\(Int.random(in: 0..<1_000_000)).stl"
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(box.writeSTLBinary(to: path))

        guard let readBack = Shape.readSTL(from: path) else {
            Issue.record("failed to read back the STL file just written")
            return
        }
        #expect(readBack.triangulationTriangleCount >= 12)
    }

    /// ASCII sibling of `binarySTLWritesEveryFace`, exercising `OCCTShapeWriteSTLAscii`.
    @Test func asciiSTLWritesEveryFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let path = "/tmp/occt_1225_ascii_\(Int.random(in: 0..<1_000_000)).stl"
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(box.writeSTLAscii(to: path))

        guard let readBack = Shape.readSTL(from: path) else {
            Issue.record("failed to read back the STL file just written")
            return
        }
        #expect(readBack.triangulationTriangleCount >= 12)
    }
}
