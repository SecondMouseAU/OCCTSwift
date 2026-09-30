import simd
// asymmetric, so column-vs-row indexing is distinguishable
let m = simd_double3x3(SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9))
print("columns.0 =", m.columns.0)
print("m[0] =", m[0], "   -> m[i] is", m[0] == m.columns.0 ? "COLUMN i" : "row i")
print("m[0][1] =", m[0][1], " (column 0, element 1 == 2 if column-indexed)")
let f = simd_float4x4(SIMD4(1,2,3,4), SIMD4(5,6,7,8), SIMD4(9,10,11,12), SIMD4(13,14,15,16))
print("f[2][3] =", f[2][3], " (== 12 if column-indexed)")
