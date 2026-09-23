import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLProp CLProps")
struct GeomLPropCLPropsTests {
    /// A cylinder (r 10, h 5) has three edges: two circles of radius 10 at z = 0 and z = 5, and
    /// the straight seam. At parameter 0 each circle is at (10, 0, z), with curvature 1/10, tangent
    /// +Y, the normal pointing back at the axis and the centre of curvature on it, which is what
    /// `GeomLProp_CLProps` reports for both.
    ///
    /// This used to look for any edge with curvature above 0.01 and check only that the
    /// tangent, normal and centre were not nil: a curvature of 0 everywhere found no such edge and
    /// passed with no assertion run, and a reversed normal passed too.
    @Test("Curve properties on circle edge")
    func curvePropsOnCircle() throws {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 5))
        let edges = cyl.subShapes(ofType: .edge)
        try #require(edges.count == 3)
        var circles = 0
        for edge in edges {
            let props = edge.curveLocalProps(at: 0)
            guard props.curvature > 0.01 else { continue }
            circles += 1
            #expect(abs(props.curvature - 0.1) < 1e-12)
            #expect(abs(props.point.x - 10) < 1e-9 && abs(props.point.y) < 1e-9)
            if let t = props.tangent {
                #expect(abs(t.x) < 1e-12 && abs(t.y - 1) < 1e-12 && abs(t.z) < 1e-12)
            } else {
                Issue.record("a circle has a tangent")
            }
            if let n = props.normal {
                #expect(abs(n.x + 1) < 1e-12 && abs(n.y) < 1e-12 && abs(n.z) < 1e-12)
            } else {
                Issue.record("a circle has a principal normal")
            }
            if let c = props.centerOfCurvature {
                #expect(abs(c.x) < 1e-9 && abs(c.y) < 1e-9 && abs(c.z - props.point.z) < 1e-9)
            } else {
                Issue.record("a circle has a centre of curvature")
            }
        }
        #expect(circles == 2)
    }

    /// The first edge of a centred 10-cube runs from (-5, -5, -5) to (-5, -5, 5) along +Z.
    @Test("Tangent defined on line edge")
    func tangentOnLineEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        let first = try #require(edges.first)
        let props = first.curveLocalProps(at: 0.5)
        if let t = props.tangent {
            #expect(abs(t.x) < 1e-12 && abs(t.y) < 1e-12 && abs(t.z - 1) < 1e-12)
        } else {
            Issue.record("a straight edge has a tangent")
        }
        // Line has zero curvature
        #expect(props.curvature < 0.001)
    }
}
