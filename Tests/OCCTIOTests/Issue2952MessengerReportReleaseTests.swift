import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #2952: `OCCTMessengerRelease` and `OCCTReportRelease` must act only on a pointer the matching
/// create handed out and has not already taken back.
///
/// Both took the pointer on trust. Their parameters are `_Nonnull`, which the compiler does not
/// enforce and which `OCCTBridge` being reachable to a consumer makes worth defending: #967
/// measured a consumer Swift target writing `import OCCTBridge` and a consumer `.m` writing
/// `#import "OCCTBridge.h"`, and both compile, link and run.
///
/// This is the sibling of #2897, with a worse ending. There the over-released object was
/// `TObj_Application`, a process-wide singleton whose own function-local static `Handle` holds a
/// permanent reference, so the bad release freed nothing at the time and the object died later in
/// an innocent caller, about 660 test lines away. `Message_Messenger` and `Message_Report` have no
/// such static: the bridge's own reference is the only one, so the FIRST release already drops the
/// count to zero and deletes. A second one reads `GetRefCount()` out of freed memory and may
/// `delete` the block again, a use-after-free and a double free in one call.
///
/// **The observable.** #2897 could compare `OCCTTObjApplicationRefCount` across the operation
/// because its object survives. Nothing here survives a correct release, so the reference count
/// cannot be read at all afterwards and the invariant's only observable is the refusal itself:
/// `OCCTBridgeRefusedReleaseCount`, a process-wide count of the releases the bridge declined.
/// Its absolute value says nothing, which is why every test below reads a baseline first.
///
/// Serialized, and the count is read before and after each operation rather than compared against
/// a constant, because the counter is process-wide. No other suite in `OCCTIOTests` creates or
/// releases a messenger or a report, which is what makes the arithmetic exact here.
@Suite(
    "Issue #2952: a messenger or report release the bridge never handed out is refused",
    .serialized)
struct Issue2952MessengerReportReleaseTests {

    @Test("the one messenger release the bridge owes goes through, and every later one is refused")
    func repeatedMessengerReleaseIsRefused() throws {
        let baseline = OCCTBridgeRefusedReleaseCount()
        let messenger = try #require(OCCTMessengerCreate())

        OCCTMessengerRelease(messenger)
        #expect(
            OCCTBridgeRefusedReleaseCount() == baseline,
            "a release matching OCCTMessengerCreate must not be refused")

        // Before #2952 this read GetRefCount() out of the block the line above freed, and deleted
        // it again whenever that read came back 0.
        OCCTMessengerRelease(messenger)
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 1)

        // A third, because the refusal has to be a property of the function rather than a
        // one-shot guard.
        OCCTMessengerRelease(messenger)
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 2)
    }

    @Test("the one report release the bridge owes goes through, and every later one is refused")
    func repeatedReportReleaseIsRefused() throws {
        let baseline = OCCTBridgeRefusedReleaseCount()
        let report = try #require(OCCTReportCreate())

        OCCTReportRelease(report)
        #expect(
            OCCTBridgeRefusedReleaseCount() == baseline,
            "a release matching OCCTReportCreate must not be refused")

        OCCTReportRelease(report)
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 1)

        OCCTReportRelease(report)
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 2)
    }

    /// The zero-bit-pattern pointer the `_Nonnull` annotation says cannot exist, synthesized the
    /// way #1424 / #1492 / #1507 do. It is reinterpreted from a null `Optional` pointer rather
    /// than from `UInt(0)`: `UnsafeMutableRawPointer(bitPattern:)` cannot express it, since it
    /// returns `nil` for 0 by construction, and `unsafeBitCast` from an integer earns a fix-it
    /// warning pointing at that initializer. Same eight zero bytes, no warning.
    private func nullRef() -> UnsafeMutableRawPointer {
        unsafeBitCast(UnsafeMutableRawPointer?.none, to: UnsafeMutableRawPointer.self)
    }

    /// Unguarded, `DecrementRefCounter()` on a null is a dereference inside `Standard_Transient`,
    /// which is an uncatchable OS signal in this build rather than something the function's
    /// `catch (...)` absorbs.
    @Test("a null is refused by both entry points")
    func nullReleaseIsRefused() {
        let baseline = OCCTBridgeRefusedReleaseCount()

        OCCTMessengerRelease(nullRef())
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 1)

        OCCTReportRelease(nullRef())
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 2)
    }

    /// The registry's point is that the bridge releases what it handed out, not what it is handed.
    /// A heap block the bridge never produced is the clearest case of the second: `malloc` is used
    /// rather than a stack address so the pointer is unambiguously valid memory that is simply not
    /// a `Message_Messenger`, which is exactly what a consumer passing the wrong handle supplies.
    @Test("a pointer this bridge never handed out is refused by both entry points")
    func foreignPointerReleaseIsRefused() throws {
        let foreign = try #require(malloc(64))
        defer { free(foreign) }

        let baseline = OCCTBridgeRefusedReleaseCount()

        OCCTMessengerRelease(foreign)
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 1)

        OCCTReportRelease(foreign)
        #expect(OCCTBridgeRefusedReleaseCount() == baseline + 2)
    }

    /// The registry is address-keyed, so a messenger still alive must not be disturbed by traffic
    /// around it: the refusals above have to leave a live object releasable exactly once.
    @Test("a live messenger is still released exactly once after refusals elsewhere")
    func refusalsDoNotDisturbALiveMessenger() throws {
        let live = try #require(OCCTMessengerCreate())

        let stale = try #require(OCCTMessengerCreate())
        OCCTMessengerRelease(stale)
        OCCTMessengerRelease(stale)

        // Untouched by the over-release above, and still usable.
        #expect(OCCTMessengerPrinterCount(live) >= 0)

        let baseline = OCCTBridgeRefusedReleaseCount()
        OCCTMessengerRelease(live)
        #expect(
            OCCTBridgeRefusedReleaseCount() == baseline,
            "the live messenger's own release must still be the one the bridge owes")
    }
}
