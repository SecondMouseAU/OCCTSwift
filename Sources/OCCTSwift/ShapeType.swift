import Foundation
import OCCTBridge
import simd

/// Topological type of a shape (matches OCCT TopAbs_ShapeEnum)
public enum ShapeType: Int, CustomStringConvertible, Sendable {
    case compound = 0
    case compSolid = 1
    case solid = 2
    case shell = 3
    case face = 4
    case wire = 5
    case edge = 6
    case vertex = 7
    case unknown = -1

    public var description: String {
        switch self {
        case .compound: return "Compound"
        case .compSolid: return "CompSolid"
        case .solid: return "Solid"
        case .shell: return "Shell"
        case .face: return "Face"
        case .wire: return "Wire"
        case .edge: return "Edge"
        case .vertex: return "Vertex"
        case .unknown: return "Unknown"
        }
    }
}
