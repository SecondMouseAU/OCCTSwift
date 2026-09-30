// Compares the WASI simd stand-in's `simd_determinant` against Apple's own, on macOS, where both
// exist. The stand-in's copy is pasted in below as `standInDeterminant` rather than imported,
// because the `simd` target is reachable only when `isWASI` and its name collides with Apple's on
// every other platform: importing both into one file is not expressible. Keep the two in step.
//
//     xcrun swiftc -O Scripts/repro/2793/determinant-parity.swift -o /tmp/det-parity && /tmp/det-parity
//
// Exits non-zero on any mismatch.

import Foundation  // `exit` and String.padding; `simd` re-exports libm but not all of Darwin.
import simd

func standInDeterminant(_ matrix: simd_float4x4) -> Float {
    let columns = matrix.columns
    let m00 = columns.0.x, m01 = columns.1.x, m02 = columns.2.x, m03 = columns.3.x
    let m10 = columns.0.y, m11 = columns.1.y, m12 = columns.2.y, m13 = columns.3.y
    let m20 = columns.0.z, m21 = columns.1.z, m22 = columns.2.z, m23 = columns.3.z
    let m30 = columns.0.w, m31 = columns.1.w, m32 = columns.2.w, m33 = columns.3.w
    return m00 * determinant3(m11, m12, m13, m21, m22, m23, m31, m32, m33)
        - m01 * determinant3(m10, m12, m13, m20, m22, m23, m30, m32, m33)
        + m02 * determinant3(m10, m11, m13, m20, m21, m23, m30, m31, m33)
        - m03 * determinant3(m10, m11, m12, m20, m21, m22, m30, m31, m32)
}

func determinant3(
    _ a: Float, _ b: Float, _ c: Float,
    _ d: Float, _ e: Float, _ f: Float,
    _ g: Float, _ h: Float, _ i: Float
) -> Float {
    a * ((e * i) - (f * h)) - b * ((d * i) - (f * g)) + c * ((d * h) - (e * g))
}

// A deterministic generator, so a failure is reproducible from the transcript alone.
struct LCG {
    var state: UInt64 = 0x2793_2793_2793_2793
    mutating func next() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return (Float(state >> 40) / Float(1 << 24) * 4) - 2
    }
}

func column(_ g: inout LCG) -> SIMD4<Float> {
    SIMD4(g.next(), g.next(), g.next(), g.next())
}

let tolerance: Float = 1e-5
var failures = 0
var worstRelative: Float = 0
var worstCase = ""

func check(_ name: String, _ m: simd_float4x4) {
    let apple = simd_determinant(m)
    let standIn = standInDeterminant(m)
    let scale = max(abs(apple), 1)
    let relative = abs(apple - standIn) / scale
    if relative > worstRelative {
        worstRelative = relative
        worstCase = name
    }
    // Float arithmetic in a different association order is not bit-identical, so the bar is a
    // relative one, and it is DERIVED rather than picked to make this pass. The expansion is about
    // 60 float operations, so worst-case error growth is around 60 * Float.ulpOfOne = 7.1e-6;
    // `tolerance` below is 1e-5, just above that. Measured over 20,000 random matrices the worst
    // real difference is 2.9e-6.
    //
    // Accumulating the same expansion in Double and narrowing at the end was measured too and moves
    // the worst case only from 2.9e-6 to 2.2e-6. That 25% is the tell: most of the residual is
    // APPLE'S rounding, not this function's, since the Double form is nearer the true value. So
    // there is no bit-parity to chase here, and Float accumulation is kept because it matches the
    // type it is declared on.
    let ok = relative <= tolerance
    if !ok { failures += 1 }
    print(
        "  \(ok ? "PASS" : "FAIL")  \(name.padding(toLength: 26, withPad: " ", startingAt: 0))"
            + " apple=\(apple) standIn=\(standIn) rel=\(relative)")
}

print("simd_determinant: WASI stand-in against Apple's, macOS")
print("")

// Apple's no-arg `simd_float4x4()` is the ZERO matrix, not the identity, which is why this case
// expects 0. The stand-in documented and implemented it as the identity until #2793; nothing in
// the package called it, so nothing depended on the difference.
check("default init (zero)", simd_float4x4())
check("identity", matrix_identity_float4x4)
check(
    "singular (duplicate column)",
    simd_float4x4(
        SIMD4(1, 2, 3, 4), SIMD4(1, 2, 3, 4), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0)))
check("all zeros", simd_float4x4(SIMD4(), SIMD4(), SIMD4(), SIMD4()))
check(
    "diagonal 2,3,4,5",
    simd_float4x4(
        SIMD4(2, 0, 0, 0), SIMD4(0, 3, 0, 0), SIMD4(0, 0, 4, 0), SIMD4(0, 0, 0, 5)))
check(
    "a perspective projection",
    simd_float4x4(
        SIMD4(1.299_038, 0, 0, 0), SIMD4(0, 1.948_557, 0, 0),
        SIMD4(0, 0, -1.002_002, -1), SIMD4(0, 0, -0.200_200_2, 0)))
check(
    "transpose of the above",
    simd_float4x4(
        SIMD4(1.299_038, 0, 0, 0), SIMD4(0, 1.948_557, 0, 0),
        SIMD4(0, 0, -1.002_002, -0.200_200_2), SIMD4(0, 0, -1, 0)))

var generator = LCG()
for index in 1...20_000 {
    let m = simd_float4x4(
        column(&generator), column(&generator), column(&generator), column(&generator))
    if index <= 4 { check("random #\(index)", m) } else {
        let apple = simd_determinant(m)
        let standIn = standInDeterminant(m)
        let relative = abs(apple - standIn) / max(abs(apple), 1)
        if relative > worstRelative {
            worstRelative = relative
            worstCase = "random #\(index)"
        }
        if relative > tolerance {
            failures += 1
            print("  FAIL  random #\(index) apple=\(apple) standIn=\(standIn) rel=\(relative)")
        }
    }
}

print("")
print("20,000 random matrices plus 6 named cases, tolerance \(tolerance)")
print("worst relative difference: \(worstRelative) (\(worstCase))")
print(failures == 0 ? "PARITY" : "\(failures) MISMATCHES")
exit(failures == 0 ? 0 : 1)
