// #3526: Shape.edges() cost against faces() and vertices(), and against the per-index loop it used
// to be.
//
// `Shape.edges()` was `(0..<edgeCount).map { edge(at: $0) }`, and every `edge(at:)` goes through
// `OCCTShapeGetEdgeAtIndex` and `occtSubShapeAt`, which builds a whole `TopTools_IndexedMapOfShape`
// with `TopExp::MapShapes` to read one entry and throws it away. That is one map per edge, so the
// enumeration was quadratic in the edge count, while `faces()` and `vertices()` map once.
//
// This harness times all three enumerations, and the explicit per-index loop beside `edges()`, on
// compounds of the same primitive at four sizes (to show the growth rate) and on a boolean-built
// plate (to show the result is not an artefact of a compound of disjoint boxes). The loop row is
// the pre-fix `edges()` spelled out, so the before and after figures come from one build: after the
// fix `edges()` and the loop differ, before it they were the same code.
//
// Run with: swift run -c release Harnesses 3526-edges-enumeration
// (or without `-c release`, which is how the issue measured it: the C++ is optimised either way,
// so debug only changes the Swift side)
//
// See Scripts/repro/3526/README.md for the measured table and how it was taken.

import Foundation
import OCCTSwift

enum EdgesEnumerationTiming {
    static func run() {
        report("compound of boxes, growing", rows: boxRows())
        report("shapes with shared and seam edges", rows: otherRows())
        sibling()
    }
}

// MARK: - Timing

/// The best (smallest) wall-clock elapsed seconds over `passes` runs of `body`.
///
/// Read off the monotonic Dispatch clock. The smallest, not the mean: what is being measured is
/// the work, and anything above the minimum is the machine.
private func best(passes: Int, _ body: () -> Void) -> Double {
    var smallest = Double.infinity
    for _ in 0..<passes {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        smallest = min(smallest, Double(end - start) / 1_000_000_000)
    }
    return smallest
}

private func fmt(_ seconds: Double) -> String {
    if seconds >= 1 { return String(format: "%9.3f s ", seconds) }
    if seconds >= 0.001 { return String(format: "%9.3f ms", seconds * 1000) }
    return String(format: "%9.1f us", seconds * 1_000_000)
}

// MARK: - Fixtures

private struct Row {
    let name: String
    let shape: Shape
}

/// A compound of `count` unit boxes in a grid, translated so every box is its own TShape.
///
/// Edge count is 12 per box, face count 6, vertex count 8, so the three scale together.
private func boxes(_ count: Int) -> Shape {
    let box = Shape.box(width: 10, height: 10, depth: 10)!
    var parts: [Shape] = []
    for i in 0..<count {
        parts.append(box.translated(by: SIMD3(Double(i % 18) * 20, Double(i / 18) * 20, 0))!)
    }
    return Shape.compound(parts)!
}

private func boxRows() -> [Row] {
    [81, 162, 324, 648].map { Row(name: "\($0) boxes", shape: boxes($0)) }
}

private func otherRows() -> [Row] {
    var rows: [Row] = []

    // 1,000 cylinders: 3 edges each (two circles and a seam that two faces share), so the seam is
    // reached twice per face walk and must still be one entry.
    let cylinder = Shape.cylinder(radius: 4, height: 10)!
    var cylinders: [Shape] = []
    for i in 0..<1000 {
        cylinders.append(
            cylinder.translated(by: SIMD3(Double(i % 25) * 12, Double(i / 25) * 12, 0))!)
    }
    rows.append(Row(name: "1000 cylinders", shape: Shape.compound(cylinders)!))

    // A plate with a grid of through holes, cut in one boolean: a single solid whose edges are
    // shared between faces, the shape a real part has. Shape.box is centred on the origin, so the
    // grid is offset to sit inside the plate; the row reports the counts that resulted.
    let plate = Shape.box(width: 320, height: 520, depth: 10)!
    let drill = Shape.cylinder(radius: 4, height: 30)!
    var drills: [Shape] = []
    for i in 0..<400 {
        drills.append(
            drill.translated(
                by: SIMD3(-150 + Double(i % 20) * 15, -250 + Double(i / 20) * 24, -15))!)
    }
    if let tool = Shape.compound(drills), let drilled = plate.subtracting(tool) {
        rows.append(Row(name: "drilled plate", shape: drilled))
    } else {
        print("  (plate with holes could not be built; row skipped)")
    }
    return rows
}

// MARK: - Report

private func report(_ title: String, rows: [Row]) {
    print("\n== \(title) ==")
    print(
        "  \("shape".padding(toLength: 18, withPad: " ", startingAt: 0))"
            + "  edges  faces  verts"
            + "     edges()      loop of edge(at:)"
            + "     faces()    vertices()   edges()/faces()")

    for row in rows {
        let shape = row.shape
        let edgeCount = shape.edgeCount
        let faceCount = shape.faceCount
        let vertexCount = shape.vertexCount

        // The loop is quadratic, so it gets fewer passes than the linear enumerations.
        let loopSeconds = best(passes: 2) {
            let all = (0..<edgeCount).map { shape.edge(at: $0) }
            if all.count != edgeCount { print("  loop returned a short array") }
        }
        let edgesSeconds = best(passes: 5) {
            let all = shape.edges()
            if all.count != edgeCount { print("  edges() returned \(all.count), not \(edgeCount)") }
        }
        let facesSeconds = best(passes: 5) { _ = shape.faces() }
        let verticesSeconds = best(passes: 5) { _ = shape.vertices() }

        let name = row.name.padding(toLength: 18, withPad: " ", startingAt: 0)
        let ratio = edgesSeconds / max(facesSeconds, 1e-9)
        print(
            "  \(name)  \(pad(edgeCount))  \(pad(faceCount))  \(pad(vertexCount))"
                + "  \(fmt(edgesSeconds))      \(fmt(loopSeconds))"
                + "  \(fmt(facesSeconds))  \(fmt(verticesSeconds))   \(String(format: "%8.1f", ratio))x"
        )
    }
}

private func pad(_ n: Int) -> String {
    String(n).padding(toLength: 5, withPad: " ", startingAt: 0)
}

/// The sibling of the defect (#3527): `Shape.measure()` read each edge length through `edge(at:)`.
///
/// It was a loop of `edge(at:)`, the same one-map-per-edge cost, and now reads the lengths off one
/// `edges()` pass. The loop column is that old cost spelled out and still runs, so a build before
/// the #3527 change reports `measure()` close to it and a build after reports `measure()` far
/// below it, the face work being what is left.
private func sibling() {
    print(
        "\n== Shape.measure() (#3527): lengths via a loop of edge(at:) against one edges() pass ==")
    for count in [162, 324] {
        let shape = boxes(count)
        let edgeCount = shape.edgeCount
        let measureSeconds = best(passes: 3) { _ = shape.measure() }
        let lengthsViaLoop = best(passes: 2) {
            _ = (0..<edgeCount).map { shape.edge(at: $0)?.length ?? 0 }
        }
        let lengthsViaEdges = best(passes: 5) { _ = shape.edges().map { $0.length } }
        print(
            "  \(count) boxes (\(edgeCount) edges)  measure() \(fmt(measureSeconds))"
                + "  lengths via loop \(fmt(lengthsViaLoop))"
                + "  lengths via edges() \(fmt(lengthsViaEdges))")
    }
}
