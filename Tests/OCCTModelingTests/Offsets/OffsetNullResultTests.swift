import Testing

@testable import OCCTSwift

/// #3061: an offset OCCT reports as done with a NULL result used to reach Swift as a non-nil
/// ``Shape`` wrapping a null `TopoDS_Shape`, for which every query is meaningless.
///
/// The input is deterministic on the released kernel: a 10 mm cube offset inward by more than half
/// its width collapses, and `BRepOffsetAPI_MakeOffsetShape::PerformByJoin` with `GeomAbs_Arc`
/// answers `IsDone()` with a null shape (measured three processes running, every time). The
/// intermittent route from the issue (the fuse of two boxes with coplanar faces left split) is not
/// used, because it depends on allocation addresses (#3003).
@Suite("Offset null result (#3061)")
struct Issue3061OffsetNullResultTests {

    @Test("A collapsing arc-join offset returns nil, never a wrapper around a null shape")
    func collapsingArcOffsetIsNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // A list walked in one test rather than `@Test(arguments:)`, so a failure names the case.
        for distance in [-5.1, -6.0, -50.0] {
            let result = box.offset(by: distance, joinType: .arc)
            #expect(result == nil, "distance \(distance)")
            if let result {
                #expect(!result.isNull, "distance \(distance) returned a null shape")
            }
        }
    }

    @Test("An offset that does not collapse still returns a real shape")
    func nonCollapsingOffsetStillWorks() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for distance in [-1.0, 1.0] {
            let result = try #require(box.offset(by: distance, joinType: .arc))
            #expect(!result.isNull)
            #expect(result.isValid)
        }
    }
}
