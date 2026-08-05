// Cluster A census (#664): does a public entry point read the deduplicated sub-shape map or the
// raw TopExp_Explorer, and what does it return on a shape with duplicated orientations?
//
// This is the DYNAMIC half of the census: it builds the fixtures with the real Shape/Face/Wire
// public API, calls every entry point identified by the Swift-side + bridge-side inventory sweep,
// and prints the measured table. See README.md for the method, the full table and the
// conclusions; `classify_topexp_sites.py` is the STATIC half (a source-level cross-check), and the
// README records where the two disagree.
//
// Run with: swift run ClusterACensus

import Foundation
import OCCTSwift
import simd

// MARK: - Fixtures

enum Fixture {
    /// A single 10mm box, origin-centred (-5...5 on every axis). No sub-shape here is reachable
    /// from more than one PARENT SHAPE, but every edge is still reachable from two adjacent faces
    /// and every vertex from three edges within the one solid -- #502's own box measurement (24
    /// edge occurrences over 12 distinct, 48 vertex occurrences over 8 distinct).
    static func plainBox() -> Shape {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            fatalError("Shape.box failed")
        }
        return box
    }

    /// Two solids sharing one cut face, from one BRepAlgoAPI_Splitter run -- the exact
    /// construction Tests/OCCTTopologyTests/Issue614FaceOrientationTests.swift uses (measured
    /// there: 11 distinct faces, 12 face occurrences). `order` controls which half is compounded
    /// first, which is #642's whole claim: AAG answers differently depending on this order alone.
    static func splitBoxCompound(order: CompoundOrder) -> Shape {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
              let plate = Shape.face(from: Wire.rectangle(width: 60, height: 60)!),
              let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
              let knife = upright.translated(by: SIMD3(10, 0, 0)),
              let pieces = block.split(by: knife),
              pieces.count == 2
        else {
            fatalError("could not build the split-box fixture")
        }
        let ordered = order == .asSplit ? pieces : pieces.reversed()
        guard let compound = Shape.compound(Array(ordered)) else {
            fatalError("Shape.compound failed")
        }
        return compound
    }

    enum CompoundOrder: String { case asSplit = "order A (lower, upper)", reversed = "order B (upper, lower)" }

    /// A second two-solid split, cut HORIZONTALLY (z=4 through an origin-centred 10mm box) rather
    /// than down the middle. #642's own measurement ("upward+horizontal node set [2,8] vs [2]")
    /// needs the SHARED wall itself to be horizontal, which `splitBoxCompound` above is not: that
    /// fixture cuts with a VERTICAL plane, so its shared wall's normal is horizontal-axis (X), not
    /// vertical, and isHorizontal()/isUpward() never look at the duplicated face at all. Measuring
    /// only that fixture would silently miss #642's actual claim -- this is exactly the kind of gap
    /// a census is supposed to catch, not repeat.
    static func horizontalSplitBoxCompound(order: CompoundOrder) -> Shape {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
              let pieces = block.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
              pieces.count == 2
        else {
            fatalError("could not build the horizontal split-box fixture")
        }
        let ordered = order == .asSplit ? pieces : pieces.reversed()
        guard let compound = Shape.compound(Array(ordered)) else {
            fatalError("Shape.compound failed")
        }
        return compound
    }
}

// #651 deprecated `nbEdges`/`nbFaces`/`nbVertices`, which now forward to
// `edgeCount`/`faceCount`/`vertexCount`. The census still measures them deliberately: its job is to
// record what the public API does, and a deprecated spelling is public API until it is removed.
//
// They are grouped into one deprecated function because a deprecated context does not warn about
// the deprecated things it calls. Read inline instead, they put 38 deprecation warnings into every
// `swift build` in the repo, since this target is wired into the root manifest and builds on every
// push (#694). Grouped, the cost is one warning at the single call site below, which is the honest
// residue: the census really does use a deprecated API on purpose.
//
// When the deprecation cycle removes the three properties this stops compiling, which is the right
// prompt to drop these rows rather than silently losing them.
@available(*, deprecated, message: "Measures #651's deprecated counters deliberately.")
func recordDeprecatedCounterRows() {
    record("vertex", "nbVertices (#651: fixed, now forwards to vertexCount)",
           plainBox: box.nbVertices, orderA: compoundA.nbVertices, orderB: compoundB.nbVertices,
           note: "deprecated, renamed: \"vertexCount\"; was occurrence (48/96/96) before #651")
    record("edge", "nbEdges (#651: fixed, now forwards to edgeCount)",
           plainBox: box.nbEdges, orderA: compoundA.nbEdges, orderB: compoundB.nbEdges,
           note: "deprecated, renamed: \"edgeCount\"; was occurrence (24/48/48) before #651")
    record("face", "nbFaces (#651: fixed, now forwards to faceCount)",
           plainBox: box.nbFaces, orderA: compoundA.nbFaces, orderB: compoundB.nbFaces,
           note: "deprecated, renamed: \"faceCount\"; was occurrence (6/12/12) before #651, agreeing with faceCount on a plain box only because no face is shared there")
}

