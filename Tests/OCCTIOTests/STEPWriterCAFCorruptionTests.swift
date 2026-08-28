import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #280: a CAF STEP read corrupts later shape-level STEP writes

@Suite("STEP writer corruption after a CAF read (#280)")
struct STEPWriterCAFCorruptionTests {

    /// Round-trip a frustum (3 faces: lateral cone + two discs) and report what survives.
    private func coneRoundTrip(_ tag: String) throws -> (
        faces: Int, volume: Double, conicalInFile: Int
    ) {
        let cone = Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-280-\(tag)-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTEP(shape: cone, to: url, modelType: .asIs)
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let reimported = try Shape.load(from: url)
        return (
            faces: reimported.subShapeCount(ofType: .face),
            volume: reimported.volume ?? 0,
            conicalInFile: text.components(separatedBy: "CONICAL_SURFACE").count - 1
        )
    }

    /// Regression guard for #280.
    ///
    /// Merely constructing a `STEPCAFControl_Reader`, i.e. any XDE STEP read, such as
    /// `Document.loadSTEP`, used to permanently corrupt every later shape-level STEP write in the
    /// process: the frustum's lateral conical face was silently dropped from the written file,
    /// leaving a 2-face solid missing 63% of its volume that still reported `isValid == true`.
    ///
    /// Upstream OCCT 8.0.0p1 bug: `STEPCAFControl_Controller`'s constructor overwrites the actor
    /// its base class configured, without re-applying `SetShapeProcessFlags`, and then
    /// `AutoRecord()`s itself under the same "STEP" name the plain writer resolves by. The actor's
    /// OperationsFlags end up empty, so `DirectFaces` never runs and faces on indirect
    /// (left-handed) surfaces, a frustum's cone, are dropped. Worked around in the bridge by
    /// installing a freshly-constructed plain controller on each shape-level write.
    ///
    /// This is also the cause of the long-standing `cone()` failure in OCCTStressTests, which
    /// passed in isolation and failed in every full run purely because OCCTIOTests reads a STEP
    /// first.
    @Test("A CAF STEP read must not corrupt later shape-level STEP writes")
    func cafReadDoesNotPoisonShapeWriter() throws {
        let analyticVolume = (Double.pi * 10 / 3) * (25 + 10 + 4)  // 130π ≈ 408.407

        // Do the CAF read ourselves so the test is self-contained. Note we deliberately do NOT
        // assert a clean "before" baseline: the poison is process-wide and permanent, and in a
        // full run another suite's CAF read has usually already tripped it before we get here,
        // a baseline assertion would make this test order-dependent (and fail for the wrong
        // reason). The invariant below holds regardless of what ran earlier.
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let boxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-280-poison-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: boxURL) }
        try box.writeSTEP(to: boxURL)
        #expect(Document.loadSTEP(from: boxURL, modes: STEPReaderModes()) != nil)

        let after = try coneRoundTrip("after")
        #expect(
            after.conicalInFile == 1,
            "CONICAL_SURFACE dropped from the written file (#280)")
        #expect(
            after.faces == 3,
            "frustum lost a face: \(after.faces) (#280)")
        #expect(
            abs(after.volume - analyticVolume) / analyticVolume < 0.01,
            "frustum volume corrupted: \(after.volume) vs \(analyticVolume) (#280)")
    }
}
