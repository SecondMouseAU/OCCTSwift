// Matrix.swift
//
// Two small column-major matrix value types that replace `simd_float4x4` and `simd_double3x3` in
// the package's public API (#2759). They are written in plain Swift over the standard library's
// `SIMD3`/`SIMD4`, so the type, its layout and every operation on it are identical on Apple and on
// WebAssembly, where Apple's `simd` does not exist.
//
// WHAT THEY ARE FOR. They carry a matrix the kernel produced (an assembly placement, a camera
// matrix, an inertia tensor) to a caller, and they do the few things a caller does with one first:
// read a column, flatten to a column-major array, take a determinant. They are deliberately not
// linear algebra: there is no multiplication, inverse or transpose, because nothing in this package
// needs one and a second matrix library is not this package's job. A consumer that multiplies
// converts to its own matrix type, which for Apple consumers is three lines (see each type's
// documentation).
//
// NO CONVERSION TO OR FROM `simd_float4x4` LIVES HERE, ON PURPOSE. It would have to sit behind
// `#if canImport(simd)` and import Apple's module into this one, which is the dependency #2759
// removed, and it would make the public surface differ by platform. The consumer owns the
// conversion; the documentation shows it.

/// A 4x4 matrix of `Float`, stored column-major.
///
/// `m[i]` is column `i` and `m[i][j]` is the element in column `i`, row `j`, the same indexing
/// `simd_float4x4` has. `AssemblyNode.transform`, `Camera.projectionMatrix` and `Camera.viewMatrix`
/// return this type.
///
/// ```swift
/// let node = document.rootNodes[0]
/// let t = node.transform
/// let translation = SIMD3(t[3].x, t[3].y, t[3].z)   // the fourth column
/// let flat: [Float] = t.columnMajorElements          // 16 elements, column 0 first
/// ```
///
/// Migrating a consumer that used `simd_float4x4`: construct the Apple type from the columns.
///
/// ```swift no-typecheck: needs Apple's simd module, which this package does not import
/// import simd
/// let appleMatrix = simd_float4x4(t.column0, t.column1, t.column2, t.column3)
/// ```
public struct Matrix4x4F: Equatable, Sendable {

    /// Column 0.
    public var column0: SIMD4<Float>

    /// Column 1.
    public var column1: SIMD4<Float>

    /// Column 2.
    public var column2: SIMD4<Float>

    /// Column 3, which holds the translation of an affine transform.
    public var column3: SIMD4<Float>

    /// Build from four columns.
    public init(
        _ column0: SIMD4<Float>, _ column1: SIMD4<Float>, _ column2: SIMD4<Float>,
        _ column3: SIMD4<Float>
    ) {
        self.column0 = column0
        self.column1 = column1
        self.column2 = column2
        self.column3 = column3
    }

    /// The zero matrix.
    ///
    /// This is not the identity; use ``identity`` for that.
    public static let zero = Matrix4x4F(SIMD4(), SIMD4(), SIMD4(), SIMD4())

