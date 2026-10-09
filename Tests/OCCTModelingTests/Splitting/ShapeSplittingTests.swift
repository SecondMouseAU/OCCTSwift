import Testing
import simd

@testable import OCCTSwift

// Uses ModelingTestExtensions.SIMD3.normalized (epsilon 1e-10)

@Suite("Shape Splitting Tests")
struct ShapeSplittingTests {

    @Test("Split box by horizontal plane")
    func splitByHorizontalPlane() {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Split at Z=0 (middle of the box)
        let halves = box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))

        #expect(halves != nil)
        #expect(halves!.count == 2)

        // Each half should be valid
        for half in halves! {
            #expect(half.isValid)
        }

        // Total volume should equal original
        let totalVolume = halves!.reduce(0.0) { $0 + ($1.volume ?? 0) }
        let originalVolume = box.volume ?? 0
        #expect(abs(totalVolume - originalVolume) < 1.0)
    }

    @Test("Split box by diagonal plane")
    func splitByDiagonalPlane() {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Split diagonally through center
        let pieces = box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(1, 1, 0).normalized)

        #expect(pieces != nil)
        #expect(pieces!.count >= 2)

        for piece in pieces! {
            #expect(piece.isValid)
        }
    }

    @Test("Split by shape tool")
    func splitByShapeTool() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Create a cutting face
        let cuttingFace = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
            .translated(by: SIMD3(0, 0, 10))!

        let pieces = box.split(by: cuttingFace)

        #expect(pieces != nil)
        #expect(pieces!.count >= 1)
    }
}
