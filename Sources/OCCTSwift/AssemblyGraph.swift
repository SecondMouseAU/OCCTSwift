import Foundation
import OCCTBridge
import simd

/// Wrapper for XCAFDoc_AssemblyGraph, read-only graph of assembly structure.
public final class AssemblyGraph: @unchecked Sendable {
    private let handle: OCCTAssemblyGraphRef

    /// Create an assembly graph from a document.
    public init?(document: Document) {
        guard let h = OCCTAssemblyGraphCreate(document.handle) else { return nil }
        self.handle = h
    }

    deinit {
        OCCTAssemblyGraphRelease(handle)
    }

    /// Number of nodes in the graph.
    public var nodeCount: Int32 {
        OCCTAssemblyGraphNbNodes(handle)
    }

    /// Number of links in the graph.
    public var linkCount: Int32 {
        OCCTAssemblyGraphNbLinks(handle)
    }

    /// Number of root nodes.
    public var rootCount: Int32 {
        OCCTAssemblyGraphNbRoots(handle)
    }

    /// Assembly graph node type.
    ///
    /// Raw values match `XCAFDoc_AssemblyGraph::NodeType` exactly (`NodeType_UNDEFINED=0`,
    /// `NodeType_AssemblyRoot=1`, `NodeType_Subassembly=2`, `NodeType_Occurrence=3`,
    /// `NodeType_Part=4`, `NodeType_Subshape=5`).
    public enum NodeType: Int32 {
        /// Undefined node type.
        case undefined = 0
        /// Root node.
        case assemblyRoot = 1
        /// Intermediate node.
        case subassembly = 2
        /// Assembly/part occurrence node.
        case occurrence = 3
        /// Leaf node representing a part.
        case part = 4
        /// Subshape node.
        case subshape = 5
    }

    /// Get the type of a node by 1-based index.
    public func nodeType(at index: Int32) -> NodeType? {
        let raw = OCCTAssemblyGraphGetNodeType(handle, index)
        guard raw >= 0 else { return nil }
        return NodeType(rawValue: raw)
    }
}