    /// The identity matrix.
    public static let identity = Matrix4x4F(
        SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1))

    /// The four columns as a tuple, in order, the shape `simd_float4x4.columns` has.
    public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) {
        get { (column0, column1, column2, column3) }
        set { (column0, column1, column2, column3) = newValue }
    }

    /// The column at `index`.
    ///
    /// Indices run 0 through 3, and an index outside that range is a precondition failure, as it
    /// is for `simd_float4x4`.
    public subscript(_ index: Int) -> SIMD4<Float> {
        get {
            switch index {
            case 0: return column0
            case 1: return column1
            case 2: return column2
            case 3: return column3
            default: preconditionFailure("Matrix4x4F column index out of range: \(index)")
            }
        }
        set {
            switch index {
            case 0: column0 = newValue
            case 1: column1 = newValue
            case 2: column2 = newValue
            case 3: column3 = newValue
            default: preconditionFailure("Matrix4x4F column index out of range: \(index)")
            }
        }
    }

    /// The sixteen elements, column 0 first: the layout Metal, OpenGL and glTF take.
    public var columnMajorElements: [Float] {
        [
            column0.x, column0.y, column0.z, column0.w,
            column1.x, column1.y, column1.z, column1.w,
            column2.x, column2.y, column2.z, column2.w,
            column3.x, column3.y, column3.z, column3.w,
        ]
    }

    /// The determinant, by Laplace expansion along the first row.
    ///
    /// `det(A) == det(Aᵀ)`, so the result does not depend on whether the columns are read as rows.
    public var determinant: Float {
        func minor(
            _ a: Float, _ b: Float, _ c: Float,
            _ d: Float, _ e: Float, _ f: Float,
            _ g: Float, _ h: Float, _ i: Float
        ) -> Float {
            a * ((e * i) - (f * h)) - b * ((d * i) - (f * g)) + c * ((d * h) - (e * g))
        }
        // Named by (row, column), so the expansion reads like the textbook one.
        let m00 = column0.x
        let m01 = column1.x
        let m02 = column2.x
        let m03 = column3.x
        let m10 = column0.y
        let m11 = column1.y
        let m12 = column2.y
        let m13 = column3.y
        let m20 = column0.z
        let m21 = column1.z
        let m22 = column2.z
        let m23 = column3.z
        let m30 = column0.w
        let m31 = column1.w
        let m32 = column2.w
        let m33 = column3.w
        return m00 * minor(m11, m12, m13, m21, m22, m23, m31, m32, m33)
            - m01 * minor(m10, m12, m13, m20, m22, m23, m30, m32, m33)
            + m02 * minor(m10, m11, m13, m20, m21, m23, m30, m31, m33)
            - m03 * minor(m10, m11, m12, m20, m21, m22, m30, m31, m32)
    }
}

/// A 3x3 matrix of `Double`, stored column-major.
///
/// `m[i]` is column `i` and `m[i][j]` is the element in column `i`, row `j`, the same indexing
/// `simd_double3x3` has. `GProps.matrixOfInertia` and `ShapeProperties.momentOfInertia` return this
/// type. An inertia tensor is symmetric, so its row-major and column-major readings are equal.
///
/// ```swift
/// let box = Shape.box(width: 2, height: 3, depth: 4)!
/// if let p = box.properties() {
///     let ixx = p.momentOfInertia[0][0]
///     let izz = p.momentOfInertia[2][2]
///     print(ixx, izz)
/// }
/// ```
///
/// Migrating a consumer that used `simd_double3x3`: construct the Apple type from the columns.
///
/// ```swift no-typecheck: needs Apple's simd module, which this package does not import
/// import simd
/// let appleMatrix = simd_double3x3(m.column0, m.column1, m.column2)
/// ```
public struct Matrix3x3D: Equatable, Sendable {

    /// Column 0.
    public var column0: SIMD3<Double>

    /// Column 1.
    public var column1: SIMD3<Double>

    /// Column 2.
    public var column2: SIMD3<Double>

    /// Build from three columns.
    public init(_ column0: SIMD3<Double>, _ column1: SIMD3<Double>, _ column2: SIMD3<Double>) {
        self.column0 = column0
        self.column1 = column1
        self.column2 = column2
    }

    /// The zero matrix.
    ///
    /// This is not the identity; use ``identity`` for that.
    public static let zero = Matrix3x3D(SIMD3(), SIMD3(), SIMD3())

    /// The identity matrix.
    public static let identity = Matrix3x3D(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))

    /// The three columns as a tuple, in order, the shape `simd_double3x3.columns` has.
    public var columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        get { (column0, column1, column2) }
        set { (column0, column1, column2) = newValue }
    }

    /// The column at `index`.
    ///
    /// Indices run 0 through 2, and an index outside that range is a precondition failure, as it
    /// is for `simd_double3x3`.
    public subscript(_ index: Int) -> SIMD3<Double> {
        get {
            switch index {
            case 0: return column0
            case 1: return column1
            case 2: return column2
            default: preconditionFailure("Matrix3x3D column index out of range: \(index)")
            }
        }
        set {
            switch index {
            case 0: column0 = newValue
            case 1: column1 = newValue
            case 2: column2 = newValue
            default: preconditionFailure("Matrix3x3D column index out of range: \(index)")
            }
        }
    }

    /// The nine elements, column 0 first.
    public var columnMajorElements: [Double] {
        [
            column0.x, column0.y, column0.z,
            column1.x, column1.y, column1.z,
            column2.x, column2.y, column2.z,
        ]
    }

    /// The determinant, the scalar triple product of the columns.
    public var determinant: Double {
        dotProduct(column0, crossProduct(column1, column2))
    }
}
