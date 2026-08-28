import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GCPnts TangentialDeflection Tests")
struct GCPntsTangentialDeflectionTests {
    @Test("tangential deflection on edge")
    func tangentialDeflectionEdge() {
        let sphere = Shape.sphere(radius: 10)!
        let edges = sphere.edges()
        if let edge = edges.first {
            let pts = edge.tangentialDeflectionPoints(
                angularDeflection: 0.1, curvatureDeflection: 0.1)
            #expect(pts.count >= 2)
        }
    }

    @Test("tighter deflection gives more points")
    func tighterDeflection() {
        let sphere = Shape.sphere(radius: 10)!
        let edges = sphere.edges()
        if let edge = edges.first {
            let coarse = edge.tangentialDeflectionPoints(
                angularDeflection: 0.5, curvatureDeflection: 1.0)
            let fine = edge.tangentialDeflectionPoints(
                angularDeflection: 0.05, curvatureDeflection: 0.01)
            #expect(fine.count >= coarse.count)
        }
    }
}
