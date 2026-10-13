import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.126.0 Tests

/// The box face lying in the x = -5 plane (outward normal -X).
private func faceAtMinX(_ box: Shape) -> Shape? {
    box.subShapes(ofType: .face).first { ($0.boundingBox?.max.x ?? 0) < -4.9 }
}

/// A 10 x 10 planar face with its NaturalRestriction flag set.
///
/// The flag has no setter, so it is written through the BREP text: the first number on a face
/// record is that flag.
private func faceWithNaturalRestriction() -> Shape? {
    guard let face = Shape.faceFromPlane(uBounds: 0...10, vBounds: 0...10),
        let brep = face.toBREPString()
    else { return nil }
    let edited = brep.replacingOccurrences(of: "Fa\n0  1e-07", with: "Fa\n1  1e-07")
    guard edited != brep else { return nil }
    return Shape.fromBREPString(edited)
}

@Suite("v0.126.0, BRep_Tool completions")
struct BRepToolCompletionsTests {
    @Test("CurveOnSurface returns pcurve of edge on face")
    func curveOnSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)  // faces
            let edges = box.subShapes(ofType: .edge)  // edges
            if faces.count > 0 && edges.count > 0 {
                // Try each edge-face pair until we find one with a pcurve
                var found = false
                for face in faces {
                    for edge in edges {
                        if let result = Shape.curveOnSurface(edge: edge, face: face) {
                            #expect(result.first < result.last || result.first == result.last)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                // Box edges always have pcurves on their adjacent faces
                #expect(found)
            }
        }
    }

    @Test("HasContinuity and Continuity between faces")
    func continuity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        let f0 = try #require(faceAtMinX(box))
        let f0Edges = f0.subShapes(ofType: .edge)

        // The x = -5 face meets four neighbours along one edge each. A box join is sharp: no
        // regularity is stored (false) and the continuity reads C0 (ordinal 0).
        var joins = 0
        for face in faces where !face.isPartner(with: f0) {
            let shared = face.subShapes(ofType: .edge).filter { e in
                f0Edges.contains { $0.isPartner(with: e) }
            }
            // The opposite face shares nothing with it; each of the four neighbours one edge.
            #expect(shared.count <= 1)
            for edge in shared {
                joins += 1
                #expect(!Shape.hasContinuity(edge: edge, face1: f0, face2: face))
                #expect(Shape.continuity(edge: edge, face1: f0, face2: face) == 0)
            }
        }
        #expect(joins == 4)

        // A filleted box stores G1 (ordinal 1) across every blend seam: 48 shared edges, all of it.
        let filleted = try #require(box.filleted(radius: 1.0))
        let blended = filleted.subShapes(ofType: .face)
        var seams = 0
        for (i, a) in blended.enumerated() {
            let aEdges = a.subShapes(ofType: .edge)
            for b in blended[(i + 1)...] {
                for edge in b.subShapes(ofType: .edge)
                where aEdges.contains(where: {
                    $0.isPartner(with: edge)
                }) {
                    seams += 1
                    #expect(Shape.hasContinuity(edge: edge, face1: a, face2: b))
                    #expect(Shape.continuity(edge: edge, face1: a, face2: b) == 1)
                }
            }
        }
        #expect(seams == 48)
    }

    @Test("HasAnyContinuity on filleted edge")
    func hasAnyContinuity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Sharp edges carry no regularity at all.
        let sharp = box.subShapes(ofType: .edge)
        #expect(sharp.count == 12)
        #expect(sharp.allSatisfy { !Shape.hasAnyContinuity(edge: $0) })
        #expect(sharp.allSatisfy { Shape.maxContinuity(edge: $0) == 0 })

        // The filleted box has 56 edges, 48 of them blend seams stored as G1 (ordinal 1).
        let filleted = try #require(box.filleted(radius: 1.0))
        let edges = filleted.subShapes(ofType: .edge)
        #expect(edges.count == 56)
        let tangent = edges.filter { Shape.hasAnyContinuity(edge: $0) }
        #expect(tangent.count == 48)
        #expect(tangent.allSatisfy { Shape.maxContinuity(edge: $0) == 1 })
    }

    @Test("Degenerated returns false for box edge")
    func degenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                #expect(!Shape.isDegenerated(edge: edges[0]))
            }
        }
    }

    @Test("NaturalRestriction on sphere face")
    func naturalRestriction() throws {
        // Primitives and faces made from bounds do not carry the flag.
        let sphere = try #require(Shape.sphere(radius: 5))
        let faces = sphere.subShapes(ofType: .face)
        #expect(faces.count == 1)
        #expect(faces.allSatisfy { !Shape.naturalRestriction(face: $0) })

        // A face whose record has the flag set reads true, so the false above is a reading.
        let flagged = try #require(faceWithNaturalRestriction())
        #expect(Shape.naturalRestriction(face: flagged))
    }

    @Test("RangeOnFace returns valid range")
    func rangeOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                // Try to find an edge that belongs to the face
                for face in faces {
                    for edge in edges {
                        if let range = Shape.rangeOnFace(edge: edge, face: face) {
                            #expect(range.first <= range.last || range.first == range.last)
                            return
                        }
                    }
                }
            }
        }
    }

    @Test("ParametersOnFace returns UV for vertex on box face")
    func parametersOnFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(faceAtMinX(box))
        // The x = -5 face is parametrised u along +Z from z = -5 and v along -Y from y = -5
        // (measured on kernel.6), so its four corners sit on u in {0, 10}, v in {0, -10}.
        let corners: [(point: SIMD3<Double>, uv: SIMD2<Double>)] = [
            (SIMD3(-5, -5, -5), SIMD2(0, 0)),
            (SIMD3(-5, -5, 5), SIMD2(10, 0)),
            (SIMD3(-5, 5, -5), SIMD2(0, -10)),
            (SIMD3(-5, 5, 5), SIMD2(10, -10)),
        ]
        var onFace = 0
        for vertex in box.subShapes(ofType: .vertex) {
            // A vertex shape's vertices() is the one-element list holding its own point.
            let point = try #require(vertex.vertices().first)
            let uv = Shape.parametersOnFace(vertex: vertex, face: face)
            if let corner = corners.first(where: { vectorLength($0.point - point) < 1e-9 }) {
                onFace += 1
                let found = try #require(uv)
                #expect(abs(found.u - corner.uv.x) < 1e-9)
                #expect(abs(found.v - corner.uv.y) < 1e-9)
            } else {
                // A vertex of the opposite face is not on this one.
                #expect(uv == nil)
            }
        }
        #expect(onFace == 4)
    }

    @Test("UVPoints returns valid UV endpoints for edge on face")
    func uvPoints() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(faceAtMinX(box))
        // The four boundary edges of the x = -5 face, as (firstU, firstV, lastU, lastV). Edge
        // order is not a contract, so they are sorted before they are compared.
        let expected: [[Double]] = [
            [0, -10, 10, -10],
            [0, 0, 0, -10],
            [0, 0, 10, 0],
            [10, 0, 10, -10],
        ]
        var found: [[Double]] = []
        for edge in face.subShapes(ofType: .edge) {
            let uv = try #require(Shape.uvPoints(edge: edge, face: face))
            found.append([uv.firstU, uv.firstV, uv.lastU, uv.lastV])
        }
        found.sort { $0.lexicographicallyPrecedes($1) }
        #expect(found.count == 4)
        for (row, want) in zip(found, expected) {
            #expect(zip(row, want).allSatisfy { abs($0 - $1) < 1e-9 })
        }
    }

    @Test("MaxTolerance returns positive value")
    func maxTolerance() throws {
        // BRepPrimAPI builds every sub-shape at Precision::Confusion(), 1e-7.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(abs(box.maxTolerance(subShapeType: 6) - 1e-7) < 1e-12)  // edges
        #expect(abs(box.maxTolerance(subShapeType: 7) - 1e-7) < 1e-12)  // vertices
        #expect(abs(box.maxTolerance(subShapeType: 4) - 1e-7) < 1e-12)  // faces

        // Edges at 0.5, vertices and faces untouched: each type reads its own population.
        let loose = try #require(boxWithLooseEdges())
        #expect(abs(loose.maxTolerance(subShapeType: 6) - 0.5) < 1e-12)
        #expect(abs(loose.maxTolerance(subShapeType: 7) - 1e-7) < 1e-12)
        #expect(abs(loose.maxTolerance(subShapeType: 4) - 1e-7) < 1e-12)
    }
}
