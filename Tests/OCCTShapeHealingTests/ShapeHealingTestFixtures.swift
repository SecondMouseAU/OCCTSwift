// ShapeHealingTestFixtures.swift
// Shared fixtures for OCCTShapeHealingTests.
// No @Suite or @Test: only factory functions.

import Testing
import Foundation
import simd
import OCCTSwift

/// Drops one face from `box` and sews the remaining five: the smallest recipe that reaches an
/// open shell with exactly 4 free edges ringing the missing face, whatever the box's own size or
/// origin. Shared by `Issue442FixSolidMultiBodyTests` and `Issue702SolidDemotionTests`, both of
/// which built this same "drop one face, sew the rest" logic independently before the #717 review
/// pointed out the duplication.
///
/// Note this drops the caller-side `#expect(faces.count == 6)` that `Issue442FixSolidMultiBodyTests`
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
