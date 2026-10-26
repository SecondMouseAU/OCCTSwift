import Foundation
import Testing

@testable import OCCTSwift

/// The fillet pull requests the kernel carries on top of upstream `IR` (patches `0079` to `0084`,
/// OCCT#1623 and #1666 to #1670) change what `Shape.filleted` answers, and these tests pin the
/// answers.
///
/// Before them, on `V8_0_1`: a fillet wider than the face it sits on answered nil, two opposite
/// fillets whose arcs cross answered nil or a solid that was not one, and a face consumed by its
/// neighbours could hang `BRepTools_WireExplorer`. After them a wider-than-face fillet is built
/// (the arc ends at the far edge of the face), opposite fillets whose arcs cross give the
/// intersection of the two rounded profiles, and a result that is not a valid solid is a failure.
///
/// The oracles are the section areas OCCT's own GTests derive (`BRepFilletAPI_MakeFillet_*_Test.cxx`
/// in the patches), times the 10 long Y extent of the 4 x 10 x 6 box:
///
/// - r = 5 on a 4 wide face: removed area 4.927428 (the arc is tangent to the side face and passes
///   through the far edge of the top face).
/// - r = 4.5 on the edge between a 4 wide face and a 3 high one: 3.426266.
/// - opposite edges, r = 3 and r = 3: 3.749792368679, which is
///   `2 w r - pi r^2 / 2 + (r - w / 2) sqrt(w r - w^2 / 4) + r^2 asin(1 - w / (2 r))` with w = 4.
/// - opposite edges, r = 1 and r = 3.5: 2.840940340.
@Suite("Fillets beyond the face: the carried fillet patches")
struct FilletBeyondTheFaceTests {

    // MARK: - Fixtures

    /// The edge whose midpoint is nearest `rel` (fractions of the shape's bounding box).
    private func edge(_ shape: Shape, _ rel: (Double, Double, Double)) throws -> Edge {
        let box = try #require(shape.bounds)
        let target = SIMD3(
            box.min.x + rel.0 * (box.max.x - box.min.x),
            box.min.y + rel.1 * (box.max.y - box.min.y),
            box.min.z + rel.2 * (box.max.z - box.min.z))
        var best: (distance: Double, edge: Edge)?
        for candidate in shape.edges() {
            guard let b = candidate.bounds else { continue }
            let d = vectorLengthSquared((b.min + b.max) / 2 - target)
            if let current = best, current.distance <= d { continue }
            best = (d, candidate)
        }
        return try #require(best).edge
    }

    /// 4 wide (X), 10 long (Y), `height` high (Z), with its corner at the origin.
    private func slab(height: Double = 6) throws -> Shape {
        try #require(Shape.box(origin: .zero, width: 4, height: 10, depth: height))
    }

    private func volume(_ shape: Shape) throws -> Double { try #require(shape.volume) }

    // MARK: - A fillet wider than its face is built

    @Test
    func aFilletWiderThanItsFaceEndsAtTheFarEdge() throws {
        let box = try slab()
        let result = try #require(box.filleted(edges: [edge(box, (0, 0.5, 1))], radius: 5))
        #expect(result.isValid)
        #expect(abs(try volume(result) - (240 - 10 * 4.927428)) < 1e-4)
    }

    @Test
    func aFilletWiderThanBothItsFacesEndsAtBothFarEdges() throws {
        let box = try slab(height: 3)
        let result = try #require(box.filleted(edges: [edge(box, (0, 0.5, 1))], radius: 4.5))
        #expect(result.isValid)
        #expect(abs(try volume(result) - (120 - 10 * 3.426266)) < 1e-4)
    }

    /// The second fillet pivots at the first one's tangent edge, so the order matters.
    @Test
    func aFilletNextToAFinishedFilletPivotsAtItsTangentEdge() throws {
        let box = try slab()
        let rounded = try #require(box.filleted(edges: [edge(box, (0, 0.5, 1))], radius: 3))
        let result = try #require(rounded.filleted(edges: [edge(rounded, (1, 0.5, 1))], radius: 3))
        #expect(result.isValid)
        #expect(abs(try volume(result) - 213.812565) < 1e-4)
    }

    // MARK: - Opposite fillets whose arcs cross

    @Test
    func oppositeFilletsWhoseArcsCrossAreTheIntersectionOfTheTwoProfiles() throws {
        let box = try slab()
        let pair = try [edge(box, (0, 0.5, 1)), edge(box, (1, 0.5, 1))]
        let equal = try #require(box.filleted(edges: pair, radius: 3))
        #expect(equal.isValid)
        #expect(abs(try volume(equal) - (240 - 10 * 3.749792368679)) < 1e-6)

        // Different radii in one builder: r = 1 on one edge, r = 3.5 on the other.
        let all = box.edges()
        let firstIndex = try #require(all.firstIndex { $0.bounds?.min == pair[0].bounds?.min })
        let secondIndex = try #require(all.firstIndex { $0.bounds?.min == pair[1].bounds?.min })
        let mixed = try #require(
            box.blendedEdges([
                (edgeIndex: firstIndex, radius: 1), (edgeIndex: secondIndex, radius: 3.5),
            ]))
        #expect(mixed.isValid)
        #expect(abs(try volume(mixed) - (240 - 10 * 2.840940340)) < 1e-6)
    }

