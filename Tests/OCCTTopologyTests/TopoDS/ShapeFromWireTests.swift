import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shape from Wire Tests")
struct ShapeFromWireTests {

    @Test("Convert rectangle wire to shape and extract edges")
    func rectangleWireEdges() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let shape = Shape.fromWire(rect)
        #expect(shape != nil)
        let polylines = try #require(shape).allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == 4)  // rectangle has 4 edges
    }

    @Test("Convert circle wire to shape and extract edges")
    func circleWireEdges() throws {
        let circle = try #require(Wire.circle(radius: 5))
        let shape = Shape.fromWire(circle)
        #expect(shape != nil)
        let polylines = try #require(shape).allEdgePolylines(deflection: 0.1)
        #expect(polylines.count >= 1)
        // Circle edge polyline should have multiple points
        #expect(polylines[0].count > 2)
    }

    @Test("Shape from wire reports correct shape type")
    func wireShapeType() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let shape = try #require(Shape.fromWire(rect))
        #expect(shape.shapeType == .wire)
    }
}
