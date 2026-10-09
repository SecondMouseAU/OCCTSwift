import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape distance to Wire/Edge/Face") struct ShapeDistanceOverloadTests {
    @Test("Shape distance to Wire")
    func distanceToWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let wire = Wire.circle(origin: SIMD3(20, 0, 0), radius: 1)
        if let box, let wire {
            let result = box.distance(to: wire)
            #expect(result != nil)
            if let result {
                #expect(result.distance > 0)
            }
        }
    }

    @Test("Shape intersects Wire")
    func intersectsWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let wire = Wire.circle(origin: SIMD3(20, 0, 0), radius: 1)
        if let box, let wire {
            #expect(!box.intersects(wire))
        }
    }

    @Test("Shape distance to Edge")
    func distanceToEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let edges = box.edges()
            if let edge = edges.first {
                let result = box.distance(to: edge)
                #expect(result != nil)
            }
        }
    }

    @Test("Shape distance to Face")
    func distanceToFace() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        if let box1, let box2 {
            let faces = box2.faces()
            if let face = faces.first {
                let result = box1.distance(to: face)
                #expect(result != nil)
            }
        }
    }
}
