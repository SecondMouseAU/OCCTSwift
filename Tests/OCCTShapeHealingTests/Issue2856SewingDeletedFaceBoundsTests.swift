import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #2856. `BRepBuilderAPI_Sewing::DeletedFace`'s `Standard_OutOfRange_Raise_if` is out-of-line
/// (`BRepBuilderAPI_Sewing.cxx:2443`), so it is absent from the kernel this package links, and
/// `myLittleFace`'s own inline `FindKey` check is expanded inside that same `.cxx`, an OCCT unit
/// compiled `-DNo_Exception`, so it is compiled out at that depth too. `deletedFace(at: 1)` was
/// therefore an uncatchable SIGSEGV on any sewing that deleted no face, which is the normal outcome
/// for a well-formed input.
///
/// The valid range is `1...nbDeletedFaces`, settled by the container rather than by
/// `DeletedFace`'s own guard: `myLittleFace` is an `NCollection_IndexedMap`, whose `FindKey`
/// requires `1 <= index <= Size()` (`NCollection_IndexedMap.hxx:583`), and OCCT's own caller of
/// that member, `NCollection_IndexedMap::Assign` at `:302`, walks
/// `for (int i = 1; i <= Extent(); ++i)`. `DeletedFace`'s `index < 0` lower bound permits `0`,
/// which `FindKey` rejects outright, so the kernel guard is wrong about index `0` even in a build
/// that keeps it.
///
/// Every assertion here is the refusal, `nil`, rather than "the process survived": a test that only
/// checked survival would pass against a build that read whatever `myData2[index - 1]` happened to
/// point at.
@Suite("Issue 2856: sewing deletedFace bounds")
struct Issue2856SewingDeletedFaceBoundsTests {

    /// A box sewn from its own six faces. Nothing is deleted, so `nbDeletedFaces` is 0 and every
    /// index is out of range.
    private func cleanBoxSewing() throws -> SewingBuilder {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in box.subShapes(ofType: .face) {
            sewing.add(face)
        }
        sewing.perform()
        return sewing
    }

    @Test("every index is refused when the sewing deleted no face")
    func emptyMapRefusesEveryIndex() throws {
        let sewing = try cleanBoxSewing()
        #expect(sewing.nbDeletedFaces == 0)

        // Written as one test walking a list rather than @Test(arguments:), because an element
        // pairing a reference-counted member with a builtin vector of 32 bytes or more corrupts the
        // Swift task allocator (swiftlang/swift#91639). Index 1 is the important one: it is the
        // first index a caller would try, the one the documentation calls 1-based, and the one the
        // kernel guard would have let through into an empty map.
        let indices = [1, 0, -1, 2, 1000, Int(Int32.max), Int(Int32.min) + 1]
        for index in indices {
            #expect(
                sewing.deletedFace(at: index) == nil,
                "index \(index) is outside 1...0 and must answer nil")
        }
    }

    @Test("the bound is nbDeletedFaces, and one past it is refused")
    func onePastTheCountIsRefused() throws {
        let sewing = try cleanBoxSewing()
        let count = sewing.nbDeletedFaces
        #expect(sewing.deletedFace(at: count + 1) == nil)

        // Whatever the count is, walking 1...count never answers nil for an index inside it, and
        // count + 1 always does. With a count of 0 the loop is empty, which is the documented safe
        // pattern.
        if count > 0 {
            for index in 1...count {
                #expect(sewing.deletedFace(at: index) != nil, "index \(index) is in range")
            }
        }
    }

    @Test("the refusal does not disturb the rest of the sewing's results")
    func refusalLeavesTheSewingUsable() throws {
        let sewing = try cleanBoxSewing()
        _ = sewing.deletedFace(at: 1)
        _ = sewing.deletedFace(at: 1000)
        let result = try #require(sewing.result)
        #expect(result.isValid)
        #expect(sewing.nbDeletedFaces == 0)
        #expect(sewing.nbFreeEdges >= 0)
    }

    @Test("a null OCCTSewingRef still answers nullptr rather than reading the index")
    func nullSewingRefIsRefused() {
        let nullSewing: OCCTSewingRef = unsafeBitCast(UInt(0), to: OCCTSewingRef.self)
        #expect(OCCTSewingDeletedFace(nullSewing, 1) == nil)
    }
}
