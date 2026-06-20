---
title: TopologyGraph — Attributes, Snapshots & References
parent: API Reference
---

# TopologyGraph — Attributes, Snapshots & References

These are the pure-Swift value types that sit alongside `TopologyGraph`: a typed attribute store (`NodeAttributeStore`) that attaches arbitrary metadata to graph nodes, a `GraphSnapshot` that serializes attributes and the source shape for round-trip persistence, and `TopologyRef` — a recipe-based identity scheme that survives graph mutations. No C++ bridge code is involved in these types. See the main **TopologyGraph** page (coming) for the graph structure, node counts, adjacency queries, and history primitives (`NodeRef`, `HistoryRecord`, `NodeKind`) that these types build on.

## Topics

- [AttrValue](#attrvalue) · [NodeAttributeStore](#nodeattributestore) · [NodeAttributeStore — Codable](#nodeattributestore--codable) · [GraphSnapshot](#graphsnapshot) · [GraphSnapshotError](#graphsnapshoterror) · [Snapshot / Restore on TopologyGraph](#snapshot--restore-on-topologygraph) · [TopologyRef](#topologyref) · [NodeRef.sentinel](#noderefsentinel) · [TopologyResolutionError](#topologyresolutionerror) · [resolve on TopologyGraph](#resolve-on-topologygraph) · [currentForms on TopologyGraph](#currentforms-on-topologygraph)

---

## AttrValue

`TopologyGraph.AttrValue` is a closed, `Codable` union of the scalar and array types you can attach to a node. The closed set keeps snapshot round-trips lossless — no open extension point means no unknown cases when deserializing.

```swift
public enum AttrValue: Codable, Hashable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case ints([Int])       // e.g. a mesh-region triangle index set
    case doubles([Double]) // e.g. fitted-surface parameters
}
```

### `AttrValue.boolValue`

Convenience unwrap — returns the wrapped `Bool`, or `nil` on type mismatch.

```swift
public var boolValue: Bool? { get }
```

---

### `AttrValue.intValue`

Convenience unwrap — returns the wrapped `Int`, or `nil` on type mismatch.

```swift
public var intValue: Int? { get }
```

---

### `AttrValue.doubleValue`

Convenience unwrap — returns the wrapped `Double`, or `nil` on type mismatch.

```swift
public var doubleValue: Double? { get }
```

---

### `AttrValue.stringValue`

Convenience unwrap — returns the wrapped `String`, or `nil` on type mismatch.

```swift
public var stringValue: String? { get }
```

---

### `AttrValue.intsValue`

Convenience unwrap — returns the wrapped `[Int]`, or `nil` on type mismatch.

```swift
public var intsValue: [Int]? { get }
```

---

### `AttrValue.doublesValue`

Convenience unwrap — returns the wrapped `[Double]`, or `nil` on type mismatch.

```swift
public var doublesValue: [Double]? { get }
```

- **Example:**
  ```swift
  let attr: TopologyGraph.AttrValue = .doubles([0.12, 0.34, 0.56])
  if let params = attr.doublesValue {
      print("params:", params)
  }
  ```

---

## NodeAttributeStore

`NodeAttributeStore` is a per-node attribute bag keyed by `TopologyGraph.NodeRef`. Keys are caller-namespaced strings (e.g. `"reconstruct.residualRMS"`). The store is `Codable`, `Sendable`, and `Equatable`; its Codable encoding is a sorted array of entries — see [NodeAttributeStore — Codable](#nodeattributestore--codable).

```swift
public struct NodeAttributeStore: Codable, Sendable, Equatable
```

### `NodeAttributeStore.init(storage:)`

Create a store, optionally pre-populated.

```swift
public init(storage: [TopologyGraph.NodeRef: [String: TopologyGraph.AttrValue]] = [:])
```

- **Parameters:** `storage` — initial contents; defaults to empty.
- **Example:**
  ```swift
  var store = NodeAttributeStore()
  ```

---

### `NodeAttributeStore.storage`

The raw dictionary backing the store.

```swift
public private(set) var storage: [TopologyGraph.NodeRef: [String: TopologyGraph.AttrValue]]
```

Direct mutation is not exposed; use the subscript and the mutating helpers below.

---

### `NodeAttributeStore.subscript(_:)`

All attributes on a node — get returns an empty dictionary when no attributes are set; set with an empty dictionary removes the node entry entirely.

```swift
public subscript(node: TopologyGraph.NodeRef) -> [String: TopologyGraph.AttrValue] { get set }
```

- **Parameters:** `node` — the node whose attribute dictionary to read or replace.
- **Example:**
  ```swift
  var store = NodeAttributeStore()
  let ref = TopologyGraph.NodeRef(kind: .face, index: 0)
  store[ref] = ["region": .int(3)]
  print(store[ref]["region"]?.intValue ?? -1)  // 3
  ```

---

### `NodeAttributeStore.value(_:for:)`

Read one attribute by key, or `nil` if unset.

```swift
public func value(_ key: String, for node: TopologyGraph.NodeRef) -> TopologyGraph.AttrValue?
```

- **Parameters:** `key` — attribute name; `node` — the node to query.
- **Returns:** The stored value, or `nil` if the key is absent.

---

### `NodeAttributeStore.set(_:_:for:)`

Set one attribute on a node.

```swift
public mutating func set(_ key: String, _ value: TopologyGraph.AttrValue, for node: TopologyGraph.NodeRef)
```

- **Parameters:** `key` — attribute name; `value` — value to store; `node` — the target node.

---

### `NodeAttributeStore.clear(_:for:)`

Remove one attribute. Drops the node entry entirely once its last attribute is cleared.

```swift
public mutating func clear(_ key: String, for node: TopologyGraph.NodeRef)
```

- **Parameters:** `key` — attribute name to remove; `node` — the target node.

---

### `NodeAttributeStore.removeAll(for:)`

Remove every attribute on a node.

```swift
public mutating func removeAll(for node: TopologyGraph.NodeRef)
```

- **Parameters:** `node` — the node whose entire attribute dictionary should be dropped.

---

### `NodeAttributeStore.annotatedNodeCount`

Number of nodes carrying at least one attribute.

```swift
public var annotatedNodeCount: Int { get }
```

- **Example:**
  ```swift
  var store = NodeAttributeStore()
  let face0 = TopologyGraph.NodeRef(kind: .face, index: 0)
  let face1 = TopologyGraph.NodeRef(kind: .face, index: 1)
  store.set("tag", .string("critical"), for: face0)
  store.set("rms", .double(0.002), for: face1)
  print(store.annotatedNodeCount)  // 2
  ```

---

## NodeAttributeStore — Codable

The store uses a custom Codable implementation so that JSON output is deterministic and diffable. Attributes are serialized as a sorted array of `{node, attrs}` entries — attributes within each entry sorted by key; entries sorted by `(kind.rawValue, index)`. Pairing this with `GraphSnapshot.canonicalEncoder()` (which adds `.sortedKeys`) makes the whole JSON byte-stable across runs.

### `NodeAttributeStore.init(from:)`

Decode from a sorted-array encoding.

```swift
public init(from decoder: Decoder) throws
```

---

### `NodeAttributeStore.encode(to:)`

Encode as a deterministically-sorted array.

```swift
public func encode(to encoder: Encoder) throws
```

---

## GraphSnapshot

`GraphSnapshot` bundles everything needed to persist a `TopologyGraph` session: the source shape as a BREP string (which is sufficient to re-derive the graph structure), plus the attribute store. The graph topology is NOT stored — it is reconstructed from `brep` on `TopologyGraph.init(snapshot:)`, relying on the fact that `TopologyGraph.init(shape:)` produces identical node indexing for the same BREP.

```swift
public struct GraphSnapshot: Codable, Sendable, Equatable
```

### `GraphSnapshot.currentFormatVersion`

Current on-disk format version. Increment on any breaking schema change.

```swift
public static let currentFormatVersion = 1
```

---

### `GraphSnapshot.brep`

BREP serialization of the source shape, used to re-derive the graph structure on load.

```swift
public var brep: String
```

---

### `GraphSnapshot.attributes`

The per-node attribute store.

```swift
public var attributes: NodeAttributeStore
```

---

### `GraphSnapshot.formatVersion`

The format version this snapshot was written with.

```swift
public var formatVersion: Int
```

---

### `GraphSnapshot.init(brep:attributes:formatVersion:)`

Create a snapshot directly.

```swift
public init(brep: String, attributes: NodeAttributeStore, formatVersion: Int = GraphSnapshot.currentFormatVersion)
```

- **Parameters:**
  - `brep` — BREP string of the source shape.
  - `attributes` — the attribute store.
  - `formatVersion` — defaults to `currentFormatVersion`.

---

### `GraphSnapshot.canonicalEncoder()`

Returns a `JSONEncoder` configured for byte-stable, diffable output.

```swift
public static func canonicalEncoder() -> JSONEncoder
```

Sets `outputFormatting` to `[.sortedKeys]`. Combined with `NodeAttributeStore`'s sorted-array encoding, the full snapshot JSON is reproducible byte-for-byte across runs — suitable for versioned sessions and golden-file tests.

- **Returns:** A configured `JSONEncoder`.
- **Example:**
  ```swift
  guard let graph = TopologyGraph(shape: myShape) else { return }
  let snap = try graph.snapshot()
  let data = try GraphSnapshot.canonicalEncoder().encode(snap)
  try data.write(to: snapshotURL)
  ```

---

## GraphSnapshotError

Errors raised while snapshotting or rebuilding a `TopologyGraph`.

```swift
public enum GraphSnapshotError: Error, Equatable, Sendable
```

### `GraphSnapshotError.noSourceShape`

The graph has no captured source shape to serialize (e.g. built from a handle directly, not from a `Shape`).

```swift
case noSourceShape
```

---

### `GraphSnapshotError.invalidBREP`

The snapshot's BREP string could not be deserialized back into a `Shape`.

```swift
case invalidBREP
```

---

### `GraphSnapshotError.graphBuildFailed`

The graph could not be rebuilt from the deserialized shape.

```swift
case graphBuildFailed
```

---

### `GraphSnapshotError.unsupportedFormatVersion(_:)`

The snapshot was written by a newer, unsupported format version.

```swift
case unsupportedFormatVersion(Int)
```

- **Associated value:** The version number found in the snapshot.

---

## Snapshot / Restore on TopologyGraph

### `TopologyGraph.attribute(_:for:)`

Read one attribute on a node, or `nil` if unset.

```swift
public func attribute(_ key: String, for node: NodeRef) -> AttrValue?
```

- **Parameters:** `key` — attribute name; `node` — the node to query.
- **Returns:** The stored value, or `nil`.
- **Note:** Pure Swift — no bridge call.
- **Example:**
  ```swift
  if let rms = graph.attribute("fit.residualRMS", for: faceRef) {
      print("RMS:", rms.doubleValue ?? 0)
  }
  ```

---

### `TopologyGraph.setAttribute(_:_:for:)`

Set one attribute on a node.

```swift
public func setAttribute(_ key: String, _ value: AttrValue, for node: NodeRef)
```

- **Parameters:** `key` — attribute name; `value` — value to store; `node` — the target node.
- **Note:** Mutates `self.attributes` in-place. Despite `self` being a class, callers don't need `mutating`.
- **Example:**
  ```swift
  graph.setAttribute("region.id", .int(7), for: faceRef)
  ```

---

### `TopologyGraph.snapshot()`

Export the attribute store and source shape for persistence or transport.

```swift
public func snapshot() throws -> GraphSnapshot
```

- **Returns:** A `GraphSnapshot` containing the BREP string and the attribute store.
- **Throws:** `GraphSnapshotError.noSourceShape` if the graph was not built from a `Shape` (e.g. constructed from a raw handle).
- **Note:** Pure Swift — no bridge call.

---

### `TopologyGraph.init(snapshot:)`

Rebuild a graph from a snapshot: deserialize the BREP, rebuild the graph (non-parallel for deterministic node indexing), and reattach the attributes.

```swift
public convenience init(snapshot: GraphSnapshot) throws
```

- **Parameters:** `snapshot` — the previously saved snapshot.
- **Throws:**
  - `GraphSnapshotError.unsupportedFormatVersion` if `snapshot.formatVersion > currentFormatVersion`.
  - `GraphSnapshotError.invalidBREP` if the BREP string cannot be parsed.
  - `GraphSnapshotError.graphBuildFailed` if graph construction fails.
- **OCCT:** `Shape.fromBREPString` + `OCCTBRepGraphCreate` with `parallel: false`.
- **Note:** Attribute keys are `NodeRef` (`kind` + `index`). The non-parallel rebuild ensures identical node indexing for the same BREP across runs — this is the contract that makes the round-trip safe.
- **Example:**
  ```swift
  // Round-trip
  guard let graph = TopologyGraph(shape: myShape) else { return }
  graph.setAttribute("quality", .string("high"), for: someRef)
  let snap = try graph.snapshot()
  let data = try GraphSnapshot.canonicalEncoder().encode(snap)

  // Later...
  let snap2 = try JSONDecoder().decode(GraphSnapshot.self, from: data)
  let graph2 = try TopologyGraph(snapshot: snap2)
  let quality = graph2.attribute("quality", for: someRef)
  // quality == .string("high")
  ```

---

## TopologyRef

`TopologyRef` is a recipe-based topology identity (OCCTSwift #72, Phase 1). OCCT node indices (`BRepGraph NodeId`) are unstable across mutations — after a fillet, split, or Boolean operation, the same index may point to a different entity or nothing at all. `TopologyRef` encodes *how to find* an entity rather than *where it is now*, and `TopologyGraph.resolve(_:)` evaluates the recipe against the current graph state on demand.

The design follows Onshape's FeatureScript query system (`qCreatedBy`, `qContainedIn`, etc.) and the Shapr3D / Onshape consensus: when a recipe can't resolve, return an error rather than silently guessing.

```swift
public indirect enum TopologyRef: Sendable, Hashable
```

`indirect` enables recursive nesting (e.g. `containedIn(parent: .createdBy(…), …)`).

### `TopologyRef.literal(_:)`

Direct reference by current `(kind, index)` — an escape hatch that bypasses recipe resolution.

```swift
case literal(TopologyGraph.NodeRef)
```

Use sparingly. A literal ref breaks the moment any mutation changes node indexing. Prefer `.createdBy` or `.containedIn` for any ref that must survive mutations.

---

### `TopologyRef.createdBy(operationName:kind:occurrence:leafOccurrence:)`

The Nth node of `kind` that appears as a replacement in a history record tagged with `operationName`.

```swift
case createdBy(operationName: String,
               kind: TopologyGraph.NodeKind,
               occurrence: Int = 0,
               leafOccurrence: Int? = 0)
```

- **Parameters:**
  - `operationName` — the tag recorded in the history log by the creating operation.
  - `kind` — the `NodeKind` to look for in the replacement set.
  - `occurrence` — which candidate to pick when the operation produced multiple nodes of `kind` (default `0` = first, in deterministic sort order: `sequenceNumber`, then `(kind.rawValue, index)`, then position in replacements vector).
  - `leafOccurrence` — after the seed node is found, walk history forward to its current live form and pick the Nth leaf. `nil` disables the forward-walk and returns the node exactly as created (useful for history inspection). Default `0`.
- **Example:**
  ```swift
  // Pick the first face created by an extrude operation
  let extrudeFace = TopologyRef.createdBy(
      operationName: "extrude_base",
      kind: .face,
      occurrence: 0
  )
  ```

---

### `TopologyRef.containedIn(parent:kind:occurrence:)`

The Nth descendant of `kind` contained within `parent`.

```swift
case containedIn(parent: TopologyRef,
                 kind: TopologyGraph.NodeKind,
                 occurrence: Int = 0)
```

- **Parameters:**
  - `parent` — a recipe resolving to the containing node (e.g. a solid or shell).
  - `kind` — the `NodeKind` to collect from the parent's children in the graph.
  - `occurrence` — zero-based index into the children of that kind (order is stable across mutations for unmodified parents).
- **Example:**
  ```swift
  // The second face of a solid created by a named operation
  let secondFace = TopologyRef.containedIn(
      parent: .createdBy(operationName: "make_box", kind: .solid),
      kind: .face,
      occurrence: 1
  )
  ```

---

### `TopologyRef.splitOf(original:occurrence:)`

The Nth replacement produced by the operation that split `original` into multiple nodes.

```swift
case splitOf(original: TopologyRef, occurrence: Int)
```

Typical use: picking one of two halves after an edge or face split.

- **Parameters:**
  - `original` — recipe for the node before the split.
  - `occurrence` — index into the replacement list produced by the split.
- **Example:**
  ```swift
  // Second half of an edge that was split
  let halfEdge = TopologyRef.splitOf(
      original: .literal(TopologyGraph.NodeRef(kind: .edge, index: 5)),
      occurrence: 1
  )
  ```

---

## NodeRef.sentinel

A sentinel `NodeRef` for recording pure creations that have no meaningful ancestor.

```swift
public static let sentinel = TopologyGraph.NodeRef(kind: .solid, index: -1)
```

Matches OCCT's default-constructed `BRepGraph_NodeId` (kind `.solid`, index `-1`). `isValid` is `false` on the sentinel.

---

## TopologyResolutionError

Errors returned from `TopologyGraph.resolve(_:)` when a recipe cannot be evaluated.

```swift
public enum TopologyResolutionError: Error, Sendable, Hashable
```

### `TopologyResolutionError.ancestorMissing(_:)`

The parent ref in a `.containedIn` or `.splitOf` recipe could not itself be resolved.

```swift
case ancestorMissing(TopologyRef)
```

---

### `TopologyResolutionError.kindMismatch(expected:found:)`

A resolved node has a different `NodeKind` than expected.

```swift
case kindMismatch(expected: TopologyGraph.NodeKind, found: TopologyGraph.NodeKind)
```

---

### `TopologyResolutionError.occurrenceOutOfRange(_:available:requested:)`

The requested `occurrence` index exceeds the number of matching candidates.

```swift
case occurrenceOutOfRange(TopologyRef, available: Int, requested: Int)
```

- **Associated values:** The failing ref, how many candidates exist, what was asked for.

---

### `TopologyResolutionError.operationNotFound(_:)`

No history record with the given `operationName` was found.

```swift
case operationNotFound(String)
```

---

### `TopologyResolutionError.noCurrentDescendant(_:)`

The original node in a `.splitOf` recipe was found in history but no history record shows it as an original with multiple replacements.

```swift
case noCurrentDescendant(TopologyRef)
```

---

### `TopologyResolutionError.invalid(_:)`

The ref is structurally invalid (e.g. a `.literal` wrapping a `NodeRef` with `index < 0`).

```swift
case invalid(TopologyRef)
```

---

## resolve on TopologyGraph

### `TopologyGraph.resolve(_:)`

Resolve a `TopologyRef` recipe against the graph's current state.

```swift
public func resolve(_ ref: TopologyRef) -> Result<NodeRef, TopologyResolutionError>
```

Recipes are evaluated lazily — `resolve` performs the full lookup on every call, walking history records as needed. For hot paths, cache the resolved `NodeRef` and invalidate on any mutation.

- **Parameters:** `ref` — the recipe to evaluate.
- **Returns:** `.success(NodeRef)` when the entity can be found; `.failure(TopologyResolutionError)` when it cannot.
- **Note:** Pure Swift — no bridge call. The evaluation walks `historyRecords` and `childIndices` (a public helper on `TopologyGraph` defined in `ConstructionEntity.swift`).
- **Example:**
  ```swift
  guard let graph = TopologyGraph(shape: myShape) else { return }
  let ref = TopologyRef.containedIn(
      parent: .literal(TopologyGraph.NodeRef(kind: .solid, index: 0)),
      kind: .face,
      occurrence: 0
  )
  switch graph.resolve(ref) {
  case .success(let node):
      print("Resolved to face index:", node.index)
  case .failure(let err):
      print("Resolution failed:", err)
  }
  ```

---

## currentForms on TopologyGraph

### `TopologyGraph.currentForms(of:)`

All current (live-leaf) descendants of `node`, in deterministic order.

```swift
public func currentForms(of node: NodeRef) -> [NodeRef]
```

A descendant is "live" when it does not appear as an original in any subsequent history record — i.e. it is the final form of that branch. Returns an empty array when `node` has no derived descendants at all (it may itself still be live; use `findDerivedOrSelf` from the main graph API for that case).

- **Parameters:** `node` — the node to walk forward from.
- **Returns:** Live leaf descendants sorted by `(kind.rawValue, index)`, or `[]` if there are none.
- **Note:** Used internally by `.createdBy` resolution when `leafOccurrence` is non-nil. Callers can use it directly to enumerate all current forms of a node that may have been split by subsequent operations.
- **Example:**
  ```swift
  let seed = TopologyGraph.NodeRef(kind: .face, index: 2)
  let leaves = graph.currentForms(of: seed)
  if leaves.isEmpty {
      print("Face 2 has not been split")
  } else {
      print("Face 2 split into", leaves.count, "live faces")
  }
  ```