    /// Whatever the radii, the answer is nil or a valid solid smaller than the box.
    ///
    /// The kernel used to report a "done" solid that was larger than the box it was cut from.
    @Test
    func overlappingOppositeFilletsAreNeverAnInvalidSolid() throws {
        let box = try slab()
        let pair = try [edge(box, (0, 0.5, 1)), edge(box, (1, 0.5, 1))]
        for radius in [2.001, 2.2, 2.5, 3.0, 3.9] {
            if let result = box.filleted(edges: pair, radius: radius) {
                #expect(result.isValid, "r = \(radius)")
                #expect(try volume(result) < 240, "r = \(radius)")
            }
        }
    }

    /// Radii that exceed half the width by less than the tolerance: the arcs meet within it.
    @Test
    func filletsMeetingWithinToleranceAreNilOrValid() throws {
        let box = try slab()
        let pair = try [edge(box, (0, 0.5, 1)), edge(box, (1, 0.5, 1))]
        for excess in [1e-12, 1e-9, 1e-7, 1e-5] {
            if let result = box.filleted(edges: pair, radius: 2 + excess) {
                #expect(result.isValid, "excess \(excess)")
                #expect(try volume(result) < 240, "excess \(excess)")
            }
        }
    }

    /// Two fillets on adjacent edges of a 4 wide face with r = w: nil or a valid solid.
    @Test
    func adjacentFilletsAtTheFaceWidthAreNilOrValid() throws {
        let box = try slab()
        let adjacent = try [edge(box, (1, 0.5, 1)), edge(box, (0.5, 1, 1))]
        if let result = box.filleted(edges: adjacent, radius: 4) {
            #expect(result.isValid)
        }
    }

    // MARK: - A face the fillets consume

    /// Four fillets round the four edges of a face, and the face between them is a point.
    ///
    /// The radius is w / 2 on a 4 x 4 face of a cube. `BRepTools_WireExplorer` used to loop on the
    /// wire this leaves, because stepping along a pcurve a rounding error long does not move the
    /// parameter. The build runs on a thread under a deadline: a hang fails the test instead of
    /// the process.
    @Test
    func fourFilletsThatConsumeTheirFaceReturn() throws {
        let cube = try #require(Shape.box(origin: .zero, width: 4, height: 4, depth: 4))
        let frame = try [
            edge(cube, (0, 0.5, 1)), edge(cube, (1, 0.5, 1)),
            edge(cube, (0.5, 0, 1)), edge(cube, (0.5, 1, 1)),
        ]
        final class Outcome: @unchecked Sendable {
            let lock = NSLock()
            var state = -1  // -1 running, 0 refused, 1 built and valid, 2 built and not valid
        }
        let outcome = Outcome()
        let finished = DispatchSemaphore(value: 0)
        let thread = Thread {
            let result = cube.filleted(edges: frame, radius: 2)
            outcome.lock.lock()
            outcome.state = result == nil ? 0 : (result?.isValid == true ? 1 : 2)
            outcome.lock.unlock()
            finished.signal()
        }
        thread.stackSize = 16 << 20
        thread.start()
        let returned = finished.wait(timeout: .now() + 60) == .success
        #expect(returned, "the build did not return within 60 s")
        outcome.lock.lock()
        defer { outcome.lock.unlock() }
        #expect(outcome.state != 2, "the builder reported a solid that is not valid")
    }
}
