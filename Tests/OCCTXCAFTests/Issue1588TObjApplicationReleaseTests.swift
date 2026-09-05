import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #1588: `OCCTTObjApplicationGetInstance()` (`OCCTBridge_Document_DocumentLifecycle.mm`) bumps
/// `TObj_Application::GetInstance()`'s refcount on every call, and until this fix nothing
/// anywhere released it, in violation of this project's own "every creating function needs a
/// matching Release" rule (see the "Handle-Based Memory Management" section of CLAUDE.md).
///
/// `TObj_Application::GetInstance()` (`TObj_Application.cxx`) is a function-local static
/// `Handle(TObj_Application)` that keeps one reference alive for the whole process regardless of
/// anything a caller does, so this leak was never observable as a crash or a wrong value, only as
/// a refcount that grows by exactly one per `.shared` access and never comes back down. Verified
/// directly (a standalone ground-truth probe against `TObj_Application::GetInstance()`, mirroring
/// `OCCTTObjApplicationGetInstance()`'s own construction/`IncrementRefCounter()`/return sequence
/// byte for byte): a true baseline of 1 (just the static handle) becomes 2 after one such call and
/// its own local `Handle` unwinding, exactly the one net leaked increment the issue describes.
///
/// `OCCTTObjApplicationRelease` (new) undoes that increment with `DecrementRefCounter()` alone. It
/// deliberately does NOT follow `OCCTMessengerRelease`/`OCCTReportRelease`'s sibling pattern of
/// `if (GetRefCount() == 0) delete`: those two wrap ordinary, non-singleton `Standard_Transient`
/// objects with exactly one owner, where reaching a zero count really does mean nothing else holds
/// a reference. `TObj_Application::GetInstance()`'s static handle means a zero count can still
/// happen (an over-release, or a caller pattern that doesn't 1:1-match every `.shared` with a
/// `deinit`), and deleting on it there would free the object out from under that still-live static
/// handle. Proved this empirically, not just architecturally: the same ground-truth probe above,
/// built a second time with `OCCTTObjApplicationRelease`'s body swapped for the
/// `OCCTMessengerRelease`-shaped "decrement then delete-on-zero" pattern, does call `delete` on the
/// live singleton the moment a double-release drives its count to 0 -- confirmed by a printf inside
/// the delete branch actually firing. The subsequent `GetInstance()`/`SetVerbose()`/`IsVerbose()`
/// calls happened not to crash in that run (undefined behavior reading/writing just-freed memory,
/// not a guaranteed crash), which is exactly why this shape is dangerous rather than self-evidently
/// broken: a "fixed" implementation copy-pasted from the Messenger/Report pattern would pass an
/// ordinary single get+release test and only corrupt the process under a double-release or a
/// caller that releases more often than it gets the singleton.
///
/// The tests below exercise that same double-release shape, and a longer repeated get+release
/// stress loop, directly against the SHIPPED (decrement-only) implementation, at the bridge level
/// (bypassing the Swift `TObjApplication` wrapper, the same way `Issue1424BndLibFaceNullGuardTests`
/// and siblings call bridge C functions directly). They cannot observe the refcount itself (no
/// bridge accessor exposes it, and adding one purely for a test felt like the wrong tradeoff for a
/// leak this low-severity), so, per this project's Test Conventions policy of proving a new test
/// actually catches its defect, the meaningful "does this fail without the fix" signal here is
/// twofold: (1) this file fails to even COMPILE against the pre-fix tree, since
/// `OCCTTObjApplicationRelease` does not exist yet -- a legitimate failure mode for a purely
/// additive bridge function; and (2) the standalone ground-truth probe described above, run
/// against a deliberately wrong ("delete-on-zero") alternative implementation, demonstrably
/// corrupts the singleton where the shipped implementation does not, which is the actual
/// correctness property this test suite protects.
///
/// `TObjApplication`'s own doc comment already flags `isVerbose`/`createDocument()` as mutating
/// the shared singleton's plain fields with no synchronization (a *different*, pre-existing race,
/// #1404), so every read-modify-verify sequence below runs inside `OCCTSerial.withLock { }`, its
/// documented mitigation, to keep these tests deterministic under Swift Testing's parallel
/// execution rather than racing every other test in this target that touches the same singleton.
@Suite("Issue #1588: TObjApplication release path")
struct Issue1588TObjApplicationReleaseTests {

