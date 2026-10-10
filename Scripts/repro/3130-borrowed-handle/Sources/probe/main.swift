import Foundation
import OCCTBridge
@testable import OCCTSwift

// Variant is chosen by argv[1]: A (bare), W (withExtendedLifetime), R (read-only temp).
let variant = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "A"

@inline(never) func bare() -> Bool {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    OCCTEdgeSetSameParameter(edges[0].handle, false)
    return b.isValid
}
@inline(never) func fenced() -> Bool {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    withExtendedLifetime(edges) { OCCTEdgeSetSameParameter(edges[0].handle, false) }
    return b.isValid
}
// Read-only last-use variants: the owner is a local whose last use is the `.handle` load.
@inline(never) func readEdge() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    return OCCTEdgeGetLength(edges[0].handle)
}
@inline(never) func readEdgeFence() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    return withExtendedLifetime(edges) { OCCTEdgeGetLength(edges[0].handle) }
}
@inline(never) func readShape() -> Bool {
    let s = Shape.box(width: 10, height: 10, depth: 10)!
    return OCCTShapeIsValid(s.handle)
}
@inline(never) func readFace() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let faces = b.faces()
    return OCCTFaceGetArea(faces[0].handle, 1e-6)
}
@inline(never) func readEdgeLocal() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let e = b.edges()[0]
    return OCCTEdgeGetLength(e.handle)
}
@inline(never) func namedCopyMut() -> Bool {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    let e = edges[0]
    OCCTEdgeSetSameParameter(e.handle, false)
    return b.isValid
}
@inline(never) func tempFirst() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    return OCCTEdgeGetLength(b.edges().first!.handle)
}
@inline(never) func tempShape() -> Bool {
    return OCCTShapeIsValid(Shape.box(width: 10, height: 10, depth: 10)!.handle)
}
@inline(never) func loopMut() -> Bool {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    for e in b.edges().prefix(1) { OCCTEdgeSetSameParameter(e.handle, false) }
    return b.isValid
}
@inline(never) func namedWire() -> Double {
    let w = Wire.rectangle(width: 4, height: 3)!
    return OCCTWireGetLength(w.handle)
}
@inline(never) func namedShapeMut() -> Bool {
    let s = Shape.box(width: 10, height: 10, depth: 10)!
    return OCCTShapeIsValid(s.handle)
}
@inline(never) func withHandleMut() -> Bool {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    edges[0].withHandle { OCCTEdgeSetSameParameter($0, false) }
    return b.isValid
}
@inline(never) func withHandleReadEdge() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let edges = b.edges()
    return edges[0].withHandle { OCCTEdgeGetLength($0) }
}
@inline(never) func withHandleReadFace() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    let faces = b.faces()
    return faces[0].withHandle { OCCTFaceGetArea($0, 1e-6) }
}
@inline(never) func withHandleTemp() -> Double {
    let b = Shape.box(width: 10, height: 10, depth: 10)!
    return b.edges().first!.withHandle { OCCTEdgeGetLength($0) }
}
@inline(never) func withHandleTempShape() -> Bool {
    Shape.box(width: 10, height: 10, depth: 10)!.withHandle { OCCTShapeIsValid($0) }
}
// Split form: `let h = owner.handle`, owner unused afterwards, h used by several later calls.
@inline(never) func splitHandle() -> Int32 {
    let doc = Document.create()!
    let h = doc.handle
    var junk = [[UInt8]]()
    for i in 0..<64 { junk.append([UInt8](repeating: UInt8(i), count: 4096)) }
    var total: Int32 = 0
    for _ in 0..<3 { total += OCCTDocumentGetLayerCount(h) + Int32(junk.count) }
    return total
}
@inline(never) func splitHandleFenced() -> Int32 {
    let doc = Document.create()!
    let h = doc.handle
    var junk = [[UInt8]]()
    for i in 0..<64 { junk.append([UInt8](repeating: UInt8(i), count: 4096)) }
    var total: Int32 = 0
    withExtendedLifetime(doc) {
        for _ in 0..<3 { total += OCCTDocumentGetLayerCount(h) + Int32(junk.count) }
    }
    return total
}
@inline(never) func splitShape() -> Bool {
    let s = Shape.box(width: 10, height: 10, depth: 10)!
    let h = s.handle
    var junk = [[UInt8]]()
    for i in 0..<64 { junk.append([UInt8](repeating: UInt8(i), count: 4096)) }
    return OCCTShapeIsValid(h) && junk.count == 64
}
switch variant {
case "SPL": print("SPL total=\(splitHandle()) (expect 192)")
case "SPLF": print("SPLF total=\(splitHandleFenced()) (expect 192)")
case "SPS": print("SPS valid=\(splitShape()) (expect true)")
case "WHM": print("WHM isValid=\(withHandleMut()) (expect false)")
case "WHE": print("WHE len=\(withHandleReadEdge()) (expect 10)")
case "WHF": print("WHF area=\(withHandleReadFace()) (expect 100)")
case "WHT": print("WHT len=\(withHandleTemp()) (expect 10)")
case "WHS": print("WHS valid=\(withHandleTempShape()) (expect true)")
case "NCM": print("NCM isValid=\(namedCopyMut()) (expect false)")
case "TF": print("TF len=\(tempFirst()) (expect 10)")
case "TS": print("TS valid=\(tempShape()) (expect true)")
case "LM": print("LM isValid=\(loopMut()) (expect false)")
case "NW": print("NW len=\(namedWire()) (expect 14)")
case "NS": print("NS valid=\(namedShapeMut()) (expect true)")
case "RE": print("RE length=\(readEdge()) (expect 10)")
case "REF": print("REF length=\(readEdgeFence()) (expect 10)")
case "RS": print("RS valid=\(readShape()) (expect true)")
case "RF": print("RF area=\(readFace()) (expect 100)")
case "REL": print("REL length=\(readEdgeLocal()) (expect 10)")
case "A": print("A isValid=\(bare()) (expected false if the setter landed)")
case "W": print("W isValid=\(fenced()) (expected false)")
default: print("unknown")
}
