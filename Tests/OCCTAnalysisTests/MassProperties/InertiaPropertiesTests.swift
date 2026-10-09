import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: Inertia Properties

@Suite("Inertia Properties")
struct InertiaPropertiesTests {
    @Test("Box volume inertia properties")
    func boxInertia() {
        // Box 10x20x30, origin at (0,0,0), extends to (10,20,30)
        // Volume = 6000, center of mass = (5, 10, 15)
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let props = box.inertiaProperties()
        #expect(props != nil)
        if let props {
            #expect(abs(props.mass - 6000) < 1)
            #expect(abs(props.centerOfMass.x - 0) < 0.1)  // Centered box
            #expect(abs(props.centerOfMass.y - 0) < 0.1)
            #expect(abs(props.centerOfMass.z - 0) < 0.1)
            // Inertia matrix should be 3x3 = 9 values
            #expect(props.inertiaMatrix.count == 9)
            // Diagonal elements should be positive
            #expect(props.inertiaMatrix[0] > 0)  // Ixx
            #expect(props.inertiaMatrix[4] > 0)  // Iyy
            #expect(props.inertiaMatrix[8] > 0)  // Izz
            // Principal moments should be positive
            #expect(props.principalMoments.x > 0)
            #expect(props.principalMoments.y > 0)
            #expect(props.principalMoments.z > 0)
        }
    }

    @Test("Sphere has symmetry point")
    func sphereSymmetry() {
        let sphere = Shape.sphere(radius: 10)!
        let props = sphere.inertiaProperties()
        #expect(props != nil)
        if let props {
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
    }

    @Test("Surface inertia properties")
    func surfaceInertia() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let props = box.surfaceInertiaProperties()
        #expect(props != nil)
        if let props {
            // Surface area of 10x10x10 box = 6 * 100 = 600
            #expect(abs(props.mass - 600) < 1)
        }
    }

    @Test("Cylinder principal moments")
    func cylinderPrincipal() {
        let cyl = Shape.cylinder(radius: 5, height: 20)!
        let props = cyl.inertiaProperties()
        #expect(props != nil)
        if let props {
            #expect(props.mass > 0)
            // Cylinder has symmetry axis
            #expect(props.hasSymmetryAxis)
        }
    }
}
