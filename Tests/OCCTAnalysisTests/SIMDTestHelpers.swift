// SIMDTestHelpers.swift
//
// THIS FILE IS IDENTICAL IN EVERY `Tests/OCCT<Domain>Tests` TARGET, ON PURPOSE (#2759).
//
// The tests used Apple's `simd_length`, `simd_dot` and friends, which exist on Apple platforms
// only. Each test target is its own module and has no shared helper module, so each carries this
// copy of the plain-Swift versions the library uses internally (`Sources/OCCTSwift/SIMDVectorOps.swift`).
// `Scripts/check-no-simd.py` fails if any copy differs from another, so an edit here is an edit in
// all of them.
//
// A zero or non-finite vector normalises to NaNs, by IEEE division, on every platform. See the
// library file for why.

func dotProduct<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint {
    (a * b).sum()
}

func vectorLengthSquared<V: SIMD>(_ a: V) -> V.Scalar where V.Scalar: FloatingPoint {
    dotProduct(a, a)
}

func vectorLength<V: SIMD>(_ a: V) -> V.Scalar where V.Scalar: FloatingPoint {
    vectorLengthSquared(a).squareRoot()
}

func vectorDistance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint {
    vectorLength(a - b)
}

func vectorDistanceSquared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint {
    vectorLengthSquared(a - b)
}

func crossProduct<Scalar: FloatingPoint>(
    _ a: SIMD3<Scalar>, _ b: SIMD3<Scalar>
) -> SIMD3<Scalar> {
    SIMD3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x)
}

func normalizedVector<V: SIMD>(_ a: V) -> V where V.Scalar: FloatingPoint {
    a / vectorLength(a)
}
