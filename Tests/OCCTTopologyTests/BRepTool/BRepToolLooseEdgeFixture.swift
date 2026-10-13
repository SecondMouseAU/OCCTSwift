import Foundation
import Testing

@testable import OCCTSwift

/// A box whose every edge record carries tolerance 0.5 (vertices and faces stay at 1e-7), written
/// through the BREP text: an edge record reads `tolerance sameParameter sameRange degenerated`.
///
/// Shared by the BRepTool suites that need a loose-edge shape; the edge tolerance has no setter.
/// The record format is the one OCCT 8.0.1's BREP writer produces (verified on kernel.6). A format
/// change fails loudly: `edited != brep` returns nil here and every caller `#require`s the result.
func boxWithLooseEdges() -> Shape? {
    guard let box = Shape.box(width: 10, height: 10, depth: 10), let brep = box.toBREPString()
    else { return nil }
    let edited = brep.replacingOccurrences(of: "Ed\n 1e-07 1 1 0", with: "Ed\n 0.5 1 1 0")
    guard edited != brep else { return nil }
    return Shape.fromBREPString(edited)
}
