import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #979: a sub-shape enumeration's array position is the sub-shape's ordinal.
///
/// An element that cannot be built is therefore not skippable. Skipping shifts every later element
/// down one, and each then answers for its neighbour with no error and no diagnostic.
///
/// Two halves. The first exercises the wrapping policy directly, because the bridge cannot
/// actually produce a hole (measured: `Scripts/repro/979-subshape-index-identity/`), so the only
/// way to induce one is at the seam every enumeration shares. The second pins the property the
/// policy exists to protect on real shapes, and re-measures the premise against the live bridge.
@Suite("Sub-shape enumerations keep position as identity (#979)")
struct Issue979SubShapeIndexIdentity {

    // MARK: - Fixtures

    /// A box cut into two solids that share the cut face: 12 face occurrences over 11 distinct
    /// faces, and the duplicate is not last, where a shifted array and a correct one are actually
    /// distinguishable. Named `planeSplitBoxCompound` (not `splitBoxCompound`) because
    /// `Issue614FaceOrientationTests.splitBoxCompound()` is a different fixture under the name
    /// this file used to share with it (#1255): that one is a 20×10×10 box split by a rotated
    /// knife *face* via `split(by:)`, this one a 10×10×10 box split by the z=4 *plane* via
    /// `split(atPlane:normal:)`.
    static func planeSplitBoxCompound() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let halves = box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1))
        else { return nil }
        return Shape.compound(halves)
    }

    /// Every shape the premise is measured against: primitives, an empty compound, shared
    /// sub-shapes, degenerate edges, and one large compound.
    static func battery() -> [(String, Shape)] {
        var shapes: [(String, Shape)] = []
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            shapes.append(("box", box))
            if let doubled = Shape.compound([box, box]) {
                shapes.append(("boxWithItself", doubled))
            }
            let row = (0..<50).compactMap { box.translated(by: SIMD3(Double($0) * 20, 0, 0)) }
            if let many = Shape.compound(row) {
                shapes.append(("compound50Boxes", many))
            }
        }
        if let sphere = Shape.sphere(radius: 5) { shapes.append(("sphere", sphere)) }
        if let cone = Shape.cone(bottomRadius: 5, topRadius: 0, height: 10) {
            shapes.append(("coneToApex", cone))
        }
        if let split = planeSplitBoxCompound() { shapes.append(("planeSplitBoxCompound", split)) }
        if let empty = Shape.compound([]) { shapes.append(("emptyCompound", empty)) }
        return shapes
    }

    /// Records its own deallocation.
    ///
    /// Lets a test tell "wrapped, then discarded" from "never wrapped", standing in for
    /// `Face`/`Edge`/`Shape`, whose `deinit` releases the real handle.
    final class WrappedElement {
        let handle: Int
        let ordinal: Int
        private let onDeinit: (Int) -> Void

        init(handle: Int, ordinal: Int, onDeinit: @escaping (Int) -> Void) {
            self.handle = handle
            self.ordinal = ordinal
            self.onDeinit = onDeinit
        }

        deinit { onDeinit(handle) }
    }

    /// Collects what the enumeration released and what it deallocated, in one place so a test can
    /// assert each handle was accounted for exactly once.
    final class Ledger: @unchecked Sendable {
        var released: [Int] = []
        var deallocated: [Int] = []
    }

    static func wrap(_ handles: [Int?], _ ledger: Ledger) -> [WrappedElement] {
        wrapSubShapeEnumeration(
            handles,
            wrap: { handle, ordinal in
                WrappedElement(handle: handle, ordinal: ordinal) { ledger.deallocated.append($0) }
            },
            release: { ledger.released.append($0) })
    }

    // MARK: - The wrapping policy

    @Test("A complete enumeration gives every ordinal its own element")
    func completeEnumerationKeepsEveryOrdinal() {
        let ledger = Ledger()
        let elements = Self.wrap([10, 11, 12, 13, 14], ledger)

        #expect(elements.count == 5)
        for (position, element) in elements.enumerated() {
            #expect(element.ordinal == position)
            #expect(element.handle == 10 + position)
        }
        #expect(
            ledger.released.isEmpty, "nothing was missing, so nothing should have been released")
    }

    @Test("A hole refuses the whole enumeration instead of shifting the elements after it")
    func aHoleRefusesTheWholeEnumeration() {
        let ledger = Ledger()
        let elements = Self.wrap([10, 11, nil, 13, 14], ledger)

        // The defect: dropping leaves four elements, and the one at position 2 is ordinal 3's.
        #expect(
            elements.count != 4,
            "the enumeration was shifted: position 2 now answers for ordinal 3")
        #expect(elements.isEmpty)
    }

    @Test("A refused enumeration releases the handles past the hole exactly once")
    func handlesPastTheHoleAreReleasedOnce() {
        let ledger = Ledger()
        _ = Self.wrap([10, 11, nil, 13, 14], ledger)

        #expect(ledger.released == [13, 14])
    }

    @Test("A refused enumeration deallocates the elements it built before the hole")
    func elementsBuiltBeforeTheHoleAreDeallocated() {
        let ledger = Ledger()
        _ = Self.wrap([10, 11, nil, 13, 14], ledger)

        #expect(ledger.deallocated.sorted() == [10, 11])
        // Neither route may claim a handle twice: an element already wrapped owns its own.
        #expect(Set(ledger.released).isDisjoint(with: Set(ledger.deallocated)))
    }

    @Test("A hole at the first position refuses, and releases every later handle")
    func aHoleAtTheFirstPositionRefuses() {
        let ledger = Ledger()
        let elements = Self.wrap([nil, 11, 12], ledger)

        #expect(elements.isEmpty)
        #expect(ledger.released == [11, 12])
        #expect(ledger.deallocated.isEmpty)
    }

    @Test("A hole at the last position refuses, so a short array is never a truncation either")
    func aHoleAtTheLastPositionRefuses() {
        let ledger = Ledger()
        let elements = Self.wrap([10, 11, nil], ledger)

        #expect(elements.isEmpty)
        #expect(ledger.released.isEmpty)
        #expect(ledger.deallocated.sorted() == [10, 11])
    }

    @Test("An empty enumeration is not a refusal")
    func anEmptyEnumerationIsNotARefusal() {
        let ledger = Ledger()
        #expect(Self.wrap([], ledger).isEmpty)
        #expect(ledger.released.isEmpty)
    }

    // MARK: - The property on real shapes

    @Test("faces(), edges() and subShapes(ofType:) return the whole enumeration, never a short one")
    func enumerationsAreCompleteOnEveryShape() {
        for (name, shape) in Self.battery() {
            #expect(shape.faces().count == shape.faceCount, "faces() is short on \(name)")
            #expect(shape.edges().count == shape.edgeCount, "edges() is short on \(name)")
            for type: ShapeType in [.face, .edge, .vertex, .wire, .shell, .solid] {
                #expect(
                    shape.subShapes(ofType: type).count == shape.subShapeCount(ofType: type),
                    "subShapes(ofType: .\(type)) is short on \(name)")
            }
        }
    }

    @Test("Every array position addresses the sub-shape its ordinal names")
    func everyArrayPositionAddressesItsOwnSubShape() {
        guard let split = Self.planeSplitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        for (position, edge) in split.edges().enumerated() {
            #expect(edge.index == position, "edges()[\(position)] carries index \(edge.index)")
            guard let indexed = split.edge(at: position),
                let a = Shape.fromEdge(edge),
                let b = Shape.fromEdge(indexed)
            else {
                Issue.record("could not resolve edge \(position) both ways")
                continue
            }
            #expect(a.isSame(as: b), "edges()[\(position)] and edge(at: \(position)) differ")
        }

        for type: ShapeType in [.face, .edge, .vertex, .wire, .shell, .solid] {
            let array = split.subShapes(ofType: type)
            for position in array.indices {
                guard let indexed = split.subShape(type: type, index: position) else {
                    Issue.record("subShape(type: .\(type), index: \(position)) is nil")
                    continue
                }
                #expect(
                    array[position].isSame(as: indexed),
                    "subShapes(ofType: .\(type))[\(position)] is not the sub-shape at that index")
            }
        }
    }

    @Test("orientedFaces() returns every occurrence, so a position is a whole occurrence number")
    func orientedFacesKeepsEveryOccurrence() {
        guard let split = Self.planeSplitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }
        let occurrences = Int(OCCTShapeGetFaceOccurrenceCount(split.handle))
        #expect(occurrences == 12, "the fixture stopped sharing its cut face")
        #expect(split.orientedFaces().count == occurrences)
    }

    // MARK: - The premise, re-measured against the live bridge

    /// The design rests on a measurement.
    ///
    /// The bridge fills every slot or fails the whole call, so a hole is unreachable. That is a
    /// property of the bridge, not of Swift, so it is re-checked here rather than taken on the
    /// reading that established it.
    @Test("The bridge never hands back a hole in a face or sub-shape enumeration")
    func theBridgeNeverHandsBackAHole() {
        for (name, shape) in Self.battery() {
            var faceCount: Int32 = 0
            if let faces = OCCTShapeGetFaces(shape.handle, &faceCount) {
                for i in 0..<Int(faceCount) {
                    #expect(faces[i] != nil, "OCCTShapeGetFaces left slot \(i) null on \(name)")
                    if let face = faces[i] { OCCTFaceRelease(face) }
                }
                OCCTFreeFaceArrayOnly(faces)
            }

            for type: ShapeType in [.face, .edge, .vertex, .wire, .shell, .solid] {
                let count = Int32(shape.subShapeCount(ofType: type))
                guard count > 0 else { continue }
                var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
                let written = OCCTShapeGetSubShapes(
                    shape.handle, Int32(type.rawValue), &handles, count)
                #expect(
                    written == count,
                    "OCCTShapeGetSubShapes wrote \(written) of \(count) .\(type) on \(name)")
                for i in 0..<Int(written) {
                    #expect(handles[i] != nil, "sub-shape slot \(i) is null on \(name)")
                    if let sub = handles[i] { OCCTShapeRelease(sub) }
                }
            }

            for i in 0..<shape.edgeCount {
                let edge = OCCTShapeGetEdgeAtIndex(shape.handle, Int32(i))
                #expect(edge != nil, "OCCTShapeGetEdgeAtIndex(\(i)) is null on \(name)")
                if let edge { OCCTEdgeRelease(edge) }
            }
        }
    }
}
