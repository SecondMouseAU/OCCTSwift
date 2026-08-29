// ShapeHealingTestFixtures.swift
// Shared fixtures for OCCTShapeHealingTests.
// No @Suite or @Test: only factory functions.

import Foundation
import OCCTSwift
import Testing
import simd

// The one shared helper CLAUDE.md's Test Layout section documents across every per-domain target
// ("the only shared helper is SIMD3.normalized"). Moved here verbatim from the top of
// OCCTShapeHealingTests.swift when that file was split by @Suite (#1301); no suite in this
// directory currently calls it, the same as before the split, since it's declared for whichever
// suite in the module needs it next rather than for a specific caller today.
extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

/// Drops one face from `box` and sews the remaining five: the smallest recipe that reaches an
/// open shell with exactly 4 free edges ringing the missing face, whatever the box's own size or
/// origin. Shared by `Issue442FixSolidMultiBody` and `Issue702SolidDemotion`, both of
/// which built this same "drop one face, sew the rest" logic independently before the #717 review
/// pointed out the duplication.
///
/// Note this drops the caller-side `#expect(faces.count == 6)` that `Issue442FixSolidMultiBody`
/// used to assert inline: a non-six face count now returns nil and surfaces as that suite's own
/// "could not sew the open shell" record instead. The test still fails, one step later and with a
/// less specific message.
func sewnBoxMissingOneFace(_ box: Shape, tolerance: Double = 1e-6) -> Shape? {
    let faces = box.subShapes(ofType: .face)
    guard faces.count == 6,
        let compound = Shape.compound(Array(faces.dropFirst()))
    else { return nil }
    return compound.sewn(tolerance: tolerance)
}

// MARK: - #1287: the #442/#443 multi-body volume fixtures

/// Volume, asserted rather than optionally-bound: a `nil` here means the solid came back
/// inverted, which must fail the test rather than skip it. `Shape.volume` is `v >= 0 ? v : nil`,
/// so it returns `nil` precisely when a solid comes back inverted. Shared by
/// `Issue442FixSolidMultiBody` and `Issue443FirstOfN`, byte-identical (including this doc comment)
/// between the two files before the #1287 review pointed out the duplication, bypassing this
/// fixtures file the same way `sewnBoxMissingOneFace` above was bypassed before #717.
func expectVolume(
    _ shape: Shape, _ expected: Double,
    _ what: String, sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let volume = shape.volume else {
        Issue.record(
            "\(what): volume is nil, the solid came back inverted",
            sourceLocation: sourceLocation)
        return
    }
    #expect(
        abs(volume - expected) < 1e-6, "\(what): volume \(volume), expected \(expected)",
        sourceLocation: sourceLocation)
}

/// Two disjoint 10mm boxes, 2000mm³ total: the #442/#443 issues' own reproducer. Shared by
/// `Issue442FixSolidMultiBody` and `Issue443FirstOfN`, same #1287 duplication as `expectVolume`
/// above.
func twoBoxes() -> Shape? {
    guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
        let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)
    else { return nil }
    return Shape.compound([a, b])
}

/// A 20mm cube with a 10mm cavity fully inside it: one solid, two shells. Shared by
/// `Issue442FixSolidMultiBody` and `Issue443FirstOfN`, same #1287 duplication as `expectVolume`
/// above.
func hollowBox() -> Shape? {
    guard let outer = Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20),
        let cavity = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
    else { return nil }
    return outer.subtracting(cavity)
}

/// One solid holding two disjoint closed shells. Pathological but real, and the case that rules
/// out the naive "outer shell per solid" selection rule, so it is the one most likely to regress
/// unnoticed. `Issue442FixSolidMultiBody` named this helper `multiconnexSolid()`;
/// `Issue443FirstOfN` inlined the identical construction directly inside a test body
/// (`solidFromMulticonnex`) instead of naming it, until the #1287 review pointed out both were
/// building the same fixture.
func multiconnexSolid() -> Shape? {
    guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
        let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
        let shellA = a.shells.first, let shellB = b.shells.first
    else { return nil }
    return Shape.solidFromShells([shellA, shellB])
}

/// A 10x10 planar panel with a 4x4 centred window, so the face carries two wires: one that is its
/// outer bound and one that is not. Shared by `Issue999OuterBoundTests` and
/// `Issue1058OuterBoundRefusalTests`, which built it independently before the #1058 review pointed
/// out the duplication, the same way #717 did for `sewnBoxMissingOneFace` above.
func panelWithCentredWindow() -> Shape? {
    guard
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
        let outer = Wire.polygon3D(
            [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
        let hole = Wire.polygon3D(
            [SIMD3(3, 3, 0), SIMD3(7, 3, 0), SIMD3(7, 7, 0), SIMD3(3, 7, 0)], closed: true)
    else { return nil }
    return Shape.face(from: plane, outer: outer, innerWires: [hole])
}
