import Foundation
import Testing
import simd

@testable import OCCTSwift

// #208: a watchdog-bounded self-intersection check. isValidSolid (topology) misses global
// self-intersection (overlapping faces), the defect that hung booleans in #206. This check
// (BOPAlgo_ArgumentAnalyzer self-interference) catches it, bounded so it cannot hang.
@Suite("Issue #208, self-intersection check")
struct Issue208SelfIntersection {

    @Test("a clean solid reports not self-intersecting")
    func cleanSolidIsClean() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false))
            return
        }
        #expect(box.isSelfIntersecting() == false)
        guard let sph = Shape.sphere(radius: 5) else {
            #expect(Bool(false))
            return
        }
        #expect(sph.isSelfIntersecting() == false)
    }

    @Test("two overlapping solids in one compound are detected as self-intersecting")
    func overlappingCompoundIsSelfIntersecting() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false))
            return
        }
        // The two boxes' faces interfere → self-interference within the single argument.
        #expect(compound.isSelfIntersecting() == true)
    }

    @Test("indeterminate when the check cannot finish in time")
    func tinyTimeoutIsIndeterminateOrConclusive() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false))
            return
        }
        // A near-zero deadline must not hang: either it found a fault first (true) or it
        // gave up (nil). It must never block, and must not falsely claim "clean".
        let r = compound.isSelfIntersecting(timeout: 1e-7)
        #expect(r == nil || r == true)
    }
}

// #319: a genuinely hard-bounded variant, following up on #293 (which documented that
// isSelfIntersecting(timeout:) is cooperative-only). Runs the check on a detached worker
// thread against a deepCopy(), with the calling thread enforcing the real deadline.
@Suite("Issue #319, hard-bounded self-intersection check")
struct Issue319HardBoundedSelfIntersection {

    @Test("a clean solid reports not self-intersecting")
    func cleanSolidIsClean() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false))
            return
        }
        #expect(box.isSelfIntersecting(hardTimeout: 30) == false)
    }

    @Test("two overlapping solids in one compound are detected as self-intersecting")
    func overlappingCompoundIsSelfIntersecting() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false))
            return
        }
        #expect(compound.isSelfIntersecting(hardTimeout: 30) == true)
    }

    @Test(
        "a near-zero deadline returns near that deadline, not after the full check, the property timeout: cannot offer"
    )
    func deadlineIsActuallyHard() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false))
            return
        }
        let start = Date()
        let r = compound.isSelfIntersecting(hardTimeout: 0.001)
        let elapsed = Date().timeIntervalSince(start)
        // Either it found a fault before the deadline (true) or the deadline won (nil),
        // both are acceptable outcomes. What matters is the CALLER'S wall-clock time, which
        // must track the deadline rather than the check's full (potentially unbounded) duration.
        #expect(r == nil || r == true)
        #expect(
            elapsed < 2.0,
            "hard deadline should bound the caller's wall-clock time, got \(elapsed)s")
    }

    // #1160: the probe this entry point builds used to share Geom_Surface/Geom_Curve handles
    // with `self` via the no-argument instance deepCopy(); a box's faces are all planar, so
    // that mistake was invisible on the fixture the two tests above use. A filleted box has
    // toroidal blend surfaces, exercising a curved Geom_Surface the analysis actually evaluates,
    // so this pins the check still answers correctly now that the probe clones geometry
    // (Shape.deepCopy(_:copyGeometry:true)) instead of sharing it.
    @Test("a clean solid with curved (filleted) surfaces reports not self-intersecting")
    func filletedSolidWithCurvedSurfacesIsClean() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let filleted = box.filleted(radius: 1)
        else {
            #expect(Bool(false))
            return
        }
        #expect(filleted.isSelfIntersecting(hardTimeout: 30) == false)
    }

    // #1549: `Shape.deepCopy` failing used to fall back to `?? self`, silently running the check
    // against `self` directly, exactly the shared `Geom_Surface`/`Geom_Curve` evaluation-cache
    // race #1160 built this probe to avoid. A `.nullified` shape forces that failure: reading
    // `BRepTools_Modifier::Perform` (`BRepTools_Modifier.cxx`, the class both `deepCopy` and
    // `BRepTools_CopyModification` are built on) shows a null `TopoDS_Shape` is its only
    // documented, non-cancellation failure path, `if (myShape.IsNull()) { throw
    // Standard_NullObject(); }`, a catchable `Standard_Failure` the bridge's own `catch (...)`
    // turns into `nil`; confirmed both by that read and by a standalone ground-truth probe
    // against the real library.
    //
    // This does NOT distinguish the fixed code from the reverted `?? self` by return value alone:
    // `BOPAlgo_ArgumentAnalyzer` (the self-intersection analyzer itself) also classifies a null
    // shape as `BOPAlgo_BadType` via its own `TestTypes` pass, not a crash, so running the check
    // against a nullified `self` answers `nil` too, same as the fix's immediate `nil`, independent
    // of the bug. Reverting `guard let probe = ... else { return nil }` back to
    // `let probe = ... ?? self` was confirmed, by hand, to leave this specific assertion passing:
    // both readings are `nil`, for the reason above, not because the revert is safe. What the
    // revert-and-restore *does* prove, and what is checked directly below, is that `deepCopy`
    // itself genuinely fails on this input every time, which is the fact this test exists to pin;
    // see the PR description for the fuller account of why no return-value-discriminating input
    // could be found for this OCCT version/API pairing.
    @Test("a shape whose deepCopy fails reports indeterminate, not a crash or a hang")
    func deepCopyFailureIsIndeterminate() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        // Confirms the forcing precondition on every run: deepCopy(copyGeometry:true,
        // copyMesh:false), the exact call this method makes, genuinely fails on this input.
        #expect(Shape.deepCopy(nulled, copyGeometry: true, copyMesh: false) == nil)
        #expect(nulled.isSelfIntersecting(hardTimeout: 5) == nil)
    }
}
