import Testing

@testable import OCCTSwift

// MARK: - Feature Recognition Tests

@Suite("Feature Recognition, AAG")
struct AAGTests {
    @Test("Box AAG has 6 nodes and 12 edges")
    func boxAAG() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let aag = box.buildAAG()
        #expect(aag.nodes.count == 6)
        // A box has 12 edges connecting 6 faces
        #expect(aag.edges.count == 12)
    }

    // #3332: the old loop asserted `node.normal != nil` and `isPlanar`, which a normal of
    // (0, 0, 0) satisfies. The six face normals of an axis-aligned box are exactly the six
    // signed unit axes (measured on the pinned kernel: -x, +x, -y, +y, -z, +z for faces 0...5),
    // each a unit vector, and only the +z / -z faces are horizontal (upward / downward) with the
    // other four vertical.
    @Test("AAG nodes have valid normals")
    func aagNodeNormals() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let aag = box.buildAAG()
        #expect(aag.nodes.count == 6)

        let boxFaces = box.faces()
        var axes = Set<[Int]>()
        for node in aag.nodes {
            let n = try #require(node.normal)
            #expect(abs(n.x * n.x + n.y * n.y + n.z * n.z - 1) < 1e-9)
            #expect(node.isPlanar)
            // Each normal is a signed unit axis: one component +-1, the others 0.
            let rounded = [Int(n.x.rounded()), Int(n.y.rounded()), Int(n.z.rounded())]
            #expect(abs(n.x - Double(rounded[0])) < 1e-9)
            #expect(abs(n.y - Double(rounded[1])) < 1e-9)
            #expect(abs(n.z - Double(rounded[2])) < 1e-9)
            axes.insert(rounded)
            // Outward: the normal points the way the face's own centre lies from the box's.
            let face = try #require(
                boxFaces.indices.contains(node.faceIndex) ? boxFaces[node.faceIndex] : nil)
            let faceShape = try #require(Shape.fromFace(face))
            let faceCentre = try #require(faceShape.center)
            #expect(n.x * faceCentre.x + n.y * faceCentre.y + n.z * faceCentre.z > 4.9)
            #expect(node.isUpward == (rounded == [0, 0, 1]))
            #expect(node.isDownward == (rounded == [0, 0, -1]))
            #expect(node.isVertical == (rounded[2] == 0))
            #expect(node.isHorizontal == (rounded[2] != 0))
        }
        let expected: Set<[Int]> = [
            [1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1],
        ]
        #expect(axes == expected)
    }

    @Test("AAG neighbors returns correct count")
    func aagNeighbors() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let aag = box.buildAAG()
        // Each face of a box touches 4 other faces
        for i in 0..<6 {
            let nbrs = aag.neighbors(of: i)
            #expect(nbrs.count == 4)
        }
    }

    // #3332: the old test took neighbour 0's edge and asserted `sharedEdgeCount > 0`, so any edge
    // object passed. Every face of a box meets four others along one convex 90 degree edge, and
    // the one face it does not meet is its opposite, whose normal is the negation of its own.
    @Test("AAG edge between adjacent faces exists")
    func aagEdgeBetween() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let aag = box.buildAAG()
        for face in 0..<6 {
            let normal = try #require(aag.nodes[face].normal)
            let neighbours = aag.neighbors(of: face)
            #expect(neighbours.count == 4)
            for other in neighbours {
                let edge = try #require(aag.edge(between: face, and: other))
                #expect(Set([edge.face1Index, edge.face2Index]) == Set([face, other]))
                #expect(edge.convexity == .convex)
                #expect(edge.sharedEdgeCount == 1)
                // Adjacent faces of a box are perpendicular.
                let otherNormal = try #require(aag.nodes[other].normal)
                let dot =
                    normal.x * otherNormal.x + normal.y * otherNormal.y + normal.z * otherNormal.z
                #expect(abs(dot) < 1e-9)
                // The edge is symmetric in its arguments.
                let reverse = try #require(aag.edge(between: other, and: face))
                #expect(reverse.face1Index == edge.face1Index)
                #expect(reverse.face2Index == edge.face2Index)
            }
            // The opposite face is the one that is not a neighbour: normals negate, no edge.
            let opposite = (0..<6).filter { $0 != face && !neighbours.contains($0) }
            #expect(opposite.count == 1)
            if let o = opposite.first {
                let oNormal = try #require(aag.nodes[o].normal)
                #expect(
                    abs(normal.x + oNormal.x) + abs(normal.y + oNormal.y)
                        + abs(normal.z + oNormal.z) < 1e-9)
                #expect(aag.edge(between: face, and: o) == nil)
            }
        }
    }

    @Test("Box with pocket detects pocket via AAG")
    func detectPocket() throws {
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
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocket = try #require(
            Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
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
    func convexConcaveNeighbors() throws {
        // #766: this test used to end in `#expect(hasAnyNeighbors || aag.nodes.count > 6)`, which
        // the node count alone satisfies, so no convexity defect could fail it. The values below
        // are the kernel's own (Scripts/repro/766-modeling-aag): the plain box's 12 adjacent
        // pairs are all convex, and the filleted box has 26 faces (6 + 12 fillet + 8 corner)
        // and 48 adjacent pairs, every one tangential, so no face has a convex or a concave
        // neighbor at all.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
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
