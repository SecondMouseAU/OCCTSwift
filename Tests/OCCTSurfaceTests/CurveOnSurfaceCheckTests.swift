import Testing

@testable import OCCTSwift

@Suite("Curve-on-Surface Check Tests")
struct CurveOnSurfaceCheckTests {

    // #766: the thresholds below (< 1e-5, < 1e-4, < 0.1) pass a check that inspected nothing and
    // reported 0. Each test now also pins the kernel's own worst deviation over the same (face,
    // edge) pairs: exactly 0 for the box, 3.46e-15 for the sphere, 1.22e-15 for the cylinder and
    // 9.53e-8 for the fuse, from BRepLib_CheckCurveOnSurface in
    // Scripts/repro/766-convert-check-evolved-revol/.

    @Test("Box has consistent edge curves")
    func boxConsistency() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let check = box.curveOnSurfaceCheck
        #expect(check != nil)
        if let check {
            // Clean box should have near-zero deviation
            #expect(check.maxDistance < 1e-5)
            #expect(check.maxDistance == 0)
        }
    }

    @Test("Sphere has consistent edge curves")
    func sphereConsistency() {
        let sphere = Shape.sphere(radius: 10)!
        let check = sphere.curveOnSurfaceCheck
        #expect(check != nil)
        if let check {
            #expect(check.maxDistance < 1e-4)
            #expect(abs(check.maxDistance - 3.4638242249419733e-15) < 1e-18)
        }
    }

    @Test("Cylinder has consistent edge curves")
    func cylinderConsistency() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let check = cyl.curveOnSurfaceCheck
        #expect(check != nil)
        if let check {
            #expect(check.maxDistance < 1e-4)
            #expect(abs(check.maxDistance - 1.2246467991473533e-15) < 1e-18)
        }
    }

    @Test("Fused shapes have consistent curves")
    func fusedConsistency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 7)!
        let fused = box.union(sphere)
        #expect(fused != nil)
        if let fused {
            let check = fused.curveOnSurfaceCheck
            #expect(check != nil)
            if let check {
                #expect(check.maxDistance < 0.1)
                #expect(abs(check.maxDistance - 9.5267920493270872e-08) < 1e-12)
            }
        }
    }
}
