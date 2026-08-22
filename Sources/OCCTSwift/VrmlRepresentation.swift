import Foundation
import OCCTBridge
import simd

/// VRML representation mode for export.
public enum VrmlRepresentation: Int32, Sendable {
    case shaded = 0
    case wireFrame = 1
    case both = 2
}
