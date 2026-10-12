import Testing

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

    // #3332: the old body asserted `count >= 2` and per-piece validity. A plane through the
    // centre of a cube, tilted 45 degrees about z, cuts it into two congruent halves of volume
    // 4000, five faces apiece (kept box faces plus the cut face), and the volumes add up to 8000.
    @Test("Split box by diagonal plane")
    func splitByDiagonalPlane() throws {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))

        // Split diagonally through center
        let pieces = try #require(
            box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(1, 1, 0).normalized))

        #expect(pieces.count == 2)
        for piece in pieces {
            #expect(piece.isValid)
            let volume = try #require(piece.volume)
            #expect(abs(volume - 4000) < 1e-6)
            #expect(piece.faceCount == 5)
        }
        let total = pieces.reduce(0.0) { $0 + ($1.volume ?? 0) }
        #expect(abs(total - 8000) < 1e-6)

        // The halves lie on opposite sides of the plane: their centres of mass are mirror images
        // through the origin along the plane normal (x = y), a third of the half-width out:
        // 10 / 3 per axis for the half of a [-10, 10] square on one side of its diagonal.
        let centres = pieces.compactMap { $0.centerOfMass }
        #expect(centres.count == 2)
        if centres.count == 2 {
            #expect(abs(centres[0].x + centres[1].x) < 1e-6)
            #expect(abs(centres[0].y + centres[1].y) < 1e-6)
            #expect(abs(centres[0].z) < 1e-6 && abs(centres[1].z) < 1e-6)
            #expect(abs(abs(centres[0].x) - 10.0 / 3.0) < 1e-6)
            #expect(abs(centres[0].x - centres[0].y) < 1e-6)
        }
    }

    // #3332: the old cutting face was translated to z = 10, the cube's own top face (the box is
    // centred, z in [-10, 10]): coplanar with a face of the body, so nothing was cut and the
    // answer was ONE piece of volume 8000, which `count >= 1` accepted. A sheet through the middle
    // (z = 0) splits it into two 4000 mm^3 halves of six faces each; at z = 5, into 2000 and
    // 6000; and at z = 10 the cube comes back whole.
    @Test("Split by shape tool")
    func splitByShapeTool() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let outline = try #require(Wire.rectangle(width: 40, height: 40))
        let sheet = try #require(Shape.face(from: outline))

        let middle = try #require(box.split(by: sheet))
        #expect(middle.count == 2)
        for piece in middle {
            #expect(piece.isValid)
            let volume = try #require(piece.volume)
            #expect(abs(volume - 4000) < 1e-6)
            #expect(piece.faceCount == 6)
        }

        let high = try #require(sheet.translated(by: SIMD3(0, 0, 5)))
        let unequal = try #require(box.split(by: high))
        #expect(unequal.count == 2)
        let volumes = unequal.compactMap { $0.volume }.sorted()
        #expect(volumes.count == 2)
        if volumes.count == 2 {
            #expect(abs(volumes[0] - 2000) < 1e-6)
            #expect(abs(volumes[1] - 6000) < 1e-6)
        }

        // Coplanar with the cube's top face (z = 10): nothing to cut, the cube comes back whole.
        let coplanar = try #require(sheet.translated(by: SIMD3(0, 0, 10)))
        let whole = try #require(box.split(by: coplanar))
        #expect(whole.count == 1)
        let wholeVolume = try #require(whole.first?.volume)
        #expect(abs(wholeVolume - 8000) < 1e-6)
    }
}
