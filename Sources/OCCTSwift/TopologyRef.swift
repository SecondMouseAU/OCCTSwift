import OCCTPlatform

// MARK: - TopologyRef — references as recipes, not indices (#72 Phase 1)
//
// OCCT's TopoDS_Shape / BRepGraph NodeId is an index. After any mutation the
// index may refer to a different node, a deleted slot, or nothing at all. For
// agent-driven CAD where operations compose freely, this is unworkable: the
// agent would have to re-infer identity after every step.
//
// Following Onshape's FeatureScript design ("qCreatedBy", "qSplitBy", etc.),
// a TopologyRef is a *recipe* — the instructions for finding an entity — and
// resolution re-evaluates the recipe against the current graph state. When the
// recipe can't resolve, we surface the error rather than silently picking a
// plausible guess (Shapr3D / Onshape consensus).
//
// v1 scope: `.literal`, `.createdBy`, `.containedIn`, `.splitOf`. `.adjacentTo`
// and `.offsetFrom` are for ConstructionEntity (Phase 2) and don't belong here.

public indirect enum TopologyRef: Sendable, Hashable {
    /// Direct reference by current `(kind, index)`. Escape hatch — use sparingly;
    /// it bypasses recipe resolution and breaks on any graph mutation.
    case literal(BRepGraph.NodeRef)

    /// The Nth node of `kind` that appears as a replacement in a history record
    /// tagged with `operationName`. Deterministic order: (sequenceNumber,
    /// original (kind, index), position within replacements vector). The order is the same in
    /// every process, including over history absorbed by
    /// ``BRepGraph/add(_:absorbing:inputRoots:operationName:)``, which records its inputs in
    /// node-id order (#3038).
    ///
    /// When a single creation splits into multiple live descendants over
    /// subsequent mutations, `leafOccurrence` picks among them; defaults to 0
    /// (the first leaf in deterministic order). Use `leafOccurrence: nil` to
    /// disable forward-walk entirely and get the node as originally created —
    /// rarely what you want, but useful for history inspection.
    case createdBy(
        operationName: String,
        kind: BRepGraph.NodeKind,
        occurrence: Int = 0,
        leafOccurrence: Int? = 0)

    /// The Nth descendant of `kind` contained within `parent`.
    ///
    /// For a solid parent, descendants of kind `.face` are that solid's faces
    /// (via the graph's child iteration). Order is stable across mutations for
    /// unmodified parents; for mutated parents the order is whatever the graph
    /// reports post-mutation.
    case containedIn(
        parent: TopologyRef,
        kind: BRepGraph.NodeKind,
        occurrence: Int = 0)

    /// The Nth replacement produced by the operation that split `original` into
    /// multiple nodes. Typical use: picking one of two halves after an edge split.
    case splitOf(original: TopologyRef, occurrence: Int)
}

public enum TopologyResolutionError: Error, Sendable, Hashable {
    case ancestorMissing(TopologyRef)
    case kindMismatch(expected: BRepGraph.NodeKind, found: BRepGraph.NodeKind)
    case occurrenceOutOfRange(TopologyRef, available: Int, requested: Int)
    case operationNotFound(String)
    case noCurrentDescendant(TopologyRef)
    case invalid(TopologyRef)
}

extension BRepGraph.NodeRef {
    /// Sentinel for recording pure creations (no meaningful ancestor).
    ///
    /// Matches OCCT's default-constructed `BRepGraph_NodeId` — kind .solid, index -1.
    public static let sentinel = BRepGraph.NodeRef(kind: .solid, index: -1)
}
