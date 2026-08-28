import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire.bounds property") struct WireBoundsTests {
    @Test("Wire rectangle has correct bounds")
    func rectangleBounds() {
        let wire = Wire.rectangle(width: 10, height: 6)
        if let wire {
            let b = wire.bounds!
            #expect(b.min.x < b.max.x)
            #expect(b.min.y < b.max.y)
            #expect(abs(b.max.x - b.min.x - 10) < 0.01)
            #expect(abs(b.max.y - b.min.y - 6) < 0.01)
        }
    }

    @Test("Wire circle has correct bounds")
    func circleBounds() {
        let wire = Wire.circle(radius: 5)
        if let wire {
            let b = wire.bounds!
            #expect(abs(b.max.x - b.min.x - 10) < 0.01)
            #expect(abs(b.max.y - b.min.y - 10) < 0.01)
        }
    }
}
