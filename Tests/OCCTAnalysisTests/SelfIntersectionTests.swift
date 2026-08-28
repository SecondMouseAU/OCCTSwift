import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Self-Intersection Tests")
struct SelfIntersectionTests {
    @Test("Box has no self-intersection")
    func boxNoSelfIntersection() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.selfIntersection()
        #expect(result != nil)
        #expect(result!.isDone)
        #expect(result!.overlapCount == 0)
    }

    @Test("Sphere has no self-intersection")
    func sphereNoSelfIntersection() throws {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.selfIntersection()
        #expect(result != nil)
        #expect(result!.isDone)
    }

    @Test("Cylinder has no self-intersection")
    func cylinderNoSelfIntersection() throws {
        let cyl = Shape.cylinder(radius: 3, height: 10)!
        let result = cyl.selfIntersection()
        #expect(result != nil)
        #expect(result!.isDone)
    }

    @Test("Custom tolerance and mesh deflection")
    func customParameters() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        let result = box.selfIntersection(tolerance: 0.01, meshDeflection: 0.1)
        #expect(result != nil)
        #expect(result!.isDone)
    }
}
