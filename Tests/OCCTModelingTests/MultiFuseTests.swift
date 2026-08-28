import Testing
import simd

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

    @Test("Fuse four spheres")
    func fuseFourSpheres() {
        let s1 = Shape.sphere(radius: 5)!
        let s2 = Shape.sphere(radius: 5)!.translated(by: SIMD3(4, 0, 0))!
        let s3 = Shape.sphere(radius: 5)!.translated(by: SIMD3(0, 4, 0))!
        let s4 = Shape.sphere(radius: 5)!.translated(by: SIMD3(4, 4, 0))!
        let result = Shape.fuseAll([s1, s2, s3, s4])
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
        }
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
