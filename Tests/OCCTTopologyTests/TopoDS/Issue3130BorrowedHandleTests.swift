import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #3130. `Edge.handle`, `Wire.handle`, `Face.handle` and `Shape.handle` are borrowed pointers: the
// compiler does not tie them to their owner. When the owner is a collection element or a
// temporary, an optimised build may release it once the `.handle` load is its last use, before
// the C call that receives the pointer runs. Measured on macOS `-c release` with
// `Scripts/repro/3130-borrowed-handle/`: every shape below crashed or answered wrongly on the
// bare `.handle` form, and answered correctly through `withHandle`.
//
// A debug build extends every lifetime to scope end, so these tests cannot fail there. They are the
// release-build regression for the helper; the static half is `check-borrowed-handle-temporaries.py`.
// CI runs them in the `release-mode-tests` job (Scripts/release-mode-test.sh, which selects every
// suite that mentions `.handle` or `withHandle`, this one included). Run them in an optimised
// build locally with
//   swift test -c release -Xswiftc -enable-testing --filter Issue3130BorrowedHandle
/// What `Probe.handle` hands out: a flag the owner's `deinit` clears, readable after the owner is gone.
private final class ProbeToken: @unchecked Sendable {
    var ownerIsAlive = true
}

/// A `NativeHandleOwner` whose lifetime is observable without touching OCCT (#3258). The pointer-based
/// tests below cannot tell whether `withHandle` held its owner, because the owners they use are kept
/// alive by something else (the enclosing `#require` temporary, a `let`, the optimiser's own choice).
/// This one can: the handle it hands out is the token its `deinit` clears.
private final class Probe: NativeHandleOwner {
    let token = ProbeToken()
    var handle: ProbeToken { token }
    deinit { token.ownerIsAlive = false }

    /// Never inlined, so the caller cannot see that the result is a fresh +1 temporary.
    @inline(never) static func make() -> Probe { Probe() }
    @inline(never) static func makeArray() -> [Probe] { [Probe(), Probe()] }
}

// #3258. The three OCCT tests in this suite pass when `withHandle` is changed to `try body(handle)`
// (measured, macOS arm64 `-c release`, every Malloc* variable set), so by themselves they pin the call
// sites and not the helper's contract. The `Probe` tests are the ones that fail on that change.
//
// WHAT THE PROBE TESTS CAN AND CANNOT DO. `withHandle` is `@inline(__always)`, and a method call only
// keeps its receiver alive while it is NOT inlined (the caller guarantees `self`); once inlined, the
// owner's last use is the `handle` load, and `withExtendedLifetime(self)` is the only thing that moves
// its release past the body. That is a release-build effect: a debug build keeps every temporary to the
// end of its statement, so these tests pass in debug whether or not the helper is correct. They are the
// release-mode job's regression for the helper; in a debug `swift test` they are expected to be green
// and prove nothing about `withHandle`.
@Suite("Issue3130BorrowedHandle")
struct Issue3130BorrowedHandleTests {
    @Test("a temporary owner is still alive inside the body (observable owner, no OCCT)")
    func temporaryOwnerIsAliveInsideBody() {
        let aliveInside = Probe.make().withHandle { token in token.ownerIsAlive }
        #expect(aliveInside, "withHandle must keep a temporary owner alive until the body returns")
    }

    @Test("an owner taken from an array and dropped by the body is still alive in it")
    func arrayElementOwnerIsAliveInsideBody() {
        var probes: [Probe]? = Probe.makeArray()
        let aliveInside = probes![0].withHandle { token -> Bool in
            // The array held the only other reference to the owner; the body drops it.
            probes = nil
            return token.ownerIsAlive
        }
        #expect(aliveInside, "withHandle must keep the element alive after the array drops it")
    }

    private static func box() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)
    }

    @Test("a setter called through a collection element lands")
    func setterThroughCollectionElementLands() throws {
        let b = try #require(Self.box())
        let edges = b.edges()
        try #require(edges.count == 12)
        edges[0].withHandle { OCCTEdgeSetSameParameter($0, false) }
        // A fresh walk, so `edges` is not used again after the call.
        #expect(b.isValid == false, "the cleared SameParameter flag must reach the shared TShape")
        b.sameParameterAll(tolerance: 1e-5)
        #expect(b.isValid)
    }

    @Test("a read through a collection element or a temporary answers")
    func readsThroughElementsAndTemporaries() throws {
        let b = try #require(Self.box())
        let faces = b.faces()
        try #require(faces.count == 6)
        let area = faces[0].withHandle { OCCTFaceGetArea($0, 1e-6) }
        #expect(abs(area - 100) < 1e-6)
        let length = try #require(b.edges().first).withHandle { OCCTEdgeGetLength($0) }
        #expect(abs(length - 10) < 1e-9)
        let valid = try #require(Self.box()).withHandle { OCCTShapeIsValid($0) }
        #expect(valid)
        let wireLength = try #require(Wire.rectangle(width: 4, height: 3)).withHandle {
            OCCTWireGetLength($0)
        }
        #expect(abs(wireLength - 14) < 1e-9)
    }

    @Test("the owner outlives the body even when its last strong reference is dropped inside it")
    func ownerOutlivesBody() throws {
        let b = try #require(Self.box())
        var edges: [Edge]? = b.edges()
        weak let weakEdge = edges?.first
        let aliveInside = try #require(edges?.first).withHandle { handle -> Bool in
            edges = nil
            return weakEdge != nil && OCCTEdgeGetLength(handle) > 0
        }
        #expect(aliveInside, "withHandle must keep the Edge alive until the body returns")
    }
}
