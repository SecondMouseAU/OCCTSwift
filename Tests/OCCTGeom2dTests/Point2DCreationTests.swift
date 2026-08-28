import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.66.0: Full TkG2d Toolkit Coverage

@Suite("Point2D Creation")
struct Point2DCreationTests {
    @Test func createPoint() {
        let p = Point2D(x: 3.0, y: 4.0)
        #expect(p != nil)
        if let p = p {
            #expect(abs(p.x - 3.0) < 1e-10)
            #expect(abs(p.y - 4.0) < 1e-10)
        }
    }

    @Test func createFromSIMD() {
        let p = Point2D(position: SIMD2(1.5, 2.5))
        #expect(p != nil)
        if let p = p {
            #expect(abs(p.position.x - 1.5) < 1e-10)
            #expect(abs(p.position.y - 2.5) < 1e-10)
        }
    }

    @Test func setCoords() {
        if let p = Point2D(x: 0, y: 0) {
            p.setCoords(x: 5.0, y: 7.0)
            #expect(abs(p.x - 5.0) < 1e-10)
            #expect(abs(p.y - 7.0) < 1e-10)
        }
    }
}
