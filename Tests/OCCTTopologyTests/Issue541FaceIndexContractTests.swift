import Testing
import Foundation
@testable import OCCTSwift

// #541: a face index meant three different things.
//
//   A. `Shape.faces()` walked a bare `TopExp_Explorer`, one entry per *occurrence* in the
//      topology tree, and wrote the array position into `Face.index`.
//   B. `Shape.faceCount` / `Shape.face(at:)`, and most of the ~30 entry points that take a face
//      index, read `TopExp::MapShapes`, one entry per *distinct* face (`TopoDS_Shape::IsSame`).
//   C. A handful read the same map 1-based, so a 0-based `Face.index` addressed the face before
//      the one it named and could never name the last face at all.
//
// Measured on the pinned kernel (`Scripts/repro/541-face-index-contract/`): the A/B divergence is
// not a hand-built curiosity. One `BRepAlgoAPI_Splitter` run cutting a box with a plane leaves two
// solids sharing the single cut face, 12 occurrences over 11 distinct faces, and the duplicate
// is not last, so from index 10 onwards the two schemes name *different* faces. A caller holding
// `Face.index` from `faces()` drafted, deleted or opened a face it had not selected.
//
// These tests fix all three on one enumeration: `occtMapSubShapes`, 0-based.

@Suite("A face index means one thing (#541)")
struct Issue541FaceIndexContractTests {

    // MARK: - Fixtures

    /// Two solids that share one face, from one ordinary modelling operation.
    ///
    /// `split(by:)` hands back the pieces separately; re-compounding them preserves the sharing,
    /// because both came out of the same BOP and reference the same cut face. Returns nil rather
    /// than recording an issue so callers can skip cleanly if the kernel stops sharing.
    static func splitBoxCompound() -> Shape? {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
              let plate = Shape.face(from: Wire.rectangle(width: 60, height: 60)!),
              let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
              let knife = upright.translated(by: SIMD3(10, 0, 0)),
              let pieces = block.split(by: knife),
              pieces.count == 2,
              let compound = Shape.compound(pieces)
        else { return nil }
        return compound
    }

