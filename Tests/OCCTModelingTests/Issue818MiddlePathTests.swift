import Foundation
import Testing

@testable import OCCTSwift

/// #818 (Pass 5d refman coverage audit, tests: peripheral subsystems): `Shape.middlePath(start:end:)`
/// (`BRepOffsetAPI_MiddlePath`) had a real bridge function, a real Swift wrapper, and a
/// `docs/reference/Shape-Healing.md` entry, but no test anywhere in the tree exercised it — a
/// genuine under-coverage finding, not a wrapping gap: #811's own lane audit already counted this
/// class `ok` (wrapped), since the census only asks "is it named in the bridge," not "does a test
/// run it." Filed and fixed in the same PR per #818's own instructions ("small enough to add a test
/// for"), unlike `LocOpe_SplitDrafts` (#818's sibling finding), whose ground-truth construction
/// needed real OCCT plumbing (a pcurve explicitly attached to the splitting wire) and was filed as
/// a follow-up instead.
///
/// Ground-truthed directly against the pinned kernel before writing this (a standalone `.mm`
/// compiled per CLAUDE.md's "Compile a Ground Truth C++ Test" recipe): a coaxial tube (an outer
/// cylinder minus a smaller coaxial inner cylinder, both the same height) is exactly the "pipe-like
/// shape" `BRepOffsetAPI_MiddlePath`'s own header docstring describes, and its two flat annular end
/// faces are valid `StartShape`/`EndShape` arguments (the header: "StartShape and EndShape may be a
/// wire or a face"). The ground truth's own printed bbox for the resulting spine was
/// `X[-1e-07,1e-07] Y[-1e-07,1e-07] Z[-1e-07,10]` for a radius-5/radius-2/height-10 tube: the
/// spine collapses onto the shared cylinder axis (X=Y=0), running the tube's full height, which is
/// the checkable, non-trivial assertion below (not just non-nil: a `nil`-shaped defect and a
/// wrong-but-non-nil spine are different failures, and the bbox check catches both).
@Suite("Issue818 middlePath ground truth (#811 under-coverage: BRepOffsetAPI_MiddlePath)")
struct Issue818MiddlePathTests {

    /// Build a coaxial tube: an outer cylinder minus a smaller coaxial inner cylinder, both
    /// `height` tall, bottom at Z=0. `BRepOffsetAPI_MiddlePath`'s own header calls this shape
    /// "pipe-like."
    private func coaxialTube(outerRadius: Double, innerRadius: Double, height: Double) -> Shape? {
        guard let outer = Shape.cylinder(radius: outerRadius, height: height),
            let inner = Shape.cylinder(radius: innerRadius, height: height)
        else { return nil }
        return outer.subtracting(inner)
    }

    @Test("middlePath of a coaxial tube collapses onto the shared axis, running the full height")
    func middlePathOfCoaxialTubeIsTheAxis() throws {
        let tube = try #require(coaxialTube(outerRadius: 5, innerRadius: 2, height: 10))

        // The tube's two flat annular ends are the only two horizontal faces at distinct Z
        // levels; `facesByZLevel()` (already used elsewhere in this tree, e.g. Face.swift's own
        // doc examples) groups them for us rather than hand-picking a face index, which would be
        // as fragile here as #541's own finding says a raw index is everywhere else in this bridge.
        let byZ = tube.facesByZLevel()
        #expect(byZ.count == 2)
        let levels = byZ.keys.sorted()
        try #require(levels.count == 2)
        let bottomFaces = try #require(byZ[levels[0]])
        let topFaces = try #require(byZ[levels[1]])
        #expect(bottomFaces.count == 1)
        #expect(topFaces.count == 1)

        let bottomCap = try #require(Shape.fromFace(bottomFaces[0]))
        let topCap = try #require(Shape.fromFace(topFaces[0]))

        let spine = tube.middlePath(start: bottomCap, end: topCap)
        let unwrapped = try #require(spine, "middlePath should succeed on a genuine pipe-like shape")

        let bounds = try #require(unwrapped.bounds)
        // The spine is the shared cylinder axis: X and Y collapse to ~0, Z spans the tube's height.
        #expect(abs(bounds.min.x) < 1e-3)
        #expect(abs(bounds.max.x) < 1e-3)
        #expect(abs(bounds.min.y) < 1e-3)
        #expect(abs(bounds.max.y) < 1e-3)
        #expect(abs(bounds.min.z - levels[0]) < 1e-3)
        #expect(abs(bounds.max.z - levels[1]) < 1e-3)
    }
}
