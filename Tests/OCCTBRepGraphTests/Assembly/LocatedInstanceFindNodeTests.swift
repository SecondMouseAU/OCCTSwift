import Foundation
import Testing

@testable import OCCTSwift

/// #2650: `findNode(for:)` returned `nil` for every sub-shape reached through a placed
/// instance in a compound, so no face, edge or vertex of a STEP assembly component resolved
/// to a node.
///
/// The kernel's contract is that they resolve. `FindNode` keys on OCCT shape identity,
/// TShape plus Location (`BRepGraph_ShapesView.hxx:216`), and the kernel binds each source
/// sub-shape key as an alias of its definition node precisely so the located ones still
/// resolve: `bindSourceShapeAliases`, declared "to keep ShapesView::FindNode() usable with
/// the original TopoDS subshapes when root placement is stored on a Product occurrence or
/// Compound child ref" (`BRepGraph_ShapesView.hxx:258`). That aliasing runs only where the
/// root's own placement goes into a ref, which for a parentless `Add` is
/// `Options::CreateAutoProduct`, and `OCCTBRepGraphCreate` passes `false` for it. So the
/// aliases were never bound.
///
/// The answer is the DEFINITION node, one per definition, so two occurrences of one part
/// resolve to the same node. That is the kernel's own collapse, not a shortcut here:
/// measured element for element against OCCT's aliasing in
/// `Scripts/repro/2650-brepgraph-located-instance-findnode/`.
@Suite("BRepGraph findNode resolves located instances (#2650)")
struct Issue2650LocatedInstanceFindNode {

    /// A pure translation as `located(matrix:)` wants it: three rows of `r r r t`.
    private static func translation(x: Double, y: Double, z: Double) -> [Double] {
        [
            1, 0, 0, x,
            0, 1, 0, y,
            0, 0, 1, z,
        ]
    }

    /// Case A from the issue: two instances of one part, one placed, in one compound.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 8, depth: 6)!
    /// let moved = box.moved(dx: 50, dy: 0, dz: 0)!
    /// let pair = Shape.compound([box, moved])!
    /// let graph = BRepGraph(shape: pair)!
    /// // Both solids, and all twelve faces, resolve.
    /// let resolved = pair.subShapes(ofType: .solid).compactMap { graph.findNode(for: $0) }
    /// print(resolved.count)  // 2
    /// ```
    @Test func twoInstancesOfOnePartBothResolve() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let pair = Shape.compound([box, moved]),
            let graph = BRepGraph(shape: pair)
        else {
            Issue.record("fixture construction failed")
            return
        }

        let solids = pair.subShapes(ofType: .solid)
        #expect(solids.count == 2)
        #expect(solids.allSatisfy { graph.findNode(for: $0) != nil })
        #expect(solids.allSatisfy { graph.hasNode(for: $0) })

        let faces = pair.subShapes(ofType: .face)
        #expect(faces.count == 12)
        #expect(faces.filter { graph.findNode(for: $0) != nil }.count == 12)

        let edges = pair.subShapes(ofType: .edge)
        #expect(edges.count == 24)
        #expect(edges.filter { graph.findNode(for: $0) != nil }.count == 24)

