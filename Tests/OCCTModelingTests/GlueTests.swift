import Testing
import simd

@testable import OCCTSwift

@Suite("Glue Tests")
struct GlueTests {

    @Test("Glue two boxes")
    func glueTwoBoxes() {
        // Create two boxes that share a face
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        let glued = Shape.glue(box1, box2, tolerance: 1e-6)

        #expect(glued != nil)
        #expect(glued!.isValid)

        // Volume should be sum of both
        let gluedVolume = glued!.volume ?? 0
        let expectedVolume = 10.0 * 10.0 * 10.0 * 2
        #expect(abs(gluedVolume - expectedVolume) < 1.0)
    }

    /// #2735: `OCCTShapeGlue` used to put both shapes into `SetArguments` and set no
    /// tools, which `BRepAlgoAPI_Fuse` reports as an error on every input, so the
    /// function always fell back to a plain, un-tolerant `BRepAlgoAPI_Fuse(s1, s2)`.
    /// That fallback never calls `SetFuzzyValue`, so two boxes separated by a gap wider
    /// than OCCT's default confusion precision (~1e-7) but inside the caller's own
    /// `tolerance` come back as two separate solids in a compound, not one glued solid.
    ///
    /// This is the discriminator ground-truthed in `Scripts/repro/2735-shape-glue-mode/`:
    /// on the same gap fixture, the buggy fallback path measured `solidCount == 2`
    /// (compound of two untouched boxes) while the fixed argument/tool + fuzzy-value
    /// path measured `solidCount == 1`. `glueTwoBoxes` above shares an exactly
    /// coincident face and cannot tell the two paths apart: a plain fuse merges exact
    /// coincidence just as well as glue mode does, which is exactly why the original bug
    /// shipped with a passing test suite.
    @Test("Glue applies the caller's tolerance to a near-coincident face")
    func glueAppliesTolerance() {
        let box1 = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
        // A gap inside `tolerance` (1e-3) but outside OCCT's default confusion precision
        // (~1e-7), so only a boolean that actually applies the caller's tolerance treats
        // the two boxes as touching.
        let gap = 5e-5
        let box2 = Shape.box(
            origin: SIMD3(10 + gap, 0, 0), width: 10, height: 10, depth: 10)!

        let glued = Shape.glue(box1, box2, tolerance: 1e-3)

        #expect(glued != nil)
        guard let glued else { return }
        #expect(glued.isValid)
        // The un-tolerant fallback leaves the boxes as two solids in a compound; glue
        // mode with the tolerance applied merges them into one.
        #expect(glued.solidCount == 1)

        let gluedVolume = glued.volume ?? 0
        let expectedVolume = 10.0 * 10.0 * 10.0 * 2
        #expect(abs(gluedVolume - expectedVolume) < 1.0)
    }
}
