import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - ThruSections Builder")
struct ThruSectionsBuilderTests {

    @Test func basicThruSections() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1),
            let s2 = Shape.fromWire(w2)
        {
            let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
            ts.addWire(s1)
            ts.addWire(s2)
            let ok = ts.build()
            #expect(ok)
            let shape = ts.shape
            #expect(shape != nil)
            if let s = shape {
                #expect(s.isValid)
            }
        }
    }

    @Test func ruledThruSections() {
        if let w1 = Wire.rectangle(width: 10, height: 10),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 15), normal: SIMD3(0, 0, 1), radius: 5),
            let s1 = Shape.fromWire(w1),
            let s2 = Shape.fromWire(w2)
        {
            let ts = ThruSectionsBuilder(isSolid: true, isRuled: true)
            ts.addWire(s1)
            ts.addWire(s2)
            let ok = ts.build()
            #expect(ok)
        }
    }

    @Test func thruSectionsWithSettings() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1), radius: 7),
            let w3 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1),
            let s2 = Shape.fromWire(w2),
            let s3 = Shape.fromWire(w3)
        {
            let ts = ThruSectionsBuilder(isSolid: true)
            ts.setSmoothing(true)
            ts.setMaxDegree(8)
            ts.setContinuity(2)
            ts.addWire(s1)
            ts.addWire(s2)
            ts.addWire(s3)
            let ok = ts.build()
            #expect(ok)
            if let s = ts.shape {
                #expect(s.isValid)
                if let vol = s.volume {
                    #expect(vol > 0)
                }
            }
        }
    }
}
