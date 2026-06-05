// TopologyGraph+Attributes.swift
//
// Per-node attribute store + Codable graph snapshot for `TopologyGraph` (OCCTSwift #168).
//
// `TopologyGraph` nodes are bare `(kind, index)` pairs with no payload, and the type wraps an
// opaque C++ handle with no serialization. This file adds a pure Swift-side sidecar that lets
// callers attach arbitrary typed metadata to any `NodeRef` and round-trip it (export → edit →
// import) via `GraphSnapshot`. No C++ bridge change — the store never touches the C++ graph.
//
// The store is generic ("critical edge", "load-path face", material tags, …). Domain-specific
// typed accessors (e.g. reconstruction fit residuals) belong in the consuming package.

import Foundation
import OCCTBridge

// MARK: - AttrValue

extension TopologyGraph {
    /// A typed, Codable attribute value. Closed set keeps the snapshot round-trip lossless.
    public enum AttrValue: Codable, Hashable, Sendable {
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case ints([Int])         // e.g. a mesh-region triangle index set
        case doubles([Double])   // e.g. fitted-surface parameters

        // Convenience unwrap accessors — return nil on type mismatch.
        public var boolValue: Bool? { if case let .bool(v) = self { return v } else { return nil } }
        public var intValue: Int? { if case let .int(v) = self { return v } else { return nil } }
        public var doubleValue: Double? { if case let .double(v) = self { return v } else { return nil } }
        public var stringValue: String? { if case let .string(v) = self { return v } else { return nil } }
        public var intsValue: [Int]? { if case let .ints(v) = self { return v } else { return nil } }
        public var doublesValue: [Double]? { if case let .doubles(v) = self { return v } else { return nil } }
    }
}

// MARK: - NodeAttributeStore

/// Per-node attribute bag keyed by ``TopologyGraph/NodeRef``.
///
/// Keys are caller-namespaced strings (e.g. `"reconstruct.residualRMS"`). Encodes as a
/// deterministically-ordered array of `{node, attrs}` entries — JSON object keys must be
/// strings, and the sorted order keeps snapshots diffable and round-trips stable.
public struct NodeAttributeStore: Codable, Sendable, Equatable {
    public private(set) var storage: [TopologyGraph.NodeRef: [String: TopologyGraph.AttrValue]]

    public init(storage: [TopologyGraph.NodeRef: [String: TopologyGraph.AttrValue]] = [:]) {
        self.storage = storage
    }

    /// All attributes on a node (empty dictionary if none).
    public subscript(node: TopologyGraph.NodeRef) -> [String: TopologyGraph.AttrValue] {
        get { storage[node] ?? [:] }
        set {
            if newValue.isEmpty { storage[node] = nil } else { storage[node] = newValue }
        }
    }

    /// Read one attribute, or nil if unset.
    public func value(_ key: String, for node: TopologyGraph.NodeRef) -> TopologyGraph.AttrValue? {
        storage[node]?[key]
    }

    /// Set one attribute.
    public mutating func set(_ key: String, _ value: TopologyGraph.AttrValue, for node: TopologyGraph.NodeRef) {
        storage[node, default: [:]][key] = value
    }

    /// Remove one attribute. Drops the node entry entirely once its last attribute is cleared.
    public mutating func clear(_ key: String, for node: TopologyGraph.NodeRef) {
        guard var attrs = storage[node] else { return }
        attrs[key] = nil
        storage[node] = attrs.isEmpty ? nil : attrs
    }

    /// Remove every attribute on a node.
    public mutating func removeAll(for node: TopologyGraph.NodeRef) {
        storage[node] = nil
    }

    /// Number of nodes carrying at least one attribute.
    public var annotatedNodeCount: Int { storage.count }

    // MARK: Codable (sorted arrays throughout, so element ORDER is deterministic; combine
    // with `JSONEncoder.outputFormatting = .sortedKeys` — or `GraphSnapshot.canonicalEncoder()`
    // — for byte-stable, diffable output. JSONEncoder hash-orders object keys otherwise.)

    /// One `key: value` attribute pair. Encoding attributes as a sorted array (rather than a
    /// `[String: AttrValue]` dictionary) avoids JSON's non-deterministic dictionary key order.
    private struct KeyValue: Codable {
        let key: String
        let value: TopologyGraph.AttrValue
    }

    private struct Entry: Codable {
        let node: TopologyGraph.NodeRef
        let attrs: [KeyValue]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let entries = try container.decode([Entry].self)
        var dict: [TopologyGraph.NodeRef: [String: TopologyGraph.AttrValue]] = [:]
        for e in entries where !e.attrs.isEmpty {
            dict[e.node] = Dictionary(uniqueKeysWithValues: e.attrs.map { ($0.key, $0.value) })
        }
        self.storage = dict
    }

