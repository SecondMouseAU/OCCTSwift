import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #2866: the four buffer-taking OCAF array setters handed the caller's `lower`/`upper` straight
/// to a `TDataStd_*Array::Set`.
///
/// Every `Init` in that family opens with
/// `Standard_RangeError_Raise_if(upper < lower)`, which is out-of-line and therefore absent from
/// the Release kernel we link, so the range reached `NCollection_HArray1` unchecked, where `mySize`
/// is `upper - lower + 1` evaluated in `int` and stored in a `size_t`.
///
/// Measured in `Scripts/repro/2866/`, one process per case, against the pinned kernel: with
/// `lower` 10 and `upper` 1, `OCCTDocumentSetByteArray`, `OCCTDocumentSetExtStringArray` and
/// `OCCTDocumentSetReferenceArray` each SIGSEGV inside `Set`, uncatchably.
/// `OCCTDocumentSetBooleanArray` survives on the arithmetic of its own `Init` and answers `true`,
/// leaving an attribute whose `Upper()` is below its `Lower()`.
///
/// **Two of these tests fail differently under injection, and that is the point.** Remove the
/// guard and `reversedRangeIsRefused` does not report a failed `#expect`: the test process dies
/// with signal 11 on the second case. `setBooleanArrayReversedRangeIsRefused` is the one that
/// fails as an ordinary assertion, because the boolean setter never faulted. Both are recorded in
/// the PR, per `okf/policies/prove-the-test-fails.md`.
///
/// The reversed ranges below are not reachable from the Swift wrappers, which always pass
/// `1, count` (or `0, count - 1`). The exposure is the public C ABI that
/// `docs/guides/consuming-from-objective-c.md` documents as supported, so the tests call it.
@Suite("Issue 2866: OCAF array setter ranges")
struct Issue2866OCAFArraySetterRangeTests {

