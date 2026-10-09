import Testing
import simd

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

    @Test func twoSectionsBuildSucceeds() {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        else { return }
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        ts.addWire(s1)
        ts.addWire(s2)
        #expect(ts.build())
        if let shape = ts.shape {
            #expect(shape.isValid)
        }
    }
}
