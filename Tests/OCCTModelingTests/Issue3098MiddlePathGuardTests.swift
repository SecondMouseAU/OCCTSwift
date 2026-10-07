import Foundation
import Testing

@testable import OCCTSwift

/// #3098: `Shape.middlePath(start:end:)` aborted the process (SIGSEGV, uncatchable) for a null
/// end, the same face twice and two adjacent faces.
///
/// `BRepOffsetAPI_MiddlePath`'s constructor reads `StartShape.ShapeType()` and casts with the
/// unchecked `TopoDS::Wire`, and `Build()` casts a bare vertex of a path to an edge when the two
/// sections share a vertex. The bridge refuses those inputs before the call. The controls are the
/// point of the second half: a guard that refused every input would fail them.
///
/// Reproducers, one input per process, are in `Scripts/repro/3098-middlepath-crash/`.
@Suite("Issue3098 middlePath refuses the inputs that crash the kernel")
struct Issue3098MiddlePathGuardTests {

    private func box() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    private func center(_ shape: Shape) throws -> SIMD3<Double> {
        let b = try #require(shape.bounds)
        return (b.min + b.max) / 2
    }

    private typealias FacePair = (Shape, Shape)

    /// The face pairs of a box that are opposite (a pipe cross-section pair) and the rest.
    private func boxFacePairs(of box: Shape) throws -> (opposite: [FacePair], touching: [FacePair])
    {
        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6)
        var opposite: [FacePair] = []
        var touching: [FacePair] = []
        for i in faces.indices {
            for j in faces.indices where j > i {
                let d = try center(faces[i]) - center(faces[j])
                // Opposite faces differ by the full edge length along exactly one axis.
                let farAxes = [abs(d.x), abs(d.y), abs(d.z)].filter { $0 > 9.99 }.count
                let isOpposite = farAxes == 1 && (abs(d.x) + abs(d.y) + abs(d.z)) < 10.01
                if isOpposite {
                    opposite.append((faces[i], faces[j]))
                } else {
                    touching.append((faces[i], faces[j]))
                }
            }
        }
        return (opposite, touching)
    }

    // MARK: Refused

    @Test func sameFaceTwiceAnswersNil() throws {
        let s = try box()
        for face in s.subShapes(ofType: .face) {
            #expect(s.middlePath(start: face, end: face) == nil)
        }
    }

    @Test func sameWireTwiceAnswersNil() throws {
        let s = try box()
        let wires = try #require(s.subShapes(ofType: .face).first).subShapes(ofType: .wire)
        let wire = try #require(wires.first)
        #expect(s.middlePath(start: wire, end: wire) == nil)
    }

    @Test func adjacentFacesAnswerNil() throws {
        let s = try box()
        let pairs = try boxFacePairs(of: s)
        // 15 pairs of a box: 3 opposite, 12 adjacent.
        try #require(pairs.touching.count == 12)
        for (a, b) in pairs.touching {
            #expect(s.middlePath(start: a, end: b) == nil)
            #expect(s.middlePath(start: b, end: a) == nil)
        }
    }

    @Test func nullShapesAnswerNil() throws {
        let s = try box()
        let face = try #require(s.subShapes(ofType: .face).first)
        let null = try #require(s.nullified)
        #expect(s.middlePath(start: null, end: null) == nil)
        #expect(s.middlePath(start: null, end: face) == nil)
        #expect(s.middlePath(start: face, end: null) == nil)
        #expect(null.middlePath(start: face, end: face) == nil)
    }

    @Test func anEdgeEndAnswersNil() throws {
        let s = try box()
        let faces = s.subShapes(ofType: .face)
        let edge = try #require(s.subShapes(ofType: .edge).first)
        let face = try #require(faces.first)
        #expect(s.middlePath(start: edge, end: face) == nil)
        #expect(s.middlePath(start: face, end: edge) == nil)
    }

    // MARK: Controls

    @Test func oppositeFacesOfABoxStillGiveASpine() throws {
        let s = try box()
        let pairs = try boxFacePairs(of: s)
        try #require(pairs.opposite.count == 3)
        for (a, b) in pairs.opposite {
            let spine = try #require(s.middlePath(start: a, end: b))
            // The spine joins the two face centres: it is 10 long along the axis between them.
            let bounds = try #require(spine.bounds)
            let extent = bounds.max - bounds.min
            #expect(abs(extent.x + extent.y + extent.z - 10) < 1e-3)
            let offset = try center(spine) - ((center(a) + center(b)) / 2)
            #expect(abs(offset.x) + abs(offset.y) + abs(offset.z) < 1e-3)
        }
    }

    @Test func oppositeWiresOfABoxStillGiveASpine() throws {
        let s = try box()
        let pairs = try boxFacePairs(of: s)
        let (a, b) = try #require(pairs.opposite.first)
        let wa = try #require(a.subShapes(ofType: .wire).first)
        let wb = try #require(b.subShapes(ofType: .wire).first)
        #expect(s.middlePath(start: wa, end: wb) != nil)
    }

    @Test func cylinderCapsStillGiveASpine() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        // The planar caps are the two faces whose bounds are flat in Z.
        let caps = cylinder.subShapes(ofType: .face).filter {
            guard let b = $0.bounds else { return false }
            return b.max.z - b.min.z < 1e-6
        }
        try #require(caps.count == 2)
        let spine = try #require(cylinder.middlePath(start: caps[0], end: caps[1]))
        let bounds = try #require(spine.bounds)
        #expect(abs(bounds.max.z - bounds.min.z - 10) < 1e-3)
    }

    @Test func aTubeStillGivesItsAxis() throws {
        let outer = try #require(Shape.cylinder(radius: 5, height: 10))
        let inner = try #require(Shape.cylinder(radius: 2, height: 10))
        let tube = try #require(outer.subtracting(inner))
        let caps = tube.subShapes(ofType: .face).filter {
            guard let b = $0.bounds else { return false }
            return b.max.z - b.min.z < 1e-6
        }
        try #require(caps.count == 2)
        let spine = try #require(tube.middlePath(start: caps[0], end: caps[1]))
        let bounds = try #require(spine.bounds)
        #expect(abs(bounds.max.z - bounds.min.z - 10) < 1e-3)
    }
}
