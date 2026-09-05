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

    // MARK: - #1584: curve3D is deliberately the raw, untrimmed curve

    @Test("Straight edge's curve3D domain is the underlying Geom_Line's unbounded range, not the edge's own finite span")
    func straightEdgeCurve3DIsUntrimmed() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        var checked = false
        for edge in box.edges() where edge.curveType == .line {
            guard let curve = edge.curve3D, let bounds = edge.parameterBounds else { continue }
            // The edge itself spans a finite, small range (a box edge is length 10).
            #expect(bounds.last - bounds.first < 100)
            // But the raw underlying Geom_Line reports its own unbounded domain
            // (±Precision::Infinite(), ~1.8e308), not the edge's trimmed extent.
            // If curve3D ever returned a Geom_TrimmedCurve over the edge's own
            // range instead, this would fail: domain would equal parameterBounds.
            #expect(curve.domain.upperBound > 1e100)
            #expect(curve.domain.lowerBound < -1e100)
            checked = true
            break
        }
        #expect(checked)
    }

    @Test("Circular edge's curve3D domain is the underlying circle's full period, not the arc's own sweep")
    func circularEdgeCurve3DIsUntrimmed() {
        // A quarter-circle arc: its own parameter range is far short of a full
        // 2*pi period, but curve3D's domain should still report the full period
        // of the underlying (periodic) Geom_Circle.
        guard
            let wire = Wire.arc(
                center: .zero, radius: 5, startAngle: 0, endAngle: .pi / 2)
        else {
            Issue.record("arc wire nil")
            return
        }
        guard let edge = wire.edges().first, edge.curveType == .circle else {
            Issue.record("expected a circular edge")
            return
        }
        guard let curve = edge.curve3D, let bounds = edge.parameterBounds else {
            Issue.record("curve3D or parameterBounds nil")
            return
        }
        // The edge's own sweep is a quarter turn.
        #expect(abs((bounds.last - bounds.first) - .pi / 2) < 1e-6)
        // The raw curve's domain is the full period, well beyond the arc's own sweep.
        #expect(curve.domain.upperBound - curve.domain.lowerBound > 6.0)
    }
}
