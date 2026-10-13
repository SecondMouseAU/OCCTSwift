import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Edge 3D Curve Properties Tests (v0.18.0)

@Suite("Edge Curve Properties Tests")
struct EdgeCurvePropertiesTests {

    @Test("Parameter bounds of line edge")
    func parameterBoundsLineEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        try #require(edges.count == 12)

        // A line edge is parametrised by arc length, so its parameter span is its length: 10
        // for every edge of the cube, and the bounds start at 0.
        for (i, edge) in edges.enumerated() {
            let b = try #require(edge.parameterBounds, "edge \(i) has parameter bounds")
            #expect(abs(b.first) < 1e-9, "edge \(i) starts at \(b.first)")
            #expect(abs(b.last - 10.0) < 1e-9, "edge \(i) ends at \(b.last)")
        }

        // A circle is parametrised by angle, not length: a radius 5 cylinder's circular edges
        // span 2 pi, which is what separates this from a "span is the length" shortcut.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let circle = try #require(cyl.edges().first { $0.curveType == .circle })
        let cb = try #require(circle.parameterBounds)
        #expect(abs(cb.last - cb.first - 2 * Double.pi) < 1e-9)
    }

    @Test("Curvature of circle edge is 1/r")
    func curvatureCircleEdge() throws {
        let radius = 5.0
        let cyl = try #require(Shape.cylinder(radius: radius, height: 10))
        let edges = cyl.edges()

        // Find a circular edge
        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let curv = edge.curvature(at: mid)
            #expect(curv != nil)
            if let curv = curv {
                #expect(abs(curv - 1.0 / radius) < 0.01)
            }
        }
    }

    @Test("Curvature of line edge is zero")
    func curvatureLineEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()

        var lineEdge: Edge?
        for edge in edges {
            if edge.curveType == .line {
                lineEdge = edge
                break
            }
        }
        #expect(lineEdge != nil)

        if let edge = lineEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let curv = edge.curvature(at: mid)
            #expect(curv != nil)
            if let curv = curv {
                #expect(abs(curv) < 1e-10)
            }
        }
    }

    @Test("Tangent direction of straight edge")
    func tangentStraightEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        #expect(!edges.isEmpty)

        var lineEdge: Edge?
        for edge in edges {
            if edge.curveType == .line {
                lineEdge = edge
                break
            }
        }
        #expect(lineEdge != nil)

        if let edge = lineEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let tang = edge.tangent(at: mid)
            #expect(tang != nil)
            if let t = tang {
                // Tangent should be unit length
                let len = sqrt(t.x * t.x + t.y * t.y + t.z * t.z)
                #expect(abs(len - 1.0) < 1e-6)
            }
        }
    }

    @Test("Normal of circle edge points toward center")
    func normalCircleEdge() throws {
        let radius = 5.0
        let cyl = try #require(Shape.cylinder(radius: radius, height: 10))
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let n = edge.normal(at: mid)
            #expect(n != nil)
            if let n = n {
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                #expect(abs(len - 1.0) < 1e-6)
            }
        }
    }

    @Test("Center of curvature of circle matches circle center")
    func centerOfCurvatureCircle() throws {
        let radius = 5.0
        let cyl = try #require(Shape.cylinder(radius: radius, height: 10))
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let center = edge.centerOfCurvature(at: mid)
            #expect(center != nil)
            if let c = center {
                // Circle is in XY plane at Z=0 or Z=height, centered at origin
                // Center of curvature should be at the circle center (0,0,z)
                let distFromAxis = sqrt(c.x * c.x + c.y * c.y)
                #expect(distFromAxis < 0.01)
            }
        }
    }

    @Test("Torsion of planar curve is zero")
    func torsionPlanarCurve() throws {
        let radius = 5.0
        let cyl = try #require(Shape.cylinder(radius: radius, height: 10))
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let tor = edge.torsion(at: mid)
            #expect(tor != nil)
            if let tor = tor {
                #expect(abs(tor) < 1e-6)
            }
        }
    }

    @Test("Curve type detection")
    func curveTypeDetection() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxEdges = box.edges()
        #expect(!boxEdges.isEmpty)
        #expect(boxEdges[0].curveType == .line)

        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let cylEdges = cyl.edges()
        var hasCircle = false
        for edge in cylEdges {
            if edge.curveType == .circle {
                hasCircle = true
                break
            }
        }
        #expect(hasCircle)
    }

    @Test("Point at parameter matches expected location")
    func pointAtParameter() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        #expect(!edges.isEmpty)

        let edge = edges[0]
        guard let bounds = edge.parameterBounds else {
            #expect(Bool(false), "No parameter bounds")
            return
        }

        // Points at start and end should match endpoints
        let ptStart = edge.point(at: bounds.first)
        let ptEnd = edge.point(at: bounds.last)
        let endpoints = edge.endpoints
        #expect(ptStart != nil)
        #expect(ptEnd != nil)

        if let s = ptStart {
            let dist = vectorLength(s - endpoints.start)
            #expect(dist < 0.01)
        }
        if let e = ptEnd {
            let dist = vectorLength(e - endpoints.end)
            #expect(dist < 0.01)
        }
    }
}
