import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1491 (Finding 2): `OCCTShapeDivideByNumber(shape, nbU, nbV)` set `NbParts() = nbU * nbV` on
/// the underlying `ShapeUpgrade_FaceDivideArea` but never called `SetNumbersUVSplits(nbU, nbV)`,
/// so `ShapeUpgrade_SplitSurfaceArea::Compute()` never saw a fixed per-axis split count
/// (`myUnbSplit`/`myVnbSplit` stayed at their constructor default, -1) and always fell back to
/// deriving its own "roughly square" split from the face's own U/V aspect ratio -- silently
/// ignoring both the caller's axis distribution AND, on a non-square face, the requested total.
///
/// Fixing only that, exactly as the issue's own fix shape describes, turned out to be a complete
/// no-op: `MaxArea()` defaults to `Precision::Infinite()`, not the `-1` sentinel
/// `ShapeUpgrade_FaceDivideArea::Perform()` checks for before deriving a max-area-per-part from
/// `NbParts()`; left unset, `Perform()`'s very next guard is unconditionally true for any finite
/// face, so `Perform()` -- and this whole function -- failed for EVERY input, independent of
/// nbU/nbV, both before and after the `SetNumbersUVSplits` fix. Confirmed with a ground-truth
/// probe against the exact call sequence this function used, on a plain box, before adding
/// `MaxArea() = -1` alongside `SetNumbersUVSplits`. This is why `DivideByNumberTests.swift`'s
/// pre-#1491 tests read "Division is geometry-dependent; may return nil for some shapes" -- it
/// was not geometry-dependent, it always returned nil, and the tests' own `if let` pattern never
/// exercised the success path to notice.
///
/// `Shape.dividedByNumber(_ parts:)`, the only Swift call site, always passes `nbV: 1`, so a
/// regression test proving the per-axis fix needs the raw C entry point (`OCCTShapeDivideByNumber`)
/// directly -- see the `OCCTBridge` dependency this suite's target needed added in Package.swift.
@Suite("Issue #1491: OCCTShapeDivideByNumber respects nbU/nbV")
struct Issue1491DivideByNumberUVAxesTests {

    /// A single planar face, deliberately elongated (100 long in U, 1 in V) so the two candidate
    /// behaviors give very different, unambiguous answers. Measured directly with a ground-truth
    /// probe (not hand-derived): the buggy "roughly square" auto-derivation gives 44 faces for
    /// nbU=5 regardless of orientation (`aSquareSize = sqrt(100/5) ≈ 4.47` floors to 22 splits in
    /// the long direction, clamps the near-zero short-direction floor up to 1, then the class's
    /// own "never leave the second axis truly unsplit in auto-derive mode" rule bumps that 1 to 2,
    /// giving 22 * 2 = 44); the fixed path, once `SetNumbersUVSplits` is actually called, takes
    /// the caller's exact nbU * nbV (5) instead, with no such bump.
    private func elongatedFace() throws -> Shape {
        let wire = try #require(Wire.rectangle(width: 100, height: 1))
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        return try #require(Shape.face(from: plane, boundary: wire))
    }

    /// Proves the exact requested split count is honored, not silently overridden by the
    /// aspect-ratio-derived "roughly square" fallback. Reverting the fix (dropping the
    /// `SetNumbersUVSplits` call this issue adds) makes this fail: the elongated fixture above
    /// makes the two paths diverge sharply (5 vs. 44), so this is not a coincidental pass.
    @Test("nbU=5, nbV=1 produces exactly 5 faces, not an aspect-ratio-derived count")
    func exactSplitCountUOnly() throws {
        let face = try elongatedFace()
        let divided = try #require(OCCTShapeDivideByNumber(face.handle, 5, 1))
        let result = Shape(handle: divided)
        #expect(
            result.faces().count == 5,
            "expected exactly 5 faces (nbU=5 * nbV=1); got \(result.faces().count), which is what the pre-#1491 'roughly square' auto-derivation on this elongated face would produce instead"
        )
    }

    /// The axis-swapped counterpart: nbU/nbV transposed, same product. Before the fix, both
    /// (5, 1) and (1, 5) fall into the same aspect-ratio-derived branch and produce the SAME
    /// (wrong) face count regardless of which axis got which value -- the issue's own
    /// verification ("nbU=5,nbV=1 and nbU=1,nbV=5 both produce 24 faces") is exactly this
    /// symmetry-under-swap signature. After the fix, both honor their own product (5) instead.
    @Test("nbU=1, nbV=5 produces exactly 5 faces too")
    func exactSplitCountVOnly() throws {
        let face = try elongatedFace()
        let divided = try #require(OCCTShapeDivideByNumber(face.handle, 1, 5))
        let result = Shape(handle: divided)
        #expect(
            result.faces().count == 5,
            "expected exactly 5 faces (nbU=1 * nbV=5); got \(result.faces().count)"
        )
    }

    /// A genuinely asymmetric split (nbU != nbV, product not a perfect square) on a face whose
    /// own aspect ratio doesn't match 6:1 at all -- if SetNumbersUVSplits were only *sometimes*
    /// wired up (e.g. only for the square case), this would still catch it.
    @Test("nbU=6, nbV=1 produces exactly 6 faces")
    func exactSplitCountAsymmetric() throws {
        let face = try elongatedFace()
        let divided = try #require(OCCTShapeDivideByNumber(face.handle, 6, 1))
        let result = Shape(handle: divided)
        #expect(result.faces().count == 6, "got \(result.faces().count)")
    }
}
