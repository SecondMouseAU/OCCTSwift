import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.119.0 Tests

@Suite("BREP_String_Serialization")
struct BREPStringSerializationTests {
    @Test func boxToAndFromBREPString() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            if let brep = box.toBREPString() {
                #expect(!brep.isEmpty)
                if let restored = Shape.fromBREPString(brep) {
                    #expect(restored.isValid)
                    if let vol = restored.volume {
                        #expect(abs(vol - 6000.0) < 1.0)
                    }
                }
            }
        }
    }

    @Test func sphereRoundTrip() {
        if let sphere = Shape.sphere(radius: 5) {
            if let brep = sphere.toBREPString() {
                #expect(brep.count > 100)
                if let restored = Shape.fromBREPString(brep) {
                    #expect(restored.isValid)
                }
            }
        }
    }

    @Test func invalidBREPStringReturnsNil() {
        let result = Shape.fromBREPString("not a valid brep")
        #expect(result == nil)
    }

    @Test func emptyBREPStringReturnsNil() {
        let result = Shape.fromBREPString("")
        #expect(result == nil)
    }
}
