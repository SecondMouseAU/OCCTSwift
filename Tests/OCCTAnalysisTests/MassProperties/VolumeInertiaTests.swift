import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Volume Inertia Tests")
struct VolumeInertiaTests {
    @Test("Box volume inertia")
    func boxVolumeInertia() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
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
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let inertia = box.volumeInertia!
        #expect(inertia.principalMoments.x > 0)
        #expect(inertia.principalMoments.y > 0)
        #expect(inertia.principalMoments.z > 0)
    }

    @Test("Inertia tensor has 9 elements")
    func inertiaTensorSize() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let inertia = box.volumeInertia!
        #expect(inertia.inertiaTensor.count == 9)
    }

    @Test("Gyration radii are positive")
    func gyrationRadii() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let inertia = box.volumeInertia!
        #expect(inertia.gyrationRadii.x > 0)
        #expect(inertia.gyrationRadii.y > 0)
        #expect(inertia.gyrationRadii.z > 0)
    }

    @Test("Sphere volume inertia")
    func sphereVolumeInertia() throws {
        let sphere = Shape.sphere(radius: 5)!
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
        let cyl = Shape.cylinder(radius: 5, height: 20)!
        let inertia = cyl.volumeInertia
        #expect(inertia != nil)
        if let inertia {
            #expect(inertia.hasSymmetryAxis)
        }
    }

    @Test("Sphere volume inertia has symmetry point")
    func sphereVolumeInertiaSymmetryPoint() throws {
        let sphere = Shape.sphere(radius: 5)!
        let inertia = sphere.volumeInertia
        #expect(inertia != nil)
        if let inertia {
            #expect(inertia.hasSymmetryPoint)
        }
    }

    // The two generations read the symmetry flags off the same GProp_PrincipalProps object,
    // this is the first test in the tree able to cross-check that, since surfaceInertia/
    // volumeInertia had no symmetry fields to compare before #848.
    @Test("Volume inertia symmetry agrees with legacy inertiaProperties")
    func volumeInertiaMatchesLegacySymmetry() throws {
        let cyl = Shape.cylinder(radius: 5, height: 20)!
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