// MARK: - Report plumbing

struct Row {
    let family: String
    let entryPoint: String
    let plainBox: String
    let orderA: String
    let orderB: String
    let note: String
}

nonisolated(unsafe) var rows: [Row] = []

func record(_ family: String, _ entryPoint: String, plainBox: Any, orderA: Any, orderB: Any, note: String = "") {
    rows.append(Row(family: family, entryPoint: entryPoint,
                     plainBox: "\(plainBox)", orderA: "\(orderA)", orderB: "\(orderB)", note: note))
}

// MARK: - Fixtures under measurement

let box = Fixture.plainBox()
let compoundA = Fixture.splitBoxCompound(order: .asSplit)
let compoundB = Fixture.splitBoxCompound(order: .reversed)
let hCompoundA = Fixture.horizontalSplitBoxCompound(order: .asSplit)
let hCompoundB = Fixture.horizontalSplitBoxCompound(order: .reversed)

// MARK: - VERTEX family

record("vertex", "vertexCount (dedup canonical)",
       plainBox: box.vertexCount, orderA: compoundA.vertexCount, orderB: compoundB.vertexCount)
record("vertex", "vertices().count (dedup)",
       plainBox: box.vertices().count, orderA: compoundA.vertices().count, orderB: compoundB.vertices().count)
record("vertex", "uniqueVertexCount (alias of vertexCount)",
       plainBox: box.uniqueVertexCount, orderA: compoundA.uniqueVertexCount, orderB: compoundB.uniqueVertexCount)
record("vertex", "subShapeCount(ofType: .vertex) (dedup canonical)",
       plainBox: box.subShapeCount(ofType: .vertex), orderA: compoundA.subShapeCount(ofType: .vertex),
       orderB: compoundB.subShapeCount(ofType: .vertex))
record("vertex", "contents.vertices (ShapeAnalysis_ShapeContents, occurrence)",
       plainBox: box.contents.vertices, orderA: compoundA.contents.vertices, orderB: compoundB.contents.vertices)
record("vertex", "contentsExtended().nbVertices (occurrence)",
       plainBox: box.contentsExtended().nbVertices, orderA: compoundA.contentsExtended().nbVertices,
       orderB: compoundB.contentsExtended().nbVertices)

// MARK: - EDGE family

record("edge", "edgeCount (dedup canonical)",
       plainBox: box.edgeCount, orderA: compoundA.edgeCount, orderB: compoundB.edgeCount)
record("edge", "edges().count (dedup)",
       plainBox: box.edges().count, orderA: compoundA.edges().count, orderB: compoundB.edges().count)
record("edge", "uniqueEdgeCount (alias of edgeCount)",
       plainBox: box.uniqueEdgeCount, orderA: compoundA.uniqueEdgeCount, orderB: compoundB.uniqueEdgeCount)
record("edge", "subShapeCount(ofType: .edge) (dedup canonical)",
       plainBox: box.subShapeCount(ofType: .edge), orderA: compoundA.subShapeCount(ofType: .edge),
       orderB: compoundB.subShapeCount(ofType: .edge))
record("edge", "contents.edges (ShapeAnalysis_ShapeContents, occurrence)",
       plainBox: box.contents.edges, orderA: compoundA.contents.edges, orderB: compoundB.contents.edges)
record("edge", "contentsExtended().nbEdges (occurrence)",
       plainBox: box.contentsExtended().nbEdges, orderA: compoundA.contentsExtended().nbEdges,
       orderB: compoundB.contentsExtended().nbEdges)

if let wireOfBox = box.wires.first {
    record("edge", "Shape(wire).edgeCount (dedup; a wire's own edges, not the parent solid's)",
           plainBox: wireOfBox.edgeCount, orderA: "n/a (single-solid wire)", orderB: "n/a",
           note: "a wire's own edges aren't shared cross-parent in these fixtures")
}

// MARK: - FACE family

record("face", "faceCount (dedup canonical, #541)",
       plainBox: box.faceCount, orderA: compoundA.faceCount, orderB: compoundB.faceCount)
