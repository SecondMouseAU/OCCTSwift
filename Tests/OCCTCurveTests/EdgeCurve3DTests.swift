import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.147 #80: Edge.curve3D

@Suite("v0.147 Edge.curve3D accessor")
struct EdgeCurve3DTests {
    @Test("Linear edge returns a Curve3D")
    func linearEdgeCurve3D() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let edges = box.edges()
        #expect(edges.count > 0)
        if let c = edges.first?.curve3D {
            #expect(c.domain.lowerBound <= c.domain.upperBound)
        } else {
            Issue.record("curve3D nil")
        }
    }

    @Test("Cylindrical face's circular edge yields circleProperties")
    func circularEdgeCircleProps() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cyl nil")
            return
        }
        var foundCircle = false
        for edge in cyl.edges() where edge.curveType == .circle {
            if let curve = edge.curve3D {
                let props = curve.circleProperties
                #expect(abs(props.radius - 5.0) < 1e-6)
                foundCircle = true
            }
        }
        #expect(foundCircle)
    }
}
