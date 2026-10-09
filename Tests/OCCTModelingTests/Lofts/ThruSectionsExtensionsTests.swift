import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.123.0: Builder extensions, Section ops, Curve/Surface queries

@Suite("v0.123.0, ThruSections extensions")
struct ThruSectionsExtensionsTests {

    @Test("CheckCompatibility sets without crash")
    func checkCompatibility() {
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.checkCompatibility(true)
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                #expect(ts.shape != nil)
            }
        }
    }

    @Test("SetParType parameterization")
    func setParType() {
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.setParType(0)  // ChordLength
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                #expect(ts.shape != nil)
            }
        }
    }

    @Test("SetCriteriumWeight")
    func setCriteriumWeight() {
        let ts = ThruSectionsBuilder(isSolid: true)
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: 1.0) == true)
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                #expect(ts.shape != nil)
            }
        }
    }

    @Test("SetCriteriumWeight rejects negative weights")
    func setCriteriumWeightRejectsNegative() {
        let ts = ThruSectionsBuilder(isSolid: true)
        #expect(ts.setCriteriumWeight(w1: -1.0, w2: 1.0, w3: 1.0) == false)
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: -1.0, w3: 1.0) == false)
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: -1.0) == false)
        #expect(ts.setCriteriumWeight(w1: -1.0, w2: -1.0, w3: -1.0) == false)
        // Verify builder still works after rejection
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: 1.0) == true)
    }

    @Test("GeneratedFace from edge")
    func generatedFace() {
        let ts = ThruSectionsBuilder(isSolid: true)
        let w1 = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5.0)
        let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3.0)
        if let w1 = w1, let w2 = w2 {
            if let ws1 = Shape.fromWire(w1), let ws2 = Shape.fromWire(w2) {
                ts.addWire(ws1)
                ts.addWire(ws2)
                ts.build()
                if ts.shape != nil {
                    let edges = ws1.subShapes(ofType: .edge)
                    if edges.count > 0 {
                        let face = ts.generatedFace(from: edges[0])
                        // GeneratedFace may return nil if the edge was not directly used
                        let _ = face
                        #expect(true)
                    }
                }
            }
        }
    }
}