    public func encode(to encoder: Encoder) throws {
        let entries = storage
            .map { node, attrs in
                Entry(node: node,
                      attrs: attrs.map { KeyValue(key: $0.key, value: $0.value) }
                                  .sorted { $0.key < $1.key })
            }
            .sorted { lhs, rhs in
                if lhs.node.kind.rawValue != rhs.node.kind.rawValue {
                    return lhs.node.kind.rawValue < rhs.node.kind.rawValue
                }
                return lhs.node.index < rhs.node.index
            }
        var container = encoder.singleValueContainer()
        try container.encode(entries)
    }
}

// MARK: - GraphSnapshot

/// A persistable, round-trippable snapshot of a graph's attributes plus its source shape.
///
/// The graph *structure* is not serialized — it is re-derived deterministically by rebuilding
/// `TopologyGraph` from `brep`. Only the source shape (as a BREP string) and the attribute
/// store travel in the snapshot.
public struct GraphSnapshot: Codable, Sendable, Equatable {
    /// Current on-disk format version. Bump on any breaking schema change.
    public static let currentFormatVersion = 1

    /// BREP serialization of the source shape (re-derives the graph structure on load).
    public var brep: String
    /// Per-node attributes.
    public var attributes: NodeAttributeStore
    /// Format version this snapshot was written with.
    public var formatVersion: Int

    public init(brep: String, attributes: NodeAttributeStore, formatVersion: Int = GraphSnapshot.currentFormatVersion) {
        self.brep = brep
        self.attributes = attributes
        self.formatVersion = formatVersion
    }

    /// A `JSONEncoder` configured for byte-stable, diffable output (`.sortedKeys`).
    ///
    /// The attribute store already emits its arrays in deterministic order; pairing that with
    /// `.sortedKeys` makes the whole snapshot reproducible byte-for-byte across runs — useful
    /// for versioned sessions and golden-file tests.
    public static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

/// Errors raised while snapshotting or rebuilding a `TopologyGraph`.
public enum GraphSnapshotError: Error, Equatable, Sendable {
    /// The graph has no captured source shape to serialize (e.g. built from a handle directly).
    case noSourceShape
    /// The snapshot's BREP string could not be deserialized into a shape.
    case invalidBREP
    /// The graph could not be rebuilt from the deserialized shape.
    case graphBuildFailed
    /// The snapshot was written by a newer, unsupported format version.
    case unsupportedFormatVersion(Int)
}

// MARK: - snapshot / restore

extension TopologyGraph {
    /// Read one attribute on a node, or nil if unset.
    public func attribute(_ key: String, for node: NodeRef) -> AttrValue? {
        attributes.value(key, for: node)
    }

    /// Set one attribute on a node.
    public func setAttribute(_ key: String, _ value: AttrValue, for node: NodeRef) {
        attributes.set(key, value, for: node)
    }

    /// Export the attribute store + source shape for persistence or transport.
    ///
    /// - Throws: ``GraphSnapshotError/noSourceShape`` if no source BREP was captured.
    public func snapshot() throws -> GraphSnapshot {
        guard let brep = sourceBREP else { throw GraphSnapshotError.noSourceShape }
        return GraphSnapshot(brep: brep, attributes: attributes)
    }

    /// Rebuild a graph from a snapshot: deserialize the BREP, rebuild the graph (non-parallel
    /// for deterministic node indexing), and reattach the attributes.
    ///
    /// - Important: Attributes are keyed by `NodeRef` (`kind` + `index`). This relies on
    ///   `TopologyGraph(shape:)` producing identical node indexing for the same BREP — which is
    ///   why the rebuild pins `parallel: false`. See the round-trip determinism test.
    public convenience init(snapshot: GraphSnapshot) throws {
        guard snapshot.formatVersion <= GraphSnapshot.currentFormatVersion else {
            throw GraphSnapshotError.unsupportedFormatVersion(snapshot.formatVersion)
        }
        guard let shape = Shape.fromBREPString(snapshot.brep) else {
            throw GraphSnapshotError.invalidBREP
        }
        guard let handle = OCCTBRepGraphCreate(shape.handle, false) else {
            throw GraphSnapshotError.graphBuildFailed
        }
        self.init(borrowedHandle: handle)
        self.sourceBREP = snapshot.brep
        self.attributes = snapshot.attributes
    }
}
