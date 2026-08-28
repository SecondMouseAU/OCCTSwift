import Testing
import simd

@testable import OCCTSwift

@Suite("Split by Angle")
struct SplitByAngleTests {
    @Test("Split cylinder by 90 degrees")
    func splitCylinder90() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.splitByAngle(90)
        #expect(result != nil)
        if let r = result {
            // A full cylinder split at 90° should produce 4 lateral faces + 2 caps
            let faceCount = r.faces().count
            #expect(faceCount > cyl.faces().count)
        }
    }

    @Test("Split sphere by 90 degrees")
    func splitSphere90() {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.splitByAngle(90)
        #expect(result != nil)
        if let r = result {
            #expect(r.faces().count > sphere.faces().count)
        }
    }

    @Test("Split box by angle is no-op or returns nil")
    func splitBoxNoOp() {
        // Box faces are all planar, no angle splitting needed
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.splitByAngle(90)
        // ShapeDivideAngle may return nil if no surfaces need splitting
        if let r = result {
            #expect(r.faces().count >= box.faces().count)
        }
    }

    @Test("Split cone by 180 degrees")
    func splitCone180() {
        let cone = Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)!
        let result = cone.splitByAngle(180)
        #expect(result != nil)
        if let r = result {
            // Full cone split at 180° should produce 2 lateral faces
            #expect(r.faces().count >= cone.faces().count)
        }
    }
}
