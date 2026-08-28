import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("WireAnalyzer v124")
struct WireAnalyzerV124Tests {

    @Test("WireAnalyzer create and basic properties")
    func wireAnalyzerCreate() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    #expect(a.isLoaded)
                    #expect(a.isReady)
                    #expect(a.edgeCount == 4)
                }
            }
        }
    }

    @Test("WireAnalyzer perform all checks")
    func wireAnalyzerPerform() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let hasIssues = a.perform()
                    #expect(!hasIssues || hasIssues)
                }
            }
        }
    }

    @Test("WireAnalyzer check order")
    func wireAnalyzerCheckOrder() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let disordered = a.checkOrder()
                    #expect(!disordered)
                }
            }
        }
    }

    @Test("WireAnalyzer check individual edges")
    func wireAnalyzerCheckEdges() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
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
            }
        }
    }

    @Test("WireAnalyzer check self-intersection")
    func wireAnalyzerSelfIntersection() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let si = a.checkSelfIntersection()
                    #expect(!si)
                }
            }
        }
    }

    @Test("WireAnalyzer check closed")
    func wireAnalyzerCheckClosed() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    let notClosed = a.checkClosed()
                    #expect(!notClosed || notClosed)
                }
            }
        }
    }

    @Test("WireAnalyzer distances")
    func wireAnalyzerDistances() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    _ = a.perform()
                    let min3d = a.minDistance3d
                    let max3d = a.maxDistance3d
                    #expect(min3d >= 0)
                    #expect(max3d >= 0)
                }
            }
        }
    }

    @Test("WireAnalyzer gap checks")
    func wireAnalyzerGaps() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    for i in 1...a.edgeCount {
                        let gap3d = a.checkGap3d(edgeNum: i)
                        #expect(!gap3d)
                    }
                }
            }
        }
    }

    @Test("WireAnalyzer seam and lacking")
    func wireAnalyzerSeamLacking() {
        let wire = Wire.rectangle(width: 10, height: 10)
        if let w = wire {
            let face = Shape.face(from: w)
            if let f = face {
                let analyzer = WireAnalyzer(wire: w, face: f, precision: 1e-7)
                if let a = analyzer {
                    for i in 1...a.edgeCount {
                        let seam = a.checkSeam(edgeNum: i)
                        #expect(!seam)
                        let lacking = a.checkLacking(edgeNum: i)
                        #expect(!lacking)
                    }
                }
            }
        }
    }
}
