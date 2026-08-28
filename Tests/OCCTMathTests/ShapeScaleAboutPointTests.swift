import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeScale")
struct ShapeScaleAboutPointTests {
    @Test("Scale box about origin")
    func scaleAboutOrigin() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let scaled = box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 2.0)
        #expect(scaled != nil)
        if let s = scaled {
            #expect(s.isValid)
            let size = s.size!
            #expect(abs(size.x - 20) < 0.5)
            #expect(abs(size.y - 20) < 0.5)
            #expect(abs(size.z - 20) < 0.5)
        }
    }

    @Test("Scale with factor 0.5")
    func halfScale() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let scaled = box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 0.5)
        #expect(scaled != nil)
        if let s = scaled {
            #expect(s.isValid)
            let size = s.size!
            #expect(abs(size.x - 10) < 0.5)
        }
    }
}

