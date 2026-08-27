//
//  SIMD3Unpacking.swift
//  OCCTSwift
//
//  Shared helper for the flat, tightly-packed (x0,y0,z0, x1,y1,z1, ...) buffer
//  layout the bridge uses for every batch position/normal/pole/point query.
//
//  Driver: issue #419 (the #377/#380 duplication audit), the 3-stride unpack
//  expression `SIMD3(buf[i*3], buf[i*3+1], buf[i*3+2])` was reimplemented at
//  dozens of call sites with no shared conversion point, and two of those
//  copies (BRepGraph's `sampleFaceUVGrid`/`sampleEdgeCurve`) had already
//  drifted on which count bounds the loop, one trusted the *requested*
//  sample count, the other the *actual* count the bridge reported writing.
//

/// Unpacks a flat, tightly-packed `(x0,y0,z0, x1,y1,z1, ...)` buffer into `[SIMD3<Scalar>]`.
///
/// `count` is the number of `SIMD3` elements to read, always the *actual* number of valid
/// entries in `buffer` (typically a bridge call's own returned/written count), never a
/// requested or upper-bound count. Passing a requested count for a buffer a bridge call only
/// partially filled would read stale or uninitialized entries past the true written range.
///
/// Works for any random-access, `Int`-indexed buffer of a SIMD-compatible scalar, a plain
/// `[Double]`/`[Float]` array, or an `UnsafeBufferPointer`/`UnsafeMutableBufferPointer` obtained
/// from `withUnsafe(Mutable)BufferPointer`.
///
/// ```swift
/// let flat: [Double] = [1, 2, 3, 4, 5, 6]
/// let points = unpackSIMD3(flat, count: 2)
/// #expect(points == [SIMD3(1, 2, 3), SIMD3(4, 5, 6)])
/// ```
internal func unpackSIMD3<Buffer: RandomAccessCollection, Scalar>(
    _ buffer: Buffer, count: Int
) -> [SIMD3<Scalar>] where Buffer.Element == Scalar, Buffer.Index == Int, Scalar: SIMDScalar {
    guard count > 0 else { return [] }
    var result = [SIMD3<Scalar>]()
    result.reserveCapacity(count)
    for i in 0..<count {
        let base = buffer.startIndex + i * 3
        result.append(SIMD3(buffer[base], buffer[base + 1], buffer[base + 2]))
    }
    return result
}

/// Packs `[SIMD3<Scalar>]` into a flat, tightly-packed `(x0,y0,z0, x1,y1,z1, ...)` array, the
/// `unpackSIMD3(_:count:)` sibling for the write direction (#1186): every bridge call that takes
/// a flat position/normal/pole/point buffer expects this exact layout.
///
/// ```swift
/// let points: [SIMD3<Double>] = [SIMD3(1, 2, 3), SIMD3(4, 5, 6)]
/// let flat = packSIMD3(points)
/// #expect(flat == [1, 2, 3, 4, 5, 6])
/// ```
internal func packSIMD3<Scalar: SIMDScalar>(_ values: [SIMD3<Scalar>]) -> [Scalar] {
    var result = [Scalar]()
    result.reserveCapacity(values.count * 3)
    for v in values {
        result.append(v.x)
        result.append(v.y)
        result.append(v.z)
    }
    return result
}

// MARK: - Single-vector/axis out-param unwrap (#899/#902, moved here from ShapeAxis.swift by
// the #914 review, finding 11, module-wide, not ShapeAxis-specific, and this is this project's
// designated home for exactly this duplication class, #419)

/// Reads an origin/direction pair from a six-`Double`-out-param `OCCT*Axis`-shaped bridge call,
/// given as a closure already bound to the caller's own handle.
/// - Returns: element 0 is origin, element 1 is direction, by position; the caller's own
///   declared return type supplies whatever labels it wants.
func unwrapAxisComponents(
    _ bridgeCall: (
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Void
) -> (SIMD3<Double>, SIMD3<Double>) {
    var px: Double = 0
    var py: Double = 0
    var pz: Double = 0
    var dx: Double = 0
    var dy: Double = 0
    var dz: Double = 0
    bridgeCall(&px, &py, &pz, &dx, &dy, &dz)
    return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
}

/// Reads a point or direction from a three-`Double`-out-param bridge call, given as a closure
/// already bound to the caller's own handle and any other arguments.
func unwrapVectorComponents(
    _ bridgeCall: (
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Void
) -> SIMD3<Double> {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    bridgeCall(&x, &y, &z)
    return SIMD3(x, y, z)
}

/// The `unwrapVectorComponents(_:)` sibling for a three-`Double`-out-param bridge call that
/// reports success/failure through its own `Bool` return, rather than always writing a value,
/// `nil` on failure, matching every call site's existing `guard ... else { return nil }` idiom
/// (#899 covered the always-succeeds shape; this one was still hand-rolled at 8 call sites across
/// `Curve3D`/`Surface`, found in the #914 review, finding 10).
func unwrapVectorComponentsIfSuccessful(
    _ bridgeCall: (
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Bool
) -> SIMD3<Double>? {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    guard bridgeCall(&x, &y, &z) else { return nil }
    return SIMD3(x, y, z)
}

/// The `unwrapAxisComponents(_:)` sibling for a six-`Double`-out-param bridge call that reports
/// success/failure through its own `Bool` return.
///
/// The bounding-box entry points are the reason this exists: a void box and a genuinely zero-size
/// box at the world origin write the same six zeros, so the values cannot carry the distinction
/// and only the `Bool` can (#943). `nil` on failure, matching every call site's existing
/// `guard ... else { return nil }` idiom.
/// - Returns: element 0 is the low corner (or origin), element 1 the high corner (or direction),
///   by position; the caller's own declared return type supplies whatever labels it wants.
func unwrapAxisComponentsIfSuccessful(
    _ bridgeCall: (
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Bool
) -> (SIMD3<Double>, SIMD3<Double>)? {
    var px: Double = 0
    var py: Double = 0
    var pz: Double = 0
    var dx: Double = 0
    var dy: Double = 0
    var dz: Double = 0
    guard bridgeCall(&px, &py, &pz, &dx, &dy, &dz) else { return nil }
    return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
}
