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

import OCCTSwift

// FoundationEssentials, and the choice matters more than it looks. #2761's saving is
// ALL-OR-NOTHING PER MODULE: one linked file importing full Foundation pulls the
// internationalisation data back in, and that includes the CONSUMER'S OWN code, not just
// the package's. Measured here: with `import Foundation` on this line and every one of
// OCCTSwift's 220 files migrated, the module was 141,893,725 bytes, which is the
// unmigrated size. The saving only appears once this line moves too.
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

// The C library, for `exit`. Foundation re-exported it; FoundationEssentials does not.
#if canImport(Darwin)
    import Darwin
#elseif canImport(WASILibc)
    import WASILibc
#elseif canImport(Glibc)
    import Glibc
#endif

// MARK: - reporting

var failures = 0

// `@MainActor` because a `var` at the top level of `main.swift` is main-actor isolated under the
// Swift 6 language mode, while a `func` at the same level is not, so an unannotated `report` is
// `main actor-isolated var 'failures' can not be mutated from a nonisolated context`.
@MainActor
func report(_ name: String, _ passed: Bool, _ detail: String) {
    let verdict = passed ? "PASS" : "FAIL"
    if !passed { failures += 1 }
    // `padding(toLength:withPad:startingAt:)` is Foundation-only, and this is column alignment in
    // a report, so it is spelled out rather than reached for.
    let padded = name.count >= 24 ? name : name + String(repeating: " ", count: 24 - name.count)
    print("case \(padded) \(verdict)  \(detail)")
}

/// Compare a measured double against an expected one, so a report cannot read as a pass on a
/// value nobody computed.
func close(_ measured: Double?, _ expected: Double, _ tolerance: Double = 1e-6) -> Bool {
    guard let measured else { return false }
    return abs(measured - expected) <= tolerance
}

// MARK: - what OCCT itself prints (#3021)
//
// OCCT writes through `Message::DefaultMessenger()`, onto the same stream as the `case ...` lines
// above. So a run with every case passing used to carry a red
// `**** ERR StepFile : Undefined Parsing` from `must-fail-internal` and a green
// `Statistics on Transfer (Write)` block from `step-export`, interleaved with the report. Both are
// expected, and a reader of #2997's green CI output spent time on the first believing it was a
// defect. Worse for the long run: a GENUINE kernel complaint had nothing to distinguish it from
// either of them, and nothing in CI could read the transcript mechanically.
//
// So every case states what OCCT is expected to say and the statement is CHECKED. An empty
// `expecting` means OCCT must say nothing at all, which is what seven of the nine cases below were
// measured to do; the two that do talk name the strings they must produce. Capturing rather than
// silencing is the half that makes the spike stronger rather than quieter:
// `must-fail-internal` is the one case whose expected OCCT output is known exactly, and an ABSENT
// complaint there would mean the STEP parser never ran, which no other assertion in this spike can
// see.
//
// This covers OCCT's messenger and nothing else. A `std::terminate` message, which is what case 5d
// produces under wasmkit, goes to stderr and still reaches the transcript.

/// One case's captured OCCT output and a verdict on it.
///
/// - Parameters:
///   - expecting: substrings the captured text must all contain. Empty means it must be empty.
///   - body: the work to run with OCCT's output captured.
/// - Returns: `body`'s value, whether OCCT said what the case expected, and one line for the report.
@MainActor
func withOCCTOutput<T>(
    expecting: [String] = [],
    _ body: () throws -> T
) rethrows -> (value: T, ok: Bool, verdict: String) {
    let (value, output) = try Messenger.capturingDefaultOutput(body)
    guard let text = output else {
        // nil rather than "" is the one shape in which this check measures nothing: no capture
        // started, so every `expecting: []` case would read as silence it never observed.
        return (value, false, "OCCT: NOT CAPTURED")
    }
    if expecting.isEmpty {
        let ok = text.isEmpty
        return (value, ok, ok ? "OCCT: silent" : "OCCT: UNEXPECTED \(oneLine(text))")
    }
    let missing = expecting.filter { !text.contains($0) }
    return (
        value, missing.isEmpty,
        missing.isEmpty
            ? "OCCT: said all \(expecting.count) expected thing(s)"
            : "OCCT: MISSING \(missing) in \(oneLine(text))"
    )
}

