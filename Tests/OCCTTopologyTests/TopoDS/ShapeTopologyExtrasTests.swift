import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape Topology Extras")
struct ShapeTopologyExtrasTests {
    @Test func shapeTypeBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.shapeTypeString == "solid")
        }
    }

    @Test func shapeTypeWire() {
        if let wire = Wire.rectangle(width: 10, height: 10) {
            if let shape = Shape.fromWire(wire) {
                #expect(shape.shapeTypeString == "wire")
            }
        }
    }

    @Test func shapeTypeVertex() {
        if let v = Shape.vertex(at: SIMD3(0, 0, 0)) {
            #expect(v.shapeTypeString == "vertex")
        }
    }
}
