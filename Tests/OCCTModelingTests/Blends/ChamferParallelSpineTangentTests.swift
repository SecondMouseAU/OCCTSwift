import Foundation
import Testing

@testable import OCCTSwift

/// #3350 (OCCT#1576, FreeCAD#21369): a chamfer at a vertex where two edges leave along one
/// direction killed the process.
///
/// `ChFi3d_ChBuilder`'s `ExtentSpineOnCommonFace` extends the two chamfer spines that meet at a
/// vertex by `dis / tan(a)`, where `a` comes from the angle between the two spine tangents. For
/// parallel tangents `sin(alpha)` is 0 and the extension is `dis / 0`, infinity. The spine range
/// `(-inf, +inf)` reached `BRepBlend_Walking`, which constructed `Extrema_ExtPC` on it with a NaN
/// point, and `Extrema_GGExtPC::Perform` read out of range: an uncatchable SIGSEGV, since
/// `OCC_CATCH_SIGNALS` is inert in this build. Carried kernel patch `0064` makes
/// `BRepBlend_Walking::Perform` report "not done" for a start, end or flecheur that is not finite,
/// so the chamfer is declined instead.
///
/// The model is the one attached to OCCT#1576: 36 edges, of which 12 (the issue's edges 14 and 16
/// to 26) crashed at distance 1 on the kernel pinned before the patch.
/// `Scripts/repro/3350-chamfer-extrema-sigsegv/` holds the measurement.
///
/// The crash cannot be caught in process, and a signal in the test runner aborts every test in the
/// target, so the parent test re-runs this test runner, with the same executable and arguments
/// minus any `--filter` or `--skip`, as a child process that does the chamfers. A child that dies
/// by signal fails the parent (a failed expectation, not an aborted run).
@Suite("Chamfer where two spine tangents are parallel")
struct ChamferParallelSpineTangentTests {

    private static let childKey = "OCCTSWIFT_CHAMFER_PARALLEL_CHILD"
    private static let markKey = "OCCTSWIFT_CHAMFER_PARALLEL_MARK"
    private static let isChild = ProcessInfo.processInfo.environment[childKey] == "1"
    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    private static func loadModel() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/chamfer-parallel-spine-tangents-model.brep")
        return try Shape.loadBREP(from: url)
    }

    /// The control: the model loads, has 36 edges and is a valid solid.
    ///
    /// This runs on every kernel, so the gated test below cannot be vacuous because the fixture
    /// failed to load.
    @Test func modelLoadsWithThirtySixEdges() throws {
        let model = try Self.loadModel()
        #expect(model.edges().count == 36)
        #expect(model.isValid)
    }

    /// The child: chamfer every edge of the model by 1, one edge at a time, in this process.
    ///
    /// Reaching the end is the regression check, because on a kernel without the patch the process
    /// dies at the first of the twelve edges. Only the parent runs it, in a fresh process.
    @Test(.enabled(if: ChamferParallelSpineTangentTests.isChild))
    func chamferEveryEdgeOnceInThisProcess() throws {
        let model = try Self.loadModel()
        let count = model.edges().count
        var done = 0
        for index in 0..<count {
            if model.chamferedWithFullHistory(distance: 1, edges: [index]) != nil { done += 1 }
        }
        #expect(count == 36)
        if let path = ProcessInfo.processInfo.environment[Self.markKey],
            let handle = FileHandle(forWritingAtPath: path)
        {
            handle.seekToEndOfFile()
            handle.write(Data("ok edges=\(count) done=\(done)\n".utf8))
            try? handle.close()
        }
    }

    /// Chamfering each of the 36 edges at distance 1 returns for every edge instead of killing the
    /// process.
    ///
    /// Gated on `OCCTSWIFT_LOCAL=1`: the fix, carried patch `0064`, is not in the pinned asset
    /// (`v4.0.0-kernel.6`), so `ci.yml`'s `build-and-test` would fail on a crash it cannot fix, and
    /// `kernel-integration.yml` runs it against a kernel built with the patch. Ungate it at the
    /// repin that pins `0064` (the skipped test and the passing one report alike, which is why the
    /// gate must go with the repin, #2983).
    ///
    /// Unpatched, the child dies by SIGSEGV. Patched, all 36 edges answer, and the count below says
    /// what: none returns a shape. 35 are declined by OCCT (`IsDone() == false`) and edge 15 builds
    /// a result of negative volume that BRepCheck rejects (a separate defect, present on upstream
    /// `IR` too), which the bridge refuses.
    @Test(
        .enabled(
            if: !ChamferParallelSpineTangentTests.isChild
                && ChamferParallelSpineTangentTests.isLocalKernel))
    func everyEdgeAnswersInsteadOfCrashing() throws {
        var arguments: [String] = []
        var skipNext = false
        for argument in CommandLine.arguments.dropFirst() {
            if skipNext {
                skipNext = false
                continue
            }
            if argument == "--filter" || argument == "--skip" {
                skipNext = true
                continue
            }
            arguments.append(argument)
        }
        arguments += ["--filter", "ChamferParallelSpineTangentTests"]

        let mark = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-chamfer-parallel-\(UUID().uuidString).marks")
        FileManager.default.createFile(atPath: mark.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: mark) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment[Self.childKey] = "1"
        environment[Self.markKey] = mark.path
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let reason = process.terminationReason == .exit ? "exit" : "signal"
        #expect(
            process.terminationReason == .exit && process.terminationStatus == 0,
            "the child ended by \(reason) \(process.terminationStatus)")
        // A child whose filter matched nothing exits 0 having measured nothing.
        let marks = (try? String(contentsOf: mark, encoding: .utf8)) ?? ""
        #expect(marks == "ok edges=36 done=0\n", "the child reported: \(marks)")
    }
}
