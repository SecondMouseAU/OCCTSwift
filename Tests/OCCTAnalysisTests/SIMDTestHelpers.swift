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
// A ZERO OR NON-FINITE VECTOR NORMALISES TO NaNs, by IEEE division, as the library's own helpers
// do. A test that feeds one through `normalizedVector` and then compares the result gets a failing
// comparison (every ordered comparison with NaN is false), so the NaN is loud and does not pass
// silently. This differs on purpose from the older `SIMD3.normalized` fixtures that some targets
// define for their own use (`ModelingTestExtensions.swift`, `DrawingTestFixtures.swift`,
// `XCAFTestFixtures.swift`): those return the zero vector unchanged for a test that wants a
// zero-safe unit vector, and were left as they are. Pick `normalized` for that, `normalizedVector`
// to match the library.

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
