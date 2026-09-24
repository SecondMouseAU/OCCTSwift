import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeMirror")
struct ShapeMirrorTests {
    @Test("Mirror box about point")
    func mirrorAboutPoint() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Box is centered at origin (-5 to +5), mirror about (20,0,0)
        let mirrored = box.mirroredAboutPoint(SIMD3(20, 0, 0))
        #expect(mirrored != nil)
        if let m = mirrored {
            #expect(m.isValid)
            let bb = m.bounds!
            // Box (-5..5) mirrored about x=20 gives (35..45)
            #expect(abs(bb.min.x - 35) < 0.5)
            #expect(abs(bb.max.x - 45) < 0.5)
        }
    }

    @Test("Mirror box about axis")
    func mirrorAboutAxis() throws {
        // A box centred on the Z axis is its own mirror image about that axis, so a mirror about
        // any wrong axis through the origin reproduced it. The box is offset so the mirror moves
        // it. Probed (Scripts/repro/766-math-shape-transforms): (1..11, 2..12, 3..13) mirrors to
        // (-11..-1, -12..-2, 3..13), each face widened by the 1e-7 vertex tolerance.
        let box = try #require(Shape.box(origin: SIMD3(1, 2, 3), width: 10, height: 10, depth: 10))
        let mirrored = box.mirroredAboutAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
        #expect(mirrored != nil)
        if let m = mirrored {
            #expect(m.isValid)
            let bounds = m.bounds
            #expect(bounds != nil)
            if let bb = bounds {
                #expect(abs(bb.min.x + 11) < 1e-6)
                #expect(abs(bb.max.x + 1) < 1e-6)
                #expect(abs(bb.min.y + 12) < 1e-6)
                #expect(abs(bb.max.y + 2) < 1e-6)
                #expect(abs(bb.min.z - 3) < 1e-6)
                #expect(abs(bb.max.z - 13) < 1e-6)
            }
        }
    }
}

