import Foundation
import Testing

@testable import OCCTSwift

@Suite("Volume Inertia Tests")
struct VolumeInertiaTests {
    @Test("Box volume inertia")
    func boxVolumeInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let inertia = box.volumeInertia
        #expect(inertia != nil)
        if let inertia {
            #expect(abs(inertia.volume - 6000) < 1.0)
            // Box is centered at origin in OCCTSwift
            #expect(abs(inertia.centerOfMass.x) < 0.1)
            #expect(abs(inertia.centerOfMass.y) < 0.1)
            #expect(abs(inertia.centerOfMass.z) < 0.1)
        }
    }

    @Test("Principal moments are positive")
    func principalMomentsPositive() throws {
        // Unit density, V = 6000: I = V (b^2 + c^2) / 12 about each axis, so
        // 650000, 500000 and 250000 for a 10 x 20 x 30 box. OCCT orders the axes, so compare
        // the sorted set.
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let inertia = try #require(box.volumeInertia)
        let pm = [
            inertia.principalMoments.x, inertia.principalMoments.y, inertia.principalMoments.z,
        ].sorted(by: >)
        #expect(abs(pm[0] - 650_000) < 1e-3, "got \(pm)")
        #expect(abs(pm[1] - 500_000) < 1e-3, "got \(pm)")
        #expect(abs(pm[2] - 250_000) < 1e-3, "got \(pm)")
    }

    @Test("Inertia tensor has 9 elements")
    func inertiaTensorSize() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let inertia = try #require(box.volumeInertia)
        #expect(inertia.inertiaTensor.count == 9)
    }

    @Test("Gyration radii are positive")
    func gyrationRadii() throws {
        // k = sqrt(I / V). A cube of side 10 has I = V * 200 / 12, so k = sqrt(200 / 12) = 4.0825
        // on every axis; the 10 x 20 x 30 box separates them: sqrt(1300 / 12), sqrt(1000 / 12)
        // and sqrt(500 / 12).
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10)?.volumeInertia)
        let k = (200.0 / 12.0).squareRoot()
        for r in [cube.gyrationRadii.x, cube.gyrationRadii.y, cube.gyrationRadii.z] {
            #expect(abs(r - k) < 1e-9, "got \(r), expected \(k)")
        }

        let box = try #require(Shape.box(width: 10, height: 20, depth: 30)?.volumeInertia)
        let ks = [box.gyrationRadii.x, box.gyrationRadii.y, box.gyrationRadii.z].sorted(by: >)
        #expect(abs(ks[0] - (1300.0 / 12.0).squareRoot()) < 1e-9, "got \(ks)")
        #expect(abs(ks[1] - (1000.0 / 12.0).squareRoot()) < 1e-9, "got \(ks)")
        #expect(abs(ks[2] - (500.0 / 12.0).squareRoot()) < 1e-9, "got \(ks)")
    }

    @Test("Sphere volume inertia")
    func sphereVolumeInertia() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let inertia = sphere.volumeInertia
        #expect(inertia != nil)
        if let inertia {
            let expectedVolume = (4.0 / 3.0) * Double.pi * 125.0
            #expect(abs(inertia.volume - expectedVolume) < 1.0)
        }
    }

    // #848: hasSymmetryAxis/hasSymmetryPoint, added to VolumeInertia to match what
    // InertiaProperties (the older generation) has always reported.
    @Test("Cylinder volume inertia has symmetry axis")
    func cylinderVolumeInertiaSymmetryAxis() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20))
        let inertia = try #require(cyl.volumeInertia)
        #expect(inertia.hasSymmetryAxis)
        // An axis and not a point: the two transverse moments are equal and differ from the
        // axial one. V = 500 pi: axial V r^2 / 2 = 19634.95, transverse V (3 r^2 + h^2) / 12 =
        // 62177.35.
        #expect(!inertia.hasSymmetryPoint)
        let pm = [
            inertia.principalMoments.x, inertia.principalMoments.y, inertia.principalMoments.z,
        ].sorted()
        #expect(abs(pm[0] - 19634.954084936207) < 1e-3, "got \(pm)")
        #expect(abs(pm[1] - 62177.35460229816) < 1e-3, "got \(pm)")
        #expect(abs(pm[2] - 62177.35460229816) < 1e-3, "got \(pm)")

        // A 10 x 20 x 30 box has three distinct moments: neither an axis nor a point.
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30)?.volumeInertia)
        #expect(!box.hasSymmetryAxis)
        #expect(!box.hasSymmetryPoint)
    }

    @Test("Sphere volume inertia has symmetry point")
    func sphereVolumeInertiaSymmetryPoint() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let inertia = try #require(sphere.volumeInertia)
        #expect(inertia.hasSymmetryPoint)
        #expect(inertia.hasSymmetryAxis)
        // A solid sphere: I = 2/5 V r^2 on every axis, V = 4/3 pi 125.
        let expected = 0.4 * (4.0 / 3.0 * Double.pi * 125.0) * 25.0
        for m in [
            inertia.principalMoments.x, inertia.principalMoments.y, inertia.principalMoments.z,
        ] {
            #expect(abs(m - expected) < 1e-6, "got \(m), expected \(expected)")
        }
        // A cylinder, which has an axis but no point, is the other side of the flag.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20)?.volumeInertia)
        #expect(!cyl.hasSymmetryPoint)
    }

    // The two generations read the symmetry flags off the same GProp_PrincipalProps object,
    // this is the first test in the tree able to cross-check that, since surfaceInertia/
    // volumeInertia had no symmetry fields to compare before #848.
    @Test("Volume inertia symmetry agrees with legacy inertiaProperties")
    func volumeInertiaMatchesLegacySymmetry() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20))
        let legacy = cyl.inertiaProperties()
        let modern = cyl.volumeInertia
        #expect(legacy != nil)
        #expect(modern != nil)
        if let legacy, let modern {
            #expect(legacy.hasSymmetryAxis == modern.hasSymmetryAxis)
            #expect(legacy.hasSymmetryPoint == modern.hasSymmetryPoint)
            #expect(abs(legacy.mass - modern.volume) < 1e-6)
        }
    }
}
