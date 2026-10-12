import Testing

@testable import OCCTSwift

// #3332: both tests ended in `_ = result`. BRepFeat_MakePrism through a box has closed forms:
//   thru-all, fuse = false: a radius-3 circle at the box's mid-plane, cut right through the
//     20 mm box in both directions (measured: the prism is not one-sided), 8000 - pi 3^2 20
//   until a face, fuse = false: a 3 x 3 profile at the centre of the 10 mm cube cut toward the
//     bottom face (4): the 5 mm from the profile plane to z = -5, 1000 - 3 * 3 * 5 = 955
// and `fuse = true` is refused (nil, measured) in both: the profile sits inside the solid, so
// there is nothing for a fused prism to add.
@Suite("Prism Until Face")
struct PrismUntilFaceTests {
    @Test("Prism thru-all creates through feature")
    func prismThruAll() throws {
        // Create a box, then extrude a small circle through it
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let circle = try #require(Wire.circle(radius: 3))
        let profile = try #require(Shape.face(from: circle))
        // Face 5 (0-based) is top face z=10 on centered box
        let result = try #require(
            box.prismUntilFace(
                profile: profile, sketchFaceIndex: 5,
                direction: SIMD3(0, 0, -1), fuse: false,
                untilFaceIndex: nil  // thru-all
            ))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - (8000 - Double.pi * 9 * 20)) < 1e-6)
        // Through: the cut leaves the box's six faces and adds the bore's one wall.
        #expect(result.faceCount == 7)

        // The sketch face index does not change a thru-all cut.
        for face in 0..<6 {
            let again = try #require(
                box.prismUntilFace(
                    profile: profile, sketchFaceIndex: face,
                    direction: SIMD3(0, 0, -1), fuse: false, untilFaceIndex: nil))
            let againVolume = try #require(again.volume)
            #expect(abs(againVolume - volume) < 1e-6, "sketch face \(face)")
        }

        // Fusing a prism that starts inside the solid is refused.
        #expect(
            box.prismUntilFace(
                profile: profile, sketchFaceIndex: 5, direction: SIMD3(0, 0, -1), fuse: true,
                untilFaceIndex: nil) == nil)
    }

    @Test("Prism until face API is callable")
    func prismUntilFaceCallable() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let rect = try #require(Wire.rectangle(width: 3, height: 3))
        let profile = try #require(Shape.face(from: rect))
        // Cut the profile (at the cube's mid-plane) toward the bottom face (4).
        let result = try #require(
            box.prismUntilFace(
                profile: profile, sketchFaceIndex: 5,
                direction: SIMD3(0, 0, -1), fuse: false,
                untilFaceIndex: 4
            ))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 955) < 1e-6)
        #expect(result.faceCount == 11)

        // Stopping at the other face of the cube measures the same 5 mm: the profile is at the
        // mid-plane and `direction` is still downward, so the face index names where the prism
        // stops, not which way it goes (measured: sketch 4 until 5 is also 955).
        let other = try #require(
            box.prismUntilFace(
                profile: profile, sketchFaceIndex: 4,
                direction: SIMD3(0, 0, -1), fuse: false,
                untilFaceIndex: 5
            ))
        let otherVolume = try #require(other.volume)
        #expect(abs(otherVolume - 955) < 1e-6)

        // A side face is not a face this prism reaches: refused, as is fusing.
        #expect(
            box.prismUntilFace(
                profile: profile, sketchFaceIndex: 5, direction: SIMD3(0, 0, -1), fuse: false,
                untilFaceIndex: 0) == nil)
        #expect(
            box.prismUntilFace(
                profile: profile, sketchFaceIndex: 5, direction: SIMD3(0, 0, -1), fuse: true,
                untilFaceIndex: 4) == nil)
    }
}
