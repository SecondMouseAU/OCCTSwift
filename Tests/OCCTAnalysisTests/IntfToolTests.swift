import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Every figure below is `Intf_Tool::LinBox` on the pinned kernel, measured in
/// `Scripts/repro/766-inttools-intf-integration/`. The box is (0, 0, 0) to (10, 10, 10) throughout,
/// and a segment's parameters are distances along the line from its origin, since the direction
/// is a unit vector.
@Suite("Intf_Tool v0.112")
struct IntfToolTests {

    /// A line along Z through the box's (0, 0) corner edge enters at z = 0 and leaves at z = 10,
    /// 10 and 20 along from its origin at z = -10.
    @Test func clipLineToBox() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(0, 0, -10),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg == 1)
        #expect(abs(tool.beginParam(segment: 1) - 10) < 1e-9)
        #expect(abs(tool.endParam(segment: 1) - 20) < 1e-9)
    }

    @Test func segmentParameters() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, -10),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg == 1)
        #expect(abs(tool.beginParam(segment: 1) - 10) < 1e-9)
        #expect(abs(tool.endParam(segment: 1) - 20) < 1e-9)
    }

    /// A line that starts inside the box runs both ways from its origin: the segment is centred on
    /// parameter 0.
    @Test func lineParallelToFace() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, 5),
            lineDirection: SIMD3(1, 0, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg == 1)
        #expect(abs(tool.beginParam(segment: 1) + 5) < 1e-9)
        #expect(abs(tool.endParam(segment: 1) - 5) < 1e-9)
    }

    @Test func lineMissesBox() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(100, 100, 100),
            lineDirection: SIMD3(0, 1, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg == 0)
    }

    @Test func lineThroughCenter() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, -100),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        // The Z range through the box, 100 and 110 along from z = -100.
        #expect(nSeg == 1)
        #expect(abs(tool.beginParam(segment: 1) - 100) < 1e-9)
        #expect(abs(tool.endParam(segment: 1) - 110) < 1e-9)
    }
}
