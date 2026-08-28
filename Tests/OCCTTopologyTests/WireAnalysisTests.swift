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
}
