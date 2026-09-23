import Testing
import simd

@testable import OCCTSwift

// MARK: - Feature Recognition Tests

@Suite("Feature Recognition, AAG")
struct AAGTests {
    @Test("Box AAG has 6 nodes and 12 edges")
    func boxAAG() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        #expect(aag.nodes.count == 6)
        // A box has 12 edges connecting 6 faces
        #expect(aag.edges.count == 12)
    }

    @Test("AAG nodes have valid normals")
    func aagNodeNormals() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        for node in aag.nodes {
            #expect(node.normal != nil)
            #expect(node.isPlanar)
        }
    }

    @Test("AAG neighbors returns correct count")
    func aagNeighbors() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        // Each face of a box touches 4 other faces
        for i in 0..<6 {
            let nbrs = aag.neighbors(of: i)
            #expect(nbrs.count == 4)
        }
    }

    @Test("AAG edge between adjacent faces exists")
    func aagEdgeBetween() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let aag = box.buildAAG()
        let nbrs = aag.neighbors(of: 0)
        guard let first = nbrs.first else {
            Issue.record("Face 0 should have neighbors")
            return
        }
        let edge = aag.edge(between: 0, and: first)
        #expect(edge != nil)
        #expect(edge?.sharedEdgeCount ?? 0 > 0)
    }

    @Test("Box with pocket detects pocket via AAG")
    func detectPocket() {
        // #703: `Shape.box(width:height:depth:)` is centred at the origin (`OCCTShapeCreateBox`),
        // so a 20mm box spans -10...10 on every axis. The pocket tool has to actually overlap that
        // range to remove real material -- this fixture used to place it at `origin: SIMD3(5, 5,
        // 10)`, whose z range (10...25) only TOUCHES the box's top face at z=10 with zero volume
        // in common (measured: `result.volume == box.volume`, unchanged), so it cut nothing at
        // all. The one "pocket" `detectPocketsAAG()` used to report there was entirely
        // `OCCTEdgeGetConvexity`'s own face1/face2 order-dependence -- the same false positive
        // #703 measured on a plain, uncut box -- not a real feature of this shape. Centring the
        // tool's footprint under the box and starting its z range below the box's own top (here,
        // 0...15, cutting through at z=10 down to a floor at z=0) gives an actual 10mm-deep pocket.
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let pocket = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15)!
        // #720 review of #703, finding 5: `(result.volume ?? 0) < (box.volume ?? 0)` would still
        // pass if EITHER volume computation silently failed and returned nil: 0 < 0 is false,
        // but 0 < someNil-coerced-to-0 reads as "no material removed", not "the fixture is
        // untrustworthy", and a genuinely negative or nil `box.volume` would pass the comparison
        // for the wrong reason. Unwrapping both and failing loudly if either is nil, matching this
        // suite's own `guard let ..., let v0 = shape.volume else { #expect(Bool(false), ...) }`
        // idiom (see e.g. Issue532CylindricalHolePartSelectionTests), means the assertion can only
        // pass because material was actually removed.
        guard let result = box.subtracting(pocket) else {
            Issue.record("Boolean subtraction failed")
            return
        }
        guard let resultVolume = result.volume, let boxVolume = box.volume else {
            #expect(false, "volume computation failed; fixture proves nothing")
            return
        }
        #expect(
            resultVolume < boxVolume,
            "pocket tool must actually remove material, or this fixture proves nothing")
        let pockets = result.detectPocketsAAG()
        // Should detect at least one pocket
        #expect(pockets.count >= 1)
        if let p = pockets.first {
            #expect(p.depth > 0)
            #expect(!p.wallFaceIndices.isEmpty)
        }
    }

    @Test("Convex and concave neighbors on filleted box")
    func convexConcaveNeighbors() {
        // #766: this test used to end in `#expect(hasAnyNeighbors || aag.nodes.count > 6)`, which
        // the node count alone satisfies, so no convexity defect could fail it. The values below
        // are the kernel's own (Scripts/repro/766-modeling-aag): the plain box's 12 adjacent
        // pairs are all convex, and the filleted box has 26 faces (6 + 12 fillet + 8 corner)
        // and 48 adjacent pairs, every one tangential, so no face has a convex or a concave
        // neighbor at all.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let plain = box.buildAAG()
        #expect(plain.edges.filter { $0.convexity == .convex }.count == 12)
        #expect((0..<plain.nodes.count).allSatisfy { plain.convexNeighbors(of: $0).count == 4 })

        guard let filleted = box.filleted(radius: 1) else {
            Issue.record("Fillet failed")
            return
        }
        let aag = filleted.buildAAG()
        #expect(aag.nodes.count == 26)
        #expect(aag.edges.count == 48)
        #expect(aag.edges.allSatisfy { $0.convexity == .smooth })
        #expect((0..<aag.nodes.count).allSatisfy { aag.convexNeighbors(of: $0).isEmpty })
        #expect((0..<aag.nodes.count).allSatisfy { aag.concaveNeighbors(of: $0).isEmpty })
    }
}
