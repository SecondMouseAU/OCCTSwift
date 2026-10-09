import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Mass Properties")
struct MassPropertiesTests {

    @Test func linearProperties() {
        if let rect = Wire.rectangle(width: 10, height: 10),
            let wireShape = Shape.fromWire(rect)
        {
            let lp = wireShape.linearProperties()
            #expect(abs((lp?.length ?? 0) - 40.0) < 0.1)  // perimeter of 10x10 rect
        }
    }

    @Test func momentOfInertia() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let moi = box.momentOfInertia()
            #expect((moi?.ixx ?? 0) > 0)
            #expect((moi?.iyy ?? 0) > 0)
            #expect((moi?.izz ?? 0) > 0)
        }
    }

    @Test func principalAxes() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let pa = box.principalAxes() {
                // Principal axes should be unit vectors (or near unit)
                let len1 = sqrt(
                    pa.axis1.x * pa.axis1.x + pa.axis1.y * pa.axis1.y + pa.axis1.z * pa.axis1.z)
                #expect(abs(len1 - 1.0) < 0.01)
            } else {
                Issue.record("a box has principal axes")
            }
        }
    }

    @Test func radiusOfGyration() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let rog = box.radiusOfGyration(axisOrigin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
            #expect((rog ?? 0) > 0)
        }
    }
}