    /// #541's stated minimal reproduction: the same face handed to `compound` twice.
    static func doubledFaceCompound() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let face = box.subShapes(ofType: .face).first
        else { return nil }
        return Shape.compound([face, face])
    }

    // MARK: - The three spellings agree

    /// The headline: `faces()` handed out `Face.index` values `face(at:)` answered nil for.
    @Test("faces() hands out only indices face(at:) can address")
    func facesArrayIndicesAreAddressable() {
        guard let duped = Self.doubledFaceCompound() else {
            Issue.record("could not build the doubled-face compound")
            return
        }
        #expect(duped.faces().count == duped.faceCount)
        #expect(duped.faceCount == duped.subShapeCount(ofType: .face))
        for face in duped.faces() {
            #expect(duped.face(at: face.index) != nil,
                    "faces() handed out index \(face.index), which face(at:) cannot address")
        }
    }

    /// The half the issue did not report, and the more serious one: on a shape whose duplicate is
    /// not the last occurrence, the two schemes named *different* faces at the same index.
    @Test("faces() and face(at:) name the same face at every index")
    func facesArrayAndIndexedAccessNameTheSameFace() {
        guard let split = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }
        let array = split.faces()
        #expect(array.count == split.faceCount)

        for face in array {
            guard let indexed = split.face(at: face.index) else {
                Issue.record("face(at: \(face.index)) is nil for an index faces() handed out")
                continue
            }
            guard let a = Shape.fromFace(face), let b = Shape.fromFace(indexed) else {
                Issue.record("could not wrap face \(face.index) as a Shape")
                continue
            }
            #expect(a.isSame(as: b),
                    "faces()[\(face.index)] and face(at: \(face.index)) are different faces")
        }
    }

    /// `subShape(type:index:)` is the generic spelling of the same enumeration; it must not be a
    /// fourth answer.
    @Test("The generic sub-shape spelling agrees with the face spellings")
    func genericSpellingAgrees() {
        guard let split = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }
        #expect(split.faceCount == split.subShapeCount(ofType: .face))
        for i in 0..<split.faceCount {
            guard let viaFace = split.face(at: i).flatMap(Shape.fromFace),
                  let viaGeneric = split.subShape(type: .face, index: i) else {
                Issue.record("index \(i) unreachable through one of the two spellings")
                continue
            }
            #expect(viaFace.isSame(as: viaGeneric), "spellings disagree at index \(i)")
        }
    }

    /// The control: on shapes that share no face, which is every shape the rest of the suite
    /// builds, converging the enumerations moves nothing.
    @Test("Ordinary shapes are unaffected")
    func ordinaryShapesUnaffected() {
        let fixtures: [(String, Shape)] = [
            ("box", Shape.box(width: 10, height: 5, depth: 3)!),
            ("cylinder", Shape.cylinder(radius: 3, height: 8)!),
            ("sphere", Shape.sphere(radius: 5)!),
        ]
        for (name, shape) in fixtures {
            #expect(shape.faces().count == shape.faceCount, "\(name) count")
            for face in shape.faces() {
                guard let indexed = shape.face(at: face.index),
                      let a = Shape.fromFace(face), let b = Shape.fromFace(indexed) else {
                    Issue.record("\(name): index \(face.index) unreachable")
                    continue
                }
                #expect(a.isSame(as: b), "\(name): index \(face.index) moved")
            }
        }
        #expect(Shape.box(width: 10, height: 10, depth: 10)!.faceCount == 6)
    }

    // MARK: - Face indices are 0-based everywhere

    /// `adjacentFaces(forEdge:)` returned 1-based indices into the same map every other face
    /// accessor reads 0-based. Feeding one straight to `face(at:)` named the wrong face, and the
    /// face at index 0 could never be returned at all.
    @Test("adjacentFaces(forEdge:) returns indices face(at:) can use")
    func adjacentFaceIndicesAreZeroBased() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.subShapes(ofType: .edge)
        guard let edge = edges.first else {
            Issue.record("box has no edges")
            return
        }
        let indices = box.adjacentFaces(forEdge: edge)
        #expect(indices.count == 2, "a box edge borders two faces")

        for i in indices {
            #expect(i >= 0 && i < box.faceCount, "index \(i) is outside 0..<\(box.faceCount)")
            guard let face = box.face(at: i).flatMap(Shape.fromFace) else {
                Issue.record("face(at: \(i)) is nil for an index adjacentFaces returned")
                continue
            }
            // The named face must actually contain the edge it was named for.
            let contains = face.subShapes(ofType: .edge).contains { $0.isSame(as: edge) }
            #expect(contains, "face \(i) does not border the edge it was returned for")
        }
    }

    /// The sibling accessor, same defect, same map.
    @Test("adjacentEdges(forVertex:) returns indices edge(at:) can use")
    func adjacentEdgeIndicesAreZeroBased() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let vertex = box.subShapes(ofType: .vertex).first else {
            Issue.record("box has no vertices")
            return
        }
        let indices = box.adjacentEdges(forVertex: vertex)
        #expect(indices.count == 3, "a box corner meets three edges")

        for i in indices {
            #expect(i >= 0 && i < box.edgeCount, "index \(i) is outside 0..<\(box.edgeCount)")
            guard let edge = box.subShape(type: .edge, index: i) else {
                Issue.record("edge index \(i) unreachable")
                continue
            }
            let contains = edge.subShapes(ofType: .vertex).contains { $0.isSame(as: vertex) }
            #expect(contains, "edge \(i) does not meet the vertex it was returned for")
        }
    }

    /// `splitByWireOnFace` took a 1-based index, so its accepted domain was `1...faceCount`
    /// rather than `0..<faceCount`: `Face.index == 0` was rejected outright, and an index equal
    /// to `faceCount`, past the end of every other spelling, was accepted.
    ///
    /// The domain is the discriminator here rather than the resulting geometry: `LocOpe_Spliter`
    /// binds the wire across the whole shape, so the split itself succeeds at any index it
    /// accepts.
    @Test("splitByWireOnFace accepts 0..<faceCount, not 1...faceCount")
    func splitByWireOnFaceIsZeroBased() {
        guard let block = Shape.box(origin: .zero, width: 20, height: 20, depth: 5),
              let square = Wire.rectangle(width: 6, height: 6),
              let flat = Shape.fromWire(square),
              let wireShape = flat.translated(by: SIMD3(10, 10, 5))
        else {
            Issue.record("could not build the split fixture")
            return
        }
        // Index 0 is a real face, not the rejected sentinel it used to be.
        #expect(block.face(at: 0) != nil)
        #expect(block.splitByWireOnFace(wireShape, faceIndex: 0) != nil,
                "face 0 is unaddressable, so the index is still 1-based")
        // One past the end must be rejected, as it is for face(at:).
        #expect(block.face(at: block.faceCount) == nil)
        #expect(block.splitByWireOnFace(wireShape, faceIndex: Int32(block.faceCount)) == nil,
                "an index past the last face was accepted")
        #expect(block.splitByWireOnFace(wireShape, faceIndex: -1) == nil)
    }

    /// `buildWires(faceIndex:)` used 0 as "all edges of the shape", which collides with the
    /// 0-based index of the first face. The sentinel is now `-1`, so every face is addressable.
    @Test("buildWires addresses face 0, and -1 still means every edge")
    func buildWiresSentinelDoesNotCollideWithFaceZero() {
        let box = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!

        guard let allEdges = box.buildWires(faceIndex: -1) else {
            Issue.record("buildWires(-1) failed")
            return
        }
        guard let faceZero = box.buildWires(faceIndex: 0) else {
            Issue.record("buildWires(0) failed, face 0 is not addressable")
            return
        }
        // One face's edges cannot be the whole box's edges.
        #expect(!allEdges.isEmpty)
        #expect(!faceZero.isEmpty)
        let allEdgeCount = allEdges.reduce(0) { $0 + $1.edgeCount }
        let faceZeroEdgeCount = faceZero.reduce(0) { $0 + $1.edgeCount }
        #expect(faceZeroEdgeCount < allEdgeCount,
                "buildWires(0) returned the whole shape's edges, so 0 was still the sentinel")
    }

    // MARK: - The index consumers read the same enumeration

    /// A sample of the entry points that walked their own explorer. Each is asked about the same
    /// index and must answer about the face `face(at:)` names.
    ///
    /// Edge *counts* cannot discriminate here, every face of a split box is a four-edged planar
    /// quad, so the check is edge *identity*: the edges `edgesInFace(at:)` reports must be the
    /// very edges of the face at that index.
    @Test("Index consumers answer about the face face(at:) names")
    func indexConsumersAgreeWithFaceAt() {
        guard let split = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }
        for i in 0..<split.faceCount {
            guard let face = split.face(at: i).flatMap(Shape.fromFace) else {
                Issue.record("face(at: \(i)) is nil below faceCount")
                continue
            }
            let own = face.subShapes(ofType: .edge)
            #expect(split.faceDomainEdgeCount(faceIndex: i) == own.count,
                    "faceDomainEdgeCount disagrees about face \(i)")

            let reported = split.edgesInFace(at: i)
            #expect(reported.count == own.count, "edgesInFace(at: \(i)) has the wrong edge count")
            for edge in reported {
                guard let asShape = Shape.fromEdge(edge) else { continue }
                #expect(own.contains { $0.isSame(as: asShape) },
                        "edgesInFace(at: \(i)) returned an edge that is not on face \(i)")
            }
        }
    }

    // MARK: - Shape.contents is a different question, and stays one

    /// `Shape.contents` is the third census, and #541 leaves it counting what it counts,
    /// occurrences, rather than converging it. These pin the contract its docs now state, so
    /// "a complexity metric, not an index bound" does not quietly become untrue.
    @Test("Shape.contents counts occurrences, not addressable sub-shapes")
    func contentsCountsOccurrences() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // A box shares no face, so the two agree there.
        #expect(box.contents.faces == box.faceCount)
        // Every edge is visited once per adjacent face, so these must NOT agree.
        #expect(box.edgeCount == 12)
        #expect(box.contents.edges == 24)
        #expect(box.vertexCount == 8)
        #expect(box.contents.vertices == 48)
    }

    /// The third dedup rule: `nbSharedFaces` discards the location, so it collapses instances
    /// that `faceCount`, which follows `IsSame`, keeps apart.
    ///
    /// The fixture has to be `moved(dx:dy:dz:)`, which only sets a `TopLoc_Location` and so
    /// yields a true instance. `translated(by:)` rebuilds the shape through
    /// `BRepBuilderAPI_Transform`, whose result shares no `TShape` with its input, all three
    /// counts then read 12 and the distinction under test disappears.
    @Test("contentsExtended's shared counts collapse instances that faceCount keeps")
    func sharedCountsDiscardLocation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let moved = box.moved(dx: 50, dy: 0, dz: 0),
              let pair = Shape.compound([box, moved])
        else {
            Issue.record("could not build the instanced compound")
            return
        }
        #expect(pair.faceCount == 12, "IsSame compares the location, so instances stay distinct")
        #expect(pair.contents.faces == 12)
        #expect(pair.contentsExtended().nbSharedFaces == 6,
                "the shared counts strip the location, so the two placements collapse")
    }

    /// Past the end must be nil or empty on every spelling, not the last face or a crash.
    @Test("Out-of-range face indices are rejected consistently")
    func outOfRangeIndicesRejected() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let past = box.faceCount
        #expect(box.face(at: past) == nil)
        #expect(box.face(at: -1) == nil)
        #expect(box.subShape(type: .face, index: past) == nil)
        #expect(box.faceDomainEdgeCount(faceIndex: past) <= 0)
        #expect(box.edgesInFace(at: past).isEmpty)
    }
}
