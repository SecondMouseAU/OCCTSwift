import Foundation
import Testing

@testable import OCCTSwift

@Suite("Surface Inertia Tests")
struct SurfaceInertiaTests {
    @Test("Box surface inertia")
    func boxSurfaceInertia() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let inertia = box.surfaceInertia
        #expect(inertia != nil)
        if let inertia {
            // Surface area = 2*(10*20 + 10*30 + 20*30) = 2*(200+300+600) = 2200
            #expect(abs(inertia.area - 2200) < 1.0)
        }
    }

    @Test("Surface inertia principal moments positive")
    func surfacePrincipalMoments() throws {
        // Unit surface density: a thin-walled cube of side a has I = (5/18) M a^2 about its
        // centre, with M the area 6 a^2 = 600, so 5/18 * 600 * 100 = 16666.67 on every axis.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let inertia = try #require(box.surfaceInertia)
        let expected = 5.0 / 18.0 * 600.0 * 100.0
        for (axis, m) in [
            ("x", inertia.principalMoments.x), ("y", inertia.principalMoments.y),
            ("z", inertia.principalMoments.z),
        ] {
            #expect(abs(m - expected) < 1e-6, "\(axis): got \(m), expected \(expected)")
        }

        // A box with three different sides separates the three axes. About x, summing the six
        // plates by the parallel-axis theorem: 2 * 600 * (20^2 + 30^2) / 12 + 2 * 300 *
        // (30^2 / 12 + 10^2) + 2 * 200 * (20^2 / 12 + 15^2) = 338333.33; the other two are
        // 263333.33 and 151666.67 (descending order here, since the axes are OCCT's to order).
        let long = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let li = try #require(long.surfaceInertia)
        let pm = [li.principalMoments.x, li.principalMoments.y, li.principalMoments.z].sorted(by: >)
        #expect(abs(pm[0] - 338333.3333333333) < 1e-3, "got \(pm)")
        #expect(abs(pm[1] - 263333.3333333333) < 1e-3, "got \(pm)")
        #expect(abs(pm[2] - 151666.6666666667) < 1e-3, "got \(pm)")
    }

    // #848: hasSymmetryAxis/hasSymmetryPoint, added to SurfaceInertia to match what
    // surfaceInertiaProperties() (the older generation) has always reported.
    @Test("Sphere surface inertia has symmetry point")
    func sphereSurfaceInertiaSymmetryPoint() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let inertia = try #require(sphere.surfaceInertia)
        #expect(inertia.hasSymmetryPoint)
        #expect(inertia.hasSymmetryAxis)
        // A thin spherical shell: I = 2/3 M r^2 with M = 4 pi 25, equal about every axis.
        let expected = 2.0 / 3.0 * (4.0 * Double.pi * 25.0) * 25.0
        for m in [
            inertia.principalMoments.x, inertia.principalMoments.y, inertia.principalMoments.z,
        ] {
            #expect(abs(m - expected) < 1e-6, "got \(m), expected \(expected)")
        }

        // The flags are not a constant: a cylinder shell has an axis but no point of symmetry,
        // and a 10 x 20 x 30 box has neither.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20)?.surfaceInertia)
        #expect(cyl.hasSymmetryAxis)
        #expect(!cyl.hasSymmetryPoint)
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30)?.surfaceInertia)
        #expect(!box.hasSymmetryAxis)
        #expect(!box.hasSymmetryPoint)
    }

    @Test("Surface inertia symmetry agrees with legacy surfaceInertiaProperties")
    func surfaceInertiaMatchesLegacySymmetry() throws {
        let sphere = Shape.sphere(radius: 5)!
        let legacy = sphere.surfaceInertiaProperties()
        let modern = sphere.surfaceInertia
        #expect(legacy != nil)
        #expect(modern != nil)
        if let legacy, let modern {
            #expect(legacy.hasSymmetryAxis == modern.hasSymmetryAxis)
            #expect(legacy.hasSymmetryPoint == modern.hasSymmetryPoint)
            #expect(abs(legacy.mass - modern.area) < 1e-6)
        }
    }
}
