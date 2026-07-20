---
title: "BREP Graph: Durable Identity & UIDs"
parent: BRep Graph
grand_parent: Cookbook
nav_order: 1
---

# BREP Graph: Durable Identity & UIDs

A `BRepGraph` gives every node (solid, shell, face, wire, edge, vertex, and the reference and
product entries around them) an identity that survives mutation of that graph. This page is about how
that identity works: the three UID flavours, how they are minted and resolved, and the one rule that
trips people up most, which is that a **UID belongs to the exact graph instance that minted it** and
resolves nowhere else.

For general graph queries (counts, adjacency, shared edges) and a lighter tour of identity, start with
[BRep Graph](brep-graph.md). This page goes deep on the identity model.

## Why indices are not enough

A node **index** is a position in a per-kind vector. It is convenient but not stable: adding or
removing topology, or calling `compact()`, renumbers the vectors, so face index 3 today may be a
different face tomorrow.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let graph = BRepGraph(shape: box)!

let faceKind = Int(BRepGraph.NodeKind.face.rawValue)   // 2
let uid = graph.uid(ofNodeKind: faceKind, index: 3)!       // pin face 3 by identity

graph.compact()                                            // vectors renumber
if let node = graph.node(forUID: uid) {
    print("that same face is now index \(node.index)")     // still resolves, index may differ
}
```

`NodeRef(kind:index:)` is the ephemeral form: a raw address, fine inside a single traversal, wrong to
store. A `GraphUID` is the durable form: it keeps naming the same node as *this* graph mutates.

## Three flavours of UID

All three are value types (`Sendable`, `Hashable`, `Codable`) carrying a `kind`, a monotonic
`counter` that never repeats within a kind, and a `graphID` provenance stamp (below). A `counter` of
`0` is the invalid sentinel; `isValid` is simply `counter > 0`.

| Type | Names | Mint | Resolve | Kind ordinals |
|---|---|---|---|---|
| `GraphUID` | a definition node | `uid(ofNodeKind:index:)` | `node(forUID:)` | `BRepGraph_NodeId::Kind`: 0 Solid, 1 Shell, 2 Face, 3 Wire, 4 Edge, 5 Vertex, 6 Compound, 7 CompSolid, 8 CoEdge, 10 Product, 11 Occurrence |
| `GraphRefUID` | a reference entry | `uid(ofRefKind:index:)` | `ref(forUID:)` | `BRepGraph_RefId::Kind`: 0 Shell, 1 Face, 2 Wire, 3 Vertex, 4 Solid, 5 Child, 6 Occurrence |
| `GraphItemUID` | either, generically | `itemUID(ofNodeKind:index:)` | `item(forUID:)` | `domain` 1 = node, 2 = reference; `kind` is the ordinal in that domain |

Reach for `GraphUID` for topology (the common case: pin a face, an edge, a solid). Use `GraphRefUID`
when you are working with the reference entries an assembly graph adds around occurrences. Use
`GraphItemUID` only when a single code path handles both nodes and references and you want one key type
for both.

## Minting and resolving: the round trip

```swift
// Mint: (kind, index) now  ->  a durable UID
guard let uid = graph.uid(ofNodeKind: faceKind, index: 0) else { return }

// Resolve: durable UID  ->  (kind, index) as of now
if let node = graph.node(forUID: uid) {
    let ref = BRepGraph.NodeRef(kind: BRepGraph.NodeKind(rawValue: Int32(node.kind))!,
                                    index: node.index)
    // ... query with ref ...
}

