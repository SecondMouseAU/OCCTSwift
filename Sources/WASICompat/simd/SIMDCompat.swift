// swift-format-ignore-file: AlwaysUseLowerCamelCase, TypeNamesShouldBeCapitalized
//
// TWO RULES ARE DISABLED FOR THIS FILE AND ONLY TWO. Every public name here has to be spelled
// exactly as Apple's `simd` module spells it, because the point of the module is that the 26 files in
// `Sources/OCCTSwift` and the 271 under `Tests/` that still write `import simd` (after #2759
// removed the rest) compile unchanged on both platforms. `simd_float4x4` cannot become `SimdFloat4x4` and `simd_dot` cannot become `simdDot`
// without defeating that, so `TypeNamesShouldBeCapitalized` and `AlwaysUseLowerCamelCase` are
// suppressed here by name rather than the whole file being exempted: everything else swift-format
// checks, including the spacing, the doc comments and the one-variable-per-line rule, still applies.
//
// This replaced a blanket entry on a style exemption manifest, removed in #2793 when the rule
// was that a file a PR touches must come into compliance. The manifests are retired since.

// SIMDCompat.swift
//
// A `simd` module for `wasm32-unknown-wasip1`, where Apple's is not available.
//
// WHY THIS IS A MODULE AND NOT A SET OF EDITS. 196 of the 230 files in `Sources/OCCTSwift` opened
// with `import simd` when this was written, which on this target is `error: no such module
// 'simd'` and stops the whole Swift layer. #2759 removed the imports no file needed, measured by
// building Apple and wasm with each one gone, and 26 remain: files that call a `simd_*` function,
// build a `simd_*` matrix, or use the unqualified SIMD `min`/`max`. The alternative to this module
// is `#if canImport(simd)` around those imports, which would still have to be followed by
// definitions of the free functions below. One target named `simd`, added to `OCCTSwift`'s
// dependencies only when `isWASI` (see `Package.swift`), leaves every remaining file unchanged on
// Apple platforms, where `import simd` still resolves to Apple's own.
//
// WHAT IS HERE IS WHAT `Sources/OCCTSwift` USES, and nothing else. Measured, not guessed:
//
//     grep -rho "simd_[a-zA-Z_0-9]*" Sources/OCCTSwift/ | sort | uniq -c
//
// gave `simd_normalize` 62, `simd_length` 32, `simd_dot` 28, `simd_cross` 16, `simd_float4x4` 8,
// `simd_length_squared` 5, `simd_distance` 4, `simd_double3x3` 3, `simd_min` 1, `simd_max` 1 when
// the stand-in was written. After #2759, counting code and not comments: `simd_normalize` 57,
// `simd_length` 30, `simd_dot` 29, `simd_cross` 15, `simd_length_squared` 6, `simd_distance` 4,
// `simd_float4x4` 6, `simd_double3x3` 5, `simd_min` 1, `simd_max` 1.
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

// APPLE'S `simd` PUTS libm IN SCOPE, AND SO MUST THIS ONE. Measured on macOS 27, not assumed: a
// file whose only import is `simd` compiles and runs `cos(1.0)` and `atan2(1.0, 2.0)`, so on Apple
// platforms `import simd` is what brings the C math functions in. 90 of the 1,428 files under
// `Tests/` depend on exactly that, most of them importing `Testing`, `simd` and `OCCTSwift` and
// nothing else, and without the re-export below they fail with `cannot find 'cos' in scope` (#2793).
//
// Re-exporting here rather than adding an import to those 90 files is the same call #2764 made for
// `simd_normalize`: where this stand-in can be faithful to Apple's module, being faithful is what
// keeps a wasm-only difference from leaking into 90 files that have nothing to do with wasm.
//
// `@_exported` is underscored and is the only spelling of re-export there is; SE-0409's
// `public import` controls visibility, not re-export. `Sources/OCCTPlatform/Platform.swift` records
// the same finding for the same reason, and its ordering is the one swift.org's WebAssembly
// porting guide publishes.
#if canImport(WASILibc)
    @_exported import WASILibc
#elseif canImport(Glibc)
    @_exported import Glibc
#endif

/// Column-major 4x4 matrix of `Float`, in the shape `Sources/OCCTSwift` builds and returns.
public struct simd_float4x4: Equatable, Sendable {

