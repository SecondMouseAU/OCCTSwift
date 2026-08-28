import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Conversion Tests")
struct BezierConversionTests {

    @Test("Cylinder converts to Bezier")
    func cylinderToBezier() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let bezier = cyl.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            let edgeCount = bezier.subShapeCount(ofType: ShapeType.edge)
            #expect(edgeCount > 0)
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount > 0)
        }
    }

    @Test("Sphere converts to Bezier")
    func sphereToBezier() {
        let sphere = Shape.sphere(radius: 10)!
        let bezier = sphere.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount > 0)
        }
    }

    @Test("Box converts to Bezier")
    func boxToBezier() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let bezier = box.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            // Box should maintain 6 faces
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount == 6)
            let edgeCount = bezier.subShapeCount(ofType: ShapeType.edge)
            #expect(edgeCount == 12)
        }
    }

    @Test("Cone converts to Bezier")
    func coneToBezier() {
        let cone = Shape.cone(bottomRadius: 10, topRadius: 5, height: 15)!
        let bezier = cone.convertedToBezier
        #expect(bezier != nil)
        if let bezier {
            let faceCount = bezier.subShapeCount(ofType: ShapeType.face)
            #expect(faceCount > 0)
        }
    }
}
