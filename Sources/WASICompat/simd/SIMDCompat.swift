// SIMDCompat.swift
//
// A `simd` module for `wasm32-unknown-wasip1`, where Apple's is not available.
//
// WHY THIS IS A MODULE AND NOT A SET OF EDITS. 196 of the 230 files in `Sources/OCCTSwift` open
// with `import simd`, which on this target is `error: no such module 'simd'` and stops the whole
// Swift layer. The alternative is 196 `#if canImport(simd)` edits, which is a large mechanical
// diff through every file in the package for a decision spike, and which would still have to be
// followed by definitions of the free functions below. One target named `simd`, added to
// `OCCTSwift`'s dependencies only when `isWASI` (see `Package.swift`), leaves every one of those
// files untouched and unchanged on Apple platforms, where `import simd` still resolves to Apple's
// own.
//
// WHAT IS HERE IS WHAT `Sources/OCCTSwift` USES, and nothing else. Measured, not guessed:
//
//     grep -rho "simd_[a-zA-Z_0-9]*" Sources/OCCTSwift/ | sort | uniq -c
//
// gives `simd_normalize` 62, `simd_length` 32, `simd_dot` 28, `simd_cross` 16, `simd_float4x4` 8,
// `simd_length_squared` 5, `simd_distance` 4, `simd_double3x3` 3, `simd_min` 1, `simd_max` 1.
// `SIMD2`/`SIMD3`/`SIMD4` themselves are Swift standard library types on every platform and are
// NOT redefined here. Nothing in `Sources/OCCTSwift` reads a matrix back apart, measured: no
// `.columns` access, no matrix arithmetic, no `matrix_*` or `vector_*` name anywhere. The two
// matrix types are therefore column containers, which is all the code that builds them asks of
// them. A consumer that multiplies matrices needs more than this, and that belongs to Phase 2
// rather than to a stand-in that pretends to be Accelerate.
//
// THIS IS A PORTING STAND-IN AND IT IS NOT A PERFORMANCE STORY. Apple's `simd` lowers these to
// vector instructions. These are scalar loops. wasm32 without the SIMD proposal has no vector
// unit to lower to, so on this target the scalar form is not a regression; on any target that has
// one it would be, which is another reason this module is reachable only under `isWASI`.

/// Column-major 4x4 matrix of `Float`, in the shape `Sources/OCCTSwift` builds and returns.
public struct simd_float4x4: Equatable, Sendable {

    /// The four columns, in order, exactly as the four-argument initialiser received them.
    public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)

    /// The identity matrix.
    public init() {
        self.init(
            SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1))
    }

    /// Build from four columns.
    public init(
        _ column0: SIMD4<Float>, _ column1: SIMD4<Float>, _ column2: SIMD4<Float>,
        _ column3: SIMD4<Float>
    ) {
        columns = (column0, column1, column2, column3)
    }

    public static func == (lhs: simd_float4x4, rhs: simd_float4x4) -> Bool {
        lhs.columns.0 == rhs.columns.0 && lhs.columns.1 == rhs.columns.1
            && lhs.columns.2 == rhs.columns.2 && lhs.columns.3 == rhs.columns.3
    }
}

/// Column-major 3x3 matrix of `Double`, in the shape `Sources/OCCTSwift` builds and returns.
public struct simd_double3x3: Equatable, Sendable {

    /// The three columns, in order, exactly as the three-argument initialiser received them.
    public var columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)

    /// The identity matrix.
    public init() {
        self.init(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
    }

    /// Build from three columns.
    public init(_ column0: SIMD3<Double>, _ column1: SIMD3<Double>, _ column2: SIMD3<Double>) {
        columns = (column0, column1, column2)
    }

    public static func == (lhs: simd_double3x3, rhs: simd_double3x3) -> Bool {
        lhs.columns.0 == rhs.columns.0 && lhs.columns.1 == rhs.columns.1
            && lhs.columns.2 == rhs.columns.2
    }
}

