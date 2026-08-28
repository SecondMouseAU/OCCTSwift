import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLProp CLProps")
struct GeomLPropCLPropsTests {
    @Test("Curve properties on circle edge")
    func curvePropsOnCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Find a circular edge
        for edge in edges {
            let props = edge.curveLocalProps(at: 0)
            if props.curvature > 0.01 {
                #expect(props.tangent != nil)
                #expect(props.normal != nil)
                #expect(props.centerOfCurvature != nil)
                return
            }
        }
    }

    @Test("Tangent defined on line edge")
    func tangentOnLineEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        let props = edges[0].curveLocalProps(at: 0.5)
        #expect(props.tangent != nil)
        // Line has zero curvature
        #expect(props.curvature < 0.001)
    }
}
