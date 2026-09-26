// #2175: the Phase 0 go/no-go spike.
//
// Swift, over the OCCTSwift public API, over the C bridge, over OCCT, in one
// wasm32-unknown-wasip1 module. Five calls: box, fuse, STEP export, STEP import, and one that
// must FAIL, in two halves.
//
// Everything here goes through the published Swift surface (`Shape`, `Exporter`,
// `OCCTDiagnostics`). Nothing calls the bridge directly, because the question this gate answers is
// whether a SwiftWasm application consuming OCCTSwift as a SwiftPM dependency can do real CAD
// work, not whether the C functions are reachable.
//
// argv[1] is a directory the host has preopened. Under wasmkit that is `--dir <path>`, a real
// directory on disk; in a browser it is a `PreopenDirectory` of in-memory `File`s. The Swift code
// cannot tell the two apart, which is the point.
//
// Exit status is the number of failed cases, so the runner needs no output parsing to know.

import Foundation
import OCCTSwift

// MARK: - reporting

var failures = 0

// `@MainActor` because a `var` at the top level of `main.swift` is main-actor isolated under the
// Swift 6 language mode, while a `func` at the same level is not, so an unannotated `report` is
// `main actor-isolated var 'failures' can not be mutated from a nonisolated context`.
@MainActor
func report(_ name: String, _ passed: Bool, _ detail: String) {
    let verdict = passed ? "PASS" : "FAIL"
    if !passed { failures += 1 }
    let padded = name.padding(toLength: 24, withPad: " ", startingAt: 0)
    print("case \(padded) \(verdict)  \(detail)")
}

/// Compare a measured double against an expected one, so a report cannot read as a pass on a
/// value nobody computed.
func close(_ measured: Double?, _ expected: Double, _ tolerance: Double = 1e-6) -> Bool {
    guard let measured else { return false }
    return abs(measured - expected) <= tolerance
}

guard CommandLine.arguments.count >= 2 else {
    print("usage: OCCTWasmSpike <preopened-directory>")
    exit(2)
}
let workDir = CommandLine.arguments[1]
let stepPath = workDir + "/spike-fused.step"
let brokenPath = workDir + "/spike-broken.step"

print("OCCTSwift wasm spike, wasm32-unknown-wasip1: Swift -> OCCTSwift -> bridge -> OCCT")
print("preopened directory: \(workDir)")

// MARK: - case 1, box
//
// Pure compute. Answers whether OCCT runs at all on this target: static initialisation under
// `_start`, the Standard_Type registry, TopoDS/BRep construction.

let box = Shape.box(width: 10, height: 20, depth: 30)
if let box {
    // Volume 6000, 6 faces, 12 edges, 8 vertices. The counts are the DEDUPLICATED ones
    // (`uniqueFaceCount`, `uniqueEdgeCount`): a TopExp_Explorer visits a shared sub-shape once per
    // owner and answers 24 for a box's edges, which is the fixture trap #2174's probe fell into.
    let ok =
        close(box.volume, 6000) && box.uniqueFaceCount == 6 && box.uniqueEdgeCount == 12
        && box.vertexCount == 8
    report(
        "box", ok,
        "10x20x30 volume=\(box.volume.map { String($0) } ?? "nil") "
            + "faces=\(box.uniqueFaceCount) edges=\(box.uniqueEdgeCount) "
            + "vertices=\(box.vertexCount)")
} else {
    report("box", false, "Shape.box returned nil")
}

// MARK: - case 2, fuse
//
// Exercises the allocator hard, which is the risk #2171 recorded and could not probe and #2174
// answered for `operator new` alone. Two unit cubes overlapping in one octant: 1000 + 1000 - 125.

let cubeA = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
let cubeB = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
var fused: Shape?
if let cubeA, let cubeB {
    fused = cubeA.fused(with: cubeB, tolerance: 0)
    if let fused {
        let ok = close(fused.volume, 1875, 1e-6) && fused.isValid
        report(
            "fuse", ok,
            "two 10-cubes overlapping in one octant, volume=\(fused.volume.map { String($0) } ?? "nil") "
                + "expected=1875.0 faces=\(fused.uniqueFaceCount) valid=\(fused.isValid)")
    } else {
        report("fuse", false, "Shape.fused returned nil")
    }
} else {
    report("fuse", false, "could not build the two operands")
}

// MARK: - case 3, STEP export
//
// String and file I/O across the WASI boundary, and the first write this stack has done from
// Swift. `Exporter.writeSTEP` takes a `URL`; the path inside it resolves against the preopened
// directory and nothing else, because a WASI module has no filesystem beyond its preopens.

var exportedBytes = 0
if let fused {
    do {
        try Exporter.writeSTEP(
            shape: fused, to: URL(fileURLWithPath: stepPath), name: "OCCTWasmSpike")
        let data = try Data(contentsOf: URL(fileURLWithPath: stepPath))
        exportedBytes = data.count
        // A STEP file that is present and empty is the failure this would otherwise read as a
        // pass, so assert on the header rather than on existence.
        let text = String(decoding: data.prefix(64), as: UTF8.self)
        let ok = exportedBytes > 0 && text.hasPrefix("ISO-10303-21;")
        report(
            "step-export", ok,
            "wrote \(stepPath) bytes=\(exportedBytes) header=\(text.split(separator: "\n").first ?? "")"
        )
    } catch {
        report("step-export", false, "threw \(error)")
    }
} else {
    report("step-export", false, "no shape to write")
}

