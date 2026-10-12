import Foundation
import Testing

@testable import OCCTSwift

@Suite("CoordinateSystem3D")
struct CoordinateSystem3DTests {
    @Test func defaultXYZ() {
        let cs = CoordinateSystem3D(
            origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        #expect(cs.isDirect)
        #expect(abs(cs.yDirection.y - 1.0) < 1e-10)
    }

    @Test func fromNormal() {
        let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        #expect(cs.isDirect)
        #expect(cs.direction == SIMD3(0, 0, 1))

        // The two directions the constructor chose are what makes this an axis system and not
        // merely a flag: unit length, square to the normal and to each other, right-handed.
        func check(_ cs: CoordinateSystem3D, _ n: SIMD3<Double>, _ what: String) {
            let x = cs.xDirection
            let y = cs.yDirection
            #expect(abs(vectorLength(x) - 1) < 1e-12, "\(what): |x| = \(vectorLength(x))")
            #expect(abs(vectorLength(y) - 1) < 1e-12, "\(what): |y| = \(vectorLength(y))")
            #expect(abs(dotProduct(x, n)) < 1e-12, "\(what): x . n")
            #expect(abs(dotProduct(y, n)) < 1e-12, "\(what): y . n")
            #expect(abs(dotProduct(x, y)) < 1e-12, "\(what): x . y")
            let c = crossProduct(x, y)
            #expect(vectorLength(c - n) < 1e-12, "\(what): x cross y = \(c)")
        }
        check(cs, SIMD3(0, 0, 1), "+z")

        // A non-unit normal. x and y are the unit axes of the system, so they are checked against
        // the unit normal. `direction` itself is the caller's vector rather than the unit one
        // (#3371), so that one assertion is a known issue.
        let n = SIMD3(1.0, 2.0, 2.0) / 3.0
        let skew = CoordinateSystem3D(origin: SIMD3(4, 5, 6), direction: SIMD3(1, 2, 2))
        check(skew, n, "(1, 2, 2)")
        withKnownIssue("#3371: direction is the caller's vector, not gp_Ax3's unit one") {
            #expect(vectorLength(skew.direction - n) < 1e-12)
        }
    }

    @Test func angle() {
        let cs1 = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        let cs2 = CoordinateSystem3D(origin: .zero, direction: SIMD3(1, 0, 0))
        #expect(abs(cs1.angle(to: cs2) - .pi / 2) < 1e-10)
    }

    @Test func isCoplanar() {
        let cs1 = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        let cs2 = CoordinateSystem3D(origin: SIMD3(1, 1, 0), direction: SIMD3(0, 0, 1))
        #expect(cs1.isCoplanar(with: cs2))
    }

    @Test func mirrorPoint() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(1, 0, 0), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let mirrored = cs.mirrored(about: .zero)
        #expect(abs(mirrored.origin.x + 1.0) < 1e-10)
    }

    @Test func rotate() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(1, 0, 0), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let rotated = cs.rotated(about: .zero, axisDirection: SIMD3(0, 0, 1), angle: .pi / 2)
        #expect(abs(rotated.origin.x) < 1e-10)
        #expect(abs(rotated.origin.y - 1.0) < 1e-10)
    }

    @Test func translate() {
        let cs = CoordinateSystem3D(
            origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let translated = cs.translated(by: SIMD3(1, 2, 3))
        #expect(abs(translated.origin.x - 1.0) < 1e-10)
        #expect(abs(translated.origin.z - 3.0) < 1e-10)
    }

    // #1443: `init(origin:direction:xDirection:)` is neither failable nor throwing, so a genuinely
    // invalid gp_Ax3 construction (parallel direction/xDirection, or a zero-length direction) has
    // to signal through the ordinary output fields. These document the fixed, Swift-API-level
    // contract using the issue's own concrete inputs; see `Issue1443Ax3EmptyCatchTests.swift` for
    // the sentinel-buffer tests that actually distinguish this fix from the pre-fix empty catch
    // (which, for these two initializers specifically, coincidentally produced the same
    // Swift-visible zeros -- see that file's own doc comment for why).

    @Test func createWithParallelDirectionAndXDirectionSignalsFailure() {
        let cs = CoordinateSystem3D(
            origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(0, 0, 1))
        #expect(!cs.isDirect)
        #expect(cs.xDirection == .zero)
        #expect(cs.yDirection == .zero)
    }

    @Test func createFromNormalWithZeroDirectionSignalsFailure() {
        let cs = CoordinateSystem3D(origin: .zero, direction: .zero)
        #expect(!cs.isDirect)
        #expect(cs.xDirection == .zero)
        #expect(cs.yDirection == .zero)
    }

    // These three chain off a degenerate source CoordinateSystem3D (built above) or a zero
    // rotation axis, so -- unlike the two tests above -- they DO distinguish the fix from the
    // pre-fix empty catch: `mirrored`/`rotated`/`translated` reconstruct their result via
    // `CoordinateSystem3D`'s own zero-pre-initialized locals, so a nonzero source origin surviving
    // into the result is only possible once the bridge's catch block actually writes it back.

    @Test func mirrorPointWithDegenerateSourceFallsBackToUnmoved() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(5, 3, 2), direction: SIMD3(0, 0, 1), xDirection: SIMD3(0, 0, 1))
        #expect(!cs.isDirect)
        let mirrored = cs.mirrored(about: SIMD3(1, 1, 1))
        #expect(mirrored.origin == SIMD3(5, 3, 2))
    }

    @Test func rotateWithZeroAxisDirectionFallsBackToUnmoved() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(5, 3, 2), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        #expect(cs.isDirect)
        let rotated = cs.rotated(about: .zero, axisDirection: .zero, angle: .pi / 2)
        #expect(rotated.origin == SIMD3(5, 3, 2))
    }

    @Test func translateWithDegenerateSourceFallsBackToUnmoved() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(5, 3, 2), direction: SIMD3(0, 0, 1), xDirection: SIMD3(0, 0, 1))
        #expect(!cs.isDirect)
        let translated = cs.translated(by: SIMD3(1, 2, 3))
        #expect(translated.origin == SIMD3(5, 3, 2))
    }
}
