import Foundation
import Testing

@testable import OCCTSwift

/// Regressions for #302: the robust importers sewed, then kept only the **first** shell, silently
/// discarding every body after it, 10 boxes in, 1 box out, no error and no diagnostic.
///
/// These assert on **body count**, not validity. That distinction is the whole point: a truncated
/// import returned a perfectly well-formed solid, which is exactly why the defect shipped
/// unnoticed. `isValid` was true the entire time. Same lesson as #286/#300, assert the property
/// that was actually broken, not the one that happens to be easy to check.
@Suite("v1.11.3 Multibody robust import (issue #302)")
struct MultibodyRobustImportTests {

    @Test("Shape.loadRobust keeps every body of a multibody STEP (#302)")
    func stepRobustKeepsAllBodies() throws {
        guard let compound = boxRow(count: 10) else {
            Issue.record("compound construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_multibody.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try compound.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(
            shape.solidCount == 10,
            "loadRobust returned \(shape.solidCount) of 10 bodies, the rest were silently dropped (#302)"
        )
        #expect(shape.faceCount == 60, "expected 60 faces, got \(shape.faceCount) (#302)")
        #expect(
            shape.shapeType == .compound,
            "multibody input should come back a compound, got \(shape.shapeType)")
        #expect(shape.isValid)
    }

    @Test("Shape.loadSTLRobust keeps every body of a multibody STL (#302)")
    func stlRobustKeepsAllBodies() throws {
        guard let compound = boxRow(count: 10) else {
            Issue.record("compound construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_multibody.stl")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeSTL(shape: compound, to: url, deflection: 0.1)

        let shape = try Shape.loadSTLRobust(fromPath: url.path, sewingTolerance: 1e-6)
        // Tessellated: each box is 12 triangles, so bodies are what matters, not face count.
        #expect(
            shape.solidCount == 10,
            "loadSTLRobust returned \(shape.solidCount) of 10 bodies, the rest were silently dropped (#302)"
        )
        #expect(shape.isValid)
    }

    @Test("Shape.loadWithDiagnostics keeps every body and reports the count (#302)")
    func diagnosticsKeepsAllBodiesAndCounts() throws {
        guard let compound = boxRow(count: 10) else {
            Issue.record("compound construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_multibody_diag.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try compound.writeSTEP(to: url)

        let result = try Shape.loadWithDiagnostics(from: url)
        #expect(
            result.shape.solidCount == 10,
            "loadWithDiagnostics returned \(result.shape.solidCount) of 10 bodies (#302)")
        #expect(
            result.solidsCreated == 10,
            "expected solidsCreated == 10, got \(result.solidsCreated), the count is what made the loss visible (#302)"
        )
        #expect(result.solidCreated)
    }

    /// Guards the hazard the fix was designed around: a hollow body owns an **outer shell plus one
    /// shell per void**. "Solidify every shell" naively, via `TopExp_Explorer(_, TopAbs_SHELL)`,
    /// descends *into* solids and would turn one hollow body into two, trading data loss for
    /// corruption. `occtSolidifyShells` walks a compound's immediate children instead, so a void
    /// stays a void. Asserted on volume, which is what a lost void would change.
    @Test("Shape.loadRobust does not split a body with an internal void (#302)")
    func internalVoidNotSplit() throws {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
            let sphere = Shape.sphere(radius: 5),
            let hollow = box.subtracting(sphere)
        else {
            Issue.record("hollow construction failed")
            return
        }
        let expected = 8000.0 - (4.0 / 3.0 * Double.pi * 125.0)
        #expect(
            hollow.shellCount == 2,
            "fixture should own an outer and a void shell, got \(hollow.shellCount)")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_void.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try hollow.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(
            shape.solidCount == 1,
            "hollow body split into \(shape.solidCount) solids, the void shell was solidified separately (#302)"
        )
        #expect(shape.shellCount == 2, "lost the void shell: \(shape.shellCount) shells (#302)")
        if let volume = shape.volume {
            #expect(
                abs(volume - expected) / expected < 0.001,
                "volume \(volume) vs expected \(expected), the void was filled in (#302)")
        }
        #expect(shape.isValid)
    }

    /// The other half of the contract: a single body must still come back a plain solid, not a
    /// compound wrapping one. This is what keeps existing single-body callers untouched.
    @Test("Shape.loadRobust still returns a plain solid for a single body (#302)")
    func singleBodyStillSolid() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt302_singlebody.step")
        defer { try? FileManager.default.removeItem(at: url) }
        try box.writeSTEP(to: url)

        let shape = try Shape.loadRobust(fromPath: url.path)
        #expect(
            shape.shapeType == .solid,
            "single-body import should stay a plain solid, got \(shape.shapeType), existing callers depend on this (#302)"
        )
        #expect(shape.solidCount == 1)
        #expect(shape.faceCount == 6)
        #expect(shape.isValid)
    }
}
