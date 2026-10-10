---
title: Matrix Value Types
parent: API Reference
---

# Matrix Value Types

`Matrix4x4F` and `Matrix3x3D` are the package's own column-major matrix values (#2759). They replaced
`simd_float4x4` and `simd_double3x3` in the public API so that the API is the same on every
platform, including WebAssembly where Apple's `simd` module does not exist. They are plain Swift
over the standard library's `SIMD3` and `SIMD4`, `Equatable` and `Sendable`.

They carry a matrix the kernel produced and do the few things a caller does with one first. They are
not linear algebra: there is no multiplication, inverse or transpose here, and a consumer that
multiplies converts to its own matrix type.

| Type | Scalar | Returned by |
|------|--------|-------------|
| `Matrix4x4F` | `Float` | `AssemblyNode.transform`, `Camera.projectionMatrix`, `Camera.viewMatrix` |
| `Matrix3x3D` | `Double` | `GProps.matrixOfInertia`, `ShapeProperties.momentOfInertia` |

## Topics

- [Matrix4x4F](#matrix4x4f) · [Matrix3x3D](#matrix3x3d) · [Migrating from simd](#migrating-from-simd)

---

## Matrix4x4F

### `Matrix4x4F.init(_:_:_:_:)`

Builds a matrix from four columns.

```swift
public init(_ column0: SIMD4<Float>, _ column1: SIMD4<Float>, _ column2: SIMD4<Float>, _ column3: SIMD4<Float>)
```

- **Example:**
  ```swift
  let translate = Matrix4x4F(
      SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(5, 6, 7, 1))
  print(translate[3])          // SIMD4<Float>(5.0, 6.0, 7.0, 1.0)
  ```

### `Matrix4x4F.identity` and `Matrix4x4F.zero`

```swift
public static let identity: Matrix4x4F
public static let zero: Matrix4x4F
```

`zero` is the all-zero matrix, as `simd_float4x4()` was. Use `identity` for the identity.

### `Matrix4x4F.columns`, `column0` to `column3`, `subscript(_:)`

```swift
public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) { get set }
public subscript(_ index: Int) -> SIMD4<Float> { get set }
```

`m[i]` is column `i` and `m[i][j]` is the element in column `i`, row `j`, which is what
`simd_float4x4` indexing gave. An index outside 0 through 3 is a precondition failure.

### `Matrix4x4F.columnMajorElements`

The sixteen elements, column 0 first: the layout Metal, OpenGL, WebGL and glTF take.

```swift
public var columnMajorElements: [Float] { get }
```

- **Example:**
  ```swift
  let flat = Matrix4x4F.identity.columnMajorElements
  print(flat.count)            // 16
  ```

### `Matrix4x4F.determinant`

```swift
public var determinant: Float { get }
```

Laplace expansion along the first row. `det(A) == det(Aᵀ)`, so the result does not depend on how the
columns are read.

---

## Matrix3x3D

### `Matrix3x3D.init(_:_:_:)`

Builds a matrix from three columns.

```swift
public init(_ column0: SIMD3<Double>, _ column1: SIMD3<Double>, _ column2: SIMD3<Double>)
```

### `Matrix3x3D.identity` and `Matrix3x3D.zero`

```swift
public static let identity: Matrix3x3D
public static let zero: Matrix3x3D
```

### `Matrix3x3D.columns`, `column0` to `column2`, `subscript(_:)`

```swift
public var columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) { get set }
public subscript(_ index: Int) -> SIMD3<Double> { get set }
```

`m[i][j]` is column `i`, row `j`. An inertia tensor is symmetric, so its row and column readings
agree; any other 3x3 matrix is not, and a symmetric test matrix cannot tell the two apart.

- **Example:**
  ```swift
  if let box = Shape.box(width: 2, height: 3, depth: 4), let p = box.properties() {
      let ixx = p.momentOfInertia[0][0]
      let izz = p.momentOfInertia[2][2]
      print(ixx > 0, izz > 0)
  }
  ```

### `Matrix3x3D.columnMajorElements`

The nine elements, column 0 first.

```swift
public var columnMajorElements: [Double] { get }
```

### `Matrix3x3D.determinant`

The scalar triple product of the columns.

```swift
public var determinant: Double { get }
```

---

## Migrating from simd

Code that read the old properties through `.columns` or `[column][row]` compiles unchanged. Code
that passed the value to an Apple API, or multiplied it, converts at the boundary. There is no
conversion in this package, on purpose: it would need Apple's module imported here, which is the
dependency #2759 removed, and it would make the public surface differ by platform.

```swift no-typecheck: needs Apple's simd module, which this package does not import
import simd

extension simd_float4x4 {
    init(_ m: Matrix4x4F) { self.init(m.column0, m.column1, m.column2, m.column3) }
}
extension Matrix4x4F {
    init(_ m: simd_float4x4) { self.init(m.columns.0, m.columns.1, m.columns.2, m.columns.3) }
}
extension simd_double3x3 {
    init(_ m: Matrix3x3D) { self.init(m.column0, m.column1, m.column2) }
}

let viewProjection = simd_float4x4(camera.projectionMatrix) * simd_float4x4(camera.viewMatrix)
```
