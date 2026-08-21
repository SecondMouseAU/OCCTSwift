---
title: BRep Graph
parent: Cookbook
nav_order: 9
has_children: true
---

# BRep Graph

A `Shape` is a B-Rep, a graph of solids, shells, faces, wires, edges and vertices wired together by
incidence. `BRepGraph` exposes that graph for **queries** (counts, adjacency, shared edges), gives
every node an identity that survives mutation of that graph, and can absorb an operation's **history**
so a selection survives the operation too, useful for selection and analysis.

## Build the graph

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
guard let graph = BRepGraph(shape: box) else { return }   // parallel: false by default
```

## Count nodes by kind

```swift
graph.faceCount     // 6  (a box)
graph.edgeCount     // 12
graph.vertexCount   // 8
graph.wireCount
graph.shellCount
graph.solidCount
graph.coedgeCount
graph.nodeCount     // total
```

(There are `active…Count` variants that exclude orphaned nodes.)

## Adjacency and shared topology

Queries are by node **index** within a kind:

```swift
let neighbours = graph.adjacentFaces(of: 0)        // faces sharing an edge with face 0 → 4 on a box
let shared     = graph.sharedEdges(between: 0, and: 1)   // the edge(s) two faces share
let outer      = graph.outerWire(of: 0)            // index of a face's outer wire

// edge-centric
graph.faces(of: edgeIndex)            // the faces meeting at an edge
graph.faceCount(of: edgeIndex)        // how many (2 = manifold interior edge)
graph.isBoundaryEdge(edgeIndex)       // on a free boundary?
graph.isManifoldEdge(edgeIndex)       // exactly two faces?
graph.adjacentEdges(of: edgeIndex)

// faces lying on the same underlying surface (e.g. after a boolean split)
graph.sameDomainFaces(of: 0)
```

## Durable identity (UIDs)

This section is the short tour. For the full model (the three UID flavours, the one-graph-instance
scope rule and provenance, what preserves identity versus mints a new one, and persistence) see
[BREP Graph: Durable Identity & UIDs](brep-graph-uids.md).

A node **index** is not stable, it shifts when topology is added or removed. For a reference that
survives mutation, use a `GraphUID` (`kind` + a never-reused `counter`):

```swift
let faceKind = Int(BRepGraph.NodeKind.face.rawValue)
guard let uid = graph.uid(ofNodeKind: faceKind, index: 0) else { return }
uid.isValid                       // counter > 0
graph.contains(uid: uid)          // still present?
if let resolved = graph.node(forUID: uid) {
    print(resolved.kind, resolved.index)   // resolve back to a current (kind, index)
}
```

A UID is scoped to the **one graph instance** that minted it. Counters restart at 1 in every graph, so
a UID from another graph would name an unrelated node; each UID carries the minting graph's
`instanceID` as `graphID`, and the resolvers return `nil` rather than a wrong node:

```swift
let other = BRepGraph(shape: Shape.cylinder(radius: 3, height: 7)!)!
other.node(forUID: uid)      // nil, uid belongs to `graph`, not to `other`
other.contains(uid: uid)     // false
```

`copy()` and `translated()` copy the whole graph and **keep** that identity, so UIDs carry across and
name the same nodes. `copyFace()` lifts a single face into a new graph and does not, so its UIDs are
its own. Parallel kinds exist for references (`GraphRefUID`) and domain-scoped items (`GraphItemUID`),
with the same scope.

```swift
let copy = graph.copy()!
copy.node(forUID: uid)                  // resolves, same face, same identity

let lifted = graph.copyFace(3)!         // one face, at index 0, new identity
lifted.node(forUID: uid)                // nil
lifted.uid(ofNodeKind: faceKind, index: 0)   // mint from the new graph instead
```

### UIDs and persistence

A rebuild is a **new graph**, so a UID does not survive one, build the graph again from the same
shape and the old UIDs are void. Storing a `GraphUID` in a file and resolving it after a rebuild does
not work (and before v1.12.0 it appeared to work, silently returning a wrong node on any other model).

To carry a selection across a save/load today, store the `(kind, index)` with the shape and re-mint
after rebuilding:

```swift
// save:  the shape, plus the node address you care about
let saved = (kind: faceKind, index: 3)
// load:  rebuild, then re-mint
let reloaded = BRepGraph(shape: Shape.fromBREPString(brep)!)!
let uid = reloaded.uid(ofNodeKind: saved.kind, index: saved.index)
```

This matches OCCT's own model: upstream's design treats a UID as a *persistence anchor into a
persisted graph model*, you would persist the graph (its defs, refs and UID vectors) and the UID
anchors into it. OCCT does not yet expose a serializer for the graph model, and OCCTSwift's
`snapshot()` stores the source BREP and rebuilds, which is precisely the case upstream defines as a
new identity (its `GraphGUID` is regenerated on every rebuild).

> **NodeRef vs UID.** `NodeRef(kind:index:)` is an ephemeral, in-memory pointer (fine for a single
> traversal); `GraphUID` keeps naming the same node as *this* graph mutates. Don't store raw indices
> and expect them to mean the same node later, and don't expect a UID to mean anything in a
> different graph. To carry a selection across a modelling operation, absorb that operation's
> history (next section).

## Tracking nodes through operations (history)

The graph can record how nodes map through an operation (e.g. a fillet replacing a face), so a
selection can be re-resolved afterward:

```swift
let orig = BRepGraph.NodeRef(kind: .face, index: 0)
let repl = BRepGraph.NodeRef(kind: .face, index: 42)
graph.recordHistory(operationName: "Fillet", original: orig, replacements: [repl])

graph.findDerived(of: orig)          // [repl], what it became
graph.findOriginal(of: repl)         // orig, where it came from
graph.findDerivedOrSelf(of: orig)    // unambiguous remap (self if untouched)
graph.hasHistoryRecord(for: orig)    // distinguish "deleted" from "untouched"
```

History is opt-in (call `recordHistory` as you mutate); `findDerivedOrSelf` is the safe choice for
remapping a selection, since an empty `findDerived` is ambiguous on its own.

## See also

- [BREP Graph: Durable Identity & UIDs](brep-graph-uids.md): the deep dive on `GraphUID` / `GraphRefUID` / `GraphItemUID`, the one-graph-instance scope rule, and persistence.
- [XCAF Assemblies](xcaf-assemblies.md), structure *across* shapes (the product tree), vs. structure *within* one shape here.
- [Healing & Validity](healing-and-validity.md), `sameDomainFaces` pairs with `unified()` after booleans.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
