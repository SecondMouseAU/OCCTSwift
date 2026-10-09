import Testing

@testable import OCCTSwift

@Suite("Curve-on-Surface Check Tests")
struct CurveOnSurfaceCheckTests {

    @Test("Box has consistent edge curves")
    func boxConsistency() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let check = box.curveOnSurfaceCheck
        #expect(check != nil)
        if let check {
            // Clean box should have near-zero deviation
            #expect(check.maxDistance < 1e-5)
        }
    }

    @Test("Sphere has consistent edge curves")
    func sphereConsistency() {
        let sphere = Shape.sphere(radius: 10)!
        let check = sphere.curveOnSurfaceCheck
        #expect(check != nil)
        if let check {
            #expect(check.maxDistance < 1e-4)
        }
    }

    @Test("Cylinder has consistent edge curves")
    func cylinderConsistency() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let check = cyl.curveOnSurfaceCheck
        #expect(check != nil)
        if let check {
            #expect(check.maxDistance < 1e-4)
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
            }
        }
    }
}
