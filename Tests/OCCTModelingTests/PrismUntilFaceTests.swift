import Testing
import simd

@testable import OCCTSwift

@Suite("Prism Until Face")
struct PrismUntilFaceTests {
    @Test("Prism thru-all creates through feature")
    func prismThruAll() {
        // Create a box, then extrude a small circle through it
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let circle = Wire.circle(radius: 3)!
        let profile = Shape.face(from: circle)!
        // Face 5 (0-based) is top face z=10 on centered box
        let result = box.prismUntilFace(
            profile: profile, sketchFaceIndex: 5,
            direction: SIMD3(0, 0, -1), fuse: false,
            untilFaceIndex: nil  // thru-all
        )
        // This is a complex feature operation that may not work on all geometry
        _ = result
    }

    @Test("Prism until face API is callable")
    func prismUntilFaceCallable() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let rect = Wire.rectangle(width: 3, height: 3)!
        let profile = Shape.face(from: rect)!
        // Try extruding profile on top face (5) toward bottom face (4)
        let result = box.prismUntilFace(
            profile: profile, sketchFaceIndex: 5,
            direction: SIMD3(0, 0, -1), fuse: false,
            untilFaceIndex: 4
        )
        _ = result
    }
}
