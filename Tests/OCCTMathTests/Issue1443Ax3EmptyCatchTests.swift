import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1443: five `gp_Ax3` bridge functions in `OCCTBridge_Spatial_GeometryUtils.mm`
/// (`OCCTAx3Create`, `OCCTAx3CreateFromNormal`, `OCCTAx3MirrorPoint`, `OCCTAx3Rotate`,
/// `OCCTAx3Translate`) swallowed OCCT's `Standard_ConstructionError` -- raised by `gp_Dir`'s
/// zero-length-vector check and, for the three-argument `gp_Ax3` constructor, its
/// parallel-direction/xDirection check -- with an empty `catch (...)`, leaving every
/// out-parameter at whatever the caller happened to pre-initialize it to.
///
/// `CoordinateSystem3D.swift` always pre-zeroes its own locals before calling into the bridge,
/// so for `OCCTAx3Create`/`OCCTAx3CreateFromNormal` the bug was invisible through the public
/// Swift API: the accidental "leave it at the caller's zero" behavior happens to read identically
/// to this fix's own deliberate zeroed fallback. `CoordinateSystem3DTests.swift`'s
/// `create*SignalsFailure` tests document that Swift-level contract (and the issue's own concrete
/// parallel-direction/xDirection example), but they cannot by themselves prove this fix changed
/// anything. These tests instead call the bridge C functions directly with sentinel (non-zero,
/// wrong-signed) pre-filled buffers, so they can tell "the catch overwrote the buffer" apart from
/// "the catch left it untouched" -- the actual defect -- per
/// `okf/policies/prove-the-test-fails.md`. Each was run against the pre-fix empty `catch (...)`
/// first (reverting just the catch body) and confirmed to fail: the sentinel values survived
/// unchanged.
///
/// `OCCTAx3MirrorPoint`/`OCCTAx3Translate` can only throw via the input axis's own construction
/// (`gp_Ax3::Mirrored(const gp_Pnt&)`/`::Translated(const gp_Vec&)` are themselves `noexcept`,
/// confirmed against `gp_Ax3.hxx`), so both are exercised here with a degenerate *input* axis.
/// `OCCTAx3Rotate` has a second, independent throw site -- the rotation axis's own `gp_Dir` --
/// exercised here with the issue's own concrete "zero rotation axis" example on an otherwise
/// perfectly valid input axis.
@Suite("Issue #1443: gp_Ax3 bridge functions' empty catch")
struct Issue1443Ax3EmptyCatchTests {

    @Test("OCCTAx3Create: parallel direction/xDirection overwrites sentinel outputs, not left untouched")
    func createParallelDirectionOverwritesSentinel() {
        var isDirect = true
        var xDx = -1.0
        var xDy = -1.0
        var xDz = -1.0
        var yDx = -1.0
        var yDy = -1.0
        var yDz = -1.0
        // direction and xDirection are the same vector -- gp_Ax3's documented parallel-input
        // ConstructionError (#1443's own concrete example).
        OCCTAx3Create(
            0, 0, 0,
            0, 0, 1,
            0, 0, 1,
            &isDirect, &xDx, &xDy, &xDz, &yDx, &yDy, &yDz)
        #expect(!isDirect)
        #expect(xDx == 0 && xDy == 0 && xDz == 0)
        #expect(yDx == 0 && yDy == 0 && yDz == 0)
    }

    @Test("OCCTAx3CreateFromNormal: zero-length normal overwrites sentinel outputs, not left untouched")
    func createFromNormalZeroNormalOverwritesSentinel() {
        var isDirect = true
        var xDx = -1.0
        var xDy = -1.0
        var xDz = -1.0
        var yDx = -1.0
        var yDy = -1.0
        var yDz = -1.0
        OCCTAx3CreateFromNormal(
            0, 0, 0,
            0, 0, 0,
            &isDirect, &xDx, &xDy, &xDz, &yDx, &yDy, &yDz)
        #expect(!isDirect)
        #expect(xDx == 0 && xDy == 0 && xDz == 0)
        #expect(yDx == 0 && yDy == 0 && yDz == 0)
    }

    @Test("OCCTAx3MirrorPoint: degenerate input axis overwrites sentinel outputs with the input point unmoved")
    func mirrorPointDegenerateSourceOverwritesSentinel() {
        var rpx = -99.0
        var rpy = -99.0
        var rpz = -99.0
        var rnx = -99.0
        var rny = -99.0
        var rnz = -99.0
        var rxDx = -99.0
        var rxDy = -99.0
        var rxDz = -99.0
        // Input axis at (5,3,2) with parallel direction/xDirection -- Mirrored() itself is
        // noexcept, so the only throw site is the input ax3's own construction.
        OCCTAx3MirrorPoint(
            5, 3, 2,
            0, 0, 1,
            0, 0, 1,
            1, 1, 1,
            &rpx, &rpy, &rpz, &rnx, &rny, &rnz, &rxDx, &rxDy, &rxDz)
        #expect(rpx == 5 && rpy == 3 && rpz == 2)
        #expect(rnx == 0 && rny == 0 && rnz == 0)
        #expect(rxDx == 0 && rxDy == 0 && rxDz == 0)
    }

    @Test("OCCTAx3Rotate: zero-length rotation axis overwrites sentinel outputs with the input point unmoved")
    func rotateZeroAxisDirectionOverwritesSentinel() {
        var rpx = -99.0
        var rpy = -99.0
        var rpz = -99.0
        var rnx = -99.0
        var rny = -99.0
        var rnz = -99.0
        var rxDx = -99.0
        var rxDy = -99.0
        var rxDz = -99.0
        // The input axis at (5,3,2) is perfectly valid (direction Z, xDirection X); only the
        // rotation axis direction is degenerate (#1443's own "zero rotation axis" example).
        OCCTAx3Rotate(
            5, 3, 2,
            0, 0, 1,
            1, 0, 0,
            0, 0, 0,
            0, 0, 0,
            .pi / 2,
            &rpx, &rpy, &rpz, &rnx, &rny, &rnz, &rxDx, &rxDy, &rxDz)
        #expect(rpx == 5 && rpy == 3 && rpz == 2)
        #expect(rnx == 0 && rny == 0 && rnz == 0)
        #expect(rxDx == 0 && rxDy == 0 && rxDz == 0)
    }

    @Test("OCCTAx3Translate: degenerate input axis overwrites sentinel outputs with the input point unmoved")
    func translateDegenerateSourceOverwritesSentinel() {
        var rpx = -99.0
        var rpy = -99.0
        var rpz = -99.0
        // Input axis at (5,3,2) with parallel direction/xDirection -- Translated() itself is
        // noexcept, so the only throw site is the input ax3's own construction.
        OCCTAx3Translate(
            5, 3, 2,
            0, 0, 1,
            0, 0, 1,
            1, 2, 3,
            &rpx, &rpy, &rpz)
        #expect(rpx == 5 && rpy == 3 && rpz == 2)
    }
}
