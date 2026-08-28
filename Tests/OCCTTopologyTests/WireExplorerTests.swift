import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire Explorer")
struct WireExplorerTests {
    @Test("Rectangle has 4 ordered edges")
    func rectangleEdges() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        #expect(rect.orderedEdgeCount == 4)
    }

    @Test("Get edge points in order")
    func getEdgePoints() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        for i in 0..<rect.orderedEdgeCount {
            let points = rect.orderedEdgePoints(at: i)
            #expect(points != nil)
            #expect(points!.count >= 2)
        }
    }

    @Test("Out of range returns nil")
    func outOfRange() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        #expect(rect.orderedEdgePoints(at: 99) == nil)
        #expect(rect.orderedEdgePoints(at: -1) == nil)
    }

    @Test("Circle has 1 ordered edge")
    func circleEdge() {
        let circle = Wire.circle(radius: 5)!
        #expect(circle.orderedEdgeCount >= 1)
    }
}
