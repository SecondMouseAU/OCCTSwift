//  BRepGraphNodeRef.swift
//
//  The two value types a graph-free build still needs: `TopologyRef`, `ConstructionPlane` and the
//  other recipe types name nodes by `BRepGraph.NodeKind` and `BRepGraph.NodeRef`, and neither
//  touches the OCCT package. They live here, outside `BRepGraph.swift`, which Package.swift leaves
//  out against a kernel without the BRepGraph package (OCCT 8.1 withdrew it, OCCT#1628), so the
//  recipes compile there while everything that resolves one against a graph does not.

extension BRepGraph {

    /// Node kind enumeration matching OCCT BRepGraph_NodeId::Kind.
    ///
    /// Topology kinds 0–5 are core hierarchy; 6/7 are containers; 8 is the
    /// face-context coedge entity. Assembly kinds (Product, Occurrence) start
    /// at 10, leaving slot 9 reserved for future topology extension.
    public enum NodeKind: Int32, Sendable, Codable {
        case solid = 0
        case shell = 1
        case face = 2
        case wire = 3
        case edge = 4
        case vertex = 5
        case compound = 6
        case compSolid = 7
        case coedge = 8
        case product = 10
        case occurrence = 11
    }

    /// A (kind, index) pair identifying a node in a `BRepGraph`.
    ///
    /// This is the Swift mirror of OCCT's `BRepGraph_NodeId`. Two pairs with the
    /// same kind+index refer to the same node **within a given graph instance**;
    /// across graph rebuilds you have to translate through the history records.
    public struct NodeRef: Sendable, Hashable, Codable {
        public let kind: NodeKind
        public let index: Int

        public init(kind: NodeKind, index: Int) {
            self.kind = kind
            self.index = index
        }

        public var isValid: Bool { index >= 0 }
    }
}
