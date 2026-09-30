import Foundation
import simd
func det3f(_ a: Float,_ b: Float,_ c: Float,_ d: Float,_ e: Float,_ f: Float,_ g: Float,_ h: Float,_ i: Float) -> Float {
    a*((e*i)-(f*h)) - b*((d*i)-(f*g)) + c*((d*h)-(e*g))
}
func detFloat(_ m: simd_float4x4) -> Float {
    let c = m.columns
    let m00=c.0.x,m01=c.1.x,m02=c.2.x,m03=c.3.x
    let m10=c.0.y,m11=c.1.y,m12=c.2.y,m13=c.3.y
    let m20=c.0.z,m21=c.1.z,m22=c.2.z,m23=c.3.z
    let m30=c.0.w,m31=c.1.w,m32=c.2.w,m33=c.3.w
    return m00*det3f(m11,m12,m13,m21,m22,m23,m31,m32,m33)
         - m01*det3f(m10,m12,m13,m20,m22,m23,m30,m32,m33)
         + m02*det3f(m10,m11,m13,m20,m21,m23,m30,m31,m33)
         - m03*det3f(m10,m11,m12,m20,m21,m22,m30,m31,m32)
}
func det3d(_ a: Double,_ b: Double,_ c: Double,_ d: Double,_ e: Double,_ f: Double,_ g: Double,_ h: Double,_ i: Double) -> Double {
    a*((e*i)-(f*h)) - b*((d*i)-(f*g)) + c*((d*h)-(e*g))
}
func detDouble(_ m: simd_float4x4) -> Float {
    let c = m.columns
    let m00=Double(c.0.x),m01=Double(c.1.x),m02=Double(c.2.x),m03=Double(c.3.x)
    let m10=Double(c.0.y),m11=Double(c.1.y),m12=Double(c.2.y),m13=Double(c.3.y)
    let m20=Double(c.0.z),m21=Double(c.1.z),m22=Double(c.2.z),m23=Double(c.3.z)
    let m30=Double(c.0.w),m31=Double(c.1.w),m32=Double(c.2.w),m33=Double(c.3.w)
    return Float(m00*det3d(m11,m12,m13,m21,m22,m23,m31,m32,m33)
         - m01*det3d(m10,m12,m13,m20,m22,m23,m30,m32,m33)
         + m02*det3d(m10,m11,m13,m20,m21,m23,m30,m31,m33)
         - m03*det3d(m10,m11,m12,m20,m21,m22,m30,m31,m32))
}
struct LCG { var s: UInt64 = 0x2793_2793_2793_2793
  mutating func next() -> Float { s = s &* 6364136223846793005 &+ 1442695040888963407; return (Float(s >> 40)/Float(1<<24)*4)-2 } }
var g = LCG()
var wf: Float = 0, wd: Float = 0
for _ in 1...20000 {
    let m = simd_float4x4(SIMD4(g.next(),g.next(),g.next(),g.next()),SIMD4(g.next(),g.next(),g.next(),g.next()),SIMD4(g.next(),g.next(),g.next(),g.next()),SIMD4(g.next(),g.next(),g.next(),g.next()))
    let a = simd_determinant(m), scale = max(abs(a), 1)
    wf = max(wf, abs(a-detFloat(m))/scale)
    wd = max(wd, abs(a-detDouble(m))/scale)
}
print("20,000 random matrices, worst relative difference from Apple's simd_determinant")
print("  Float accumulation : \(wf)")
print("  Double accumulation: \(wd)")