    /// Reversed by more than one, the ranges that fault.
    ///
    /// One document per case: a process that survives a corrupt allocation is not a process to
    /// reuse.
    @Test("the four buffer-taking array setters refuse a reversed range")
    func reversedRangeIsRefused() {
        // Written as one test walking a list rather than @Test(arguments:), per
        // swiftlang/swift#91639: an element pairing a reference-counted member with a builtin
        // vector of 32 bytes or more corrupts the task allocator whatever the body does.
        let reversed: [(Int32, Int32)] = [
            (10, 1), (1, -1), (0, -1_000_000), (Int32.max, Int32.min),
        ]
        for (lower, upper) in reversed {
            guard let doc = Document.create() else {
                Issue.record("could not create a document")
                return
            }
            let h = doc.handle
            let bools: [Bool] = [true]
            let bytes: [UInt8] = [1]
            let refs: [Int32] = [3]

            #expect(
                bools.withUnsafeBufferPointer {
                    OCCTDocumentSetBooleanArray(h, 21, lower, upper, $0.baseAddress!, 1)
                } == false,
                "boolean array, lower \(lower) / upper \(upper)")
            #expect(
                bytes.withUnsafeBufferPointer {
                    OCCTDocumentSetByteArray(h, 22, lower, upper, $0.baseAddress!, 1)
                } == false,
                "byte array, lower \(lower) / upper \(upper)")
            #expect(
                withOneCString("x") {
                    OCCTDocumentSetExtStringArray(h, 23, lower, upper, $0, 1)
                } == false,
                "ext string array, lower \(lower) / upper \(upper)")
            #expect(
                refs.withUnsafeBufferPointer {
                    OCCTDocumentSetReferenceArray(h, 24, lower, upper, $0.baseAddress!, 1)
                } == false,
                "reference array, lower \(lower) / upper \(upper)")

            // Refused means nothing was created, so no attribute reads back.
            #expect(doc.hasBooleanArray(tag: 21) == false)
            #expect(doc.hasByteArray(tag: 22) == false)
            #expect(doc.hasExtStringArray(tag: 23) == false)
            #expect(doc.hasReferenceArray(tag: 24) == false)
        }
    }

    /// The boolean setter alone never faulted, so it is the case that fails as an assertion rather
    /// than as a signal.
    ///
    /// Kept separate so a crash in the sibling above cannot mask it.
    @Test("setBooleanArray no longer builds an array whose Upper is below its Lower")
    func setBooleanArrayReversedRangeIsRefused() {
        guard let doc = Document.create() else {
            Issue.record("could not create a document")
            return
        }
        let values: [Bool] = [true]
        let created = values.withUnsafeBufferPointer {
            OCCTDocumentSetBooleanArray(doc.handle, 31, 10, 1, $0.baseAddress!, 1)
        }
        #expect(created == false, "lower 10 / upper 1 answered true and created a malformed array")
        #expect(doc.hasBooleanArray(tag: 31) == false)
    }

    /// `upper == lower - 1` is the one reversed spelling that does not fault, and it is the one the
    /// Swift wrappers produce for an empty array.
    ///
    /// It is refused anyway: OCAF cannot persist it. Measured in `Scripts/repro/2866/`, an
    /// attribute built that way saves to BinOcaf and to XmlOcaf and reloads as "failure reading
    /// attribute" from OCCT's own drivers, while a one-element control round-trips clean.
    @Test("the exactly-empty range is refused too, since OCAF cannot persist it")
    func exactlyEmptyRangeIsRefused() {
        guard let doc = Document.create() else {
            Issue.record("could not create a document")
            return
        }
        #expect(doc.setBooleanArray(tag: 41, values: []) == false)
        #expect(doc.setByteArray(tag: 42, values: []) == false)
        #expect(doc.setExtStringArray(tag: 43, values: []) == false)
        #expect(doc.setReferenceArray(tag: 44, refTags: []) == false)

        #expect(doc.hasBooleanArray(tag: 41) == false)
        #expect(doc.hasByteArray(tag: 42) == false)
        #expect(doc.hasExtStringArray(tag: 43) == false)
        #expect(doc.hasReferenceArray(tag: 44) == false)
    }

    /// The `TDataStd_*List` attributes are what an empty collection belongs in, and they still take
    /// one.
    ///
    /// This is the assertion that keeps the refusal above from reading as a dead end.
    @Test("the list attributes still accept an empty collection")
    func listAttributesStillAcceptEmpty() {
        guard let doc = Document.create() else {
            Issue.record("could not create a document")
            return
        }
        #expect(doc.setBooleanList(tag: 51, values: []))
        #expect(doc.setExtStringList(tag: 52, values: []))
        #expect(doc.setReferenceList(tag: 53, refTags: []))
        #expect(doc.booleanList(tag: 51) == [])
    }

    /// Nothing above is worth anything if the guard also refuses the ranges the wrappers really
    /// use.
    ///
    /// Every well-formed range still lands and reads back.
    @Test("well-formed ranges are unaffected")
    func wellFormedRangesStillWork() {
        guard let doc = Document.create() else {
            Issue.record("could not create a document")
            return
        }
        #expect(doc.setBooleanArray(tag: 61, values: [true, false, true]))
        #expect(doc.booleanArray(tag: 61) == [true, false, true])

        #expect(doc.setByteArray(tag: 62, values: [1, 2, 3, 255]))
        #expect(doc.byteArray(tag: 62) == [1, 2, 3, 255])

        #expect(doc.setExtStringArray(tag: 63, values: ["alpha", "beta"]))
        #expect(doc.extStringArrayLength(tag: 63) == 2)
        #expect(doc.extStringArrayValue(tag: 63, index: 1) == "alpha")

        #expect(doc.setReferenceArray(tag: 64, refTags: [2, 3]))
        #expect(doc.referenceArray(tag: 64)?.count == 2)

        // A one-element array is the smallest well-formed range, and `lower == upper` is the
        // boundary the guard sits next to.
        #expect(doc.setByteArray(tag: 65, values: [7]))
        #expect(doc.byteArray(tag: 65) == [7])
    }

    // MARK: - Helper

    /// One C string, as the one-element `const char* const*` the ext string bridge takes.
    private func withOneCString<R>(
        _ value: String, _ body: (UnsafePointer<UnsafePointer<CChar>>) -> R
    ) -> R {
        value.withCString { cString in
            let pointers: [UnsafePointer<CChar>] = [cString]
            return pointers.withUnsafeBufferPointer { body($0.baseAddress!) }
        }
    }
}
