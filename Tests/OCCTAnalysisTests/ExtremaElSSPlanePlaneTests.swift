import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// `Extrema_ExtElSS` implements plane/plane and nothing else, and even plane/plane computes only a
/// square distance. `ExtremaElSS.planeToPlane` reports exactly that after #1632: the square
/// distance when the planes are parallel, and nothing when they are not.
///
/// The two removed methods, `planeToSphere` and `sphereToSphere`, cannot have a test any more:
/// naming them is a compile error, which is the point. Their old suites asserted
/// `results.count >= 0`, which is true of every `Int` and could not fail.
///
/// Ground truth: `Scripts/repro/1632-extremaelss-refusal/probe.mm`.
@Suite("Extrema_ExtElSS Plane-Plane")
struct ExtremaElSSPlanePlaneTests {

    @Test func parallelPlanesReportTheSquareDistance() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 10), plane2Normal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        #expect(r.squareDistance != nil)
        if let sq = r.squareDistance { #expect(abs(sq - 100) < 1e-9) }

        // Second construction, a different OCCT class: the distance from a point on plane 1 to
        // plane 2, through Extrema_ExtPElS. Same 100, and this one does report a point pair.
        let viaPoint = ExtremaPointSurface.pointToPlane(
            point: SIMD3(3, -7, 0),
            planePoint: SIMD3(0, 0, 10), planeNormal: SIMD3(0, 0, 1))
        #expect(viaPoint.count == 1)
        if let first = viaPoint.first { #expect(abs(first.squareDistance - 100) < 1e-9) }
    }

    /// Crossing planes meet, so their distance is zero all along the intersection line and there
    /// is no extremum to report. `nil` says "no extremal distance", not "zero".
    @Test func crossingPlanesReportNoDistance() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 0), plane2Normal: SIMD3(1, 0, 0)
        )
        #expect(!r.isParallel)
        #expect(r.squareDistance == nil)
    }

    /// Antiparallel normals are still parallel planes. z = 0 facing up and z = 4 facing down.
    @Test func oppositeNormalsAreStillParallel() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 4), plane2Normal: SIMD3(0, 0, -1)
        )
        #expect(r.isParallel)
        #expect(r.squareDistance != nil)
        if let sq = r.squareDistance { #expect(abs(sq - 16) < 1e-9) }
    }

    /// Coincident planes are parallel at distance zero. Here `0` IS the measurement, and it is
    /// reported as `.some(0)` rather than as `nil`, which is the distinction #1632 is about.
    @Test func coincidentPlanesReportZeroRatherThanNil() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(4, -9, 0), plane2Normal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        #expect(r.squareDistance != nil)
        if let sq = r.squareDistance { #expect(abs(sq) < 1e-9) }
    }

    /// A zero-length normal cannot make a `gp_Dir`. The constructor throws inside the bridge and
    /// the refusal comes back as `(false, nil)`.
    @Test func degenerateNormalIsRefused() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 0),
            plane2Point: SIMD3(0, 0, 10), plane2Normal: SIMD3(0, 0, 1)
        )
        #expect(!r.isParallel)
        #expect(r.squareDistance == nil)
    }
}

/// #1463, carried onto the signature #1632 gave `OCCTExtremaElSSPlanePlane`.
///
/// The original defect was a buffer-count mismatch: the parallel branch gated the write on
/// `max > 0` but returned `1` unconditionally, so a caller passing a zero-capacity buffer was told
/// "1 extremum available" while `out[0]` was never touched. That exact defect cannot exist now,
/// because the function no longer takes a buffer: #1632 replaced `OCCTExtremaElResult* out` and
/// `int32_t max` with a single `double* outSquareDistance`, since the point fields the buffer
/// carried were written as zeros that OCCT never computed.
///
/// What survives is the guard underneath it, and it is the same one: **an out-parameter must not
/// be written when nothing was computed.** These tests assert it on the new signature with the
/// same sentinel technique the #1463 suite used, so the contract keeps a test rather than losing
/// one to the signature change.
@Suite("Issue #1463: OCCTExtremaElSSPlanePlane writes its out-param only when it has an answer")
struct Issue1463ExtremaPlanePlaneOutParamTests {

    /// A value the function could never produce by chance, and not the `0.0` a default-initialised
    /// local would hold.
    private static let sentinel = -999.0

    @Test("parallel planes: returns 1 and writes the square distance")
    func parallelPlanesWriteTheDistance() {
        var isParallel = false
        var squareDistance = Self.sentinel

        let n = OCCTExtremaElSSPlanePlane(
            0, 0, 0, 0, 0, 1,
            0, 0, 10, 0, 0, 1,
            &isParallel, &squareDistance
        )

        #expect(isParallel)
        #expect(n == 1)
        #expect(abs(squareDistance - 100) < 1e-9)
    }

    @Test("crossing planes: returns 0 and leaves the out-param untouched")
    func crossingPlanesLeaveTheOutParamUntouched() {
        var isParallel = true  // deliberately wrong, the function must overwrite it
        var squareDistance = Self.sentinel

        let n = OCCTExtremaElSSPlanePlane(
            0, 0, 0, 0, 0, 1,
            0, 0, 0, 1, 0, 0,
            &isParallel, &squareDistance
        )

        #expect(!isParallel)
        #expect(n == 0)
        #expect(squareDistance == Self.sentinel, "outSquareDistance must be untouched when n == 0")
    }

    @Test("a refused input: returns -1 and leaves the out-param untouched")
    func refusedInputLeavesTheOutParamUntouched() {
        var isParallel = true
        var squareDistance = Self.sentinel

        // A zero-length normal: gp_Dir's constructor throws, the bridge catches and returns -1.
        let n = OCCTExtremaElSSPlanePlane(
            0, 0, 0, 0, 0, 0,
            0, 0, 10, 0, 0, 1,
            &isParallel, &squareDistance
        )

        #expect(n == -1)
        #expect(!isParallel, "outIsParallel is set to false before anything can throw")
        #expect(squareDistance == Self.sentinel, "outSquareDistance must be untouched when n < 0")
    }
}
