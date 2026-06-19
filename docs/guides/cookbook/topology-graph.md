---
title: Topology Graph
parent: Cookbook
nav_order: 9
---

# Topology Graph

A `Shape` is a B-Rep — a graph of solids, shells, faces, wires, edges and vertices wired together by
incidence. `TopologyGraph` exposes that graph for **queries** (counts, adjacency, shared edges) and
gives every node a **durable identity** that survives modelling operations — useful for selection,
analysis, and persisting references across sessions.

## Build the graph

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
guard let graph = TopologyGraph(shape: box) else { return }   // parallel: false by default
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

A node **index** is not stable — it shifts when topology is added or removed. For a reference that
survives mutation, use a `GraphUID` (`kind` + a never-reused `counter`):

```swift
let faceKind = Int(TopologyGraph.NodeKind.face.rawValue)
guard let uid = graph.uid(ofNodeKind: faceKind, index: 0) else { return }
uid.isValid                       // counter > 0
graph.contains(uid: uid)          // still present?
if let resolved = graph.node(forUID: uid) {
    print(resolved.kind, resolved.index)   // resolve back to a current (kind, index)
}
```

UIDs are scoped to a **generation** (`graph.generation`, bumped on rebuild) — validate the generation
matches before reusing a UID across a rebuild. Parallel kinds exist for references (`GraphRefUID`) and
domain-scoped items (`GraphItemUID`).

> **NodeRef vs UID.** `NodeRef(kind:index:)` is an ephemeral, in-memory pointer (fine for a single
> traversal); `GraphUID` is the durable handle to persist or carry across operations. Don't store
> raw indices and expect them to mean the same node later.

## Tracking nodes through operations (history)

The graph can record how nodes map through an operation (e.g. a fillet replacing a face), so a
selection can be re-resolved afterward:

```swift
let orig = TopologyGraph.NodeRef(kind: .face, index: 0)
let repl = TopologyGraph.NodeRef(kind: .face, index: 42)
graph.recordHistory(operationName: "Fillet", original: orig, replacements: [repl])

graph.findDerived(of: orig)          // [repl]    — what it became
graph.findOriginal(of: repl)         // orig      — where it came from
graph.findDerivedOrSelf(of: orig)    // unambiguous remap (self if untouched)
graph.hasHistoryRecord(for: orig)    // distinguish "deleted" from "untouched"
```

History is opt-in (call `recordHistory` as you mutate); `findDerivedOrSelf` is the safe choice for
remapping a selection, since an empty `findDerived` is ambiguous on its own.

## See also

- [XCAF Assemblies](xcaf-assemblies.md) — structure *across* shapes (the product tree), vs. structure *within* one shape here.
- [Healing & Validity](healing-and-validity.md) — `sameDomainFaces` pairs with `unified()` after booleans.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
