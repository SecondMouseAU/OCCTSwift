import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.142 / #72 Phase 2: ConstructionEntity recipes

@Suite("v0.142 ConstructionPlane resolution")
struct ConstructionPlaneTests {
    /// Finds the index of the first vertex in `graph` within `tolerance` of the origin, or nil
    /// if none exists. Shared by the two fallback fixtures below (cone-apex, sphere-center),
    /// which each searched for their target placeholder vertex with an identical inline loop
    /// that had drifted to two different tolerances (1e-6 vs 1e-9) despite every surrounding
    /// assertion at both call sites checking against 1e-6 -- 1e-6 is what's kept here (#1251).
    private func firstVertexAtOrigin(in graph: BRepGraph, tolerance: Double = 1e-6) -> Int? {
        for i in 0..<graph.vertexCount {
            let p = graph.vertexPoint(i)
            if abs(p.x) < tolerance, abs(p.y) < tolerance, abs(p.z) < tolerance {
                return i
            }
        }
        return nil
    }

    @Test("Absolute plane resolves to specified origin+normal")
    func absolutePlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1))
        switch graph.resolve(plane) {
        case .success(let p):
            #expect(p.origin == SIMD3(1, 2, 3))
            #expect(abs(p.zAxis.z - 1.0) < 1e-9)
        case .failure(let e): Issue.record("failed: \(e)")
        }
    }

    @Test("offsetFromFace produces a parallel plane at the offset")
    func offsetFromFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        // Pick any face; the exact normal is produced from the UV midpoint.
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let plane = ConstructionPlane.offsetFromFace(face: faceRef, distance: 5.0)
        switch graph.resolve(plane) {
        case .success(let p):
            // The face normal is unit length; offset 5.0 along it produces a
            // plane whose origin is 5.0 away (in the plane normal direction) from
            // the face centroid.
            #expect(simd_length(p.zAxis) > 0.99 && simd_length(p.zAxis) < 1.01)
        case .failure(let e): Issue.record("failed: \(e)")
        }
    }

    @Test("byThreePoints returns a valid plane through three vertices")
    func byThreePoints() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v0 = TopologyRef.literal(.init(kind: .vertex, index: 0))
        let v1 = TopologyRef.literal(.init(kind: .vertex, index: 1))
        let v2 = TopologyRef.literal(.init(kind: .vertex, index: 2))
        let plane = ConstructionPlane.byThreePoints(v0, v1, v2)
        switch graph.resolve(plane) {
        case .success(let p):
            #expect(simd_length(p.zAxis) > 0.99)
        case .failure: Issue.record("byThreePoints failed")
        }
    }

    @Test("byThreePoints on collinear points fails with degenerate")
    func collinearPointsDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        // Three references to the same vertex → collinear (all zero vector).
        let plane = ConstructionPlane.byThreePoints(v, v, v)
        if case .failure(.degenerate) = graph.resolve(plane) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test("normalToEdge produces plane perpendicular to edge tangent")
    func normalToEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: 0))
        let plane = ConstructionPlane.normalToEdge(edge: edgeRef, t: 0.5)
        switch graph.resolve(plane) {
        case .success(let p):
            // The plane normal is the edge tangent, so non-zero unit vector.
            #expect(simd_length(p.zAxis) > 0.99 && simd_length(p.zAxis) < 1.01)
        case .failure(let e): Issue.record("failed: \(e)")
        }
    }

    @Test(
        "tangentToFace on a cylinder uses the vertex's own local normal, not the face UV midpoint (#879)"
    )
    func tangentToFaceCylinderLocalNormal() {
        // A radius-5 cylinder's lateral face is periodic in U; its seam runs
        // through both circle vertices at u=0 (local +X, radial normal (1,0,0)).
        // The face's own UV midpoint sits at u=π (local -X, radial normal
        // (-1,0,0)), the far side of the cylinder. Before #879, tangentToFace
        // returned that antiparallel UV-midpoint normal instead of the normal at
        // the requested vertex.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 1))
        // The lateral face's seam runs through TWO structurally symmetric vertices at u=0
        // (top z=10, bottom z=0), read the actual z of vertex 1 rather than assuming which
        // one it is: vertex enumeration order isn't guaranteed stable across an OCCT kernel
        // rebuild or platform (CLAUDE.md Test Conventions; #897 review, third pass), the
        // property under test (local normal follows the vertex, not the UV midpoint) holds
        // at either seam vertex.
        let expectedZ = graph.vertexPoint(1).z
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            #expect(abs(p.origin.x - 5) < 1e-6)
            #expect(abs(p.origin.z - expectedZ) < 1e-6)
            // The correct local normal points radially outward (+X); the old,
            // broken UV-midpoint normal pointed radially inward (-X) instead.
            #expect(p.zAxis.x > 0.99)
        case .failure(let e): Issue.record("tangentToFace failed: \(e)")
        }
    }

    @Test(
        "tangentToFace at a cone apex falls back to the UV-midpoint normal instead of failing (PR #897 review, 3rd pass)"
    )
    func tangentToFaceConeApexFallsBackToNormal() {
        // A cone whose apex sits at the BASE (bottomRadius: 0) puts the apex vertex
        // at v=0 exactly on the lateral face's own parametrization -- a genuine
        // GeomLProp_SLProps normal singularity (the two tangent directions
        // coincide there, not merely shrink; see docs/reference/Face.md's `normal`
        // entry and Issue401's SurfaceNormalParityTests.coneApexIsUndefinedInBoth).
        // Before this fix, resolveFaceNormal had no fallback, so tangentToFace at
        // this real vertex on real topology failed with .missingGeometry --
        // regressing the pre-#879 always-succeeds-for-any-uvBounds-face behavior.
        //
        // (A sphere's pole is NOT an equivalent reproducer here: OCCT's own
        // higher-derivative resolution keeps the normal defined there --
        // SurfaceNormalParityTests.spherePoleStillHasANormal already pins that.)
        guard let cone = Shape.cone(bottomRadius: 0, topRadius: 5, height: 10),
            let graph = BRepGraph(shape: cone)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))

        // Sanity: find the apex vertex (at the origin) and confirm the fixture
        // really does hit the singularity this test claims to exercise.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first else {
            Issue.record("face0 unavailable")
            return
        }
        guard let apexIndex = firstVertexAtOrigin(in: graph) else {
            Issue.record("no vertex at the cone apex")
            return
        }
        guard let projection = face.project(point: SIMD3(0, 0, 0)) else {
            Issue.record("apex projection failed")
            return
        }
        #expect(
            face.normal(atU: projection.u, v: projection.v) == nil,
            "fixture should hit a genuine normal singularity")
        // This fixture exercises resolveFaceNormal's "projection succeeds, normal-at-that-uv
        // fails" branch specifically -- NOT the "projection itself fails" branch (see
        // projectedNormalWhenProjectionItselfFails below for that one). The apex vertex already
        // lies exactly on the face, so `projection.point` and the raw input point coincide here,
        // which is why this test alone can't distinguish the two fallback branches (#897 review,
        // second xhigh pass, finding 3).
        guard let expectedFallback = face.uvMidpointNormal() else {
            Issue.record("uvMidpointNormal unavailable")
            return
        }

        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: apexIndex))
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            #expect(abs(p.origin.x) < 1e-6)
            #expect(abs(p.origin.y) < 1e-6)
            #expect(abs(p.origin.z) < 1e-6)
            #expect(abs(simd_length(p.zAxis) - 1.0) < 1e-6)
            // Compare against the actual UV-midpoint normal value, not just unit length, so a
            // wrong (but still unit-length) fallback normal would be caught (#897 review, second
            // xhigh pass, finding 3).
            #expect(simd_length(p.zAxis - simd_normalize(expectedFallback)) < 1e-6)
        case .failure(let e):
            Issue.record("tangentToFace failed at the cone apex: \(e)")
        }
    }

    @Test(
        "tangentToFace falls back to the UV-midpoint sample, with an on-face origin, when Face.project(point:) itself fails to converge (PR #897 review, second xhigh pass, findings 1 + 3)"
    )
    func tangentToFaceProjectionItselfFailsFallsBackToOnFaceOrigin() {
        // A sphere's own center is equidistant from its ENTIRE surface, so
        // GeomAPI_ProjectPointOnSurf's gradient search has no unique stationary point to
        // converge to -- Face.project(point:) genuinely returns nil here (measured directly,
        // not assumed), unlike the cone-apex fixture above, where `project()` itself succeeds
        // and only the subsequent `normal(atU:v:)` lookup fails. This is the ONLY branch of
        // resolveFaceNormal's 3-way fallback the rest of this suite doesn't otherwise exercise.
        //
        // A sphere has no real vertex at its own center, so a standalone vertex shape is added
        // there and the two are grouped in a compound -- `at` resolving to a vertex from a
        // DIFFERENT shape than `face` is the same "genuine misuse" pattern
        // `tangentToFaceOriginIsOnFaceNotRawPoint` below already uses, here specifically to
        // place a real topological vertex exactly at the sphere's center.
        guard let sph = Shape.sphere(radius: 5),
            let centerVertex = Shape.vertex(at: SIMD3(0, 0, 0)),
            let compound = Shape.compound([sph, centerVertex]),
            let graph = BRepGraph(shape: compound)
        else {
            Issue.record("setup failed")
            return
        }

        // Sphere added first -- confirm face 0 of the compound really is the sphere, not
        // assumed.
        guard let faceShape = graph.shape(nodeKind: .face, nodeIndex: 0),
            let face = faceShape.faces().first, face.surfaceType == .sphere
        else {
            Issue.record("face 0 of the compound is not the sphere")
            return
        }
        // Sanity: confirm the fixture really does hit the branch this test claims to exercise.
        #expect(face.project(point: SIMD3(0, 0, 0)) == nil, "fixture should fail to project")
        guard let (expectedFallbackPoint, expectedFallbackNormal) = face.uvMidpointSample() else {
            Issue.record("uvMidpointSample unavailable")
            return
        }

        // The standalone vertex, wherever BRepGraph placed it -- found by position, not assumed
        // to be a specific index (CLAUDE.md Test Conventions).
        guard let centerIndex = firstVertexAtOrigin(in: graph) else {
            Issue.record("no vertex at the sphere center")
            return
        }

        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: centerIndex))
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            // The origin must be the UV-midpoint sample's own point -- a genuine on-face
            // location -- NOT the raw sphere-center input point, which is nowhere near the
            // face's surface (distance = the sphere's own radius, 5).
            #expect(simd_length(p.origin - expectedFallbackPoint) < 1e-6)
            #expect(simd_length(p.origin) > 1.0, "origin should not be the raw center point")
            #expect(simd_length(p.zAxis - simd_normalize(expectedFallbackNormal)) < 1e-6)
        case .failure(let e):
            Issue.record("tangentToFace failed: \(e)")
        }
    }

    @Test(
        "tangentToFace: Placement.origin is the actual on-face point, not `at`'s raw position, when `at` doesn't lie on `face` (PR #897 review, finding 2)"
    )
    func tangentToFaceOriginIsOnFaceNotRawPoint() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let (samplePoint, sampleNormal) = face.uvMidpointSample()
        else {
            Issue.record("face0 unavailable")
            return
        }
        let faceNormalUnit = simd_normalize(sampleNormal)

        // Find a vertex that does NOT lie on face 0 -- the genuine misuse scenario finding 2
        // describes, where `at` doesn't actually reference a point on `face`.
        var offFaceVertexIndex: Int?
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let p = SIMD3(raw.x, raw.y, raw.z)
            if abs(simd_dot(p - samplePoint, faceNormalUnit)) > 1e-3 {
                offFaceVertexIndex = vertexIndex
                break
            }
        }
        guard let offFaceVertexIndex else {
            Issue.record("no off-face vertex found")
            return
        }
        let rawTuple = graph.vertexPoint(offFaceVertexIndex)
        let rawPoint = SIMD3(rawTuple.x, rawTuple.y, rawTuple.z)
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: offFaceVertexIndex))
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            // The origin must lie ON face 0's plane, not at the raw off-face vertex position.
            #expect(abs(simd_dot(p.origin - samplePoint, faceNormalUnit)) < 1e-6)
            #expect(
                simd_length(p.origin - rawPoint) > 1e-3,
                "origin should differ from the raw off-face point")
        case .failure(let e):
            Issue.record("tangentToFace failed: \(e)")
        }
    }
}
