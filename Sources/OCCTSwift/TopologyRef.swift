import Foundation

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
    /// original (kind, index), position within replacements vector).
    ///
    /// When a single creation splits into multiple live descendants over
    /// subsequent mutations, `leafOccurrence` picks among them; defaults to 0
    /// (the first leaf in deterministic order). Use `leafOccurrence: nil` to
    /// disable forward-walk entirely and get the node as originally created —
    /// rarely what you want, but useful for history inspection.
    case createdBy(operationName: String,
                   kind: BRepGraph.NodeKind,
                   occurrence: Int = 0,
                   leafOccurrence: Int? = 0)

    /// The Nth descendant of `kind` contained within `parent`.
    ///
    /// For a solid parent, descendants of kind `.face` are that solid's faces
    /// (via the graph's child iteration). Order is stable across mutations for
    /// unmodified parents; for mutated parents the order is whatever the graph
    /// reports post-mutation.
    case containedIn(parent: TopologyRef,
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
    /// Matches OCCT's default-constructed `BRepGraph_NodeId` — kind .solid, index -1.
    public static let sentinel = BRepGraph.NodeRef(kind: .solid, index: -1)
}

extension BRepGraph {
    /// Resolve a `TopologyRef` recipe against the graph's current state.
    ///
    /// Recipes are evaluated lazily — `resolve` performs the lookup every call,
    /// walking history records as needed. For hot paths, the caller can cache
    /// the resolved `NodeRef` and invalidate on any mutation.
    public func resolve(_ ref: TopologyRef) -> Result<NodeRef, TopologyResolutionError> {
        switch ref {
        case .literal(let node):
            return node.isValid
                ? .success(node)
                : .failure(.invalid(ref))

        case .createdBy(let opName, let kind, let occurrence, let leafOccurrence):
            return resolveCreatedBy(opName: opName, kind: kind,
                                    occurrence: occurrence,
                                    leafOccurrence: leafOccurrence,
                                    ref: ref)

        case .containedIn(let parent, let kind, let occurrence):
            return resolveContainedIn(parent: parent, kind: kind,
                                      occurrence: occurrence, ref: ref)

        case .splitOf(let original, let occurrence):
            return resolveSplitOf(original: original, occurrence: occurrence, ref: ref)
        }
    }

    // MARK: - Recipe evaluators

    private func resolveCreatedBy(opName: String,
                                  kind: NodeKind,
                                  occurrence: Int,
                                  leafOccurrence: Int? = 0,
                                  ref: TopologyRef) -> Result<NodeRef, TopologyResolutionError> {
        // Collect all replacement nodes of the target kind across matching records,
        // in deterministic order.
        let records = historyRecords
        let matching = records.enumerated().filter { $0.element.operationName == opName }
        if matching.isEmpty {
            return .failure(.operationNotFound(opName))
        }
        struct Candidate { let seq: Int; let origKey: NodeRef; let posInRepls: Int; let node: NodeRef }
        var candidates: [Candidate] = []
        for (_, record) in matching {
            // Stable key order over the mapping (otherwise dictionary iteration is nondeterministic).
            let sortedOrigs = record.mapping.keys.sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
                return lhs.index < rhs.index
            }
            for origKey in sortedOrigs {
                let repls = record.mapping[origKey] ?? []
                for (i, node) in repls.enumerated() where node.kind == kind {
                    candidates.append(Candidate(seq: record.sequenceNumber,
                                                origKey: origKey,
                                                posInRepls: i,
                                                node: node))
                }
            }
        }
        candidates.sort { a, b in
            if a.seq != b.seq { return a.seq < b.seq }
            if a.origKey.kind != b.origKey.kind { return a.origKey.kind.rawValue < b.origKey.kind.rawValue }
            if a.origKey.index != b.origKey.index { return a.origKey.index < b.origKey.index }
            return a.posInRepls < b.posInRepls
        }
        guard occurrence >= 0, occurrence < candidates.count else {
            return .failure(.occurrenceOutOfRange(ref, available: candidates.count, requested: occurrence))
        }
        let seed = candidates[occurrence].node
        // leafOccurrence == nil disables forward-walk; return the node as created.
        guard let leafOcc = leafOccurrence else {
            return .success(seed)
        }
        let leaves = currentForms(of: seed)
        // Empty leaves means the node has no descendants — return itself.
        if leaves.isEmpty {
            return .success(seed)
        }
        guard leafOcc >= 0, leafOcc < leaves.count else {
            return .failure(.occurrenceOutOfRange(ref, available: leaves.count, requested: leafOcc))
        }
        return .success(leaves[leafOcc])
    }

    private func resolveContainedIn(parent: TopologyRef,
                                    kind: NodeKind,
                                    occurrence: Int,
                                    ref: TopologyRef) -> Result<NodeRef, TopologyResolutionError> {
        let resolvedParent: NodeRef
        switch resolve(parent) {
        case .success(let n): resolvedParent = n
        case .failure: return .failure(.ancestorMissing(parent))
        }
        let indices = childIndices(rootKind: resolvedParent.kind,
                                    rootIndex: resolvedParent.index,
                                    targetKind: kind)
        guard occurrence >= 0, occurrence < indices.count else {
            return .failure(.occurrenceOutOfRange(ref, available: indices.count, requested: occurrence))
        }
        return .success(NodeRef(kind: kind, index: indices[occurrence]))
    }

    private func resolveSplitOf(original: TopologyRef,
                                occurrence: Int,
                                ref: TopologyRef) -> Result<NodeRef, TopologyResolutionError> {
        let resolvedOriginal: NodeRef
        switch resolve(original) {
        case .success(let n): resolvedOriginal = n
        case .failure: return .failure(.ancestorMissing(original))
        }
        // Find the record where resolvedOriginal appears as an original with >1 replacements.
        for record in historyRecords {
            guard let repls = record.mapping[resolvedOriginal], repls.count > 1 else { continue }
            guard occurrence >= 0, occurrence < repls.count else {
                return .failure(.occurrenceOutOfRange(ref, available: repls.count, requested: occurrence))
            }
            return .success(currentForm(of: repls[occurrence]))
        }
        return .failure(.noCurrentDescendant(ref))
    }

    /// Walk history forward from `node` to its current form. If `node` has
    /// derived descendants, return the first leaf in deterministic order.
    private func currentForm(of node: NodeRef) -> NodeRef {
        let leaves = currentForms(of: node)
        return leaves.first ?? node
    }

    /// All current (live-leaf) descendants of `node`, in deterministic order.
    ///
    /// A descendant is "live" when it doesn't appear as an original in any
    /// subsequent history record — i.e. it's the final form of that branch.
    /// Useful when a single creation has split into multiple live children
    /// (e.g., a face created by an extrude, then split by a subsequent fillet).
    public func currentForms(of node: NodeRef) -> [NodeRef] {
        let derived = findDerived(of: node)
        if derived.isEmpty { return [] }
        let allOriginals: Set<NodeRef> = historyRecords.reduce(into: []) { acc, rec in
            for key in rec.mapping.keys { acc.insert(key) }
        }
        // Deterministic sort: by kind, then index — stable across runs.
        let leaves = derived.filter { !allOriginals.contains($0) }
        return leaves.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.index < rhs.index
        }
    }
}
