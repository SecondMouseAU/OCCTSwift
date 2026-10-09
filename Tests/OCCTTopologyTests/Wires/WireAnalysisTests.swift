import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire Topology Analysis")
struct WireAnalysisTests {
    @Test("Analyze closed rectangle wire")
    func analyzeRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let analysis = rect.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.edgeCount == 4)
            #expect(a.isClosed)
            #expect(!a.hasSelfIntersection)
        }
    }

    @Test("Analyze open line wire")
    func analyzeOpenLine() {
        guard let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else { return }
        let analysis = line.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.edgeCount == 1)
            // #1415: ShapeAnalysis_Wire's face was never set, so IsReady() was always false and
            // CheckClosed()/CheckSelfIntersection() always took their unready early return.
            // Because the bridge negated CheckClosed's result, that forced isClosed to true
            // unconditionally, even for this definitively open, single-edge wire.
            #expect(!a.isClosed)
            #expect(!a.hasSelfIntersection)
        }
    }

    @Test("Analyze open polyline wire (endpoints far apart)")
    func analyzeOpenPolyline() {
        // An "L" shape: three points, two edges, open (start and end 11+ units apart). Distinct
        // from analyzeOpenLine's single-edge case: this one CAN get a supporting planar face built
        // for it (BRepBuilderAPI_MakeFace succeeds), so it specifically exercises that isClosed
        // is computed directly from 3D endpoint coincidence rather than from
        // ShapeAnalysis_Wire::CheckClosed(), whose DONE/FAIL semantics leave "closed" and "failed
        // to determine" both reading as `false` -- true even with a real face set (#1415).
        guard
            let wire = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 5, 0)], closed: false)
        else { return }
        let analysis = wire.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.edgeCount == 2)
            #expect(!a.isClosed)
        }
    }

    @Test("Analyze circle wire")
    func analyzeCircle() {
        let circle = Wire.circle(radius: 5)!
        let analysis = circle.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.isClosed)
        }
    }

    @Test("Analyze self-intersecting bowtie wire")
    func analyzeSelfIntersectingBowtie() {
        // A closed planar "bowtie" quad (edges cross in the middle): (0,0)-(10,10)-(10,0)-(0,10)
        // back to (0,0). #1415: hasSelfIntersection was always false regardless of the wire's
        // actual geometry, because the analyzer's face was never set and
        // CheckSelfIntersection() always took its unready early return.
        guard
            let wire = Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 10, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0),
                ], closed: true)
        else { return }
        let analysis = wire.analyze()
        #expect(analysis != nil)
        if let a = analysis {
            #expect(a.edgeCount == 4)
            #expect(a.isClosed)
            #expect(a.hasSelfIntersection)
        }
    }
}
