import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_BuilderSolid Tests")
struct BOPAlgoBuilderSolidTests {
    @Test("Build solid from box faces")
    func buildSolidFromFaces() throws {
        // #766: every step used to sit in a nested `if let`, so a fixture that failed to build
        // skipped all the assertions, and the count was only `>= 1`. The fixtures are now
        // `try #require`, and the kernel's answer is pinned (Scripts/repro/766-modeling-bopalgo-
        // builder-solid): BOPAlgo_BuilderSolid on the six faces of the centred 10 mm box returns
        // exactly 1 valid solid of volume 1000.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = b.subShapes(ofType: .face)
        try #require(faces.count == 6)
        let r = try #require(Shape.buildSolids(from: faces))
        #expect(r.count >= 1)
        #expect(r.count == 1)
        let solid = try #require(r.first)
        #expect(solid.isValid)
        let volume = try #require(solid.volume)
        #expect(abs(volume - 1000) < 1e-6)
    }
}