    /// The four columns, in order, exactly as the four-argument initialiser received them.
    public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)

    /// The zero matrix, which is what Apple's no-argument initialiser gives.
    ///
    /// Measured on macOS 27, not assumed: `simd_float4x4().columns.0` is `SIMD4(0, 0, 0, 0)` and
    /// `simd_determinant(simd_float4x4())` is `0.0`. This stand-in said "the identity matrix" and
    /// built one until #2793, which is a wrong answer to a public initialiser rather than a
    /// documented simplification. Nothing in this package calls it, measured across `Sources/` and
    /// all 1,428 files under `Tests/`, so nothing depended on the difference. Use
    /// `matrix_identity_float4x4` for the identity, which is Apple's own spelling.
    public init() {
        self.init(SIMD4(), SIMD4(), SIMD4(), SIMD4())
    }

    /// Build from four columns.
    public init(
        _ column0: SIMD4<Float>, _ column1: SIMD4<Float>, _ column2: SIMD4<Float>,
        _ column3: SIMD4<Float>
    ) {
        columns = (column0, column1, column2, column3)
    }

    /// The column at `index`. Column-indexed like `simd_double3x3`'s, which the comment there
    /// records the measurement for.
    public subscript(index: Int) -> SIMD4<Float> {
        get {
            switch index {
            case 0: return columns.0
            case 1: return columns.1
            case 2: return columns.2
            case 3: return columns.3
            default: preconditionFailure("simd_float4x4 column index out of range: \(index)")
            }
        }
        set {
            switch index {
            case 0: columns.0 = newValue
            case 1: columns.1 = newValue
            case 2: columns.2 = newValue
            case 3: columns.3 = newValue
            default: preconditionFailure("simd_float4x4 column index out of range: \(index)")
            }
        }
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

    /// The zero matrix, which is what Apple's no-argument initialiser gives.
    ///
    /// Measured the same way as `simd_float4x4.init()` above, and corrected for the same reason
    /// (#2793). Use `matrix_identity_double3x3` for the identity.
    public init() {
        self.init(SIMD3(), SIMD3(), SIMD3())
    }

    /// Build from three columns.
    public init(_ column0: SIMD3<Double>, _ column1: SIMD3<Double>, _ column2: SIMD3<Double>) {
        columns = (column0, column1, column2)
    }

    /// The column at `index`, which is what Apple's subscript returns.
    ///
    /// Measured on macOS 27, not assumed, because a symmetric test matrix cannot tell a column
    /// subscript from a row one: for `simd_double3x3(SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9))`
    /// Apple gives `m[0] == SIMD3(1, 2, 3)`, equal to `columns.0`, and `m[0][1] == 2`. So `m[i][j]`
    /// is column `i`, element `j`. Added for #2793: `CenterOfMassTests` reads
    /// `props.momentOfInertia[1][1]`, and that one site is diagonal, which is exactly the case that
    /// would have hidden a transpose here.
    public subscript(index: Int) -> SIMD3<Double> {
        get {
            switch index {
            case 0: return columns.0
            case 1: return columns.1
            case 2: return columns.2
            default: preconditionFailure("simd_double3x3 column index out of range: \(index)")
            }
        }
        set {
            switch index {
            case 0: columns.0 = newValue
            case 1: columns.1 = newValue
            case 2: columns.2 = newValue
            default: preconditionFailure("simd_double3x3 column index out of range: \(index)")
            }
        }
    }

    public static func == (lhs: simd_double3x3, rhs: simd_double3x3) -> Bool {
        lhs.columns.0 == rhs.columns.0 && lhs.columns.1 == rhs.columns.1
            && lhs.columns.2 == rhs.columns.2
    }
}

// MARK: - The identity constants, because the initialisers above are Apple's zero matrix

/// The 4x4 identity, under Apple's own name for it.
///
/// Added with #2793, when the no-argument initialisers were corrected to Apple's zero matrix: a
/// caller that wanted an identity would otherwise have had no spelling for one at all. Apple's
/// `simd` declares these as `matrix_identity_float4x4` and `matrix_identity_double3x3`, so a file
/// using them compiles unchanged on both platforms.
public let matrix_identity_float4x4 = simd_float4x4(
    SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1))

/// The 3x3 identity, under Apple's own name for it.
///
/// See `matrix_identity_float4x4`.
public let matrix_identity_double3x3 = simd_double3x3(
    SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))

// MARK: - The vector functions, for any SIMD of a floating-point scalar

/// Sum of the componentwise products.
public func simd_dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
where V.Scalar: FloatingPoint {
    var total = V.Scalar.zero
    for index in 0..<a.scalarCount { total += a[index] * b[index] }
    return total
}

/// Squared Euclidean length, which avoids the square root where a comparison is all that is
/// wanted.
///
/// Four of the five call sites in `Sources/OCCTSwift` compare it against a squared tolerance for
/// exactly that reason.
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

