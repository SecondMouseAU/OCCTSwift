import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - GCPnts Expansion")
struct GCPntsExpansionTests {

    @Test func edgeArcLength() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let len = edges[0].edgeArcLength
                #expect(len > 0)
            }
        }
    }

    @Test func edgeArcLengthBetween() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                let halfLen = edges[0].edgeArcLength(
                    from: domain.lowerBound,
                    to: (domain.lowerBound + domain.upperBound) / 2.0)
                #expect(halfLen > 0)
            }
        }
    }

    @Test func edgeParameterAtFraction() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let midParam = edges[0].edgeParameterAtFraction(0.5)
                let domain = edges[0].edgeAdaptorDomain
                #expect(midParam >= domain.lowerBound)
                #expect(midParam <= domain.upperBound)
            }
        }
    }

    @Test func edgeParameterAtArcLength() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let domain = edges[0].edgeAdaptorDomain
                let totalLen = edges[0].edgeArcLength
                let param = edges[0].edgeParameterAtArcLength(
                    totalLen * 0.5, from: domain.lowerBound)
                #expect(param >= domain.lowerBound)
            }
        }
    }

    @Test func edgeParameterAtArcLengthRefusesANonFiniteDistance() throws {
        // #3034: the shared walk refuses a non-finite distance or start, so the edge entry points
        // answer 0 (their failure value) and not an infinite parameter. A finite control shows the
        // edge itself is fine: 4 along a 10-long edge from its start is 4.
        let edge = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)))
        let lower = edge.edgeAdaptorDomain.lowerBound
        #expect(abs(edge.edgeParameterAtArcLength(4, from: lower) - (lower + 4)) < 1e-9)
        for value in [Double.infinity, -.infinity, .nan] {
            #expect(edge.edgeParameterAtArcLength(value, from: lower) == 0, "distance \(value)")
            #expect(edge.edgeParameterAtArcLength(4, from: value) == 0, "start \(value)")
            #expect(edge.edgeParameterAtFraction(value) == 0, "fraction \(value)")
        }
    }
}
