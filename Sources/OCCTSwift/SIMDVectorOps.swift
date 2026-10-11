// SIMDVectorOps.swift
//
// The six vector operations `Sources/OCCTSwift` needs, written against the Swift standard library's
// `SIMD` protocols and nothing else (#2759).
//
// WHY THIS FILE EXISTS. Apple's `simd` module is not available on every platform this package
// builds for, and the stand-in that used to cover the gap (`Sources/WASICompat/simd`) was a second
// implementation of the same functions that had to be kept in step with the first. These helpers
// are one implementation, in plain Swift, that Apple and WebAssembly both compile, so there is no
// platform on which a result can differ because a different library computed it.
//
// NO FILE UNDER `Sources/` MAY `import simd` OR CALL A `simd_` FUNCTION. `Scripts/check-no-simd.py`
// holds that, and a `--self-test` case holds the gate.
//
// THE ONE BEHAVIOUR FOR A ZERO OR NON-FINITE VECTOR (#2759) is the IEEE one, and it is the same on
// every platform because it is this code and not a platform library:
//
//   - `normalizedVector(.zero)` is a vector of NaNs (0 / 0).
//   - `normalizedVector` of a vector with an infinite component has a NaN in that component
//     (inf / inf) and 0 in the finite ones, so it is not a unit vector.
//   - A vector whose squared length overflows or underflows (components around 1e154 or 1e-162)
//     normalises with the same IEEE division, so it is not rescaled; callers feeding such values get
//     what the division gives.
//
// NaN is the answer the Apple build always gave, and it is not an accident: `ConstructionLayer`'s
// `planeShape` (#880) reads `Placement(normal: .zero)`'s NaN points to report `.planeShapeFailed`,
// where a returned zero vector would have handed `BRepBuilderAPI_MakePolygon` coincident points
// instead. A caller that wants a zero vector refused, or survived, tests its own length first, where
// the choice is visible. The previous claim in the stand-in, that every one of the 62 call sites
// "either guards the length first or feeds OCCT", was audited site by site for #2759 and was not
// true of all of them; the sites that did neither now guard, and `VectorMathTests` pins the
// decision.
//
// Last-bit results can differ from Apple's `simd` (it computes `x * rsqrt(|x|^2)`, these compute
// `x / |x|`). That is a difference from the old Apple build, not between platforms.

/// Sum of the componentwise products.
@inline(__always)
internal func dotProduct<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint {
    (a * b).sum()
}

/// Squared Euclidean length, for comparisons against a squared tolerance without the square root.
@inline(__always)
internal func vectorLengthSquared<V: SIMD>(_ a: V) -> V.Scalar where V.Scalar: FloatingPoint {
    dotProduct(a, a)
}

/// Euclidean length.
@inline(__always)
internal func vectorLength<V: SIMD>(_ a: V) -> V.Scalar where V.Scalar: FloatingPoint {
    vectorLengthSquared(a).squareRoot()
}

/// Distance between two points.
@inline(__always)
internal func vectorDistance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint {
    vectorLength(a - b)
}

/// Squared distance between two points.
@inline(__always)
internal func vectorDistanceSquared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
where V.Scalar: FloatingPoint {
    vectorLengthSquared(a - b)
}

/// The 3-D cross product.
@inline(__always)
internal func crossProduct<Scalar: FloatingPoint>(
    _ a: SIMD3<Scalar>, _ b: SIMD3<Scalar>
) -> SIMD3<Scalar> {
    SIMD3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x)
}

/// The unit vector in the same direction, by IEEE division.
///
/// A zero vector, or one with a non-finite component, gives NaNs. See the file header for why that
/// is the chosen behaviour and not a gap; a caller that must not propagate NaN checks
/// `vectorLength(_:)` first.
///
/// ```swift
/// normalizedVector(SIMD3(0, 3, 4))   // (0, 0.6, 0.8)
/// normalizedVector(SIMD3<Double>())  // (nan, nan, nan)
/// ```
@inline(__always)
internal func normalizedVector<V: SIMD>(_ a: V) -> V where V.Scalar: FloatingPoint {
    a / vectorLength(a)
}

/// The unit vector in the same direction, or nil for a zero or non-finite vector.
///
/// The spelling for a call site that must refuse such an input instead of carrying NaNs forward.
///
/// A vector whose squared length underflows to zero (components below about 1e-154) counts as
/// zero here, exactly as `normalizedVector` turns it into NaNs (0 / 0); no CAD coordinate is
/// that small, and the two spellings agree on which inputs they refuse.
@inline(__always)
internal func normalizedVectorOrNil<V: SIMD>(_ a: V) -> V? where V.Scalar: FloatingPoint {
    let length = vectorLength(a)
    guard length.isFinite, length > 0 else { return nil }
    return a / length
}