// MARK: - case 4, STEP import
//
// The READ side of the preopen question, which nothing in this effort had touched: export writes,
// import must open and read a file the host provides. It also runs `Interface_Static` under the
// #2170 shim's no-op locks on the read path, and allocates at a scale export does not reach.

if exportedBytes > 0 {
    do {
        let reread = try Shape.load(fromPath: stepPath)
        // Round-trip against case 2's own numbers rather than against a literal, so a STEP file
        // that parses into the wrong solid cannot pass.
        let ok =
            close(reread.volume, fused?.volume ?? .nan, 1e-6)
            && reread.uniqueFaceCount == (fused?.uniqueFaceCount ?? -1)
        report(
            "step-import", ok,
            "read back volume=\(reread.volume.map { String($0) } ?? "nil") "
                + "faces=\(reread.uniqueFaceCount) against the written shape's "
                + "\(fused?.volume.map { String($0) } ?? "nil")/\(fused?.uniqueFaceCount ?? -1)")
    } catch {
        report("step-import", false, "threw \(error)")
    }
} else {
    report("step-import", false, "nothing was exported to read back")
}

// MARK: - case 5a, the must-fail call: a raise crossing OCCT into the bridge
//
// THE MOST IMPORTANT CASE. #2171 measured that a translation unit built without
// WASM_CXX_EH_FLAGS returns correct boxes, correct fuses and correct STEP files, and answers every
// error by trapping the module or leaking every Handle between the raise and the bridge, with no
// diagnostic anywhere. Nothing in cases 1 to 4 can distinguish that build from a correct one.
//
// `BRepPrimAPI_MakeBox` with zero extents throws Standard_DomainError from BRepPrim_GWedge.cxx, a
// TKPrim object of the archive, and `OCCTShapeCreateBox`'s outermost `catch (...)` is in the
// bridge. So the unwinder crosses from OCCT into the bridge, and the refusal arrives in Swift as
// `nil` rather than as a trap. #2174 proved the same raise reaches a C++ `main`; this is the first
// time it is asked to reach SWIFT.
//
// The diagnostic channel (#1161/#2077) is what makes this an assertion rather than a hope: a nil
// with no record would also be what a bridge that never entered OCCT returns.

let (degenerate, raiseDiagnostics) = OCCTDiagnostics.capturing {
    Shape.box(width: 0, height: 0, depth: 0)
}
let raiseOK =
    degenerate == nil && raiseDiagnostics.count == 1
    && raiseDiagnostics[0].kind == .occtFailure
    && !raiseDiagnostics[0].exceptionType.isEmpty
report(
    "must-fail-raise", raiseOK,
    "Shape.box(0,0,0) -> \(degenerate == nil ? "nil" : "A SHAPE"), "
        + "records=\(raiseDiagnostics.count) "
        + "\(raiseDiagnostics.map { "[\($0.function): \($0.exceptionType): \($0.message)]" }.joined(separator: " "))"
)

// MARK: - case 5b, the must-fail call: OCCT's OWN handler, no raise reaching the bridge
//
// The other half the issue asks for: a call whose documented failure mode is a false return
// rather than a raise. `IFSelect_WorkSession::ReadFile` wraps the parse in its own try/catch and
// turns a Standard_Failure into IFSelect_RetFail, which the bridge reports as a status and Swift
// throws as `ImportError.readFailed`.
//
// That handler is inside OCCT's own translation units, so it is exactly the thing #2171 says
// disappears with no diagnostic if the exception flags miss a file. The discriminating assertion
// is the pair: a refusal reaches Swift AND the bridge's own capture stays EMPTY, because nothing
// propagated as far as the bridge. A build whose OCCT missed the flags would either trap here or
// record at the bridge instead.

do {
    try Data("NOT A STEP FILE, not even close.\n".utf8).write(
        to: URL(fileURLWithPath: brokenPath))
    let (outcome, internalDiagnostics) = OCCTDiagnostics.capturing {
        () -> Result<Shape, Error> in
        do { return .success(try Shape.load(fromPath: brokenPath)) } catch { return .failure(error) }
    }
    switch outcome {
    case .success:
        report("must-fail-internal", false, "a malformed STEP file imported successfully")
    case .failure(let error):
        let ok = internalDiagnostics.isEmpty
        report(
            "must-fail-internal", ok,
            "malformed STEP refused as \(error), bridge records=\(internalDiagnostics.count) "
                + "(expected 0: OCCT's own handler turned the failure into a status)")
    }
} catch {
    report("must-fail-internal", false, "could not stage the malformed file: \(error)")
}

// MARK: - the bytes-out convenience, reported and not gated
//
// `Exporter.stepData(shape:)` already gives a browser host bytes without a path, by writing to
// `FileManager.default.temporaryDirectory` and reading back. Whether that directory is reachable
// is a property of the host's preopens, not of the API, so this is REPORTED rather than asserted:
// it is a finding for the memo either way. See Scripts/repro/2175/README.md.

if let fused {
    do {
        let bytes = try Exporter.stepData(shape: fused, name: "OCCTWasmSpike")
        print(
            "note stepData                 bytes=\(bytes.count) via "
                + "FileManager.default.temporaryDirectory = \(FileManager.default.temporaryDirectory.path)"
        )
    } catch {
        print(
            "note stepData                 unavailable: \(error) "
                + "(temporaryDirectory = \(FileManager.default.temporaryDirectory.path))")
    }
}

print("failures: \(failures)")
exit(Int32(failures))
