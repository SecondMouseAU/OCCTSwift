//
//  SIMD3Unpacking.swift
//  OCCTSwift
//
//  Shared helper for the flat, tightly-packed (x0,y0,z0, x1,y1,z1, ...) buffer
//  layout the bridge uses for every batch position/normal/pole/point query.
//
//  Driver: issue #419 (the #377/#380 duplication audit) — the 3-stride unpack
//  expression `SIMD3(buf[i*3], buf[i*3+1], buf[i*3+2])` was reimplemented at
//  dozens of call sites with no shared conversion point, and two of those
//  copies (BRepGraph's `sampleFaceUVGrid`/`sampleEdgeCurve`) had already
//  drifted on which count bounds the loop — one trusted the *requested*
//  sample count, the other the *actual* count the bridge reported writing.
//

/// Unpacks a flat, tightly-packed `(x0,y0,z0, x1,y1,z1, ...)` buffer into `[SIMD3<Scalar>]`.
///
/// `count` is the number of `SIMD3` elements to read — always the *actual* number of valid
/// entries in `buffer` (typically a bridge call's own returned/written count), never a
/// requested or upper-bound count. Passing a requested count for a buffer a bridge call only
/// partially filled would read stale or uninitialized entries past the true written range.
///
/// Works for any random-access, `Int`-indexed buffer of a SIMD-compatible scalar — a plain
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
