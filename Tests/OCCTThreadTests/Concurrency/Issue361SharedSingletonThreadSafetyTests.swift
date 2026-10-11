import Foundation
import Testing

@testable import OCCTSwift

// Issue #361 (fixed further in #363): two more process-global bridge singletons found
// scoping #342, both originally matching the #341/#344/#353 shape (unsynchronized shared
// state, mutated by callers who have no reason to expect they're touching anything shared).
//
// A. getDocNamingScope() (OCCTBridge_Document.mm) originally returned one TNaming_Scope
//    instance shared across every OCCTDocument. v1.15.13 (#361) made concurrent access to it
//    memory-safe with docNamingScopeMutex() -- but that left the underlying design bug
//    intact: every document shared the same TNaming_Scope, so document A's valid-label set
//    could leak into document B's regardless of locking. Upstream reviewer gkv311's pushback
//    on #341's analogous AutoNamingScope fix (OCCT#1388) prompted a second look: relocate the
//    state to its actual owner instead of locking it in place. #363 moves naming scope onto a
//    per-OCCTDocument field (doc->namingScope) -- no lock needed at all, since two threads
//    working on two different Document instances no longer touch anything shared.
//
// B. Font_FontMgr's font-list cache (OCCTBridge_Visualization.mm): g_fontList/
//    g_fontListPopulated is an unsynchronized check-then-act lazy-init, and
//    FontManager.initDatabase() can reassign both at any time from any thread, racing an
//    in-progress read in fontName(at:)/fontPath(at:)/fontHasAspect(at:). Fixed with
//    fontListMutex(), held for the duration of every access (population and read) -- this one
//    stayed a mutex fix, since Font_FontMgr's system font registry is genuinely one
//    process-wide resource by OCCT's own design, unlike TNaming_Scope above.
//
// Like #341/#359's equivalent suites, the concurrent tests below are basic exercisers through
// the Swift API -- confirms no deadlock and no functional regression -- not the authoritative
// verification for a lock-coverage bug. The isolation test IS authoritative for its specific
// claim (two documents' naming scopes don't share state), since that's a deterministic,
// single-threaded correctness property, not a race.
@Suite("Issue #361/#363, shared singletons (TNaming_Scope, Font_FontMgr) are thread-safe")
struct Issue361SharedSingletonThreadSafetyTests {

    @Test("Two documents' naming scopes are isolated (#363, not just race-free, but not shared)")
    func namingScopesAreIsolatedAcrossDocuments() throws {
        let docA = try #require(Document.create())
        let docB = try #require(Document.create())

        let boxA = Shape.box(width: 5, height: 5, depth: 5)!
        let boxB = Shape.box(width: 7, height: 7, depth: 7)!
        let labelA = docA.addShape(boxA, makeAssembly: false)
        let labelB = docB.addShape(boxB, makeAssembly: false)

        docA.namingScopeValid(labelId: labelA)
        docA.namingScopeValid(labelId: labelA)  // repeat marks are idempotent, not cumulative

        #expect(docA.namingScopeValidCount == 1)
        #expect(
            docB.namingScopeValidCount == 0,
            "document B's valid count must not reflect document A's marks")
        #expect(docA.namingScopeIsValid(labelId: labelA))
        #expect(!docB.namingScopeIsValid(labelId: labelB))

        docB.namingScopeValid(labelId: labelB)
        #expect(docB.namingScopeValidCount == 1)

        docA.namingScopeClear()
        #expect(docA.namingScopeValidCount == 0)
        #expect(
            docB.namingScopeValidCount == 1,
            "clearing document A must not clear document B's scope")
    }

    @Test("Concurrent naming-scope access across independent documents doesn't crash or deadlock")
    func concurrentNamingScopeAccessSucceeds() async throws {
        // Each task owns its documents, so every count below is deterministic whatever the
        // other seven tasks do. A scope shared between documents (the #363 defect) makes some
        // other task's mark or clear show up in a count and fails here; the previous version
        // only counted failed Document.create() calls, which a shared scope never produces.
        struct Outcome: Sendable {
            var setupFailures = 0
            var wrongAnswers = 0
        }

        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for _ in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    for _ in 0..<20 {
                        guard let doc = Document.create(),
                            let box = Shape.box(width: 5, height: 5, depth: 5)
                        else {
                            o.setupFailures += 1
                            continue
                        }
                        let labelId = doc.addShape(box, makeAssembly: false)

                        doc.namingScopeValid(labelId: labelId)
                        if !doc.namingScopeIsValid(labelId: labelId) { o.wrongAnswers += 1 }
                        if doc.namingScopeValidCount != 1 { o.wrongAnswers += 1 }
                        doc.namingScopeValidChildren(labelId: labelId)
                        if doc.namingScopeValidCount < 1 { o.wrongAnswers += 1 }
                        doc.namingScopeUnvalid(labelId: labelId)
                        if doc.namingScopeIsValid(labelId: labelId) { o.wrongAnswers += 1 }
                        doc.namingScopeValid(labelId: labelId)
                        doc.namingScopeClear()
                        if doc.namingScopeValidCount != 0 { o.wrongAnswers += 1 }
                        if doc.namingScopeIsValid(labelId: labelId) { o.wrongAnswers += 1 }
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group {
                total.setupFailures += o.setupFailures
                total.wrongAnswers += o.wrongAnswers
            }
            return total
        }

        #expect(agg.setupFailures == 0, "document or box creation failed (expected 0 of 160)")
        #expect(agg.wrongAnswers == 0, "a document's naming scope reflected another's state")
    }

    @Test("Concurrent font-database init + queries don't crash or deadlock")
    func concurrentFontQueriesSucceed() async throws {
        // Font availability is environment-dependent, so the expectation is relative: read the
        // count once serially, then require every concurrent read to agree with it.
        // initDatabase() rebuilds the same list under the mutex, so a reader that saw an empty
        // or half-built list (the #361 race) disagrees. The pinned kernel registers no fonts
        // at all (FontManagerTests.fontCount pins 0), so there the in-range branch below is
        // dormant and the agreement of the counts is the whole assertion; where fonts exist
        // it also requires every in-range index to resolve.
        FontManager.initDatabase()
        let expectedCount = FontManager.fontCount

        struct Outcome: Sendable {
            var countMismatches = 0
            var missingEntries = 0
        }
        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for taskIndex in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    for i in 0..<10 {
                        if (taskIndex + i) % 3 == 0 {
                            FontManager.initDatabase()
                        }
                        let count = FontManager.fontCount
                        if count != expectedCount { o.countMismatches += 1 }
                        if count > 0 {
                            let idx = i % count
                            if FontManager.fontName(at: idx) == nil { o.missingEntries += 1 }
                            // A font without a regular face has no regular path, so the path
                            // is only required where the same font says it has one.
                            if FontManager.fontHasAspect(at: idx, aspect: .regular),
                                FontManager.fontPath(at: idx) == nil
                            {
                                o.missingEntries += 1
                            }
                        }
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group {
                total.countMismatches += o.countMismatches
                total.missingEntries += o.missingEntries
            }
            return total
        }

        #expect(agg.countMismatches == 0, "font count changed under concurrent initDatabase()")
        #expect(
            agg.missingEntries == 0,
            "an in-range font index had no name, or a regular face had no path")
    }
}