record("face", "faces().count (dedup)",
       plainBox: box.faces().count, orderA: compoundA.faces().count, orderB: compoundB.faces().count)
record("face", "orientedFaces().count (occurrence, deliberate #614)",
       plainBox: box.orientedFaces().count, orderA: compoundA.orientedFaces().count,
       orderB: compoundB.orientedFaces().count,
       note: "documented, paired counterpart of faces() -- not a defect")
record("face", "uniqueFaceCount (alias of faceCount)",
       plainBox: box.uniqueFaceCount, orderA: compoundA.uniqueFaceCount, orderB: compoundB.uniqueFaceCount)
record("face", "subShapeCount(ofType: .face) (dedup canonical)",
       plainBox: box.subShapeCount(ofType: .face), orderA: compoundA.subShapeCount(ofType: .face),
       orderB: compoundB.subShapeCount(ofType: .face))
recordDeprecatedCounterRows()
record("face", "contents.faces (ShapeAnalysis_ShapeContents, occurrence)",
       plainBox: box.contents.faces, orderA: compoundA.contents.faces, orderB: compoundB.contents.faces)
record("face", "contentsExtended().nbFaces (occurrence)",
       plainBox: box.contentsExtended().nbFaces, orderA: compoundA.contentsExtended().nbFaces,
       orderB: compoundB.contentsExtended().nbFaces)
record("face", "contentsExtended().nbSharedFaces (location-discarding dedup, a THIRD rule)",
       plainBox: box.contentsExtended().nbSharedFaces, orderA: compoundA.contentsExtended().nbSharedFaces,
       orderB: compoundB.contentsExtended().nbSharedFaces)

record("face (occurrence-derived, already fixed)", "horizontalFaces().count (#614, reads orientedFaces())",
       plainBox: box.horizontalFaces().count, orderA: compoundA.horizontalFaces().count,
       orderB: compoundB.horizontalFaces().count)
record("face (occurrence-derived, already fixed)", "upwardFaces().count (#614, reads orientedFaces())",
       plainBox: box.upwardFaces().count, orderA: compoundA.upwardFaces().count,
       orderB: compoundB.upwardFaces().count)
record("face (occurrence-derived, already fixed)", "facesByZLevel() total (#614, reads horizontalFaces())",
       plainBox: box.facesByZLevel().values.reduce(0) { $0 + $1.count },
       orderA: compoundA.facesByZLevel().values.reduce(0) { $0 + $1.count },
       orderB: compoundB.facesByZLevel().values.reduce(0) { $0 + $1.count })
record("face (occurrence-derived, already fixed)", "upwardFaces().count [horizontal-cut fixture]",
       plainBox: box.upwardFaces().count, orderA: hCompoundA.upwardFaces().count,
       orderB: hCompoundB.upwardFaces().count,
       note: "corroborates #642's own table: #614's fix IS order-independent on the SAME fixture AAG is not")

// MARK: - #642: AAG rides the lossy faces()
//
// Measured on BOTH split fixtures. The vertical-cut compound (compoundA/B) shares a face whose
// normal is horizontal-axis, so it never touches isHorizontal()/isUpward() at all -- a census that
// stopped there would wrongly conclude AAG is order-INDEPENDENT. The horizontal-cut compound
// (hCompoundA/B) shares a face whose normal IS vertical, which is #642's actual claim.

let aagA = compoundA.buildAAG()
let aagB = compoundB.buildAAG()
record("face (AAG, #642)", "buildAAG().nodes.count [vertical-cut fixture]",
       plainBox: box.buildAAG().nodes.count, orderA: aagA.nodes.count, orderB: aagB.nodes.count)
let upwardHorizontalA = aagA.nodes.filter { $0.isUpward && $0.isHorizontal }.count
let upwardHorizontalB = aagB.nodes.filter { $0.isUpward && $0.isHorizontal }.count
record("face (AAG, #642)", "AAG upward+horizontal count [vertical-cut fixture]",
       plainBox: "n/a", orderA: upwardHorizontalA, orderB: upwardHorizontalB,
       note: "shared wall's normal is horizontal-axis here, so it never reaches isHorizontal() -- order-independent by construction, not by a fix")
record("face (AAG, #642)", "detectPocketsAAG().count [vertical-cut fixture]",
       plainBox: box.detectPocketsAAG().count, orderA: compoundA.detectPocketsAAG().count,
       orderB: compoundB.detectPocketsAAG().count,
       note: "no pocket geometry here regardless of order -- this fixture does not exercise #642")

