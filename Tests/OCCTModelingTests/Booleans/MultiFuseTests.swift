import Foundation
import Testing

@testable import OCCTSwift

@Suite("Multi-Tool Boolean Fuse")
struct MultiFuseTests {
    @Test("Fuse three overlapping boxes")
    func fuseThreeBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 0, 0))!
        let box3 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(0, 5, 0))!
        let result = Shape.fuseAll([box1, box2, box3])
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
            // Fused volume should be less than sum of individual volumes
            #expect(r.volume! < 3000)
            #expect(r.volume! > 1000)
        }
    }

    // #3332: the old test asserted `volume > 0`. Four radius-5 spheres centred (0,0), (4,0), (0,4),
    // (4,4) overlap pairwise, so the union volume is well below the 2094.395 sum. The expected
    // 1269.52 was checked independently with a 20-million-point Monte Carlo of the union
    // (1269.54 +- 0.3); two spheres 4 apart give 821.003, which is the closed form
    // 2 V - pi (4 r + d)(2 r - d)^2 / 12. `fuseAll` is General Fuse, so the answer is a compound
    // of split parts rather than one merged solid: the volume is pinned, the part count is not.
    @Test("Fuse four spheres")
    func fuseFourSpheres() throws {
        let s1 = try #require(Shape.sphere(radius: 5))
        let s2 = try #require(s1.translated(by: SIMD3(4, 0, 0)))
        let s3 = try #require(s1.translated(by: SIMD3(0, 4, 0)))
        let s4 = try #require(s1.translated(by: SIMD3(4, 4, 0)))

        // The pair first: the closed-form lens removes from two spheres.
        let pair = try #require(Shape.fuseAll([s1, s2]))
        let pairVolume = try #require(pair.volume)
        let sphere = 4.0 / 3.0 * Double.pi * 125
        let lens = Double.pi * (4 * 5 + 4) * pow(2 * 5 - 4.0, 2) / 12
        #expect(abs(pairVolume - (2 * sphere - lens)) < 1e-3)

        let result = try #require(Shape.fuseAll([s1, s2, s3, s4]))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 1269.52) < 0.05)
        #expect(volume < 4 * sphere - 100)
        let bounds = try #require(result.bounds)
        #expect(abs(bounds.min.x + 5) < 1e-3 && abs(bounds.max.x - 9) < 1e-3)
        #expect(abs(bounds.min.y + 5) < 1e-3 && abs(bounds.max.y - 9) < 1e-3)
        #expect(abs(bounds.min.z + 5) < 1e-3 && abs(bounds.max.z - 5) < 1e-3)
    }

    @Test("Fuse with less than 2 shapes returns nil")
    func fuseTooFew() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = Shape.fuseAll([box])
        #expect(result == nil)
    }

    @Test("Fuse non-overlapping shapes produces compound")
    func fuseNonOverlapping() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 20, 20))!
        let result = Shape.fuseAll([box1, box2])
        #expect(result != nil)
        if let r = result {
            // Sum of volumes should be preserved
            #expect(abs(r.volume! - 250.0) < 1.0)
        }
    }
}
