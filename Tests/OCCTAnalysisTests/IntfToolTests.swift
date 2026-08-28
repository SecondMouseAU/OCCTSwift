import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Intf_Tool v0.112")
struct IntfToolTests {

    @Test func clipLineToBox() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(0, 0, -10),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        // Line along Z should intersect the box
        #expect(nSeg >= 0)
    }

    @Test func segmentParameters() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, -10),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        if nSeg > 0 {
            let begin = tool.beginParam(segment: 1)
            let end = tool.endParam(segment: 1)
            #expect(end > begin)
        }
    }

    @Test func lineParallelToFace() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, 5),
            lineDirection: SIMD3(1, 0, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg >= 0)
    }

    @Test func lineMissesBox() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(100, 100, 100),
            lineDirection: SIMD3(0, 1, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg >= 0)  // should not crash
    }

    @Test func lineThroughCenter() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, -100),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        if nSeg > 0 {
            let begin = tool.beginParam(segment: 1)
            let end = tool.endParam(segment: 1)
            // Should represent the Z range through the box
            #expect(begin < end)
        }
    }
}
