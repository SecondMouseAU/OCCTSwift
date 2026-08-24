import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// PR #870 aggregate review: `OCCTShapeExtendShapeType`'s null-shape/exception fallback used to
/// return `7` (`TopAbs_VERTEX`, a real, legitimate case) instead of a failure sentinel, so
/// `Shape.predominantShapeType()` silently decoded a failed classification as `.vertex` with no
/// way for a caller to tell the two apart. Fixed to return `-1`, matching `ShapeType`'s own
/// `.unknown = -1` decode-failure case.
///
/// `Shape.handle` is non-optional, so the null-shape path isn't reachable through the public
/// Swift API (same as the other bridge null-guards this codebase documents as "hardening, not an
/// observable behavior change") -- this calls the bridge function directly with a null
/// `OCCTShapeRef` to exercise it.
@Suite("Issue #870: OCCTShapeExtendShapeType failure fallback")
struct Issue870ShapeExtendShapeTypeFailureTests {

    @Test("a null shape returns -1 (ShapeType.unknown), not 7 (TopAbs_VERTEX)")
    func nullShapeReturnsUnknownSentinel() {
        #expect(OCCTShapeExtendShapeType(nil, true) == -1)
        #expect(OCCTShapeExtendShapeType(nil, false) == -1)
        #expect(OCCTShapeExtendShapeType(nil, true) != 7)
    }

    @Test("the sentinel decodes to ShapeType.unknown, not a real case")
    func sentinelDecodesToUnknownNotVertex() {
        let raw = OCCTShapeExtendShapeType(nil, true)
        #expect(ShapeType(rawValue: Int(raw)) == .unknown)
        #expect(ShapeType(rawValue: Int(raw)) != .vertex)
    }

    @Test("an ordinary shape still reports its real predominant type, unaffected")
    func ordinaryShapeUnaffected() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.predominantShapeType() == .solid)

        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        #expect(vertex.predominantShapeType() == .vertex)
    }
}
