import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Point Projection Tests (v0.18.0)

@Suite("Point Projection Tests")
struct PointProjectionTests {

    @Test("Project point onto box face")
    func projectPointOntoBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()

        // Find the top face (Z=5)
        var topFace: Face?
        for face in faces {
            if let n = face.normal, n.z > 0.9 {
                topFace = face
                break
            }
        }
        #expect(topFace != nil)

        if let face = topFace {
            // Project a point directly above the face center
            let proj = face.project(point: SIMD3(0, 0, 15))
            #expect(proj != nil)
            if let p = proj {
                #expect(abs(p.point.z - 5.0) < 0.01)
                #expect(abs(p.distance - 10.0) < 0.01)
            }
        }
    }

    @Test("Project point onto sphere face with UV")
    func projectPointOntoSphere() {
        let radius = 5.0
        let sphere = Shape.sphere(radius: radius)!
        let faces = sphere.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        // Project a point outside the sphere
        let proj = face.project(point: SIMD3(10, 0, 0))
        #expect(proj != nil)
        if let p = proj {
            #expect(abs(p.distance - 5.0) < 0.1)
            // Closest point should be on the sphere at (5,0,0)
            #expect(abs(p.point.x - 5.0) < 0.1)
            #expect(abs(p.point.y) < 0.1)
            #expect(abs(p.point.z) < 0.1)
        }
    }

    @Test("All projections returns results")
    func allProjections() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        // Find the top face
        var topFace: Face?
        for face in faces {
            if let n = face.normal, n.z > 0.9 {
                topFace = face
                break
            }
        }
        #expect(topFace != nil)

        if let face = topFace {
            // Project a point above the face - should get at least one result
            let projs = face.allProjections(of: SIMD3(0, 0, 15))
            #expect(!projs.isEmpty)
            if let first = projs.first {
                #expect(abs(first.distance - 10.0) < 0.1)
            }
        }
    }

    @Test("Project point onto straight edge")
    func projectPointOntoEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(!edges.isEmpty)

        // Find a line edge
        var lineEdge: Edge?
        for edge in edges {
            if edge.curveType == .line {
                lineEdge = edge
                break
            }
        }
        #expect(lineEdge != nil)

        if let edge = lineEdge {
            // Project a point near the midpoint of the edge
            let mid = edge.endpoints
            let midPt = (mid.start + mid.end) / 2.0
            let offset = midPt + SIMD3(1, 1, 1)  // offset from midpoint
            let proj = edge.project(point: offset)
            #expect(proj != nil)
            if let p = proj {
                #expect(p.distance > 0)
                #expect(p.distance < 3.0)  // should be reasonably close
            }
        }
    }

    @Test("Project point onto circular edge")
    func projectPointOntoCircularEdge() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
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
            // Get a point on the circle edge and offset it radially outward
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            guard let onCurve = edge.point(at: mid) else {
                #expect(Bool(false), "No point at param")
                return
            }
            // Offset radially outward by 3 units in XY plane
            let radialDir = SIMD3(onCurve.x, onCurve.y, 0.0)
            let radialLen = simd_length(radialDir)
            let offset =
                radialLen > 0.01
                ? onCurve + (radialDir / radialLen) * 3.0
                : onCurve + SIMD3(3, 0, 0)
            let proj = edge.project(point: offset)
            #expect(proj != nil)
            if let p = proj {
                #expect(abs(p.distance - 3.0) < 0.5)
            }
        }
    }
}
