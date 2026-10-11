// SIMDTestHelpers.swift
//
// THIS FILE IS IDENTICAL IN EVERY `Tests/OCCT<Domain>Tests` TARGET, ON PURPOSE (#2759).
//
// The tests used Apple's `simd_length`, `simd_dot` and friends, which exist on Apple platforms
// only. Each test target is its own module and has no shared helper module, so each carries this
// copy of plain-Swift vector helpers written against the standard library's `SIMD` protocols
// (componentwise arithmetic and `.sum()`), with no dependency on Apple's `simd` module. Once the
// whole #2759 series has merged, `Scripts/check-no-simd.py` fails if any copy differs from another,
// so an edit here is an edit in all of them.
//
// A ZERO OR NON-FINITE VECTOR NORMALISES TO NaNs, by IEEE division. That is what Apple's
// `simd_normalize`, which these tests used before, returns (measured: a zero vector gives
// (nan, nan, nan), and (inf, 0, 0) gives (nan, 0, 0)), so migrating changed no result. It is a
// different contract from the library's public `Vector3DMath.normalize`, which returns nil.
//
// Two consequences for a test author. An assertion on a NaN result, `#expect(x < tol)`, fails,
// because every ordered comparison with NaN is false. A GUARD written as `length < tol` does not
// catch NaN for the same reason; write `!(length >= tol)` where a zero input is possible.
//
// The older per-target `SIMD3.normalized` fixtures some targets define for their own use
// (`ModelingTestExtensions.swift`, `DrawingTestFixtures.swift`, `XCAFTestFixtures.swift`) return the
// zero vector unchanged, for a test that wants a zero-safe unit vector, and were left as they are.
// Pick `normalized` for that, `normalizedVector` to match Apple's behaviour.

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