    @Test("a single get + release round-trip does not crash and leaves the singleton usable")
    func singleGetReleaseRoundTrip() throws {
        try OCCTSerial.withLock {
            let app = try #require(OCCTTObjApplicationGetInstance())
            OCCTTObjApplicationRelease(app)

            // The singleton must still be alive and fully functional immediately afterward:
            // TObj_Application::GetInstance()'s own static Handle keeps it alive regardless.
            let again = try #require(OCCTTObjApplicationGetInstance())
            OCCTTObjApplicationSetVerbose(again, true)
            #expect(OCCTTObjApplicationIsVerbose(again))
            OCCTTObjApplicationRelease(again)
        }
    }

    @Test("releasing more times than the singleton was fetched (double-release) does not crash")
    func doubleReleaseDoesNotCorruptSingleton() throws {
        try OCCTSerial.withLock {
            let app = try #require(OCCTTObjApplicationGetInstance())
            OCCTTObjApplicationRelease(app)
            // An extra, unmatched release: no corresponding OCCTTObjApplicationGetInstance() call.
            // This is exactly the sequence the ground-truth probe (see the suite's own doc comment)
            // showed WOULD delete the singleton under the Messenger/Report-shaped alternative that
            // was considered and rejected; the shipped decrement-only implementation must survive it.
            OCCTTObjApplicationRelease(app)

            let again = try #require(OCCTTObjApplicationGetInstance())
            OCCTTObjApplicationSetVerbose(again, false)
            #expect(!OCCTTObjApplicationIsVerbose(again))
            let doc = OCCTTObjApplicationCreateDocument(again)
            #expect(doc != nil)
            if let doc { OCCTDocumentRelease(doc) }
            OCCTTObjApplicationRelease(again)
        }
    }

    @Test("many repeated get+release cycles leave the singleton alive and functional")
    func repeatedGetReleaseCyclesDoNotCorruptSingleton() throws {
        try OCCTSerial.withLock {
            for i in 0..<500 {
                guard let app = OCCTTObjApplicationGetInstance() else {
                    Issue.record("OCCTTObjApplicationGetInstance() returned nil on iteration \(i)")
                    return
                }
                OCCTTObjApplicationSetVerbose(app, i % 2 == 0)
                OCCTTObjApplicationRelease(app)
            }

            let again = try #require(OCCTTObjApplicationGetInstance())
            let doc = try #require(OCCTTObjApplicationCreateDocument(again))
            OCCTDocumentRelease(doc)
            OCCTTObjApplicationRelease(again)
        }
    }

    @Test("TObjApplication.shared accessed and dropped repeatedly (deinit -> Release) stays usable")
    func repeatedSharedAccessDoesNotCorruptSingleton() throws {
        // Public-API counterpart of the bridge-level stress test above: `.shared` is an ordinary
        // computed property callers are expected to invoke fresh each time, so each iteration's
        // `TObjApplication` wrapper is dropped at the end of the loop body, running `deinit` ->
        // `OCCTTObjApplicationRelease` on the shared singleton just like `StressBuilderLifecycleTests`'s
        // `destroyWithoutBuild`-style tests do for their own builders.
        try OCCTSerial.withLock {
            for i in 0..<500 {
                guard let app = TObjApplication.shared else {
                    Issue.record("TObjApplication.shared returned nil on iteration \(i)")
                    return
                }
                app.isVerbose = (i % 2 == 0)
            }

            let app = try #require(TObjApplication.shared)
            app.isVerbose = true
            #expect(app.isVerbose)
            let doc = app.createDocument()
            #expect(doc != nil)
        }
    }
}
