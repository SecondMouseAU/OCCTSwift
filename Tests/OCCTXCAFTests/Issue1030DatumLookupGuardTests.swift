import Foundation
import Testing

@testable import OCCTSwift

// #1030: `XCAFDoc_Datum::GetObject` builds the datum point's X from the annotation plane's array
// rather than the point's own, so a datum carrying a point with no plane location dereferences a
// null handle and takes the process down with an uncatchable SIGSEGV (#1022).
// `Scripts/patches/0029-*` fixes it in the kernel and is in no built kernel, so
// `occtDocumentDatumObjectAt` refuses that one shape before it calls `GetObject`.
@Suite("Datum lookup refuses the point-without-plane shape (#1030)")
struct Issue1030DatumLookupGuardTests {

    // XCAFDoc_Datum.cxx's ChildLab_* values are a file-local anonymous enum, invisible from the
    // header, so the two tags the guard reads are spelled out here as they are in the bridge.
    private static let planeLocationTag: Int32 = 14
    private static let pointTag: Int32 = 17

    /// The datum label carrying `name`.
    ///
    /// Found through the name child rather than by walking to the DimTol tool at a fixed tag:
    /// `XCAFDoc_Datum::SetObject` writes the object's name to a child label, so the datum label is
    /// that child's father, and the search needs no third private tag.
    private func datumLabel(_ doc: Document, named name: String) -> AssemblyNode? {
        guard let main = doc.mainLabel else { return nil }
        return main.descendants(allLevels: true).first { $0.asciiString == name }?.father
    }

    /// A three-element `TDataStd_RealArray` on the child of `label` at `tag`, matching what
    /// `XCAFDoc_Datum::SetObject` writes for a plane location or a point.
    @discardableResult
    private func writeTriple(_ label: AssemblyNode, tag: Int32, _ value: Double) -> Bool {
        guard let child = label.findChild(tag: tag, create: true) else { return false }
        guard child.initRealArray(lower: 1, upper: 3) else { return false }
        return (1...3).allSatisfy { child.setRealArrayValue(at: $0, value: value) }
    }

    /// A document holding one datum, with the point child written and the plane location child
    /// written only when `withPlaneLocation` is set.
    private func documentWithPointDatum(withPlaneLocation: Bool) -> (Document, Int)? {
        guard let doc = Document.create() else { return nil }
        let name = "Datum1030"
        guard let index = doc.createDatum(name: name) else { return nil }
        guard let label = datumLabel(doc, named: name) else { return nil }
        if withPlaneLocation {
            guard writeTriple(label, tag: Self.planeLocationTag, 6) else { return nil }
        }
        guard writeTriple(label, tag: Self.pointTag, 7) else { return nil }
        return (doc, index)
    }

    @Test("The crashing shape is authorable through the public label API")
    func theCrashingShapeIsAuthorable() {
        // Nothing on this path reaches XCAFDoc_Datum::GetObject, so it runs unfixed as well as
        // fixed. It exists because every other test here asserts a refusal, and a refusal is
        // indistinguishable from a fixture that never built what it claims to.
        guard let doc = Document.create() else {
            Issue.record("document nil")
            return
        }
        let name = "Datum1030"
        guard let index = doc.createDatum(name: name) else {
            Issue.record("createDatum nil")
            return
        }
        #expect(index == 0)
        guard let label = datumLabel(doc, named: name) else {
            Issue.record("datum label not found")
            return
        }
        // Child existence proves nothing here: XCAFDoc_Datum::SetObject opens every child from
        // ChildLab_Begin to ChildLab_End and only forgets their attributes, so createDatum leaves
        // all nineteen present and empty. The array attribute is what both the kernel and the
        // guard actually test, so that is what this asserts.
        #expect(label.findChild(tag: Self.pointTag)?.realArrayBounds == nil)
        #expect(writeTriple(label, tag: Self.pointTag, 7))
        // The point child now holds (7, 7, 7) and no plane location array exists, which is the
        // state XCAFDoc_Datum::GetObject reads its aLoc handle out of while it is still null.
        let point = label.findChild(tag: Self.pointTag)
        #expect(point?.realArrayBounds?.upper == 3)
        #expect(point?.realArrayValue(at: 1) == 7)
        #expect(point?.realArrayValue(at: 3) == 7)
        #expect(label.findChild(tag: Self.planeLocationTag)?.realArrayBounds == nil)
    }

    @Test("A datum with a point and no plane location is refused rather than read")
    func pointWithoutPlaneLocationIsRefused() {
        guard let (doc, index) = documentWithPointDatum(withPlaneLocation: false) else {
            Issue.record("fixture nil")
            return
        }
        // Unfixed this is a SIGSEGV inside GetObject, not a nil, so the whole test process dies
        // here and no assertion below reports.
        #expect(doc.datum(at: index) == nil)
        #expect(doc.datums.isEmpty)
    }

    @Test("A write path takes the same refusal, since the shared lookup runs before it")
    func aWritePathIsRefusedToo() {
        guard let (doc, index) = documentWithPointDatum(withPlaneLocation: false) else {
            Issue.record("fixture nil")
            return
        }
        // Five of the seven callers of the shared lookup are writes, and the lookup calls
        // GetObject before any of them can look at what it returned, so a write that never
        // touches the point still took the crash.
        #expect(!doc.setDatumPosition(at: index, 2))
        #expect(!doc.setDatumTarget(at: index, type: .point, number: 1))
    }

    @Test("A datum with both a point and a plane location still reads")
    func pointWithPlaneLocationStillReads() {
        guard let (doc, index) = documentWithPointDatum(withPlaneLocation: true) else {
            Issue.record("fixture nil")
            return
        }
        // The guard is only about the null handle. A plane location makes GetObject's aLoc
        // non-null, so the read completes, and the datum point OCCT then builds is wrong in its X
        // (#1022) but is not part of what the bridge reports.
        let datum = doc.datum(at: index)
        #expect(datum != nil)
        #expect(datum?.name == "Datum1030")
        #expect(doc.datums.count == 1)
    }

    @Test("A datum with no point child is untouched by the guard")
    func plainDatumStillReads() {
        guard let doc = Document.create() else {
            Issue.record("document nil")
            return
        }
        guard let index = doc.createDatum(name: "Datum1030") else {
            Issue.record("createDatum nil")
            return
        }
        // The control that keeps the two refusals above from passing by refusing every datum.
        // This is also the only shape anything in this package writes today.
        let datum = doc.datum(at: index)
        #expect(datum?.name == "Datum1030")
        #expect(doc.setDatumPosition(at: index, 2))
        #expect(doc.datum(at: index)?.position == 2)
    }
}
