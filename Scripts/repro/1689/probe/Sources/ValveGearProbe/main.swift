// #1689's stated requirements, exactly: Shape.loadSTEP, Shape.writeSTEP, basic BRep construction,
// plus the tessellation a three.js consumer needs and which nothing has ever run on wasm.
//
// Written with explicit locals rather than chained optionals: the first draft used
// `box?.volume.map { ... } ?? false` and the wasm compiler answered
// "failed to produce diagnostic for expression; please submit a bug report" instead of a type
// error. That is worth knowing on its own, and it is not a reason to keep the chain.
import Foundation
import OCCTSwift

guard CommandLine.arguments.count >= 2 else { print("usage: probe <dir>"); exit(2) }
let dir = CommandLine.arguments[1]
var failures = 0

// @MainActor because a `var` at the top level of main.swift is main-actor isolated under the Swift 6
// language mode, while a `func` at the same level is not. Exactly what #2175's spike documented, and
// a consumer writing their first SwiftWasm executable hits it too.
@MainActor
func check(_ name: String, _ ok: Bool, _ detail: String) {
    let padded = name.padding(toLength: 22, withPad: " ", startingAt: 0)
    print("\(ok ? "PASS" : "FAIL")  \(padded)  \(detail)")
    if !ok { failures += 1 }
}

func near(_ value: Double?, _ expected: Double, _ tol: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tol
}

func show(_ value: Double?) -> String { value.map { String($0) } ?? "nil" }

// "basic BRep construction (makeBox, makeCylinder, etc.)"
let box = Shape.box(width: 40, height: 20, depth: 10)
check("box", near(box?.volume, 8000, 1e-6), "volume=\(show(box?.volume)) expected=8000.0")

let cyl = Shape.cylinder(radius: 5, height: 20)
let cylExpected = Double.pi * 25 * 20
check("cylinder", near(cyl?.volume, cylExpected, 1e-3),
      "volume=\(show(cyl?.volume)) expected=\(cylExpected)")

// A valve-gear-ish part: a bar with a hole through it, which is what a linkage is.
var linkage: Shape?
if let box, let cyl {
    linkage = box.subtracting(cyl)
}
let linkageVolume = linkage?.volume
if let v = linkageVolume {
    check("subtract (linkage)", v > 7000 && v < 8000, "volume=\(v), a bar minus a pin hole")
} else {
    check("subtract (linkage)", false, "nil")
}

// "Must expose: Shape.writeSTEP"
let stepPath = dir + "/linkage.step"
var wrote = 0
if let linkage {
    do {
        try Exporter.writeSTEP(shape: linkage, to: URL(fileURLWithPath: stepPath), name: "linkage")
        wrote = try Data(contentsOf: URL(fileURLWithPath: stepPath)).count
        check("writeSTEP", wrote > 0, "\(wrote) bytes at \(stepPath)")
    } catch {
        check("writeSTEP", false, "threw \(error)")
    }
} else {
    check("writeSTEP", false, "no shape")
}

// "Must expose: Shape.loadSTEP"
if wrote > 0 {
    do {
        let back = try Shape.load(fromPath: stepPath)
        let ok = near(back.volume, linkageVolume ?? .nan, 1e-6)
        check("loadSTEP", ok, "volume=\(show(back.volume)) faces=\(back.uniqueFaceCount)")
    } catch {
        check("loadSTEP", false, "threw \(error)")
    }
} else {
    check("loadSTEP", false, "nothing written")
}

// Bytes without a path, which is what a browser export actually needs.
if let linkage {
    do {
        let bytes = try Exporter.stepData(shape: linkage, name: "linkage")
        check("stepData (bytes out)", bytes.count > 0, "\(bytes.count) bytes, no path involved")
    } catch {
        check("stepData (bytes out)", false, "threw \(error)")
    }
}

// THE UNEXERCISED PATH. #1689 asks for three.js compatibility, which means tessellation: a browser
// app has to DISPLAY geometry, not only export it. #2175's six cases never touched meshing, so this
// is the first time Shape.mesh() and Mesh.vertices run on wasm. It goes straight through the WASI
// simd shim, because vertices and normals are [SIMD3<Float>].
if let linkage {
    if let m = linkage.mesh(linearDeflection: 0.5, angularDeflection: 0.5) {
        let verts = m.vertices
        let idx = m.indices
        let norms = m.normals
        let maxIndex = idx.max().map { Int($0) } ?? -1
        let finite = verts.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
        let ok = !verts.isEmpty && !idx.isEmpty && idx.count % 3 == 0
            && maxIndex < verts.count && finite
        check("mesh (three.js)", ok,
              "\(verts.count) verts, \(m.triangleCount) tris, \(idx.count) indices, "
                + "\(norms.count) normals, maxIndex=\(maxIndex), allFinite=\(finite)")
    } else {
        check("mesh (three.js)", false, "Shape.mesh returned nil")
    }
}

print("failures: \(failures)")
exit(Int32(failures))
