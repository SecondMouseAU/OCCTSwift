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
/// which built this same "drop one face, sew the rest" logic independently before #717 review
/// finding 5 pointed out the duplication.
func sewnBoxMissingOneFace(_ box: Shape, tolerance: Double = 1e-6) -> Shape? {
    let faces = box.subShapes(ofType: .face)
    guard faces.count == 6,
          let compound = Shape.compound(Array(faces.dropFirst()))
    else { return nil }
    return compound.sewn(tolerance: tolerance)
}
