import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.142 ConstructionPoint resolution")
struct ConstructionPointTests {
    @Test("atVertex returns the vertex's 3D point")
    func atVertex() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        switch graph.resolve(ConstructionPoint.atVertex(v)) {
        case .success(let p):
            // Box corner must be at (0, 0, 0) for some vertex or similar.
            #expect(abs(p.x) < 20 && abs(p.y) < 20 && abs(p.z) < 20)
        case .failure: Issue.record("atVertex failed")
        }
    }

    @Test("midpointOfEdge lies between endpoints")
    func midpointOfEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let edge = TopologyRef.literal(.init(kind: .edge, index: 0))
        switch graph.resolve(ConstructionPoint.midpointOfEdge(edge)) {
        case .success(let p):
            #expect(abs(p.x) < 20 && abs(p.y) < 20 && abs(p.z) < 20)
        case .failure: Issue.record("midpointOfEdge failed")
        }
    }

    @Test("intersectionOfAxisAndPlane for axis parallel to plane fails")
    func parallelIntersectionFails() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: SIMD3(0, 0, 5), direction: SIMD3(1, 0, 0))
        if case .failure(.degenerate) = graph.resolve(
            ConstructionPoint.intersectionOfAxisAndPlane(axis, plane))
        {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test("intersectionOfAxisAndPlane computes correct intersection")
    func intersectionCorrect() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: SIMD3(3, 4, 0), direction: SIMD3(0, 0, 1))
        switch graph.resolve(ConstructionPoint.intersectionOfAxisAndPlane(axis, plane)) {
        case .success(let p):
            #expect(abs(p.x - 3) < 1e-9)
            #expect(abs(p.y - 4) < 1e-9)
            #expect(abs(p.z - 10) < 1e-9)
        case .failure: Issue.record("intersection failed")
        }
    }

    @Test("centroidOfFace on a cylinder matches the real area centroid, not the UV midpoint (#884)")
    func centroidOfFaceCylinderSurfaceInertia() {
        // A radius-5, height-10 cylinder's lateral face has its true area centroid
        // on the cylinder's own axis (x=y=0, z=5), the UV-midpoint approximation
        // instead sits a full radius off-axis, on the surface itself.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        switch graph.resolve(ConstructionPoint.centroidOfFace(faceRef)) {
        case .success(let p):
            let distanceFromAxis = (p.x * p.x + p.y * p.y).squareRoot()
            #expect(distanceFromAxis < 1e-6)
            #expect(abs(p.z - 5) < 1e-6)
        case .failure(let e): Issue.record("centroidOfFace failed: \(e)")
        }
    }

    @Test(
        "centroidOfFace on a genuinely zero-area face fails with .degenerate, not a fabricated point (PR #897 review)"
    )
    func centroidOfFaceZeroAreaDegenerate() {
        // A 2-vertex "polygon" wire is a degenerate zero-area loop, the same fixture
        // Issue234DegenerateHoleTests uses for a degenerate hole, here used as the base
        // face itself. Its surfaceInertia.centerOfMass is nil because BRepGProp_Sinert
        // measures its area as exactly 0. The old UV-midpoint-based centroidOfFace always
        // succeeded for any face with uvBounds; resolveFaceCentroid must decline instead.
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(10, 0, 0)
        guard let wire = Wire.polygon3D([p0, p1], closed: true),
            let degenerateFace = Shape.face(from: wire, planar: true),
            let graph = BRepGraph(shape: degenerateFace)
        else {
            Issue.record("setup")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))

        // Sanity: the fixture really is zero-area, so this exercises the branch it claims to.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first else {
            Issue.record("fixture face unavailable")
            return
        }
        #expect(face.surfaceInertia.centerOfMass == nil, "fixture should be zero-area")

        if case .failure(.degenerate(let message)) =
            graph.resolve(ConstructionPoint.centroidOfFace(faceRef))
        {
            #expect(message == "face area is zero, or its inertia could not be computed")
        } else {
            Issue.record(
                "expected .degenerate(\"face area is zero, or its inertia could not be computed\")")
        }
    }

    @Test(
        "atEdgeParameter matches Edge.parameterByLinearFraction(_:) + point(at:) for the same edge and t"
    )
    func atEdgeParameterMatchesFraction() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        // Edge enumeration order isn't guaranteed stable across an OCCT kernel rebuild
        // or platform, iterate every edge rather than hardcoding index 0 (CLAUDE.md
        // Test Conventions; PR #897 review, finding 12).
        #expect(graph.edgeCount > 0)
        for edgeIndex in 0..<graph.edgeCount {
            guard let edge = graph.shape(nodeKind: .edge, nodeIndex: edgeIndex)?.edges().first,
                let param = edge.parameterByLinearFraction(0.25),
                let expected = edge.point(at: param)
            else {
                Issue.record("edge \(edgeIndex) unavailable")
                continue
            }
            let edgeRef = TopologyRef.literal(.init(kind: .edge, index: edgeIndex))
            switch graph.resolve(ConstructionPoint.atEdgeParameter(edge: edgeRef, t: 0.25)) {
            case .success(let p):
                #expect(simd_length(p - expected) < 1e-9)
            case .failure(let e): Issue.record("atEdgeParameter failed at edge \(edgeIndex): \(e)")
            }
        }
    }
}
