import Foundation
import Testing
import simd

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
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let inertia = box.surfaceInertia!
        #expect(inertia.principalMoments.x > 0)
        #expect(inertia.principalMoments.y > 0)
        #expect(inertia.principalMoments.z > 0)
    }

    // #848: hasSymmetryAxis/hasSymmetryPoint, added to SurfaceInertia to match what
    // surfaceInertiaProperties() (the older generation) has always reported.
    @Test("Sphere surface inertia has symmetry point")
    func sphereSurfaceInertiaSymmetryPoint() throws {
        let sphere = Shape.sphere(radius: 5)!
        let inertia = sphere.surfaceInertia
        #expect(inertia != nil)
        if let inertia {
            #expect(inertia.hasSymmetryPoint)
        }
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
