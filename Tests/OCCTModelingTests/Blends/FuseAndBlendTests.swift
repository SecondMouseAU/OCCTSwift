import Testing
import simd

@testable import OCCTSwift

// MARK: - Fuse and Blend Tests (v0.38.0)

@Suite("Fuse and Blend")
struct FuseAndBlendTests {

    @Test("Fuse two overlapping boxes with blend")
    func fuseBlendBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 0, 0))!
        let result = box1.fusedAndBlended(with: box2, radius: 1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 1000.0)
            #expect(r.isValid)
        }
    }

    @Test("Fuse box and cylinder with blend")
    func fuseBlendBoxCylinder() {
        let box = Shape.box(width: 20, height: 20, depth: 10)!.translated(by: SIMD3(-10, -10, 0))!
        let cyl = Shape.cylinder(radius: 5, height: 15)!
        let result = box.fusedAndBlended(with: cyl, radius: 1.0)
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Cut and blend")
    func cutBlend() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!.translated(by: SIMD3(-10, -10, 0))!
        let cyl = Shape.cylinder(radius: 5, height: 25)!
        let result = box.cutAndBlended(with: cyl, radius: 1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! < 8000.0)
        }
    }
}
