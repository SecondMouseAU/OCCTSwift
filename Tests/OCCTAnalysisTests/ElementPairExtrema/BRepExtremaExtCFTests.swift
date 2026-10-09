import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values probed on the pinned kernel: Scripts/repro/766-brepextrema-extcf/transcript.txt.
//
// Before #766's execution pass neither test could fail. Each looped over edge/face pairs, set a
// `foundResult` flag it never read, and asserted only `result.distance >= 0` on whatever it
// found, so a bridge returning nil for every pair passed both ("May or may not find result
// depending on geometry"). Both now assert that a result exists and pin what it measures.
@Suite("BRepExtrema_ExtCF Tests")
struct BRepExtremaExtCFTests {
    @Test("Edge to sphere face distance")
    func edgeToSphereFace() throws {
        // The 20x1x1 box is centred on the origin, so its eight short edges sit at x = +/-10,
        // each with its nearest point sqrt(10^2 + 0.5^2) from the centre of the radius-3 sphere,
        // and its four long edges run through the sphere, crossing its face.
        guard let box = Shape.box(width: 20, height: 1, depth: 1),
            let sphere = Shape.sphere(radius: 3)
        else {
            Issue.record("could not build the box and sphere")
            return
        }
        let edgeCount = box.edges().count
        #expect(edgeCount == 12)

        let outside = (100.25).squareRoot() - 3
        var farEdges = 0
        var crossingEdges = 0
        for i in 0..<edgeCount {
            guard let result = box.edgeFaceExtrema(edgeIndex: i, other: sphere, faceIndex: 0)
            else {
                Issue.record("no edge-face extrema for edge \(i) against the sphere face")
                continue
            }
            #expect(!result.isParallel, "edge \(i)")
            if abs(result.distance - outside) < 1e-9 {
                farEdges += 1
                #expect(result.solutionCount == 2, "edge \(i)")
                #expect(abs(abs(result.pointOnEdge.x) - 10) < 1e-12, "edge \(i)")
            } else if abs(result.distance) < 1e-9 {
                crossingEdges += 1
                #expect(result.solutionCount == 4, "edge \(i)")
                // The crossing point lies on the sphere: |p| = 3.
                #expect(abs(simd_length(result.pointOnFace) - 3) < 1e-9, "edge \(i)")
            } else {
                Issue.record("edge \(i): unexpected distance \(result.distance)")
            }
        }
        #expect(farEdges == 8)
        #expect(crossingEdges == 4)
    }

    @Test("Box edge to box face")
    func boxEdgeToBoxFace() throws {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(0, 0, 20), width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build the two boxes")
            return
        }

        // Walk the first four edges against the first four faces, as before, and keep the first
        // non-parallel pair with an extremum. Most of these pairs are parallel (an axis-aligned
        // edge against an axis-aligned face), and the pinned kernel finds exactly one kind of
        // answer among the rest: the edge's midpoint (-5, 0, +/-5) against box2's corner
        // (0, 0, 20).
        var found: Shape.EdgeFaceExtrema?
        let edgeCount = box1.edges().count
        let faceCount = box2.faces().count
        search: for i in 0..<min(edgeCount, 4) {
            for j in 0..<min(faceCount, 4) {
                if let result = box1.edgeFaceExtrema(edgeIndex: i, other: box2, faceIndex: j),
                    !result.isParallel, result.solutionCount > 0
                {
                    found = result
                    break search
                }
            }
        }
        guard let result = found else {
            Issue.record("no non-parallel edge-face extremum among the first 4x4 pairs")
            return
        }
        #expect(result.solutionCount == 1)
        #expect(abs(result.distance - (250.0).squareRoot()) < 1e-9, "got \(result.distance)")
        #expect(simd_length(result.pointOnEdge - SIMD3(-5, 0, 5)) < 1e-6, "got \(result.pointOnEdge)")
        #expect(simd_length(result.pointOnFace - SIMD3(0, 0, 20)) < 1e-9, "got \(result.pointOnFace)")
    }
}
