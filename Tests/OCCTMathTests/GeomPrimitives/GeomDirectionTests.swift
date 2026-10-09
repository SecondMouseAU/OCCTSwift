import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomDirection Tests")
struct GeomDirectionTests {
    @Test("create unit direction")
    func create() throws {
        let d = try #require(GeomDirection(x: 0, y: 0, z: 1))
        let c = d.coordinates
        #expect(abs(c.z - 1) < 1e-10)
    }

    @Test("auto-normalizes")
    func normalizes() throws {
        let d = try #require(GeomDirection(x: 3, y: 4, z: 0))
        let c = d.coordinates
        let mag = sqrt(c.x * c.x + c.y * c.y + c.z * c.z)
        #expect(abs(mag - 1.0) < 1e-10)
        // The direction itself, not just its length: (3, 4, 0) / 5.
        #expect(abs(c.x - 0.6) < 1e-10)
        #expect(abs(c.y - 0.8) < 1e-10)
        #expect(abs(c.z) < 1e-10)
    }

    @Test("crossed product")
    func crossed() throws {
        let dx = try #require(GeomDirection(x: 1, y: 0, z: 0))
        let dy = try #require(GeomDirection(x: 0, y: 1, z: 0))
        let cross = try #require(dx.crossed(with: dy))
        #expect(abs(cross.coordinates.z - 1.0) < 1e-10)
    }

    @Test("setCoordinates")
    func setCoordinates() throws {
        let d = try #require(GeomDirection(x: 1, y: 0, z: 0))
        #expect(d.setCoordinates(x: 0, y: 1, z: 0))
        #expect(abs(d.coordinates.y - 1.0) < 1e-10)
    }
}

// #2331: `Geom_Direction`'s constructor, `SetCoord` and `Crossed` each carry
// `Standard_ConstructionError_Raise_if(D <= gp::Resolution())`, but all three are out-of-line
// members compiled into libOCCT with `-DNo_Exception` (Release +
// `BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`), so the raise is gone and the division by a zero length
// runs. Every one of them used to hand back NaN coordinates, and the bridge's `catch` block, which
// substituted `(0, 0, 1)`, was unreachable. Measured in
// `Scripts/repro/2331-geom-direction-zero/probe.mm`.
//
// These assert the VALUE, not just that a call returns: the old code returned a perfectly
// well-formed `GeomDirection` for every input below.
@Suite("GeomDirection refuses a vector it cannot normalise (#2331)")
struct Issue2331GeomDirectionZeroVectorTests {

    /// The zero vector itself, the case #2331 was filed on.
    @Test("The zero vector is refused, not turned into (0, 0, 1) or NaN")
    func zeroVectorIsRefused() {
        #expect(GeomDirection(x: 0, y: 0, z: 0) == nil)
        #expect(GeomDirection(simd: SIMD3(0, 0, 0)) == nil)
    }

    /// `sqrt(x*x + y*y + z*z)` underflows to exactly 0 here even though every component is well
    /// above `gp::Resolution()` (2.2e-308), which is why the guard tests the square modulus the
    /// way `StepToGeom::MakeDirection` does rather than the length.
    @Test("A magnitude that underflows when squared is refused")
    func underflowingMagnitudeIsRefused() {
        #expect(GeomDirection(x: 1e-200, y: 0, z: 0) == nil)
        #expect(GeomDirection(x: 1e-200, y: 1e-200, z: 1e-200) == nil)
    }

    @Test("A non-finite component is refused")
    func nonFiniteComponentsAreRefused() {
        #expect(GeomDirection(x: .infinity, y: 0, z: 0) == nil)
        #expect(GeomDirection(x: 0, y: -.infinity, z: 0) == nil)
        #expect(GeomDirection(x: 0, y: 0, z: .nan) == nil)
    }

    /// OCCT's "infinite" is `Precision::Infinite() / 2`, which is `1e100`, not IEEE infinity, and
    /// `StepToGeom::MakeDirection` refuses a component at or beyond it before squaring anything:
    /// "5.08.2021. Unstable test bugs xde bug24759: Y is very large value - FPE in SquareModulus".
    ///
    /// The guard is that test rather than `isFinite`, so the boundary is OCCT's, not IEEE's.
    @Test("A component at or beyond OCCT's infinite threshold is refused, just below it is not")
    func occtInfiniteThresholdIsTheBoundary() throws {
        #expect(GeomDirection(x: 1e100, y: 0, z: 0) == nil)
        #expect(GeomDirection(x: -1e100, y: 0, z: 0) == nil)
        #expect(GeomDirection(x: 1e150, y: 0, z: 0) == nil)
        let justBelow = try #require(GeomDirection(x: 1e99, y: 0, z: 0))
        #expect(abs(justBelow.coordinates.x - 1.0) < 1e-10)
    }