// Existence without needing the address back
graph.contains(uid: uid)     // true while the node it names still exists in this graph
```

`uid(ofNodeKind:index:)` returns `nil` for an out-of-range, removed, or invalid node. `node(forUID:)`
returns `nil` if the node has since been removed **or** if this graph did not mint the UID (next
section). `contains(uid:)` is the cheap existence check when you do not need the current index back.

`GraphRefUID` and `GraphItemUID` follow the identical mint / resolve / contains shape with their own
methods.

## The rule that matters: a UID belongs to one graph instance

This is the heart of UID management. A UID is scoped to the **graph instance** that minted it. It is
not scoped to the shape, and not to any "generation" counter.

Every graph allocates counters from 1 independently. So the same `(kind, counter)` names some
unrelated node in every other graph. A box's face UID would otherwise resolve happily against a
cylinder, returning a plausible but wrong node with no error. To prevent that, every UID carries the
minting graph's `instanceID` in its `graphID` field, and the resolvers reject a UID that came from
anywhere else.

```swift
let boxGraph = BRepGraph(shape: box)!
let faceUID  = boxGraph.uid(ofNodeKind: faceKind, index: 0)!
print(faceUID.graphID == boxGraph.instanceID)   // true: this graph minted it

let cyl = BRepGraph(shape: Shape.cylinder(radius: 3, height: 7)!)!
print(cyl.node(forUID: faceUID))                // nil, not a wrong face
print(cyl.contains(uid: faceUID))               // false
```

`instanceID` is unique among every graph this process builds, and, because the sequence starts at a
random point, distinct from any other process's ids with overwhelming probability. That randomness is
what makes a decoded UID from another process resolve nowhere rather than by accident.

> This foreign-UID rejection landed in v1.12.0 ([#295](https://github.com/SecondMouseAU/OCCTSwift/issues/295)).
> Before it, a UID stored and reloaded, or simply taken from a different graph, would silently resolve
> to whatever node held that counter, which on any other model is the wrong node. If you persisted UIDs
> under an older version, re-read the persistence section below.

### `generation` is always 1: do not use it

OCCT has a graph generation counter, but OCCTSwift clears a graph exactly once when it builds it and
never rebuilds an existing one ([#303](https://github.com/SecondMouseAU/OCCTSwift/issues/303)), so the
counter lands at 1 and never moves. It is the same 1 for every graph, so it cannot tell two graphs
apart or detect a stale reference. The `generation` property is deprecated for exactly this reason.
`node(forUID:)` already rejects a foreign UID on its own, and `instanceID` compares graph identity
directly; use those.

## What preserves identity, and what mints a new one

Knowing which operations keep `instanceID` and which start a fresh one tells you exactly when your UIDs
survive.

| Operation | Identity | UIDs |
|---|---|---|
| `compact()` | same instance | keep resolving (indices renumber, UIDs do not) |
| `copy(copyGeometry:)` | **inherited** | carry over; name the same nodes |
| `translated(dx:dy:dz:copyGeometry:)` | **inherited** | carry over |
| `copyFace(_:copyGeometry:)` | **new instance** | old UIDs resolve nowhere; mint fresh ones |
| rebuild `BRepGraph(shape:)` | **new instance** | old UIDs void |

`copy()` and `translated()` inherit the identity because the kernel copies the graph wholesale: it
transplants the UID counter space itself, so a copy genuinely *is* the same identity and every UID
keeps naming the same node.

```swift
let copy = graph.copy()!
print(copy.instanceID == graph.instanceID)   // true
print(copy.node(forUID: uid) != nil)         // true: same face, same identity

let lifted = graph.copyFace(3)!              // one face lifted into a new graph
print(lifted.instanceID == graph.instanceID) // false
print(lifted.node(forUID: uid))              // nil
let liftedUID = lifted.uid(ofNodeKind: faceKind, index: 0)   // mint from the new graph instead
```

A rebuild from the same shape is a new instance by the same token: same geometry, different graph,
void UIDs.

## Persistence: UIDs are Codable, but instance-scoped

The UID types are `Codable`, so you can encode one. The catch is that `graphID` names a graph instance
in one process's lifetime. It does not survive a rebuild, and it does not survive the process. Encoding
a UID, then rebuilding the graph (this session or a later one) and decoding it, yields a UID whose
`graphID` matches no live graph, so it resolves to `nil`. That is the honest answer: the node it named
belonged to a graph that no longer exists.

Payloads written before provenance existed (#295) have no `graphID`. They decode as `graphID == 0`
(unstamped) rather than failing the load, and an unstamped UID resolves in no graph. This is
deliberate: an old UID never carried the information that says which graph it meant, so resolving
nowhere is safer than resolving somewhere by luck.

To carry a selection across a save and reload today, **store the `(kind, index)` address alongside the
shape, and re-mint after rebuilding**:

```swift
// Save: the shape (as BREP), plus the node address you care about.
let saved = (kind: faceKind, index: 3)
let brep  = box.toBREPString()!