// MARK: - The vector functions, for any SIMD of a floating-point scalar

/// Sum of the componentwise products.
public func simd_dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
where V.Scalar: FloatingPoint {
    var total = V.Scalar.zero
    for index in 0..<a.scalarCount { total += a[index] * b[index] }
    return total
}

/// Squared Euclidean length, which avoids the square root where a comparison is all that is
/// wanted. Four of the five call sites in `Sources/OCCTSwift` compare it against a squared
/// tolerance for exactly that reason.
public func simd_length_squared<V: SIMD>(_ a: V) -> V.Scalar
where V.Scalar: FloatingPoint {
    simd_dot(a, a)
}

/// Euclidean length.
public func simd_length<V: SIMD>(_ a: V) -> V.Scalar
where V.Scalar: BinaryFloatingPoint {
    V.Scalar(Double(simd_length_squared(a)).squareRoot())
}

/// Distance between two points.
public func simd_distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
where V.Scalar: BinaryFloatingPoint {
    simd_length(a - b)
}

/// The unit vector in the same direction.
///
/// A zero vector normalises to a vector of NaNs, which is what Apple's `simd_normalize` does, and
/// this divides rather than special-casing so that it gets there the same way.
///
/// An earlier version of this stand-in returned the zero vector unchanged, on the reasoning that
/// every call site in `Sources/OCCTSwift` either guards the length first or feeds the result to
/// OCCT, which refuses a zero direction. That was wrong, and the counting gate in
/// `check-inventory-prose.py` that was written to hold the claim honest is what found it:
/// `ConstructionLayer.swift`'s `planeShape` (#880) depends on the NaN, and says so in a comment
/// recording a direct measurement. A placement built from `normal: .zero` produces NaN points,
/// `BRepBuilderAPI_MakePolygon` reports a "done" wire from them anyway, and `MakeFace` then fails,
/// which is what makes `.planeShapeFailed` the reported outcome rather than a NaN-vertexed shape
/// silently entering the document. Returning zero there would hand `MakePolygon` four coincident
/// points instead, and what OCCT does with those is a different question nobody has measured.
///
/// So this is faithful, and deliberately has no behaviour of its own to remember. A caller that
/// wants a zero vector to survive normalisation guards its own length, where the choice is visible
/// (#2759).
public func simd_normalize<V: SIMD>(_ a: V) -> V
where V.Scalar: BinaryFloatingPoint {
    let length = simd_length(a)
    var result = a
    for index in 0..<a.scalarCount { result[index] = a[index] / length }
    return result
}

/// Componentwise minimum.
public func simd_min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable {
    var result = a
    for index in 0..<a.scalarCount { result[index] = Swift.min(a[index], b[index]) }
    return result
}

/// Componentwise maximum.
public func simd_max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable {
    var result = a
    for index in 0..<a.scalarCount { result[index] = Swift.max(a[index], b[index]) }
    return result
}

// The UNQUALIFIED spellings, which Apple's module also provides and which `Mesh.boundingBox`
// calls as plain `min(a, b)` on two `SIMD3<Float>`. Without them the diagnostic is
// `global function 'min' requires that 'SIMD3<Float>' conform to 'Comparable'`, because the only
// candidate in scope is `Swift.min` for `Comparable`, which no SIMD type is. There is no
// ambiguity with `Swift.min` for the same reason: these two overloads accept exactly the types
// that one rejects.

/// Componentwise minimum, the spelling Apple's `simd` also exports.
public func min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable {
    simd_min(a, b)
}

/// Componentwise maximum, the spelling Apple's `simd` also exports.
public func max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable {
    simd_max(a, b)
}

/// The 3-D cross product, the one function here that is not defined for every width.
public func simd_cross<Scalar: FloatingPoint>(_ a: SIMD3<Scalar>, _ b: SIMD3<Scalar>) -> SIMD3<
    Scalar
> {
    SIMD3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x)
}
