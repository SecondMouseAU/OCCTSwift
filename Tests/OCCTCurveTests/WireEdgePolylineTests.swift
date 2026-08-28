import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire.edgePolyline") struct WireEdgePolylineTests {
    @Test("Wire.edgePolyline returns points for single edge")
    func singleEdge() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let polyline = wire.edgePolyline(at: 0)
            #expect(polyline != nil)
            if let polyline {
                #expect(polyline.count >= 2)
            }
        }
    }
}
