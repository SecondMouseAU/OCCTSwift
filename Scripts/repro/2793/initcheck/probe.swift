import simd
let m = simd_float4x4()
print("Apple simd_float4x4() columns.0 =", m.columns.0)
print("Apple simd_float4x4() determinant =", simd_determinant(m))
print("matrix_identity_float4x4 determinant =", simd_determinant(matrix_identity_float4x4))
