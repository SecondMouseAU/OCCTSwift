import Foundation
import simd
import OCCTBridge

/// Wrapper for XCAFDoc_AssemblyGraph — read-only graph of assembly structure.
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
    public enum NodeType: Int32 {
        case node = 0
        case occurrence = 1
        case part = 2
        case instance = 3
        case subshape = 4
        case free = 5
    }

    /// Get the type of a node by 1-based index.
    public func nodeType(at index: Int32) -> NodeType? {
        let raw = OCCTAssemblyGraphGetNodeType(handle, index)
        guard raw >= 0 else { return nil }
        return NodeType(rawValue: raw)
    }
}
