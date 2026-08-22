import Testing

@testable import OCCTSwift

/// `Shape.selfIntersects` returned `BOPAlgo_CheckerSI::HasErrors()`, which is "did this algorithm
/// fail" rather than "did it find an interference", so it answered `false` for every shape that
/// genuinely self-intersects and `true` for a check that merely errored (#1088).
///
/// The fixtures are three independent constructions of "genuinely self-intersecting", so an answer
/// that holds across them is not holding because of anything specific to one primitive.
@Suite("selfIntersects reports the check, not the checker (issue #1088)")
struct Issue1088SelfIntersectsAnswer {

    // MARK: - Fixtures

    /// Two 10-unit boxes overlapping by 5 along X, in one compound. `box(origin:...)` is
    /// corner-based (the bare `box(width:height:depth:)` is centred), so these occupy [0,10] and
    /// [5,15] in X and share a 5-unit slab.
    private static func overlappingBoxes() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    /// The same defect through a different primitive and a different surface type: two spheres
    /// whose centres are closer together than the sum of their radii.
    private static func overlappingSpheres() -> Shape? {
        guard let a = Shape.sphere(center: SIMD3(0, 0, 0), radius: 10),
            let b = Shape.sphere(center: SIMD3(12, 0, 0), radius: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    /// The control for both: the same compound wrapper over two solids that do not touch.
    private static func disjointBoxes() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(50, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    // MARK: - The fixture control

    /// Proves the overlap fixture still means its name, which no assertion on the bridge's answer
    /// can do: two boxes of 1000 each, overlapping by exactly a 5x10x10 slab, fuse to 1500.
    ///
    /// Without this, a fixture that silently stopped overlapping would leave every test below
    /// passing for the wrong reason.
    @Test("The overlap fixture really does overlap")
    func overlapFixtureActuallyOverlaps() {
        // Deliberately reaches into the fixture the other tests use rather than rebuilding an
        // equivalent pair here. A control that builds its own copy proves a different pair of
        // boxes overlaps, which is not the claim being made.
        guard let compound = Self.overlappingBoxes() else {
            Issue.record("could not build the overlap fixture")
            return
        }
        let solids = compound.subShapes(ofType: .solid)
        #expect(solids.count == 2)
        guard solids.count == 2 else { return }

        if let va = solids[0].volume, let vb = solids[1].volume {
            #expect(abs(va - 1000) < 1e-6)
            #expect(abs(vb - 1000) < 1e-6)
        }
        if let fused = solids[0].union(solids[1]), let vf = fused.volume {
            #expect(abs(vf - 1500) < 1e-3)
        } else {
            Issue.record("the fixture's two solids did not fuse, so the overlap is unproven")
        }
    }

    // MARK: - The false negative

    @available(*, deprecated)
    @Test("Two overlapping boxes are reported as self-intersecting")
    func overlappingBoxesReportSelfIntersection() {
        guard let shape = Self.overlappingBoxes() else {
            Issue.record("could not build the overlapping-box compound")
            return
        }
        #expect(shape.selfIntersects)
    }

    @available(*, deprecated)
    @Test("Two overlapping spheres are reported as self-intersecting")
    func overlappingSpheresReportSelfIntersection() {
        guard let shape = Self.overlappingSpheres() else {
            Issue.record("could not build the overlapping-sphere compound")
            return
        }
        #expect(shape.selfIntersects)
    }

    // MARK: - The controls

    @available(*, deprecated)
    @Test("A plain box is not reported as self-intersecting")
    func cleanBoxReportsNoSelfIntersection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the control box")
            return
        }
        #expect(!box.selfIntersects)
    }

    @available(*, deprecated)
    @Test("Two disjoint boxes in a compound are not reported as self-intersecting")
    func disjointBoxesReportNoSelfIntersection() {
        guard let shape = Self.disjointBoxes() else {
            Issue.record("could not build the disjoint-box compound")
            return
        }
        #expect(!shape.selfIntersects)
    }

    // MARK: - The guard

    /// A shape with no content is not a self-intersecting one. The pre-#1088 body answered `true`
    /// here, because `BOPAlgo_CheckerSI` reports an error for it and the error was being returned
    /// as the answer.
    ///
    /// It also covers the null-shape guard, though not through this assertion: removing the guard
    /// takes the whole test process down with a SIGSEGV on 12 of 15 runs, and on the other 3 this
    /// test passes. So the guard is held by process death rather than by a failed expectation, and
    /// a single green run of this file is not by itself evidence the guard is present.
    @available(*, deprecated)
    @Test("A nullified shape is not reported as self-intersecting")
    func nullifiedShapeIsNotReportedAsSelfIntersecting() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let nulled = box.nullified
        else {
            Issue.record("could not build a nullified shape")
            return
        }
        #expect(!nulled.selfIntersects)
    }

    // MARK: - Agreement with the bounded spelling

    /// The two public spellings of this question now agree on shapes where the bounded one
    /// completes, which is the property that makes the deprecation a redirection rather than a
    /// behaviour change.
    @available(*, deprecated)
    @Test("The deprecated spelling agrees with isSelfIntersecting(timeout:)")
    func answerAgreesWithTheBoundedSpelling() {
        guard let dirty = Self.overlappingBoxes(),
            let clean = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("could not build the comparison fixtures")
            return
        }
        if let bounded = dirty.isSelfIntersecting(timeout: 30) {
            #expect(bounded == dirty.selfIntersects)
        }
        if let bounded = clean.isSelfIntersecting(timeout: 30) {
            #expect(bounded == clean.selfIntersects)
        }
    }
}
