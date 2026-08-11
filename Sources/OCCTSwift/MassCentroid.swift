//
//  MassCentroid.swift
//  OCCTSwift
//
//  Shared helper for the "zero mass, no centroid" rule every OCCT mass-properties bridge result
//  in this project reports the same way: a measurement with zero mass (an empty triangulation, a
//  coplanar face, a degenerate edge) has no meaningful centroid, so surfacing the (0,0,0) OCCT
//  happens to leave behind would read as a real answer at the origin rather than the absence of
//  one (#605, #609). Six call sites repeated the identical inline ternary
//  `r.mass == 0 ? nil : SIMD3(r.centerX, r.centerY, r.centerZ)` — Face.swift's meshProps,
//  surfaceInertia, surfaceInertia(epsilon:), volumeInertia, volumeInertia(planeNormal:planeDistance:),
//  and Edge.swift's curveInertia — consolidated here (#842).
//

import simd

/// Returns the measured centroid, or `nil` when `mass` is zero.
///
/// ```swift
/// massCentroid(mass: 0, x: 1, y: 2, z: 3)   // nil, not (1, 2, 3)
/// massCentroid(mass: 5, x: 1, y: 2, z: 3)   // SIMD3(1, 2, 3)
/// ```
internal func massCentroid(mass: Double, x: Double, y: Double, z: Double) -> SIMD3<Double>? {
    mass == 0 ? nil : SIMD3(x, y, z)
}