/// A captured block on one line and truncated, so a report line stays a report line.
func oneLine(_ text: String, limit: Int = 240) -> String {
    let flat = text.split(whereSeparator: \.isNewline).joined(separator: " | ")
    return flat.count <= limit ? flat : String(flat.prefix(limit)) + "..."
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

// MARK: - case 0, the output capture every case below depends on (#3021)
//
// FIRST, because every other case's OCCT verdict is only as good as this mechanism. A capture that
// detached no printer would leave the transcript as noisy as before while every case still passed,
// and `Messenger.defaultPrinterCount` is the only observable that tells the two apart: exactly one
// printer inside the scope is the capture's own, so anything more means OCCT's output was DUPLICATED
// rather than redirected.
//
// A capture that collected nothing is caught elsewhere, by `step-export` and `must-fail-internal`
// requiring real text, which is why this case does not also assert on content.

let printersBefore = Messenger.defaultPrinterCount
var printersInside = -1
let (_, captureOK, captureVerdict) = withOCCTOutput {
    printersInside = Messenger.defaultPrinterCount
}
let printersAfter = Messenger.defaultPrinterCount
let captureCaseOK =
    captureOK && printersBefore >= 1 && printersInside == 1
    && printersAfter == printersBefore
report(
    "occt-output-capture", captureCaseOK,
    "default printers before=\(printersBefore) inside=\(printersInside) after=\(printersAfter), "
        + captureVerdict)

// MARK: - case 1, box
//
// Pure compute. Answers whether OCCT runs at all on this target: static initialisation under
// `_start`, the Standard_Type registry, TopoDS/BRep construction.

let (box, boxOutputOK, boxOutputVerdict) = withOCCTOutput {
    Shape.box(width: 10, height: 20, depth: 30)
}
if let box {
    // Volume 6000, 6 faces, 12 edges, 8 vertices. The counts are the DEDUPLICATED ones
    // (`uniqueFaceCount`, `uniqueEdgeCount`): a TopExp_Explorer visits a shared sub-shape once per
    // owner and answers 24 for a box's edges, which is the fixture trap #2174's probe fell into.
    let ok =
        close(box.volume, 6000) && box.uniqueFaceCount == 6 && box.uniqueEdgeCount == 12
        && box.vertexCount == 8
    report(
        "box", ok && boxOutputOK,
        "10x20x30 volume=\(box.volume.map { String($0) } ?? "nil") "
            + "faces=\(box.uniqueFaceCount) edges=\(box.uniqueEdgeCount) "
            + "vertices=\(box.vertexCount), \(boxOutputVerdict)")
} else {
    report("box", false, "Shape.box returned nil, \(boxOutputVerdict)")
}

// MARK: - case 2, fuse
//
// Exercises the allocator hard, which is the risk #2171 recorded and could not probe and #2174
// answered for `operator new` alone. Two unit cubes overlapping in one octant: 1000 + 1000 - 125.

let cubeA = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
let cubeB = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
var fused: Shape?
if let cubeA, let cubeB {
    let (result, fuseOutputOK, fuseOutputVerdict) = withOCCTOutput {
        cubeA.fused(with: cubeB, tolerance: 0)
    }
    fused = result
    if let fused {
        let ok = close(fused.volume, 1875, 1e-6) && fused.isValid
        report(
            "fuse", ok && fuseOutputOK,
            "two 10-cubes overlapping in one octant, volume=\(fused.volume.map { String($0) } ?? "nil") "
                + "expected=1875.0 faces=\(fused.uniqueFaceCount) valid=\(fused.isValid), "
                + fuseOutputVerdict)
    } else {
        report("fuse", false, "Shape.fused returned nil, \(fuseOutputVerdict)")
    }
} else {
    report("fuse", false, "could not build the two operands")
}

// MARK: - case 3, STEP export
//
// String and file I/O across the WASI boundary, and the first write this stack has done from
// Swift. `Exporter.writeSTEP` takes a `URL`; the path inside it resolves against the preopened
// directory and nothing else, because a WASI module has no filesystem beyond its preopens.

// OCCT TALKS HERE, and this is the second of the two cases that assert on what it said. The writer
// reaches `StepSelect_WorkLibrary::WriteFile`, which prints the whole
// `Statistics on Transfer (Write)` block through the default messenger, in green: measured on macOS
// 2026-10-02, four lines naming the transfer mode, the shape type, the work session and the file.
// Requiring them turns what used to be the noisiest part of the transcript into evidence that the
// writer ran its transfer rather than short-circuiting to a file.
var exportedBytes = 0
if let fused {
    do {
        let (data, writeOutputOK, writeOutputVerdict) = try withOCCTOutput(expecting: [
            "Statistics on Transfer (Write)",
            "Transfer Mode = 0",
            "WorkSession : Sending all data",
            "Write  Done",
        ]) { () -> Data in
            try Exporter.writeSTEP(
                shape: fused, to: URL(fileURLWithPath: stepPath), name: "OCCTWasmSpike")
            return try Data(contentsOf: URL(fileURLWithPath: stepPath))
        }
        exportedBytes = data.count
        // A STEP file that is present and empty is the failure this would otherwise read as a
        // pass, so assert on the header rather than on existence.
        let text = String(decoding: data.prefix(64), as: UTF8.self)
        let ok = exportedBytes > 0 && text.hasPrefix("ISO-10303-21;")
        report(
            "step-export", ok && writeOutputOK,
            "wrote \(stepPath) bytes=\(exportedBytes) "
                + "header=\(text.split(separator: "\n").first ?? ""), \(writeOutputVerdict)"
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

// The READ side prints NOTHING on a file it accepts, measured: there is no
// `Statistics on Transfer (Read)` unless a caller asks for one, and the bridge does not. So silence
// is the assertion here, and it is not a weak one: the ONE message this path is known to produce is
// the parse complaint case 5b provokes, so a reader appearing here would mean this file, the one
// case 3 wrote, had failed to parse.
if exportedBytes > 0 {
    do {
        let (reread, readOutputOK, readOutputVerdict) = try withOCCTOutput { () -> Shape in
            try Shape.load(fromPath: stepPath)
        }
        // Round-trip against case 2's own numbers rather than against a literal, so a STEP file
        // that parses into the wrong solid cannot pass.
        let ok =
            close(reread.volume, fused?.volume ?? .nan, 1e-6)
            && reread.uniqueFaceCount == (fused?.uniqueFaceCount ?? -1)
        report(
            "step-import", ok && readOutputOK,
            "read back volume=\(reread.volume.map { String($0) } ?? "nil") "
                + "faces=\(reread.uniqueFaceCount) against the written shape's "
                + "\(fused?.volume.map { String($0) } ?? "nil")/\(fused?.uniqueFaceCount ?? -1), "
                + readOutputVerdict)
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

// OCCT PRINTS NOTHING on this path, measured: the raise crosses into the bridge's `catch (...)`
// without ever reaching the messenger, which is why #1161's diagnostic channel had to exist at all.
// Requiring silence here says exactly that, and it is a second, independent reading of the same
// fact: a `Standard_DomainError` that OCCT had instead REPORTED would be a different kernel from the
// one this spike is measuring.
let ((degenerate, raiseDiagnostics), raiseOutputOK, raiseOutputVerdict) = withOCCTOutput {
    OCCTDiagnostics.capturing {
        Shape.box(width: 0, height: 0, depth: 0)
    }
}
let raiseOK =
    degenerate == nil && raiseDiagnostics.count == 1
    && raiseDiagnostics[0].kind == .occtFailure
    && !raiseDiagnostics[0].exceptionType.isEmpty
report(
    "must-fail-raise", raiseOK && raiseOutputOK,
    "Shape.box(0,0,0) -> \(degenerate == nil ? "nil" : "A SHAPE"), "
        + "records=\(raiseDiagnostics.count) "
        + "\(raiseDiagnostics.map { "[\($0.function): \($0.exceptionType): \($0.message)]" }.joined(separator: " ")), "
        + raiseOutputVerdict
)

// MARK: - cases 5c and 5d (#2894): the SAME exception at two unwind depths
//
// #2894's measurement, moved into the spike because the spike is the only module this repository
// runs under BOTH wasmkit and Node, and the open question is whether the defect belongs to the
// generated code or to the runtime that executes it.
//
// Both cases raise `Standard_ConstructionError` from `Geom_TrimmedCurve` with the message
// `Geom_TrimmedCurve::U1 == U2`. They differ in ONE variable, the number of frames between the throw
// and the bridge's `catch (...)`:
//
//   5c  `Curve3D.trimmed(from: 1, to: 1)`  one frame: the bridge constructs it inside its own `try`
//   5d  `Shape.evolved(spine:profile:)`    several, through BRepFill_Evolved's Perform chain
//
// Measured under wasmkit: 5c is caught, 5d reaches `std::terminate` and ends the module. Measured on
// macOS: both are caught, with the identical message. So the exception's type and its translation
// unit are not the variable; the unwind is.
//
// 5d IS LAST FOR A REASON. A terminate ends the module, so anything after it is unreported.

let shallowBasis = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
if let basis = shallowBasis {
    let ((shallowTrim, shallowDiagnostics), shallowOutputOK, shallowOutputVerdict) =
        withOCCTOutput {
            OCCTDiagnostics.capturing {
                basis.trimmed(from: 1.0, to: 1.0)
            }
        }
    report(
        "unwind-depth-1",
        shallowTrim == nil && shallowDiagnostics.count == 1 && shallowOutputOK,
        "Curve3D.trimmed(1,1) -> \(shallowTrim == nil ? "nil" : "A CURVE"), "
            + "records=\(shallowDiagnostics.count) "
            + "\(shallowDiagnostics.map { "[\($0.exceptionType): \($0.message)]" }.joined(separator: " ")), "
            + shallowOutputVerdict
    )
} else {
    report("unwind-depth-1", false, "the basis line fixture failed to build")
}

let evolvedSpine = Wire.arc(center: SIMD3(0, 0, 0), radius: 20, startAngle: 0, endAngle: .pi / 2)
let evolvedProfile = Wire.rectangle(width: 2, height: 2)
if let spine = evolvedSpine, let profile = evolvedProfile {
    print("case unwind-depth-n       ATTEMPTING: no further output means the throw was not caught")
    // The capture takes OCCT's messenger and not stderr, so a `std::terminate` here still prints
    // where this note says to look for it.
    let ((evolved, evolvedDiagnostics), evolvedOutputOK, evolvedOutputVerdict) = withOCCTOutput {
        OCCTDiagnostics.capturing {
            Shape.evolved(spine: spine, profile: profile)
        }
    }
    report(
        "unwind-depth-n",
        evolved == nil && evolvedDiagnostics.count == 1 && evolvedOutputOK,
        "Shape.evolved -> \(evolved == nil ? "nil" : "A SHAPE"), "
            + "records=\(evolvedDiagnostics.count) "
            + "\(evolvedDiagnostics.map { "[\($0.exceptionType): \($0.message)]" }.joined(separator: " ")), "
            + evolvedOutputVerdict
    )
} else {
    report("unwind-depth-n", false, "the spine or profile fixture failed to build")
}

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

// THE CASE #3021 IS ABOUT, and the one whose expected OCCT output is known exactly. OCCT's parser
// writes, through the default messenger at Message_Fail gravity and therefore in red:
//
//     **** ERR StepFile : Undefined Parsing: Line 2: Incorrect syntax: unexpected TYPE, expecting
//     STEP    ****
//
// from `StepFile_Interrupt` in `StepFile_Read.cxx`. That line is what a reader of #2997's green run
// flagged as a defect needing investigation. It is now REQUIRED rather than tolerated, which makes
// the case strictly stronger: an empty capture would mean the parser never ran, and the pair below
// (a refusal reaching Swift, the bridge's own capture staying empty) cannot tell that apart from a
// parser that ran and refused the file. The line numbers and the token names are left out of the
// expectation, because they are bison's and not a contract.
do {
    try Data("NOT A STEP FILE, not even close.\n".utf8).write(
        to: URL(fileURLWithPath: brokenPath))
    let ((outcome, internalDiagnostics), parseOutputOK, parseOutputVerdict) = withOCCTOutput(
        expecting: ["**** ERR StepFile", "Undefined Parsing", "Incorrect syntax"]
    ) {
        OCCTDiagnostics.capturing { () -> Result<Shape, Error> in
            do { return .success(try Shape.load(fromPath: brokenPath)) } catch {
                return .failure(error)
            }
        }
    }
    switch outcome {
    case .success:
        report("must-fail-internal", false, "a malformed STEP file imported successfully")
    case .failure(let error):
        let ok = internalDiagnostics.isEmpty
        report(
            "must-fail-internal", ok && parseOutputOK,
            "malformed STEP refused as \(error), bridge records=\(internalDiagnostics.count) "
                + "(expected 0: OCCT's own handler turned the failure into a status), "
                + parseOutputVerdict)
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

// Silenced rather than captured, which is the one place in this file that asks for less. It writes a
// second STEP file and so prints a second `Statistics on Transfer (Write)` block, and since the case
// is REPORTED and not gated there is no verdict for a capture to feed: asserting on text whose case
// cannot fail would be decoration.
if let fused {
    do {
        let bytes = try Messenger.silencingDefaultOutput {
            try Exporter.stepData(shape: fused, name: "OCCTWasmSpike")
        }
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
