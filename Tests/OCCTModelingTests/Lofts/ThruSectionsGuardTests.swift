import Testing

@testable import OCCTSwift

// MARK: - SEGV Guard Regression Tests (Issues #54, #55, #56)

@Suite("SEGV Guards, ThruSections empty/single-section")
struct ThruSectionsGuardTests {

    @Test func emptyBuildReturnsFalse() {
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        #expect(!ts.build())
        #expect(ts.shape == nil)
    }

    @Test func singleWireBuildReturnsFalse() {
        guard let w = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let s = Shape.fromWire(w)
        else { return }
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        ts.addWire(s)
        #expect(!ts.build())
    }

    @Test func singleVertexBuildReturnsFalse() {
        let ts = ThruSectionsBuilder(isSolid: false, isRuled: false)
        if let v = Shape.vertex(at: SIMD3(0, 0, 0)) {
            ts.addVertex(v)
            #expect(!ts.build())
        }
    }

    // #3332: the old body was `guard ... else { return }` and `if let shape { isValid }`. Two
    // sections are the smallest build the guards above let through, so it must really build: the
    // r = 5 to r = 3 frustum over 10 mm, V = pi 10 / 3 (25 + 15 + 9) = 513.127, three faces.
    @Test func twoSectionsBuildSucceeds() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        ts.addWire(s1)
        ts.addWire(s2)
        #expect(ts.build())
        let shape = try #require(ts.shape)
        #expect(shape.isValid)
        #expect(shape.shapeType == .solid)
        #expect(shape.faceCount == 3)
        let volume = try #require(shape.volume)
        #expect(abs(volume - Double.pi * 10 / 3 * (25 + 15 + 9)) < 1e-3)
    }
}
