import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.42.0: Solid Construction

@Suite("Solid Construction")
struct SolidConstructionTests {
    @Test("Solid from single box shell")
    func solidFromSingleShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let solid = Shape.solidFromShells([box])
        #expect(solid != nil)
        if let solid {
            #expect(solid.isValid)
            // Volume should match the box volume
            let vol = solid.volume!
            #expect(abs(vol - 1000.0) < 1.0)
        }
    }

    @Test("Solid from two box shells (outer + cavity)")
    func solidFromTwoShells() throws {
        let outer = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let inner = try #require(Shape.box(width: 10, height: 10, depth: 10))

        // The cavity shell has to point inward. With the inner box reversed, the result is the
        // hollow block: 8000 - 1000, two shells, twelve faces, valid.
        let reversedInner = try #require(inner.reversed)
        let hollow = try #require(Shape.solidFromShells([outer, reversedInner]))
        #expect(hollow.isValid)
        #expect(hollow.subShapes(ofType: .shell).count == 2)
        #expect(hollow.faces().count == 12)
        #expect(abs((hollow.volume ?? 0) - 7000) < 1e-6)

        // As documented ("rest = cavities") the plain inner box should do the same. Measured on
        // kernel.6 it does not: the shells are taken as given, the solid is invalid and reads
        // 9000. #3359.
        let plain = try #require(Shape.solidFromShells([outer, inner]))
        #expect(plain.subShapes(ofType: .shell).count == 2)
        withKnownIssue("an unreversed inner shell is not oriented as a cavity (#3359)") {
            #expect(plain.isValid)
            #expect(abs(plain.signedVolume - 7000) < 1e-6)
        }
    }

    @Test("Solid from empty array returns nil")
    func solidFromEmptyReturnsNil() {
        let solid = Shape.solidFromShells([])
        #expect(solid == nil)
    }
}
