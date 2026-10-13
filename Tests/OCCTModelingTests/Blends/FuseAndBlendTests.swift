import Testing

@testable import OCCTSwift

// MARK: - Fuse and Blend Tests (v0.38.0)

@Suite("Fuse and Blend")
struct FuseAndBlendTests {

    @Test("Fuse two overlapping boxes with blend")
    func fuseBlendBoxes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 0, 0)))
        let result = box1.fusedAndBlended(with: box2, radius: 1.0)
        #expect(result != nil)
        if let r = result {
            #expect(try #require(r.volume) > 1000.0)
            #expect(r.isValid)
        }
    }

    // A 20 x 20 x 10 slab (x, y in [-20, 0], z in [-5, 5]) and a r = 5, h = 15 cylinder on the
    // origin overlap in a quarter of the cylinder's lower 5 mm. The plain union is
    // 4000 + 1178.097 - 98.175 = 5079.922...; the r = 1 blend adds fillet material along the
    // concave seam, measured 5085.8656... on the pinned kernel (v4.0.0-kernel.6).
    @Test("Fuse box and cylinder with blend")
    func fuseBlendBoxCylinder() throws {
        let box = try #require(
            Shape.box(width: 20, height: 20, depth: 10)?.translated(by: SIMD3(-10, -10, 0)))
        let cyl = try #require(Shape.cylinder(radius: 5, height: 15))
        let plain = try #require(box.union(cyl))
        let plainVolume = try #require(plain.volume)
        #expect(abs(plainVolume - 5079.922474671491) < 1e-6)

        let result = try #require(box.fusedAndBlended(with: cyl, radius: 1.0))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 5085.865669986801) < 1e-4)
        // The blend adds material at the concave seam, it does not remove any.
        #expect(volume > plainVolume)
        // Five more faces than the plain union: the blend strips.
        #expect(result.faces().count == 14)
        #expect(plain.faces().count == 9)
    }

    @Test("Cut and blend")
    func cutBlend() throws {
        let box = try #require(
            Shape.box(width: 20, height: 20, depth: 20)?.translated(by: SIMD3(-10, -10, 0)))
        let cyl = try #require(Shape.cylinder(radius: 5, height: 25))
        let result = box.cutAndBlended(with: cyl, radius: 1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(try #require(r.volume) < 8000.0)
        }
    }
}
