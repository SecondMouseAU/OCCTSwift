import Testing
import simd

@testable import OCCTSwift

@Suite("Partial Oriented Primitives")
struct PartialOrientedPrimitivesTests {

    @Test("Oriented partial cylinder")
    func orientedPartialCylinder() {
        let full = Shape.cylinder(
            at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5, height: 10)
        let partial = Shape.cylinder(
            at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5, height: 10, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented partial cone")
    func orientedPartialCone() {
        let full = Shape.cone(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), bottomRadius: 5, topRadius: 2, height: 10
        )
        let partial = Shape.cone(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), bottomRadius: 5, topRadius: 2,
            height: 10, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented partial torus")
    func orientedPartialTorus() {
        let full = Shape.torus(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3)
        let partial = Shape.torus(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3,
            angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented torus segment")
    func orientedTorusSegment() {
        let full = Shape.torus(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3)
        let segment = Shape.torus(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3,
            angle1: 0, angle2: .pi)
        #expect(full != nil)
        #expect(segment != nil)
        if let s = segment { #expect(s.isValid) }
        if let fv = full?.volume, let sv = segment?.volume {
            #expect(sv < fv)
        }
    }

    @Test("Oriented partial sphere")
    func orientedPartialSphere() {
        let full = Shape.sphere(at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5)
        let partial = Shape.sphere(
            at: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1), radius: 5, angle: .pi)
        #expect(full != nil)
        #expect(partial != nil)
        if let p = partial { #expect(p.isValid) }
        if let fv = full?.volume, let pv = partial?.volume {
            #expect(pv < fv)
            #expect(abs(pv - fv / 2.0) < 0.01)
        }
    }

    @Test("Oriented sphere segment")
    func orientedSphereSegment() {
        let full = Shape.sphere(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5)
        let segment = Shape.sphere(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, angle1: 0, angle2: .pi / 2)
        #expect(full != nil)
        #expect(segment != nil)
        if let s = segment { #expect(s.isValid) }
        if let fv = full?.volume, let sv = segment?.volume {
            #expect(sv < fv)
        }
    }
}
