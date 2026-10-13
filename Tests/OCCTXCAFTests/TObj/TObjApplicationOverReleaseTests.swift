import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #2897: `OCCTTObjApplicationRelease` must refuse a release that no `GetInstance` paid for.
///
/// `TObj_Application` is a process-wide singleton whose own function-local static `Handle` holds
/// one permanent reference. Until this fix the bridge's release was a bare
/// `DecrementRefCounter()`, so a release with no matching `OCCTTObjApplicationGetInstance()` took
/// that permanent reference's place in the count. Nothing was freed at that moment, which is what
/// made it look safe and is why `Issue1588TObjApplicationReleaseTests` could assert "does not
/// crash" and pass: the object dies later, when the next ordinary `occ::handle` falls out of
/// scope, decrements to zero and calls `Delete()`. `GetInstance()`'s static handle then dangles,
/// and every later caller reads a vptr out of reclaimed memory and dispatches through it.
///
/// That is #2897's trace. On wasm the function index the garbage vptr selects has a type the call
/// site did not declare and the engine traps, which is why `OCCTXCAFTests` died inside
/// `OCCTTObjApplicationCreateDocument` roughly 660 test lines after the over-release. On Apple the
/// same read is an indirect branch through whatever the reclaimed block now holds;
/// `Scripts/repro/2897/run.sh --native` is a SIGSEGV on the same sequence, so this was never a
/// wasm defect, only a defect wasm is the one platform to report.
///
/// The reference count is the only observable this invariant has, which is why
/// `OCCTTObjApplicationRefCount` exists. Its absolute value says nothing on its own, since it
/// counts every open document as well; what it is for is exactly this, comparing it across an
/// operation that must not change it.
@Suite("Issue #2897: an over-release must not strand the TObj_Application singleton")
struct Issue2897TObjApplicationOverReleaseTests {

    @Test("a release with no matching GetInstance leaves the reference count alone")
    func unmatchedReleaseLeavesTheReferenceCountAlone() throws {
        // `isVerbose`/`createDocument` reach the shared singleton's own unsynchronized fields
        // (#1404) and every other test in this target that touches it takes this lock; so does
        // this one, because the count it reads is process-wide and a concurrent `.shared` would
        // move it under the comparison.
        try OCCTSerial.withLock {
            let app = try #require(OCCTTObjApplicationGetInstance())
            OCCTTObjApplicationRelease(app)

            // Balanced: one get, one release. Whatever the count is now is what it has to stay.
            let balanced = OCCTTObjApplicationRefCount(app)
            #expect(balanced > 0)

            OCCTTObjApplicationRelease(app)
            #expect(OCCTTObjApplicationRefCount(app) == balanced)

            // And a second one, because the refusal has to be a property of the function rather
            // than a one-shot guard.
            OCCTTObjApplicationRelease(app)
            #expect(OCCTTObjApplicationRefCount(app) == balanced)
        }
    }
}