/// Squared distance between two points.
///
/// Apple's `simd` defines this as the squared length of the difference, and so does this, by
/// calling the two functions above rather than restating either. It is here because two
/// `OCCTAnalysisTests` suites compare a bridge-reported square distance against the one they can
/// compute from the two witness points, and taking a square root to compare squares would add an
/// error the comparison exists to measure (#3007).
public func simd_distance_squared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
where V.Scalar: FloatingPoint {
    simd_length_squared(a - b)
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

// The same argument as `min`/`max` above, for the five vector functions the tests reach for by
// their unqualified names. Apple's module exports both spellings; this stand-in exported only the
// `simd_`-prefixed one until #2793, and the diagnostic is `cannot find 'distance' in scope`.
//
// Measured across `Sources/OCCTSwift` and all 1,428 files under `Tests/`: `length` 33, `distance`
// 28, `cross` 21, `normalize` 15, `dot` 1. `Sources/OCCTSwift` itself uses the prefixed spelling
// throughout, so every one of these is a test, which is why #2175 never needed them.

/// Euclidean length, the spelling Apple's `simd` also exports.
public func length<V: SIMD>(_ a: V) -> V.Scalar where V.Scalar: BinaryFloatingPoint {
    simd_length(a)
}

/// Distance between two points, the spelling Apple's `simd` also exports.
public func distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: BinaryFloatingPoint {
    simd_distance(a, b)
}

/// Sum of the componentwise products, the spelling Apple's `simd` also exports.
public func dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint {
    simd_dot(a, b)
}

/// The unit vector in the same direction, the spelling Apple's `simd` also exports.
///
/// A zero vector normalises to NaNs here exactly as it does through `simd_normalize`.
public func normalize<V: SIMD>(_ a: V) -> V where V.Scalar: BinaryFloatingPoint {
    simd_normalize(a)
}

/// Cross product, the spelling Apple's `simd` also exports.
public func cross<Scalar: FloatingPoint>(_ a: SIMD3<Scalar>, _ b: SIMD3<Scalar>) -> SIMD3<Scalar> {
    simd_cross(a, b)
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

// MARK: - The one matrix function anything in this package asks for

/// Determinant of a 4x4 matrix.
///
/// The only matrix operation the package needs on this target, and it is needed by a test rather
/// than by `Sources/OCCTSwift`: `Tests/OCCTDrawingTests/Visualization/CameraTests.swift` asserts that
/// `Camera.projectionMatrix` is invertible. The measured census of `simd_*` names across all 1,428
/// test files is `simd_length` 187, `simd_distance` 102, `simd_dot` 39, `simd_normalize` 36,
/// `simd_cross` 12, `simd_double3x3` 1 and this, once (#2793). Everything else was already here.
///
/// This is deliberately not the start of matrix arithmetic. The header above says these two types
/// are column containers and that a consumer wanting real linear algebra needs more than a porting
/// stand-in, and that is still true: a determinant is a single scalar read off the container, not
/// multiplication, inversion or transposition.
///
/// **Storage order does not matter here**, which removes the whole class of column-major versus
/// row-major mistakes from this function: `det(A) == det(Aᵀ)`, so reading the columns as rows gives
/// the same answer. Verified against Apple's own `simd_determinant` rather than assumed; the
/// comparison is in `Scripts/repro/2793/`.
///
/// ```swift
/// // `simd_float4x4()` is Apple's ZERO matrix, so the identity has its own name.
/// #expect(simd_determinant(matrix_identity_float4x4) == 1)
/// #expect(simd_determinant(simd_float4x4()) == 0)
/// ```
public func simd_determinant(_ matrix: simd_float4x4) -> Float {
    let columns = matrix.columns

    // Named by (row, column), so the expansion below reads like the textbook one.
    let m00 = columns.0.x
    let m01 = columns.1.x
    let m02 = columns.2.x
    let m03 = columns.3.x
    let m10 = columns.0.y
    let m11 = columns.1.y
    let m12 = columns.2.y
    let m13 = columns.3.y
    let m20 = columns.0.z
    let m21 = columns.1.z
    let m22 = columns.2.z
    let m23 = columns.3.z
    let m30 = columns.0.w
    let m31 = columns.1.w
    let m32 = columns.2.w
    let m33 = columns.3.w

    // Laplace expansion along the first row.
    return m00 * determinant3(m11, m12, m13, m21, m22, m23, m31, m32, m33)
        - m01 * determinant3(m10, m12, m13, m20, m22, m23, m30, m32, m33)
        + m02 * determinant3(m10, m11, m13, m20, m21, m23, m30, m31, m33)
        - m03 * determinant3(m10, m11, m12, m20, m21, m22, m30, m31, m32)
}

/// Determinant of the 3x3 minor, taken by row so `simd_determinant` above reads as the expansion.
private func determinant3(
    _ a: Float, _ b: Float, _ c: Float,
    _ d: Float, _ e: Float, _ f: Float,
    _ g: Float, _ h: Float, _ i: Float
) -> Float {
    a * ((e * i) - (f * h)) - b * ((d * i) - (f * g)) + c * ((d * h) - (e * g))
}
