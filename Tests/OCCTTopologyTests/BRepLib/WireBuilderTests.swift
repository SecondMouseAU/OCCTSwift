import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - WireBuilder")
struct WireBuilderTests {

    @Test func buildWireFromEdges() {
        // Create edges that form a triangle
        if let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)),
            let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(5, 10, 0)),
            let e3 = Shape.edgeFromPoints(SIMD3(5, 10, 0), SIMD3(0, 0, 0))
        {
            let wb = WireBuilder()
            wb.addEdge(e1)
            wb.addEdge(e2)
            wb.addEdge(e3)
            #expect(wb.isDone)
            #expect(wb.error == .wireDone)
            let wire = wb.wire
            #expect(wire != nil)
        }
    }

    @Test func buildWireFromWire() {
        if let rect = Wire.rectangle(width: 10, height: 5),
            let wireShape = Shape.fromWire(rect)
        {
            let wb = WireBuilder()
            wb.addWire(wireShape)
            #expect(wb.isDone)
            let wire = wb.wire
            #expect(wire != nil)
        }
    }

    @Test func emptyWireError() {
        let wb = WireBuilder()
        #expect(!wb.isDone)
        #expect(wb.error == .emptyWire)
    }
}
