import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.66.0: Full TkG2d Toolkit Coverage

@Suite("Point2D Creation")
struct Point2DCreationTests {
    @Test func createPoint() throws {
        let p = try #require(Point2D(x: 3.0, y: 4.0))  // #1979: was `if let`
        #expect(abs(p.x - 3.0) < 1e-10)
        #expect(abs(p.y - 4.0) < 1e-10)
    }

    @Test func createFromSIMD() throws {
        let p = try #require(Point2D(position: SIMD2(1.5, 2.5)))  // #1979: was `if let`
        #expect(abs(p.position.x - 1.5) < 1e-10)
        #expect(abs(p.position.y - 2.5) < 1e-10)
    }

    @Test func setCoords() throws {
        let p = try #require(Point2D(x: 0, y: 0))  // #1979: was `if let`
        p.setCoords(x: 5.0, y: 7.0)
        #expect(abs(p.x - 5.0) < 1e-10)
        #expect(abs(p.y - 7.0) < 1e-10)
    }
}