// Load: rebuild the graph from the shape, then re-mint the UID.
let reloaded = BRepGraph(shape: Shape.fromBREPString(brep)!)!
let freshUID = reloaded.uid(ofNodeKind: saved.kind, index: saved.index)
```

This matches OCCT's own model. Upstream treats a UID as a *persistence anchor into a persisted graph
model*: you would serialize the graph itself (its definitions, references, and UID vectors) and the UID
anchors into that. OCCT does not yet expose a serializer for the graph model, and OCCTSwift's
`snapshot()` stores the source BREP and rebuilds from it, which is precisely the case upstream defines
as a **new identity** (its graph GUID is regenerated on every rebuild). Until a graph serializer
exists, `(kind, index)` plus the shape is the durable pair.

## UIDs carry a selection across mutations; history carries it across operations

Keep two questions apart:

- **"I am mutating one graph and want to keep pointing at the same node."** That is what UIDs are for.
  Mint a `GraphUID`, mutate, resolve it back.
- **"I am running a modelling operation (a boolean, a fillet) that rebuilds the shape, and want my
  picked face to survive it."** A UID cannot help here, because the operation produces a new shape and
  therefore, when you build a graph on it, a new instance. Use the graph's **history** instead.

The graph can absorb an operation's history so a selection re-resolves through it. Build the graph from
the operation's input, hand it the result and its history, then resolve the pinned node forward:

```swift
let graph  = BRepGraph(shape: base)!
let root   = graph.findNode(for: base)!
let pinned = /* the node you picked, as a NodeRef */

let (result, history) = base.subtractedWithFullHistory(tool)!
graph.add(result, absorbing: history,
          inputRoots: [BRepGraph.NodeRef(kind: root.kind, index: root.index)],
          operationName: "cut")

graph.currentForms(of: pinned)      // what the pinned node became after the cut
```

Because that path keeps everything inside one graph instance, the `NodeRef`s and UIDs you already hold
stay valid: there is no second graph to look them up in. See
[BRep Graph](brep-graph.md#tracking-nodes-through-operations-history) for the history API
(`add(_:absorbing:inputRoots:operationName:)`, `currentForms(of:)`, `recordHistory`,
`findDerivedOrSelf`, `historyIsDeleted`), and issue
[#290](https://github.com/SecondMouseAU/OCCTSwift/issues/290) for the design.

## Choosing a reference: a decision guide

| You want to... | Use |
|---|---|
| point at a node for the rest of one traversal | `NodeRef(kind:index:)` |
| keep pointing at a node while you mutate this graph | `GraphUID` (mint, resolve back) |
| the same, for a reference entry or a mixed node/ref path | `GraphRefUID` / `GraphItemUID` |
| keep a selection across a boolean, fillet, or other rebuild | absorb the operation's **history** |
| keep a selection across a save and reload | store `(kind, index)` + the shape, re-mint on load |

Two rules cover the mistakes: do not store a raw index and expect it to mean the same node later, and
do not expect a UID to mean anything in a different graph.

## See also

- [BRep Graph](brep-graph.md) for graph construction, queries, adjacency, and the history API.
- [XCAF Assemblies](xcaf-assemblies.md) for identity *across* shapes (the product tree) rather than
  within one shape.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md).
