import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("WireAnalyzer v124")
struct WireAnalyzerV124Tests {

    /// A rectangle wire, its face, and a `WireAnalyzer` over both — the fixture all nine tests
    /// below share (#1285; each previously rebuilt this independently inside a triple-nested
    /// `if let`).
    private func rectangleAnalyzer(precision: Double = 1e-7) -> WireAnalyzer? {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let face = Shape.face(from: wire)
        else { return nil }
        return WireAnalyzer(wire: wire, face: face, precision: precision)
    }

    @Test("WireAnalyzer create and basic properties")
    func wireAnalyzerCreate() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        #expect(a.isLoaded)
        #expect(a.isReady)
        #expect(a.edgeCount == 4)
    }

    @Test("WireAnalyzer perform all checks")
    func wireAnalyzerPerform() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        let hasIssues = a.perform()
        #expect(!hasIssues || hasIssues)
    }

    @Test("WireAnalyzer check order")
    func wireAnalyzerCheckOrder() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        let disordered = a.checkOrder()
        #expect(!disordered)
    }

    @Test("WireAnalyzer check individual edges")
    func wireAnalyzerCheckEdges() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        let n = a.edgeCount
        #expect(n == 4)
        for i in 1...n {
            let connected = a.checkConnected(edgeNum: i)
            #expect(!connected)
            let small = a.checkSmall(edgeNum: i)
            #expect(!small)
            let degen = a.checkDegenerated(edgeNum: i)
            #expect(!degen)
        }
    }

    @Test("WireAnalyzer check self-intersection")
    func wireAnalyzerSelfIntersection() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        let si = a.checkSelfIntersection()
        #expect(!si)
    }

    @Test("WireAnalyzer check closed")
    func wireAnalyzerCheckClosed() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        let notClosed = a.checkClosed()
        #expect(!notClosed || notClosed)
    }

    @Test("WireAnalyzer distances")
    func wireAnalyzerDistances() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        _ = a.perform()
        let min3d = a.minDistance3d
        let max3d = a.maxDistance3d
        #expect(min3d >= 0)
        #expect(max3d >= 0)
    }

    @Test("WireAnalyzer gap checks")
    func wireAnalyzerGaps() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        for i in 1...a.edgeCount {
            let gap3d = a.checkGap3d(edgeNum: i)
            #expect(!gap3d)
        }
    }

    @Test("WireAnalyzer seam and lacking")
    func wireAnalyzerSeamLacking() {
        guard let a = rectangleAnalyzer() else {
            Issue.record("could not build the rectangle WireAnalyzer")
            return
        }
        for i in 1...a.edgeCount {
            let seam = a.checkSeam(edgeNum: i)
            #expect(!seam)
            let lacking = a.checkLacking(edgeNum: i)
            #expect(!lacking)
        }
    }
}
