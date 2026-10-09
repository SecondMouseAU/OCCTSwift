import Testing
import simd

@testable import OCCTSwift

@Suite("Oriented Primitives")
struct OrientedPrimitivesTests {
    // MARK: - Sphere variants

    @Test("Sphere at center")
    func sphereAtCenter() {
        let s = Shape.sphere(center: SIMD3(10, 20, 30), radius: 5)
        #expect(s != nil)
        if let s {
            #expect(s.isValid)
            let expectedVol = (4.0 / 3.0) * Double.pi * 125.0
            if let vol = s.volume {
                #expect(abs(vol - expectedVol) < 1.0)
            }
        }
    }

    @Test("Oriented sphere")
    func orientedSphere() {
        let s = Shape.sphere(at: SIMD3(5, 5, 5), direction: SIMD3(1, 0, 0), radius: 3)
        #expect(s != nil)
        if let s {
            #expect(s.isValid)
            let expectedVol = (4.0 / 3.0) * Double.pi * 27.0
            if let vol = s.volume {
                #expect(abs(vol - expectedVol) < 1.0)
            }
        }
    }

    @Test("Partial sphere")
    func partialSphere() {
        let s = Shape.sphere(radius: 10, angle: .pi)
        #expect(s != nil)
        if let s {
            #expect(s.isValid)
            // Half sphere volume = (2/3) * pi * r^3
            let expectedVol = (2.0 / 3.0) * Double.pi * 1000.0
            if let vol = s.volume {
                #expect(abs(vol - expectedVol) < 10.0)
            }
        }
    }

    // MARK: - Cone oriented

    @Test("Oriented cone")
    func orientedCone() {
        let c = Shape.cone(
            at: SIMD3(10, 0, 0), direction: SIMD3(0, 1, 0),
            bottomRadius: 5, topRadius: 2, height: 10)
        #expect(c != nil)
        if let c {
            #expect(c.isValid)
            // Frustum volume = pi/3 * h * (R1^2 + R1*R2 + R2^2)
            let expectedVol = Double.pi / 3.0 * 10.0 * (25.0 + 10.0 + 4.0)
            if let vol = c.volume {
                #expect(abs(vol - expectedVol) < 5.0)
            }
        }
    }

    @Test("Oriented cone volume matches default")
    func orientedConeVolume() {
        let c1 = Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)
        let c2 = Shape.cone(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
            bottomRadius: 5, topRadius: 2, height: 10)
        if let v1 = c1?.volume, let v2 = c2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Torus oriented

    @Test("Oriented torus")
    func orientedTorus() {
        let t = Shape.torus(
            at: SIMD3(0, 0, 10), direction: SIMD3(0, 1, 0),
            majorRadius: 10, minorRadius: 3)
        #expect(t != nil)
        if let t {
            #expect(t.isValid)
            // Torus volume = 2 * pi^2 * R * r^2
            let expectedVol = 2.0 * Double.pi * Double.pi * 10.0 * 9.0
            if let vol = t.volume {
                #expect(abs(vol - expectedVol) < 10.0)
            }
        }
    }

    @Test("Oriented torus volume matches default")
    func orientedTorusVolume() {
        let t1 = Shape.torus(majorRadius: 10, minorRadius: 3)
        let t2 = Shape.torus(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 3)
        if let v1 = t1?.volume, let v2 = t2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Box oriented

    @Test("Oriented box")
    func orientedBox() {
        let b = Shape.box(
            at: SIMD3(5, 5, 5), direction: SIMD3(0, 1, 0),
            width: 10, height: 20, depth: 30)
        #expect(b != nil)
        if let b {
            #expect(b.isValid)
            let expectedVol = 10.0 * 20.0 * 30.0
            if let vol = b.volume {
                #expect(abs(vol - expectedVol) < 1.0)
            }
        }
    }

    @Test("Oriented box volume matches default")
    func orientedBoxVolume() {
        let b1 = Shape.box(width: 10, height: 20, depth: 30)
        let b2 = Shape.box(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
            width: 10, height: 20, depth: 30)
        if let v1 = b1?.volume, let v2 = b2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Cylinder partial

    @Test("Partial cylinder")
    func partialCylinder() {
        let c = Shape.cylinder(radius: 5, height: 10, angle: .pi)
        #expect(c != nil)
        if let c {
            #expect(c.isValid)
            // Half cylinder volume = pi * r^2 * h / 2
            let expectedVol = Double.pi * 25.0 * 10.0 / 2.0
            if let vol = c.volume {
                #expect(abs(vol - expectedVol) < 5.0)
            }
        }
    }

    @Test("Full cylinder via angle matches default")
    func fullCylinderAngle() {
        let c1 = Shape.cylinder(radius: 5, height: 10)
        let c2 = Shape.cylinder(radius: 5, height: 10, angle: 2.0 * .pi)
        if let v1 = c1?.volume, let v2 = c2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }

    // MARK: - Wedge oriented

    @Test("Oriented wedge")
    func orientedWedge() {
        let w = Shape.wedge(
            at: SIMD3(0, 0, 10), direction: SIMD3(0, 1, 0),
            dx: 10, dy: 5, dz: 8, ltx: 4)
        #expect(w != nil)
        if let w {
            #expect(w.isValid)
        }
    }

    @Test("Oriented wedge volume matches default")
    func orientedWedgeVolume() {
        let w1 = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 4)
        let w2 = Shape.wedge(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
            dx: 10, dy: 5, dz: 8, ltx: 4)
        if let v1 = w1?.volume, let v2 = w2?.volume {
            #expect(abs(v1 - v2) < 0.01)
        }
    }
}
