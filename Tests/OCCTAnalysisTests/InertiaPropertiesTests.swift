import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: Inertia Properties

@Suite("Inertia Properties")
struct InertiaPropertiesTests {
    /// A centred 10 x 20 x 30 box at unit density: volume 6000, centroid at the origin, and the
    /// diagonal of the inertia tensor about the centroid is m(b²+c²)/12, m(a²+c²)/12,
    /// m(a²+b²)/12 = 650000, 500000, 250000, which is also what
    /// `GProp_PrincipalProps::Moments` reports, in that order.
    ///
    /// This used to check only that those values were positive, so a tensor with Ixx and Iyy
    /// exchanged, or principal moments off by any positive factor, passed.
    @Test("Box volume inertia properties")
    func boxInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let props = try #require(box.inertiaProperties())
        #expect(abs(props.mass - 6000) < 1)
        #expect(abs(props.centerOfMass.x - 0) < 0.1)  // Centered box
        #expect(abs(props.centerOfMass.y - 0) < 0.1)
        #expect(abs(props.centerOfMass.z - 0) < 0.1)
        // Inertia matrix should be 3x3 = 9 values
        try #require(props.inertiaMatrix.count == 9)
        #expect(abs(props.inertiaMatrix[0] - 650_000) < 1e-6)  // Ixx
        #expect(abs(props.inertiaMatrix[4] - 500_000) < 1e-6)  // Iyy
        #expect(abs(props.inertiaMatrix[8] - 250_000) < 1e-6)  // Izz
        #expect(abs(props.principalMoments.x - 650_000) < 1e-6)
        #expect(abs(props.principalMoments.y - 500_000) < 1e-6)
        #expect(abs(props.principalMoments.z - 250_000) < 1e-6)
    }

    @Test("Sphere has symmetry point")
    func sphereSymmetry() throws {
        let sphere = try #require(Shape.sphere(radius: 10))
        let props = try #require(sphere.inertiaProperties())
        // Sphere volume = 4/3 * pi * r^3
        let expectedVol = 4.0 / 3.0 * Double.pi * 1000.0
        #expect(abs(props.mass - expectedVol) / expectedVol < 0.01)
        // Center at origin
        #expect(abs(props.centerOfMass.x) < 0.1)
        #expect(abs(props.centerOfMass.y) < 0.1)
        #expect(abs(props.centerOfMass.z) < 0.1)
        // Sphere has symmetry point
        #expect(props.hasSymmetryPoint)
    }

    @Test("Surface inertia properties")
    func surfaceInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let props = try #require(box.surfaceInertiaProperties())
        // Surface area of 10x10x10 box = 6 * 100 = 600
        #expect(abs(props.mass - 600) < 1)
    }

    /// A cylinder of radius 5 and height 20: volume 500π, moment about its own axis
    /// m r²/2 = 19634.95, and about either transverse axis through the centroid
    /// m(3r² + h²)/12 = 62177.35, reported by `GProp_PrincipalProps::Moments` as (62177.35,
    /// 62177.35, 19634.95). The test used to be named for these moments and check only that the
    /// mass was positive.
    @Test("Cylinder principal moments")
    func cylinderPrincipal() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20))
        let props = try #require(cyl.inertiaProperties())
        let mass = Double.pi * 25 * 20
        #expect(abs(props.mass - mass) < 1e-6)
        let axial = mass * 25 / 2
        let transverse = mass * (3 * 25 + 400) / 12
        #expect(abs(props.principalMoments.x - transverse) < 1e-6)
        #expect(abs(props.principalMoments.y - transverse) < 1e-6)
        #expect(abs(props.principalMoments.z - axial) < 1e-6)
        // Cylinder has symmetry axis
        #expect(props.hasSymmetryAxis)
    }
}
