import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape from Wire Tests")
struct ShapeFromWireTests {

    @Test("Convert rectangle wire to shape and extract edges")
    func rectangleWireEdges() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let shape = Shape.fromWire(rect)
        #expect(shape != nil)
        let polylines = shape!.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == 4)  // rectangle has 4 edges
    }

    @Test("Convert circle wire to shape and extract edges")
    func circleWireEdges() {
        let circle = Wire.circle(radius: 5)!
        let shape = Shape.fromWire(circle)
        #expect(shape != nil)
        let polylines = shape!.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count >= 1)
        // Circle edge polyline should have multiple points
        #expect(polylines[0].count > 2)
    }

    @Test("Shape from wire reports correct shape type")
    func wireShapeType() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let shape = Shape.fromWire(rect)!
        #expect(shape.shapeType == .wire)
    }
}
