// BooleanTestFixtures.swift
// Shared fixtures for boolean operation tests.
// No @Suite or @Test: only shared helpers.

import Foundation
import OCCTSwift

/// Shared boolean operation fixtures.
enum BooleanTestFixtures {
    /// Two 10mm boxes overlapping by 5mm along X: box A at (0,0,0), box B at (5,0,0).
    /// Used for timeout, outcome, and delegation tests.
    static func overlappingBoxes() -> (Shape, Shape)? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return (a, b)
    }

    /// Two 10mm boxes stacked along Z: lower at (0,0,0), upper at (0,0,10).
    /// Used for coincident-face and option tests.
    static func stackedBoxes() -> (Shape, Shape)? {
        guard let lower = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let upper = Shape.box(origin: SIMD3(0, 0, 10), width: 10, height: 10, depth: 10)
        else {
            return nil
        }
        return (lower, upper)
    }
}
