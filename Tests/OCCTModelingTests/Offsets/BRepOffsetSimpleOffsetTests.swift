import Testing

@testable import OCCTSwift

@Suite("BRepOffset SimpleOffset")
struct BRepOffsetSimpleOffsetTests {
    // `BRepOffset_SimpleOffset` is topology-preserving and does not intersect: each face's
    // surface becomes its offset surface and keeps the same trimming, vertices land on the
    // average of the re-approximated edge ends, and tolerances grow to cover the difference. On
    // a 10 cube at distance 1 the six planes therefore sit at 6 with their original 10 x 10
    // extent (area 600, not the 864 of a true 12 cube). The signed volume of six outward faces
    // at distance h with area A is A * h / 3 each, so 1200 is "every plane at 6" and 1400 at
    // distance 2 is "every plane at 7" (measured on kernel.6; the vertices come out with
    // tolerance near 1.4, which is why a bounding box reads +-7.4 and is not used here).
    @Test("Simple offset on box")
    func simpleOffsetBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.simpleOffsetShape(distance: 1.0))
        #expect(result.isValid)
        let faces = result.subShapes(ofType: .face)
        #expect(faces.count == 6)
        for face in faces {
            #expect(abs((face.surfaceArea ?? -1) - 100.0) < 1e-6)
        }
        #expect(abs((result.surfaceArea ?? -1) - 600.0) < 1e-6)
        #expect(abs(result.signedVolume - 1200.0) < 1e-6)

        let farther = try #require(box.simpleOffsetShape(distance: 2.0))
        #expect(farther.isValid)
        #expect(abs(farther.signedVolume - 1400.0) < 1e-6)
    }
}
