// ModelingTestExtensions.swift
// Shared extensions for OCCTModelingTests.
// No @Suite or @Test: only shared helpers.

import simd
import OCCTSwift

extension SIMD3 where Scalar == Double {
    /// Returns a unit vector in the same direction, or `self` if the length is zero.
    ///
    /// Uses a small epsilon threshold (1e-10) rather than exact zero to avoid
    /// normalizing near-zero vectors that would produce NaN or extreme values.
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 1e-10 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

/// Shared glue test helper: tries all face pairs between two shapes using the given
/// glue function, returning the first successful result. Avoids duplicating the
/// byte-identical face-pair search loop across BRepFeat_Gluer and LocOpe_Gluer tests.
func tryGlueAllFacePairs<Result>(
    _ shape1: Shape, _ shape2: Shape,
    glue: (Shape, Shape, [(base: Shape, glued: Shape)]) -> Result?
) -> Result? {
    let faces1 = shape1.subShapes(ofType: .face)
    let faces2 = shape2.subShapes(ofType: .face)
    for f1 in faces1 {
        for f2 in faces2 {
            if let result = glue(shape1, shape2, [(base: f1, glued: f2)]) {
                return result
            }
        }
    }
    return nil
}
