import Foundation
import Testing

@testable import OCCTSwift

// Issue #341: RWMesh_CafReader::fillDocument() (the shared base of RWObj_CafReader
// and RWGltf_CafReader) saves/mutates/restores XCAFDoc_ShapeTool's process-global
// theAutoNaming flag with zero synchronization, and XCAFDoc_ShapeTool::AddShape
// reads that same flag. Confirmed via ThreadSanitizer against a minimal-module TSan
// build of V8_0_0_p1 (Scripts/repro/341-meshcaf/occt_341_stress.cpp,
// obj_roundtrip_unique scenario): every run of 8-10 concurrent OBJ round-trips
// (each on its own uniquely-named file, so this is not a file-path collision)
// reported 9-17 distinct data races, all resolving to this one global. This is
// NOT the long-claimed "NCollection race" (see CLAUDE.md's corrected Known OCCT
// Bugs entry) -- it lives in XCAF, is reachable from any concurrent OBJ/glTF/PLY
// import or export, and was previously undetected because it produces silent
// wrong-but-plausible auto-naming or an occasional import failure, not a
// deterministic crash.
//
// Originally mitigated at the bridge layer (v1.15.4, a dedicated meshCafMutex() in
// OCCTBridge_IO.mm); fixed properly in the kernel as of v1.15.5
// (Scripts/patches/0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch --
// XCAFDoc_ShapeTool::AutoNamingScope, a recursive_mutex-backed RAII guard, plus
// making theAutoNaming itself std::atomic<bool>), at which point the bridge-side
// lock was removed as redundant. This suite exercises concurrent OBJ round-trips
// through the Swift API as a basic regression exerciser -- but, like the race
// itself, it does NOT reliably fail without the fix at this scale (verified: 15
// runs of 8x15 concurrent round-trips all passed even with meshCafMutex()
// reverted, before the kernel fix existed -- the race needs either sanitizer
// instrumentation or the much higher operation count of a full `swift test`
// parallel run to surface as an observable failure). The authoritative
// reproducer is the ThreadSanitizer harness at Scripts/repro/341-meshcaf/,
// matching the #319 precedent of using a sanitizer-backed C++ repro rather than
// a Swift test as the primary verification tool for a race this narrow.
@Suite("Issue #341, concurrent OBJ import/export is thread-safe (meshCafMutex)")
struct Issue341MeshCafThreadSafetyTests {

    @Test("Concurrent OBJ round-trips all succeed with a non-empty shape")
    func concurrentOBJRoundTripsSucceed() async throws {
        struct Outcome: Sendable {
            var writeFailed = 0, readFailed = 0, emptyDocument = 0
        }

        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for taskIndex in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    for i in 0..<15 {
                        let box = Shape.box(width: 10, height: 20, depth: 30)!
                        let path = NSTemporaryDirectory() + "occt341_meshcaf_\(taskIndex)_\(i).obj"
                        let url = URL(fileURLWithPath: path)
                        defer { try? FileManager.default.removeItem(at: url) }

                        do {
                            try box.writeOBJ(to: url)
                        } catch {
                            o.writeFailed += 1
                            continue
                        }

                        guard let doc = Document.loadOBJ(from: url) else {
                            o.readFailed += 1
                            continue
                        }
                        if doc.allShapes().isEmpty { o.emptyDocument += 1 }
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group {
                total.writeFailed += o.writeFailed
                total.readFailed += o.readFailed
                total.emptyDocument += o.emptyDocument
            }
            return total
        }

        #expect(agg.writeFailed == 0, "concurrent OBJ writes failed (expected 0 of 120)")
        #expect(
            agg.readFailed == 0,
            "concurrent OBJ reads failed (expected 0 of 120), the #341 AutoNaming race")
        #expect(
            agg.emptyDocument == 0,
            "concurrent OBJ reads produced an empty document (expected 0 of 120)")
    }
}