let hAagA = hCompoundA.buildAAG()
let hAagB = hCompoundB.buildAAG()
record("face (AAG, #642)", "buildAAG().nodes.count [horizontal-cut fixture]",
       plainBox: box.buildAAG().nodes.count, orderA: hAagA.nodes.count, orderB: hAagB.nodes.count)
let hUpwardHorizontalIdxA = hAagA.nodes.enumerated().filter { $0.element.isUpward && $0.element.isHorizontal }.map(\.offset)
let hUpwardHorizontalIdxB = hAagB.nodes.enumerated().filter { $0.element.isUpward && $0.element.isHorizontal }.map(\.offset)
record("face (AAG, #642)", "AAG upward+horizontal NODE INDICES [horizontal-cut fixture]",
       plainBox: "n/a", orderA: "\(hUpwardHorizontalIdxA)", orderB: "\(hUpwardHorizontalIdxB)",
       note: "the shared wall's node keeps whichever half's orientation faces() reached first -- this is the #642 mechanism")
record("face (AAG, #642)", "detectPocketsAAG().count [horizontal-cut fixture]",
       plainBox: box.detectPocketsAAG().count, orderA: hCompoundA.detectPocketsAAG().count,
       orderB: hCompoundB.detectPocketsAAG().count,
       note: "THE #642 HEADLINE MEASUREMENT -- same geometry, order-dependent answer if it reproduces here")

// MARK: - WIRE family

record("wire", "wireCount (forwards to subShapeCount(.wire), dedup)",
       plainBox: box.wireCount, orderA: compoundA.wireCount, orderB: compoundB.wireCount)
record("wire", "wires.count (dedup)",
       plainBox: box.wires.count, orderA: compoundA.wires.count, orderB: compoundB.wires.count)
record("wire", "subShapeCount(ofType: .wire) (dedup canonical)",
       plainBox: box.subShapeCount(ofType: .wire), orderA: compoundA.subShapeCount(ofType: .wire),
       orderB: compoundB.subShapeCount(ofType: .wire))
record("wire", "contents.wires (occurrence)",
       plainBox: box.contents.wires, orderA: compoundA.contents.wires, orderB: compoundB.contents.wires)

// MARK: - SHELL family

record("shell", "shellCount (forwards to subShapeCount(.shell), dedup)",
       plainBox: box.shellCount, orderA: compoundA.shellCount, orderB: compoundB.shellCount)
record("shell", "shells.count (dedup)",
       plainBox: box.shells.count, orderA: compoundA.shells.count, orderB: compoundB.shells.count)
record("shell", "subShapeCount(ofType: .shell) (dedup canonical)",
       plainBox: box.subShapeCount(ofType: .shell), orderA: compoundA.subShapeCount(ofType: .shell),
       orderB: compoundB.subShapeCount(ofType: .shell))
record("shell", "outerShells.count (occurrence explorer, #439 restricts to per-solid use)",
       plainBox: box.outerShells.count, orderA: compoundA.outerShells.count, orderB: compoundB.outerShells.count)

// MARK: - SOLID family

record("solid", "solidCount (forwards to subShapeCount(.solid), dedup)",
       plainBox: box.solidCount, orderA: compoundA.solidCount, orderB: compoundB.solidCount)
record("solid", "solids.count (dedup)",
       plainBox: box.solids.count, orderA: compoundA.solids.count, orderB: compoundB.solids.count)
record("solid", "subShapeCount(ofType: .solid) (dedup canonical)",
       plainBox: box.subShapeCount(ofType: .solid), orderA: compoundA.subShapeCount(ofType: .solid),
       orderB: compoundB.subShapeCount(ofType: .solid))

// MARK: - Print the table

func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

let header = ["family", "entry point", "plain box", "order A", "order B", "note"]
let widths = [30, 62, 12, 10, 10, 90]

print(zip(header, widths).map { pad($0, $1) }.joined(separator: " | "))
print(widths.map { String(repeating: "-", count: $0) }.joined(separator: "-|-"))
for row in rows {
    let cells = [row.family, row.entryPoint, row.plainBox, row.orderA, row.orderB, row.note]
    print(zip(cells, widths).map { pad($0, $1) }.joined(separator: " | "))
}

print()
print("fixtures:")
print("  plain box:  Shape.box(width: 10, height: 10, depth: 10) -- one solid, no cross-parent sharing")
print("  order A:    Fixture.splitBoxCompound(order: .asSplit)   -- two solids, cut face shared, split-order kept")
print("  order B:    Fixture.splitBoxCompound(order: .reversed)  -- same geometry, compound member order reversed")
print()
print("row count: \(rows.count)")
