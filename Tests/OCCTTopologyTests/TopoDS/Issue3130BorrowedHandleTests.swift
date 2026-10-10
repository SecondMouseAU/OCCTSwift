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
@Suite("Issue3130BorrowedHandle")
struct Issue3130BorrowedHandleTests {
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
