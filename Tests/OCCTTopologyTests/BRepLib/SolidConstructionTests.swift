import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.42.0: Solid Construction

@Suite("Solid Construction")
struct SolidConstructionTests {
    @Test("Solid from single box shell")
    func solidFromSingleShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let solid = Shape.solidFromShells([box])
        #expect(solid != nil)
        if let solid {
            #expect(solid.isValid)
            // Volume should match the box volume
            let vol = try #require(solid.volume)
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

        // As documented ("rest = cavities") the plain inner box does the same: a cavity shell is
        // classified against itself and reversed when it points outward (#3359, the rule
        // ShapeFix_Solid's CreateSolids applies to a hole shell). Before the fix the shells were
        // taken as given, the solid was invalid and read 9000.
        let plain = try #require(Shape.solidFromShells([outer, inner]))
        #expect(plain.subShapes(ofType: .shell).count == 2)
        #expect(plain.isValid)
        #expect(abs(plain.signedVolume - 7000) < 1e-6)
        #expect(plain.faces().count == 12)
    }

    /// Caller-supplied orientation must not matter, and the caller's own shapes are not edited.
    @Test("Cavity orientation is normalised without touching the inputs")
    func cavityOrientationIsNormalised() throws {
        let outer = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let inner = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let innerVolumeBefore = inner.signedVolume

        let first = try #require(Shape.solidFromShells([outer, inner]))
        let second = try #require(Shape.solidFromShells([outer, inner]))
        #expect(first.isValid)
        #expect(second.isValid)
        #expect(abs(first.signedVolume - 7000) < 1e-6)
        #expect(abs(second.signedVolume - 7000) < 1e-6)
        // The receiver of the call is read-only for the bridge: the inner box is still a solid
        // of +1000 afterwards.
        #expect(abs(inner.signedVolume - innerVolumeBefore) < 1e-9)
        #expect(abs(innerVolumeBefore - 1000) < 1e-9)
    }

    /// Two cavities, one passed already reversed and one passed as a plain box, give the same
    /// answer: the volume of the block less both.
    @Test("Mixed-orientation cavities")
    func mixedOrientationCavities() throws {
        let outer = try #require(Shape.box(width: 40, height: 20, depth: 20))
        let a = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let b = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let aMoved = try #require(a.translated(by: SIMD3(-10, 0, 0)))
        let bMoved = try #require(b.translated(by: SIMD3(10, 0, 0)))
        let bReversed = try #require(bMoved.reversed)

        let solid = try #require(Shape.solidFromShells([outer, aMoved, bReversed]))
        #expect(solid.subShapes(ofType: .shell).count == 3)
        #expect(solid.isValid)
        #expect(abs(solid.signedVolume - (16000 - 250)) < 1e-6)
    }

    @Test("Solid from empty array returns nil")
    func solidFromEmptyReturnsNil() {
        let solid = Shape.solidFromShells([])
        #expect(solid == nil)
    }
}
