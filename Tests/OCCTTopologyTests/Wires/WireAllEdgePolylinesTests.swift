import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire.allEdgePolylines, Issue #46") struct WireAllEdgePolylinesTests {
    @Test("Wire.allEdgePolylines returns polylines for rectangle")
    func rectanglePolylines() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let polylines = wire.allEdgePolylines()
            #expect(polylines.count == 4)
            for polyline in polylines {
                #expect(polyline.count >= 2)
            }
        }
    }

    @Test("Wire.allEdgePolylines returns polylines for circle")
    func circlePolylines() {
        let wire = Wire.circle(radius: 10)
        if let wire {
            let polylines = wire.allEdgePolylines()
            #expect(polylines.count >= 1)
            #expect(polylines.first?.count ?? 0 > 2)
        }
    }
}
