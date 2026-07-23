import Testing
import Foundation
@testable import OCCTSwift

// Issue #361: two more process-global bridge singletons found scoping #342, both matching
// the #341/#344/#353 shape (unsynchronized shared state, mutated by callers who have no
// reason to expect they're touching anything shared).
//
// A. getDocNamingScope() (OCCTBridge_Document.mm) returns one TNaming_Scope instance shared
//    across every OCCTDocument. TNaming_Scope's own NCollection_Map<TDF_Label> myValid has no
//    internal synchronization -- two threads calling namingScopeValid/IsValid/etc. on two
//    unrelated documents race on that shared map. Fixed with docNamingScopeMutex(), held for
//    the duration of every access.
//
// B. Font_FontMgr's font-list cache (OCCTBridge_Visualization.mm): g_fontList/
//    g_fontListPopulated is an unsynchronized check-then-act lazy-init, and
//    FontManager.initDatabase() can reassign both at any time from any thread, racing an
//    in-progress read in fontName(at:)/fontPath(at:)/fontHasAspect(at:). Fixed with
//    fontListMutex(), held for the duration of every access (population and read).
//
// Like #341/#359's equivalent suites, this is a basic exerciser through the Swift API --
// confirms no deadlock and no functional regression -- not the authoritative verification for
// a lock-coverage bug on a plain (non-recursive) std::mutex.
@Suite("Issue #361 — shared singletons (TNaming_Scope, Font_FontMgr) are thread-safe")
struct Issue361SharedSingletonThreadSafetyTests {

    @Test("Concurrent naming-scope access across independent documents doesn't crash or deadlock")
    func concurrentNamingScopeAccessSucceeds() async throws {
        struct Outcome: Sendable {
            var failures = 0
        }

        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for _ in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    for _ in 0..<20 {
                        guard let doc = Document.create() else { o.failures += 1; continue }
                        let box = Shape.box(width: 5, height: 5, depth: 5)!
                        let labelId = doc.addShape(box, makeAssembly: false)

                        doc.namingScopeValid(labelId: labelId)
                        _ = doc.namingScopeIsValid(labelId: labelId)
                        doc.namingScopeValidChildren(labelId: labelId)
                        _ = doc.namingScopeValidCount
                        doc.namingScopeUnvalid(labelId: labelId)
                        doc.namingScopeClear()
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group { total.failures += o.failures }
            return total
        }

        #expect(agg.failures == 0, "concurrent document creation failed (expected 0 of 160)")
    }

    @Test("Concurrent font-database init + queries don't crash or deadlock")
    func concurrentFontQueriesSucceed() async throws {
        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<8 {
                group.addTask {
                    for i in 0..<10 {
                        if (taskIndex + i) % 3 == 0 {
                            FontManager.initDatabase()
                        }
                        let count = FontManager.fontCount
                        if count > 0 {
                            let idx = i % count
                            _ = FontManager.fontName(at: idx)
                            _ = FontManager.fontPath(at: idx)
                            _ = FontManager.fontHasAspect(at: idx, aspect: .regular)
                        }
                    }
                }
            }
        }
        // No #expect needed beyond "didn't crash/deadlock" -- font availability is
        // environment-dependent (headless CI may have zero system fonts registered).
    }
}
