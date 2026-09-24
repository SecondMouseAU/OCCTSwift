import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Both tests assert what the kernel's volume maker returns.
///
/// #1809: the one test here ran `makeVolume` and discarded the result, "just verify it doesn't
/// crash", so an implementation returning anything, or nothing, passed. Both tests now assert
/// what BOPAlgo_MakerVolume reports for the same inputs (`Scripts/repro/766-make-volume/`).
@Suite("Make Volume")
struct MakeVolumeTests {
    /// Six faces that close a region make one solid of that region's volume.
    @Test("Make volume from faces")
    func volumeFromFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let result = try #require(Shape.makeVolume(from: faces))
        #expect(result.subShapes(ofType: .solid).count == 1)
        let volume = try #require(result.volume)
        #expect(abs(volume - 1000) < 1e-6, "got \(volume)")
    }

    /// The test's original input: two coincident faces enclose nothing.
    ///
    /// The kernel reports no
    /// error and an empty result, so the wrapper returns a shape with no solid in it, not nil.
    @Test("Two coincident faces enclose no volume")
    func coincidentFacesEncloseNothing() throws {
        let w1 = try #require(Wire.rectangle(width: 10, height: 10))
        let w2 = try #require(Wire.rectangle(width: 10, height: 10))
        let f1 = try #require(Shape.face(from: w1))
        let f2 = try #require(Shape.face(from: w2))
        let result = try #require(Shape.makeVolume(from: [f1, f2]))
        #expect(result.subShapes(ofType: .solid).isEmpty)
    }
}
