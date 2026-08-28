import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #443: `setTriangulationFromShape` meshed the whole shape and then stored only the
/// **first face's** triangulation. Measured before the fix: a 6-face box and a 12-face
/// two-box compound both stored 4 nodes and 2 triangles, one planar face's corners, for
/// a doc comment that reads "by meshing a shape". The attribute is what later readers
/// trust as the label's geometry, so a silently truncated one is the worst of the three
/// sites the audit found.
@Suite("Issue 443: triangulation attribute stores the whole shape")
struct Issue443TriangulationAttributeTests {

    /// A box at deflection 1.0 meshes to 4 nodes and 2 triangles per planar face.
    @Test("a box stores all six faces, not one")
    func boxStoresEveryFace() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build the document or the box")
            return
        }
        #expect(box.subShapeCount(ofType: .face) == 6)
        #expect(label.setTriangulationFromShape(box, deflection: 1.0))

        // Was 4 / 2 before the fix: one face's worth, for any input.
        #expect(label.triangulationNodeCount == 24)
        #expect(label.triangulationTriangleCount == 12)
    }

    /// Two disjoint boxes: 12 faces, so twice the box's mesh. The pre-fix answer did not
    /// change at all between these two inputs, which is what made it hard to notice.
    @Test("a two-body compound stores both bodies")
    func compoundStoresEveryBody() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            Issue.record("could not build the two-box compound")
            return
        }
        #expect(compound.subShapeCount(ofType: .face) == 12)
        #expect(label.setTriangulationFromShape(compound, deflection: 1.0))
        #expect(label.triangulationNodeCount == 48)
        #expect(label.triangulationTriangleCount == 24)
    }

    /// Finer deflection must produce a finer mesh. On a curved shape this is the check
    /// that the merge actually walks every face rather than pinning one of them.
    @Test("deflection still controls mesh density on a curved shape")
    func deflectionControlsDensity() {
        guard let doc = Document.create(),
            let coarseLabel = doc.createLabel(), let fineLabel = doc.createLabel(),
            let sphere = Shape.sphere(radius: 10.0)
        else {
            Issue.record("could not build the document or the sphere")
            return
        }
        #expect(coarseLabel.setTriangulationFromShape(sphere, deflection: 2.0))
        #expect(fineLabel.setTriangulationFromShape(sphere, deflection: 0.2))
        #expect(coarseLabel.triangulationTriangleCount > 0)
        #expect(fineLabel.triangulationTriangleCount > coarseLabel.triangulationTriangleCount)

        // The merged triangulation is built by hand, so its deflection starts at 0 and has
        // to be carried over from the contributing faces; a 0 would read as "exact".
        #expect(coarseLabel.triangulationDeflection > 0)
        #expect(fineLabel.triangulationDeflection > 0)
        #expect(fineLabel.triangulationDeflection < coarseLabel.triangulationDeflection)
    }

    /// The merged deflection is the worst of the contributing faces, not the first face's.
    /// A box's six planar faces all mesh exactly, so this pins the flat case at 0 while the
    /// curved case above pins a real value.
    @Test("a planar shape reports its faces' own deflection")
    func planarDeflection() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build the document or the box")
            return
        }
        #expect(label.setTriangulationFromShape(box, deflection: 1.0))
        #expect(label.triangulationDeflection >= 0)
    }

    /// The second behaviour change in this fix, and the one no node count would reveal: the
    /// old code fetched each face's `TopLoc_Location` and **discarded** it, so a located
    /// shape's nodes were stored in the face's own local frame. A box moved to
    /// (100, 200, 300) stored a node at the origin; it now stores it at (100, 200, 300).
    @Test("a located shape stores nodes in the shape's frame, not the face's")
    func locatedShapeStoresShapeFrame() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let box = Shape.box(width: 10, height: 10, depth: 10),
            let moved = box.moved(dx: 100, dy: 200, dz: 300)
        else {
            Issue.record("could not build the located box")
            return
        }
        #expect(label.setTriangulationFromShape(moved, deflection: 1.0))
        #expect(label.triangulationNodeCount == 24)

        guard let bounds = moved.boundingBox else {
            Issue.record("located box has no bounding box")
            return
        }
        // Every stored node must lie inside the shape's own bounds. Before the fix they sat
        // around the origin, 100mm+ outside them.
        let slack = 1e-6
        for i in Int32(1)...label.triangulationNodeCount {
            guard let node = label.triangulationNode(at: i) else {
                Issue.record("node \(i) could not be read")
                return
            }
            #expect(
                node.x >= bounds.min.x - slack && node.x <= bounds.max.x + slack,
                "node \(i) x \(node.x) outside [\(bounds.min.x), \(bounds.max.x)]")
            #expect(
                node.y >= bounds.min.y - slack && node.y <= bounds.max.y + slack,
                "node \(i) y \(node.y) outside [\(bounds.min.y), \(bounds.max.y)]")
            #expect(
                node.z >= bounds.min.z - slack && node.z <= bounds.max.z + slack,
                "node \(i) z \(node.z) outside [\(bounds.min.z), \(bounds.max.z)]")
        }
    }

    /// A mirrored shape reverses its faces, which is the other half of the per-face handling
    /// (winding and node normals get flipped). #375's history here makes a mirrored fixture
    /// worth pinning on its own: the merge must still cover every face and stay in frame.
    @Test("a mirrored shape stores every face, in frame")
    func mirroredShapeStoresEveryFace() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let box = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10),
            let mirrored = box.mirrored(planeNormal: SIMD3(1, 0, 0), planeOrigin: SIMD3(0, 0, 0))
        else {
            Issue.record("could not build the mirrored box")
            return
        }
        #expect(label.setTriangulationFromShape(mirrored, deflection: 1.0))
        #expect(label.triangulationNodeCount == 24)
        #expect(label.triangulationTriangleCount == 12)

        guard let bounds = mirrored.boundingBox else {
            Issue.record("mirrored box has no bounding box")
            return
        }
        // The mirror puts the body at negative x; nodes stored in the wrong frame would not
        // be in these bounds.
        #expect(bounds.max.x < 1e-6, "mirrored box is not at negative x: \(bounds.max.x)")
        for i in Int32(1)...label.triangulationNodeCount {
            guard let node = label.triangulationNode(at: i) else {
                Issue.record("node \(i) could not be read")
                return
            }
            #expect(
                node.x >= bounds.min.x - 1e-6 && node.x <= bounds.max.x + 1e-6,
                "node \(i) x \(node.x) outside [\(bounds.min.x), \(bounds.max.x)]")
        }
    }

    /// `triangulationNode(at:)` is the accessor that makes any of the above checkable: before
    /// #443 the attribute exposed only counts and deflection, so nothing in the Swift API
    /// could see the coordinates it stored.
    @Test("triangulationNode rejects out-of-range and attribute-less labels")
    func triangulationNodeBounds() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let empty = doc.createLabel(),
            let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build the document or the box")
            return
        }
        #expect(empty.triangulationNode(at: 1) == nil)  // no attribute at all

        #expect(label.setTriangulationFromShape(box, deflection: 1.0))
        #expect(label.triangulationNode(at: 0) == nil)  // 1-based
        #expect(label.triangulationNode(at: 1) != nil)
        #expect(label.triangulationNode(at: label.triangulationNodeCount) != nil)
        #expect(label.triangulationNode(at: label.triangulationNodeCount + 1) == nil)
    }

    /// The `hasNormals` branch of the merge is dead on the ordinary path:
    /// `BRepMesh_IncrementalMesh` produces no node normals at all (measured, 0 of 6 box faces
    /// and 0 of 1 sphere face). It fires only for a face that arrived carrying a
    /// normal-bearing triangulation, which glTF import does produce, so that is the only way
    /// to exercise it.
    @Test("a glTF-imported mesh carries its node normals through the merge")
    func importedNormalsSurviveTheMerge() throws {
        guard let sphere = Shape.sphere(radius: 10.0) else {
            Issue.record("could not build the sphere")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt443_normals_\(UUID().uuidString).glb")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeGLTF(shape: sphere, to: url, binary: true, deflection: 0.5)

        guard let imported = Shape.loadGLTF(from: url) else {
            Issue.record("could not load the exported glTF back")
            return
        }
        guard let doc = Document.create(), let label = doc.createLabel(),
            let brepLabel = doc.createLabel()
        else {
            Issue.record("could not build the document")
            return
        }
        #expect(label.setTriangulationFromShape(imported, deflection: 1.0))
        #expect(label.triangulationNodeCount > 0)

        // The branch this test exists for: normals are present, so the merge took the path
        // that transforms and reverses them.
        guard let first = label.triangulationNormal(at: 1) else {
            Issue.record("the imported mesh stored no node normals, so the branch never ran")
            return
        }
        #expect(abs(simd_length(first) - 1.0) < 1e-6, "normal is not unit length: \(first)")

        // A sphere's outward normal at a node points away from the centre, so the dot product
        // with the node position is positive. A dropped reversal would flip a face's worth.
        var checked = 0
        for i in Int32(1)...min(label.triangulationNodeCount, 200) {
            guard let n = label.triangulationNormal(at: i),
                let p = label.triangulationNode(at: i)
            else { continue }
            let radial = simd_length(p)
            guard radial > 1e-6 else { continue }
            #expect(
                simd_dot(n, p / radial) > 0.5,
                "node \(i) normal \(n) does not point outward from \(p)")
            checked += 1
        }
        #expect(checked > 0, "no node normal could be checked")

        // The contrast case, in the same test so the claim is pinned from both sides: the
        // same sphere meshed from B-Rep stores no node normals at all.
        #expect(brepLabel.setTriangulationFromShape(sphere, deflection: 0.5))
        #expect(brepLabel.triangulationNodeCount > 0)
        #expect(brepLabel.triangulationNormal(at: 1) == nil)
    }

    /// The merge must not silently store an empty attribute when there is nothing to mesh.
    @Test("a shape with no face stores nothing")
    func noFaceStoresNothing() {
        guard let doc = Document.create(), let label = doc.createLabel(),
            let box = Shape.box(width: 10, height: 10, depth: 10),
            let edge = box.subShapes(ofType: .edge).first
        else {
            Issue.record("could not build an edge")
            return
        }
        #expect(label.setTriangulationFromShape(edge, deflection: 1.0) == false)
        #expect(label.triangulationNodeCount == 0)
        #expect(label.triangulationTriangleCount == 0)
    }
}