        let vertices = pair.subShapes(ofType: .vertex)
        #expect(vertices.count == 16)
        #expect(vertices.filter { graph.findNode(for: $0) != nil }.count == 16)
    }

    /// The two occurrences collapse onto one definition node, which is what the kernel's own
    /// aliasing does.
    ///
    /// Asserted rather than left implicit, because a downstream table keying a
    /// per-instance identity off this node would be keying off the definition.
    @Test func bothOccurrencesResolveToTheSameDefinitionNode() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let pair = Shape.compound([box, moved]),
            let graph = BRepGraph(shape: pair)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let solids = pair.subShapes(ofType: .solid)
        guard solids.count == 2,
            let first = graph.findNode(for: solids[0]),
            let second = graph.findNode(for: solids[1])
        else {
            Issue.record("both solids should resolve")
            return
        }
        #expect(first.kind == .solid)
        #expect(second.kind == .solid)
        #expect(first.index == second.index)
        // One definition, so the graph holds one solid node for the two occurrences.
        #expect(graph.solidCount == 1)
    }

    /// Case B from the issue: a single placed instance inside a compound, so nothing in the
    /// compound is unplaced and the pre-fix count was zero of six.
    @Test func singlePlacedInstanceInACompoundResolves() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let one = Shape.compound([moved]),
            let graph = BRepGraph(shape: one)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let faces = one.subShapes(ofType: .face)
        #expect(faces.count == 6)
        #expect(faces.filter { graph.findNode(for: $0) != nil }.count == 6)
    }

    /// Case C from the issue, which already worked and must keep working: the placed solid as
    /// the graph's own root.
    ///
    /// Here the definition carries the root's placement, so the direct
    /// key hits and no alias key is needed.
    @Test func placedSolidAsTheGraphRootStillResolves() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let graph = BRepGraph(shape: moved)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let faces = moved.subShapes(ofType: .face)
        #expect(faces.count == 6)
        #expect(faces.filter { graph.findNode(for: $0) != nil }.count == 6)
    }

    /// A nested placement, so a sub-shape carries two composed locations rather than one.
    ///
    /// Stripping the whole composed placement is the right key because the kernel stores a
    /// compound child's definition at the identity.
    @Test func nestedPlacementResolves() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let inner = Shape.compound([moved]),
            let innerMoved = inner.moved(dx: 0, dy: 30, dz: 0),
            let outer = Shape.compound([box, innerMoved]),
            let graph = BRepGraph(shape: outer)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let faces = outer.subShapes(ofType: .face)
        #expect(faces.count == 12)
        #expect(faces.filter { graph.findNode(for: $0) != nil }.count == 12)
        let solids = outer.subShapes(ofType: .solid)
        #expect(solids.count == 2)
        #expect(solids.filter { graph.findNode(for: $0) != nil }.count == 2)
    }

    /// The second construction, and it does not go through `moved(dx:dy:dz:)`, the call the
    /// fix was measured on. `located(matrix:)` reaches `OCCTShapeLocated` in a different
    /// bridge function and builds the placement from twelve doubles, so a fix that happened
    /// to work only for TopoDS_Shape::Moved's own translation would fail here.
    ///
    /// The two constructions are proved to agree on everything except the placement: same
    /// sub-shape counts, same resolved node for the corresponding solid.
    @Test func locatedMatrixInstanceResolvesTheSameWayAsMoved() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let viaMoved = box.moved(dx: 50, dy: 0, dz: 0),
            let viaMatrix = box.located(matrix: Self.translation(x: 50, y: 0, z: 0)),
            let pairViaMoved = Shape.compound([box, viaMoved]),
            let pairViaMatrix = Shape.compound([box, viaMatrix]),
            let graphViaMoved = BRepGraph(shape: pairViaMoved),
            let graphViaMatrix = BRepGraph(shape: pairViaMatrix)
        else {
            Issue.record("fixture construction failed")
            return
        }

        // The two compounds agree on everything but how the placement was built.
        #expect(
            pairViaMoved.subShapes(ofType: .face).count
                == pairViaMatrix.subShapes(ofType: .face).count)
        #expect(graphViaMoved.solidCount == graphViaMatrix.solidCount)
        #expect(graphViaMoved.faceCount == graphViaMatrix.faceCount)

        let matrixFaces = pairViaMatrix.subShapes(ofType: .face)
        #expect(matrixFaces.count == 12)
        #expect(matrixFaces.filter { graphViaMatrix.findNode(for: $0) != nil }.count == 12)

        let movedSolids = pairViaMoved.subShapes(ofType: .solid)
        let matrixSolids = pairViaMatrix.subShapes(ofType: .solid)
        guard movedSolids.count == 2, matrixSolids.count == 2 else {
            Issue.record("both compounds should hold two solids")
            return
        }
        for index in 0..<2 {
            let a = graphViaMoved.findNode(for: movedSolids[index])
            let b = graphViaMatrix.findNode(for: matrixSolids[index])
            #expect(a?.kind == b?.kind)
            #expect(a?.index == b?.index)
        }
    }

    /// The bound on the fix: a placed shape the graph never ingested stays unresolved.
    ///
    /// The
    /// graph holds the unplaced box, the query is the same part somewhere else, and
    /// `hasNode(for:)` still means "was part of construction input".
    @Test func placedShapeTheGraphNeverIngestedStaysUnresolved() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let boxOnly = Shape.compound([box]),
            let elsewhere = box.moved(dx: 50, dy: 0, dz: 0),
            let graph = BRepGraph(shape: boxOnly)
        else {
            Issue.record("fixture construction failed")
            return
        }
        #expect(graph.findNode(for: elsewhere) == nil)
        #expect(!graph.hasNode(for: elsewhere))
        let strangerFaces = elsewhere.subShapes(ofType: .face)
        #expect(strangerFaces.count == 6)
        #expect(strangerFaces.allSatisfy { graph.findNode(for: $0) == nil })
        // The unplaced definition still resolves, so the refusal above is about the
        // placement rather than about the part.
        #expect(box.subShapes(ofType: .face).allSatisfy { graph.findNode(for: $0) != nil })
    }

    /// An unrelated shape stays unresolved whether or not it is placed, so the retry cannot
    /// be answering on TShape alone.
    @Test func unrelatedShapeStaysUnresolved() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let pair = Shape.compound([box, moved]),
            let sphere = Shape.sphere(radius: 5),
            let placedSphere = sphere.moved(dx: 50, dy: 0, dz: 0),
            let graph = BRepGraph(shape: pair)
        else {
            Issue.record("fixture construction failed")
            return
        }
        #expect(!graph.hasNode(for: sphere))
        #expect(!graph.hasNode(for: placedSphere))
        #expect(graph.findNode(for: placedSphere) == nil)
    }
}
