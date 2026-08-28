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
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mirrored = box.mirroredAboutAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
        #expect(mirrored != nil)
        if let m = mirrored {
            #expect(m.isValid)
        }
    }
}