    /// The guard must not have swallowed the legitimate small-but-representable case.
    @Test("A tiny magnitude that still normalises is accepted, with finite coordinates")
    func tinyButUsableMagnitudeIsAccepted() throws {
        let d = try #require(GeomDirection(x: 1e-150, y: 0, z: 0))
        let c = d.coordinates
        #expect(c.x.isFinite && c.y.isFinite && c.z.isFinite)
        #expect(abs(c.x - 1.0) < 1e-10)
    }

    /// Every accepted direction has finite coordinates of unit length.
    ///
    /// This is the assertion the
    /// old suite lacked: it built directions and read one component, never checking for NaN.
    @Test("Every accepted direction is a finite unit vector")
    func acceptedDirectionsAreFiniteUnitVectors() throws {
        let inputs: [SIMD3<Double>] = [
            SIMD3(1, 0, 0), SIMD3(0, 0, 1), SIMD3(3, 4, 0), SIMD3(-1, -1, -1), SIMD3(1e-150, 0, 0),
            SIMD3(1e99, 0, 0),
        ]
        for input in inputs {
            let d = try #require(GeomDirection(simd: input), "refused \(input)")
            let c = d.coordinates
            #expect(c.x.isFinite && c.y.isFinite && c.z.isFinite, "NaN or infinite for \(input)")
            let mag = sqrt(c.x * c.x + c.y * c.y + c.z * c.z)
            #expect(abs(mag - 1.0) < 1e-10, "magnitude \(mag) for \(input)")
        }
    }

    @Test("setCoordinates refuses the same inputs and leaves the direction untouched")
    func setCoordinatesRefusesAndPreserves() throws {
        let d = try #require(GeomDirection(x: 0, y: 1, z: 0))
        for bad: (Double, Double, Double) in [
            (0, 0, 0), (1e-200, 0, 0), (.infinity, 0, 0), (0, 0, .nan),
        ] {
            #expect(!d.setCoordinates(x: bad.0, y: bad.1, z: bad.2), "accepted \(bad)")
            let c = d.coordinates
            #expect(abs(c.y - 1.0) < 1e-10, "direction was overwritten by \(bad): \(c)")
            #expect(c.x.isFinite && c.y.isFinite && c.z.isFinite, "NaN after \(bad)")
        }
        // ...and a good one still lands.
        #expect(d.setCoordinates(x: 0, y: 0, z: 2))
        #expect(abs(d.coordinates.z - 1.0) < 1e-10)
    }

    /// `crossed(with:)` is documented to return `nil` for a parallel pair.
    ///
    /// It used to return a
    /// non-nil direction whose coordinates were all NaN, because `Geom_Direction::Crossed` runs
    /// gp_Dir's zero-norm check inside libOCCT, where `No_Exception` has removed it.
    @Test("A parallel pair crosses to nil, not to a NaN direction")
    func parallelCrossIsNil() throws {
        let x = try #require(GeomDirection(x: 1, y: 0, z: 0))
        let sameWay = try #require(GeomDirection(x: 2, y: 0, z: 0))
        let otherWay = try #require(GeomDirection(x: -3, y: 0, z: 0))
        #expect(x.crossed(with: x) == nil)
        #expect(x.crossed(with: sameWay) == nil)
        #expect(x.crossed(with: otherWay) == nil)
    }

    @Test("A non-parallel pair crosses to a finite unit normal")
    func nonParallelCrossIsFinite() throws {
        let x = try #require(GeomDirection(x: 1, y: 0, z: 0))
        let y = try #require(GeomDirection(x: 0, y: 1, z: 0))
        let z = try #require(x.crossed(with: y))
        let c = z.coordinates
        #expect(c.x.isFinite && c.y.isFinite && c.z.isFinite)
        #expect(abs(c.x) < 1e-10)
        #expect(abs(c.y) < 1e-10)
        #expect(abs(c.z - 1.0) < 1e-10)
    }
}
