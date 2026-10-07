import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #443: `setTriangulationFromShape` meshed the whole shape and then stored only the
/// **first face's** triangulation.
///
/// Measured before the fix: a 6-face box and a 12-face
/// two-box compound both stored 4 nodes and 2 triangles, one planar face's corners, for
/// a doc comment that reads "by meshing a shape". The attribute is what later readers
/// trust as the label's geometry, so a silently truncated one is the worst of the three
/// sites the audit found.
@Suite("Issue 443: triangulation attribute stores the whole shape")
struct Issue443TriangulationAttributeTests {

    /// Every node stored for a label, read back through the public accessor.
    ///
    /// Requires every index in `1...count` to answer, so a count that over-reports or an
    /// accessor that refuses an in-range index fails here and names itself.
    private func storedNodes(_ label: AssemblyNode) throws -> [SIMD3<Double>] {
        let count = label.triangulationNodeCount
        try #require(count > 0, "the label stores no triangulation")
        var nodes: [SIMD3<Double>] = []
        for i in Int32(1)...count {
            let node = try #require(
                label.triangulationNode(at: i), "node \(i) of \(count) unreadable")
            nodes.append(node)
        }
        return nodes
    }

    /// What the shape's own faces say about their triangulation, summed: node and triangle
    /// counts, and the worst deflection. `setTriangulationFromShape` meshes the shape in place, so
    /// each face carries the triangulation the label's merged one was built from, and this reads
    /// it through a different accessor (`Shape.triangulation...`, which is per face).
    private func faceTotals(_ shape: Shape) -> (nodes: Int32, triangles: Int32, deflection: Double)
    {
        var nodes: Int32 = 0
        var triangles: Int32 = 0
        var deflection = 0.0
        for face in shape.subShapes(ofType: .face) {
            nodes += face.triangulationNodeCount
            triangles += face.triangulationTriangleCount
            deflection = max(deflection, face.triangulationDeflection)
        }
        return (nodes, triangles, deflection)
    }

    /// How many stored nodes sit at each corner of the axis-aligned box `lo...hi`.
    ///
    /// A node that is not on a corner is returned as `stray`. A planar face meshed at any
    /// deflection has exactly its four corners as nodes, so for a box every node is a corner
    /// and each corner belongs to the three faces that meet there.
    private func cornerCounts(
        _ nodes: [SIMD3<Double>], lo: SIMD3<Double>, hi: SIMD3<Double>
    ) -> (counts: [SIMD3<Double>: Int], stray: [SIMD3<Double>]) {
        let tol = 1e-6
        func snap(_ v: Double, _ a: Double, _ b: Double) -> Double? {
            if abs(v - a) < tol { return a }
            if abs(v - b) < tol { return b }
            return nil
        }
        var counts: [SIMD3<Double>: Int] = [:]
        var stray: [SIMD3<Double>] = []
        for n in nodes {
            if let x = snap(n.x, lo.x, hi.x), let y = snap(n.y, lo.y, hi.y),
                let z = snap(n.z, lo.z, hi.z)
            {
                counts[SIMD3(x, y, z), default: 0] += 1
            } else {
                stray.append(n)
            }
        }
        return (counts, stray)
    }

    /// A box at deflection 1.0 meshes to 4 nodes and 2 triangles per planar face.
    @Test("a box stores all six faces, not one")
    func boxStoresEveryFace() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.subShapeCount(ofType: .face) == 6)
        // Control: nothing is stored until the call is made, so the counts below come from it.
        #expect(label.triangulationNodeCount == 0)
        #expect(label.setTriangulationFromShape(box, deflection: 1.0))

        // Was 4 / 2 before the fix: one face's worth, for any input.
        #expect(label.triangulationNodeCount == 24)
        #expect(label.triangulationTriangleCount == 12)

        // Which nodes, not only how many: every one is a corner of the 10 mm box centred on the
        // origin, and each of the eight corners is stored three times (once per meeting face).
        // Six faces' worth of one face's corners would also count 24 and fail here.
        let nodes = try storedNodes(label)
        let lo = SIMD3<Double>(-5, -5, -5)
        let hi = SIMD3<Double>(5, 5, 5)
        let read = cornerCounts(nodes, lo: lo, hi: hi)
        #expect(read.stray.isEmpty, "nodes off the box corners: \(read.stray)")
        #expect(read.counts.count == 8)
        #expect(read.counts.values.allSatisfy { $0 == 3 }, "corner multiplicities: \(read.counts)")
    }

    /// Two disjoint boxes: 12 faces, so twice the box's mesh.
    ///
    /// The pre-fix answer did not
    /// change at all between these two inputs, which is what made it hard to notice.
    @Test("a two-body compound stores both bodies")
    func compoundStoresEveryBody() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
        let compound = try #require(Shape.compound([a, b]))
        #expect(compound.subShapeCount(ofType: .face) == 12)
        #expect(label.setTriangulationFromShape(compound, deflection: 1.0))
        #expect(label.triangulationNodeCount == 48)
        #expect(label.triangulationTriangleCount == 24)

        // Both bodies are present, 24 nodes each, rather than one body's mesh stored twice. A
        // box built from an origin spans origin ... origin + size here, which the bounding box
        // of each input states, so the expected corners are read from the inputs.
        let nodes = try storedNodes(label)
        let boundsA = try #require(a.boundingBox)
        let boundsB = try #require(b.boundingBox)
        let inA = cornerCounts(nodes, lo: boundsA.min, hi: boundsA.max)
        let inB = cornerCounts(nodes, lo: boundsB.min, hi: boundsB.max)
        #expect(inA.counts.count == 8, "body A corners stored: \(inA.counts.count)")
        #expect(inB.counts.count == 8, "body B corners stored: \(inB.counts.count)")
        #expect(inA.counts.values.allSatisfy { $0 == 3 })
        #expect(inB.counts.values.allSatisfy { $0 == 3 })
        // A node of A is "stray" for B and the other way round, so together they cover every node.
        #expect(inA.counts.values.reduce(0, +) == 24)
        #expect(inB.counts.values.reduce(0, +) == 24)
    }

    /// Finer deflection must produce a finer mesh.
    ///
    /// On a curved shape this is the check
    /// that the merge actually walks every face rather than pinning one of them.
    @Test("deflection still controls mesh density on a curved shape")
    func deflectionControlsDensity() throws {
        let doc = try #require(Document.create())
        let coarseLabel = try #require(doc.createLabel())
        let fineLabel = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 10.0))
        #expect(coarseLabel.setTriangulationFromShape(sphere, deflection: 2.0))
        // The sphere's own face holds the mesh just made, so the label's counts and deflection
        // are checked against it before the finer call replaces it.
        let coarseFaces = faceTotals(sphere)
        #expect(coarseFaces.nodes > 0)
        #expect(coarseLabel.triangulationNodeCount == coarseFaces.nodes)
        #expect(coarseLabel.triangulationTriangleCount == coarseFaces.triangles)
        #expect(coarseLabel.triangulationDeflection == coarseFaces.deflection)
        #expect(fineLabel.setTriangulationFromShape(sphere, deflection: 0.2))
        let fineFaces = faceTotals(sphere)
        #expect(fineLabel.triangulationNodeCount == fineFaces.nodes)
        #expect(fineLabel.triangulationTriangleCount == fineFaces.triangles)
        #expect(fineLabel.triangulationDeflection == fineFaces.deflection)
        #expect(coarseLabel.triangulationTriangleCount > 0)
        #expect(fineLabel.triangulationTriangleCount > coarseLabel.triangulationTriangleCount)
        #expect(fineLabel.triangulationNodeCount > coarseLabel.triangulationNodeCount)

        // Every stored node is a vertex of the mesh, so it lies on the sphere: radius 10 at any
        // density. A node read back in the wrong frame, scaled or from the wrong index leaves it.
        for label in [coarseLabel, fineLabel] {
            for node in try storedNodes(label) {
                #expect(abs(simd_length(node) - 10.0) < 1e-6, "node \(node) is off the sphere")
            }
        }

        // The merged triangulation is built by hand, so its deflection starts at 0 and has
        // to be carried over from the contributing faces; a 0 would read as "exact". Each is
        // positive and the finer request gives the smaller one. Not compared with the requested
        // value: the achieved deflection is OCCT's, and at 0.2 it measures 0.238, above the
        // request, because the angular limit binds first.
        #expect(coarseLabel.triangulationDeflection > 0.01)
        #expect(fineLabel.triangulationDeflection > 0.01)
        #expect(fineLabel.triangulationDeflection < coarseLabel.triangulationDeflection)
    }

    /// The merged deflection is the worst of the contributing faces, not the first face's.
    ///
    /// A box's six planar faces all mesh exactly, so the flat case reads as zero up to
    /// rounding, and a compound of a box and a sphere reads the sphere's value whichever
    /// comes first.
    @Test("a planar shape reports its faces' own deflection")
    func planarDeflection() throws {
        let doc = try #require(Document.create())
        let flat = try #require(doc.createLabel())
        let curved = try #require(doc.createLabel())
        let boxFirst = try #require(doc.createLabel())
        let sphereFirst = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // One sphere per measurement: meshing stores its triangulation on the shape's faces and
        // a later call at a coarser deflection reuses it, so a shared sphere would make the
        // second reading depend on the first.
        let sphere = try #require(Shape.sphere(radius: 10.0))
        let sphereA = try #require(Shape.sphere(radius: 10.0))
        let sphereB = try #require(Shape.sphere(radius: 10.0))
        let boxThenSphere = try #require(Shape.compound([box, sphereA]))
        let sphereThenBox = try #require(Shape.compound([sphereB, box]))

        #expect(flat.setTriangulationFromShape(box, deflection: 1.0))
        #expect(curved.setTriangulationFromShape(sphere, deflection: 2.0))
        #expect(boxFirst.setTriangulationFromShape(boxThenSphere, deflection: 2.0))
        #expect(sphereFirst.setTriangulationFromShape(sphereThenBox, deflection: 2.0))

        // Planar: a plane meshes exactly. Not asserted as `== 0`, since the value is rounding
        // noise (about 3e-16 on this kernel), and not as `>= 0`, which every value satisfies.
        #expect(flat.triangulationDeflection >= 0)
        #expect(flat.triangulationDeflection < 1e-9)
        #expect(curved.triangulationDeflection > 0.01)

        // Against the faces themselves: the label's deflection is the worst of its faces', and
        // its counts are their sums, for the flat box, the sphere and both compounds.
        for (label, shape) in [
            (flat, box), (curved, sphere), (boxFirst, boxThenSphere), (sphereFirst, sphereThenBox),
        ] {
            let faces = faceTotals(shape)
            #expect(label.triangulationNodeCount == faces.nodes)
            #expect(label.triangulationTriangleCount == faces.triangles)
            #expect(label.triangulationDeflection == faces.deflection)
        }

        // The worst face wins, so both orders read the sphere's deflection, and neither reads
        // the box's, which is what the first face would give for [box, sphere].
        #expect(boxFirst.triangulationDeflection == curved.triangulationDeflection)
        #expect(sphereFirst.triangulationDeflection == curved.triangulationDeflection)
        // Faces of both bodies are in the merged mesh: 8 box corners x 3 plus the sphere's nodes.
        #expect(
            boxFirst.triangulationNodeCount
                == flat.triangulationNodeCount + curved.triangulationNodeCount)
    }

    /// The second behaviour change in this fix, and the one no node count would reveal: the
    /// old code fetched each face's `TopLoc_Location` and **discarded** it, so a located
    /// shape's nodes were stored in the face's own local frame.
    ///
    /// A box moved to
    /// (100, 200, 300) stored a node at the origin; it now stores it at (100, 200, 300).
    @Test("a located shape stores nodes in the shape's frame, not the face's")
    func locatedShapeStoresShapeFrame() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let moved = try #require(box.moved(dx: 100, dy: 200, dz: 300))
        #expect(label.setTriangulationFromShape(moved, deflection: 1.0))
        #expect(label.triangulationNodeCount == 24)

        // The box is centred on the origin, so the moved one spans 95...105, 195...205 and
        // 295...305: stated from the move, not read back from the shape under test.
        let nodes = try storedNodes(label)
        let read = cornerCounts(
            nodes, lo: SIMD3(95, 195, 295), hi: SIMD3(105, 205, 305))
        #expect(read.stray.isEmpty, "nodes outside the moved box's corners: \(read.stray)")
        #expect(read.counts.count == 8)
        #expect(read.counts.values.allSatisfy { $0 == 3 }, "corner multiplicities: \(read.counts)")
        // The pre-fix defect, stated directly: nothing sits near the origin.
        #expect(nodes.allSatisfy { simd_length($0) > 100 })
    }

    /// A mirrored shape reverses its faces, which is the other half of the per-face handling
    /// (winding and node normals get flipped). #375's history here makes a mirrored fixture
    /// worth pinning on its own: the merge must still cover every face and stay in frame.
    @Test("a mirrored shape stores every face, in frame")
    func mirroredShapeStoresEveryFace() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(
            Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10))
        let mirrored = try #require(
            box.mirrored(planeNormal: SIMD3(1, 0, 0), planeOrigin: SIMD3(0, 0, 0)))
        #expect(label.setTriangulationFromShape(mirrored, deflection: 1.0))
        #expect(label.triangulationNodeCount == 24)
        #expect(label.triangulationTriangleCount == 12)

        // The box spans x 10...20 (origin 10, width 10) and the mirror in the plane x = 0 puts
        // it at x -20...-10, y and z unchanged: stated from the construction. Nodes stored in the
        // wrong frame, or not mirrored, would sit at x 10...20 and fail the corner check.
        let nodes = try storedNodes(label)
        let read = cornerCounts(nodes, lo: SIMD3(-20, 0, 0), hi: SIMD3(-10, 10, 10))
        #expect(read.stray.isEmpty, "nodes off the mirrored box's corners: \(read.stray)")
        #expect(read.counts.count == 8)
        #expect(read.counts.values.allSatisfy { $0 == 3 }, "corner multiplicities: \(read.counts)")
    }

    /// `triangulationNode(at:)` is the accessor that makes any of the above checkable: before
    /// #443 the attribute exposed only counts and deflection, so nothing in the Swift API
    /// could see the coordinates it stored.
    @Test("triangulationNode rejects out-of-range and attribute-less labels")
    func triangulationNodeBounds() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let empty = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(empty.triangulationNode(at: 1) == nil)  // no attribute at all

        #expect(label.setTriangulationFromShape(box, deflection: 1.0))
        // The count is 24, so 1...24 answer and nothing else does. Spelled with the literal as
        // well as the count, so a count that over-reports cannot move both edges with it.
        #expect(label.triangulationNodeCount == 24)
        #expect(label.triangulationNode(at: 0) == nil)  // 1-based
        #expect(label.triangulationNode(at: -1) == nil)
        #expect(label.triangulationNode(at: 1) != nil)
        #expect(label.triangulationNode(at: 24) != nil)
        #expect(label.triangulationNode(at: 25) == nil)
        #expect(label.triangulationNode(at: Int32.max) == nil)

        // Node 1 and node 24 are different faces' nodes, not one node answered for every index:
        // the first two stored nodes differ, and every one of the 24 is a corner.
        let first = try #require(label.triangulationNode(at: 1))
        let second = try #require(label.triangulationNode(at: 2))
        #expect(first != second)
        let nodes = try storedNodes(label)
        #expect(Set(nodes).count == 8, "24 nodes cover the 8 corners, not one repeated")
    }

    /// The `hasNormals` branch of the merge is dead on the ordinary path:
    /// `BRepMesh_IncrementalMesh` produces no node normals at all (measured, 0 of 6 box faces
    /// and 0 of 1 sphere face).
    ///
    /// It fires only for a face that arrived carrying a
    /// normal-bearing triangulation, which glTF import does produce, so that is the only way
    /// to exercise it.
    @Test("a glTF-imported mesh carries its node normals through the merge")
    func importedNormalsSurviveTheMerge() throws {
        let sphere = try #require(Shape.sphere(radius: 10.0))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt443_normals_\(UUID().uuidString).glb")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeGLTF(shape: sphere, to: url, binary: true, deflection: 0.5)

        let imported = try #require(Shape.loadGLTF(from: url), "could not load the glTF back")
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let brepLabel = try #require(doc.createLabel())
        #expect(label.setTriangulationFromShape(imported, deflection: 1.0))
        #expect(label.triangulationNodeCount > 0)

        // The branch this test exists for: normals are present, so the merge took the path
        // that transforms and reverses them. Every node has one, not only the first.
        let nodes = try storedNodes(label)
        // Nodes lie on the sphere (the glTF mesh was made from it), which is what makes the
        // outward direction at a node its own position over its length.
        for (i, p) in nodes.enumerated() {
            #expect(abs(simd_length(p) - 10.0) < 1e-3, "node \(i + 1) at \(p) is off the sphere")
        }
        var checked = 0
        for (i, p) in nodes.enumerated() {
            let n = try #require(
                label.triangulationNormal(at: Int32(i + 1)),
                "node \(i + 1) stored no normal, so the branch did not run")
            #expect(abs(simd_length(n) - 1.0) < 1e-6, "normal \(n) is not unit length")
            // The sphere's outward normal at p is p / |p|. A dropped reversal flips a face's
            // worth (dot near -1) and a normal read from the wrong node points elsewhere. The
            // glTF carries the sphere's analytic normals, so the stored one is radial to double
            // precision (measured: the smallest dot over all 168 nodes is 1 - 1.2e-15); 1 - 1e-6
            // leaves six orders of margin and still rejects a normal turned by even 0.1 degree.
            #expect(
                simd_dot(n, p / simd_length(p)) > 1 - 1e-6,
                "node \(i + 1) normal \(n) does not point outward from \(p)")
            checked += 1
        }
        #expect(checked == nodes.count)
        #expect(label.triangulationNormal(at: 0) == nil)
        #expect(label.triangulationNormal(at: label.triangulationNodeCount + 1) == nil)

        // The contrast case, in the same test so the claim is pinned from both sides: the
        // same sphere meshed from B-Rep stores no node normals at all.
        #expect(brepLabel.setTriangulationFromShape(sphere, deflection: 0.5))
        #expect(brepLabel.triangulationNodeCount > 0)
        #expect(brepLabel.triangulationNormal(at: 1) == nil)
        #expect(brepLabel.triangulationNormal(at: brepLabel.triangulationNodeCount) == nil)
    }

    /// The merge must not silently store an empty attribute when there is nothing to mesh.
    @Test("a shape with no face stores nothing")
    func noFaceStoresNothing() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let control = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        // Control: the same label and the same document do store a mesh for the box, so the
        // zeros below are the edge's answer and not a document that cannot store one.
        #expect(control.setTriangulationFromShape(box, deflection: 1.0))
        #expect(control.triangulationNodeCount == 24)

        #expect(label.setTriangulationFromShape(edge, deflection: 1.0) == false)
        #expect(label.triangulationNodeCount == 0)
        #expect(label.triangulationTriangleCount == 0)
        #expect(label.triangulationNode(at: 1) == nil)
    }
}
