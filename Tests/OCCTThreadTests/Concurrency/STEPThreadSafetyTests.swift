import Foundation
import Testing

@testable import OCCTSwift

// Issue #359: #181-B (fixed by PR #184) serialized STEP/IGES *writers* on a shared
// igesMutex(), since STEPControl/STEPCAFControl/IGESControl readers and writers all
// touch OCCT's process-global Interface_Static parameter table. That fix never
// covered STEP *import* (the original #181-B report was specifically about
// concurrent writeSTEP), and 3 STEP writer entry points added afterward
// (OCCTExportSTEPWithName, OCCTExportSTEPWithModeProgress, OCCTDocumentWriteSTEPWithModes)
// never picked up the lock either. Found while scoping #342 (bridge-level
// thread-handling contract) by auditing every function touching
// STEPControl_Reader/Writer or STEPCAFControl_Reader/Writer for igesMutex()
// coverage -- 18 functions were missing it. Fixed by adding igesMutex() to all 18,
// matching the existing #181-B convention (bridge-only, no kernel change).
//
// Like #341's equivalent suite, this is a basic regression exerciser through the
// Swift API, not the authoritative verification -- a std::mutex-guarded critical
// section either serializes correctly or doesn't; it isn't the kind of race that
// reliably manifests as an observable Swift-level failure at modest concurrency
// without sanitizer instrumentation. Mixing concurrent imports and exports here at
// least confirms the fix doesn't deadlock (all 18 sites lock a single
// non-recursive std::mutex with no nested acquisition) and doesn't regress
// ordinary round-trip correctness.
@Suite("Issue #359, concurrent STEP import/export is thread-safe (igesMutex)")
struct Issue359STEPThreadSafetyTests {

    @Test("Concurrent STEP import + export round-trips all succeed with a non-empty shape")
    func concurrentSTEPRoundTripsSucceed() async throws {
        struct Outcome: Sendable {
            var writeFailed = 0, readFailed = 0, emptyShape = 0
        }

        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for taskIndex in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    for i in 0..<15 {
                        let box = Shape.box(width: 10, height: 20, depth: 30)!
                        let path = NSTemporaryDirectory() + "occt359_step_\(taskIndex)_\(i).step"
                        let url = URL(fileURLWithPath: path)
                        defer { try? FileManager.default.removeItem(at: url) }

                        do {
                            try Exporter.writeSTEP(shape: box, to: url, modelType: .asIs)
                        } catch {
                            o.writeFailed += 1
                            continue
                        }

                        guard let loaded = try? Shape.load(from: url) else {
                            o.readFailed += 1
                            continue
                        }
                        if loaded.subShapeCount(ofType: .face) == 0 { o.emptyShape += 1 }
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group {
                total.writeFailed += o.writeFailed
                total.readFailed += o.readFailed
                total.emptyShape += o.emptyShape
            }
            return total
        }

        #expect(agg.writeFailed == 0, "concurrent STEP writes failed (expected 0 of 120)")
        #expect(agg.readFailed == 0, "concurrent STEP reads failed (expected 0 of 120)")
        #expect(
            agg.emptyShape == 0, "concurrent STEP reads produced an empty shape (expected 0 of 120)"
        )
    }
}
