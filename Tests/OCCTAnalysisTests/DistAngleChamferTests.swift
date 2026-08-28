import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Distance-Angle Chamfer")
struct DistAngleChamferTests {
    @Test("Distance-angle chamfer on box edge")
    func distAngleChamfer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedDistAngle([
            (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: 45.0)
        ])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Distance-angle chamfer at 30 degrees")
    func distAngle30() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedDistAngle([
            (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: 30.0)
        ])
        #expect(result != nil)
    }

    @Test("Distance-angle chamfer at 60 degrees")
    func distAngle60() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedDistAngle([
            (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: 60.0)
        ])
        #expect(result != nil)
    }
}
