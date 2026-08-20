// #990: does `ThreadFeatures.swift`'s own `orthonormalRadial(axis:)` agree with the module-wide
// `perpendicularBasis(to:)`, and if so on which of that function's two elements?
//
// Both implementations are copied verbatim below so the probe runs standalone, with no OCCT and
// no package build:
//
//     swiftc -O basis-compare.swift -o basis-compare && ./basis-compare
//
// The gp_Ax2 column is ground truth read from the pinned kernel by `gp_ax2_truth.mm`, not
// recomputed here. The copy of `perpendicularBasis(to:)` is checked against it first: a probe
// whose copy has drifted from the real function would compare two things neither of which is in
// the tree.

import Foundation
import simd

// Verbatim from Sources/OCCTSwift/ThreadFeatures.swift:561, before the #990 fix.
func orthonormalRadial(axis: SIMD3<Double>) -> SIMD3<Double> {
    let a = simd_normalize(axis)
    let up = abs(a.z) < 0.9 ? SIMD3<Double>(0, 0, 1) : SIMD3<Double>(1, 0, 0)
    return simd_normalize(simd_cross(a, up))
}

// Verbatim from Sources/OCCTSwift/PerpendicularBasis.swift:28.
func perpendicularBasis(to direction: SIMD3<Double>) -> (SIMD3<Double>, SIMD3<Double>) {
    let v = simd_normalize(direction)
    let aAbs = abs(v.x)
    let bAbs = abs(v.y)
    let cAbs = abs(v.z)
    let raw: SIMD3<Double>
    if bAbs <= aAbs && bAbs <= cAbs {
        raw = aAbs > cAbs ? SIMD3(-v.z, 0, v.x) : SIMD3(v.z, 0, -v.x)
    } else if aAbs <= bAbs && aAbs <= cAbs {
        raw = bAbs > cAbs ? SIMD3(0, -v.z, v.y) : SIMD3(0, v.z, -v.y)
    } else {
        raw = aAbs > bAbs ? SIMD3(-v.y, v.x, 0) : SIMD3(v.y, -v.x, 0)
    }
    let right = simd_normalize(raw)
    let up = simd_normalize(simd_cross(v, right))
    return (right, up)
}

/// `gp_ax2_truth.mm`'s output: axis, then gp_Ax2's XDirection and YDirection.
let truth: [(String, SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)] = [
    ("+X", SIMD3(1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, -1, 0)),
    ("-X", SIMD3(-1, 0, 0), SIMD3(0, 0, -1), SIMD3(0, -1, 0)),
    ("+Y", SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(1, 0, 0)),
    ("-Y", SIMD3(0, -1, 0), SIMD3(0, 0, -1), SIMD3(1, 0, 0)),
    ("+Z", SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0)),
    ("-Z", SIMD3(0, 0, -1), SIMD3(-1, 0, 0), SIMD3(0, 1, 0)),
    (
        "(1,2,3)", SIMD3(1, 2, 3),
        SIMD3(1.1390805436183623e-17, 0.83205029433784383, -0.55470019622522915),
        SIMD3(-0.96362411165943163, 0.14824986333222026, 0.22237479499833041)
    ),
    (
        "(1,1,1)", SIMD3(1, 1, 1),
        SIMD3(0.70710678118654757, 1.1097163582100281e-17, -0.70710678118654757),
        SIMD3(-0.40824829046386313, 0.81649658092772615, -0.40824829046386307)
    ),
    (
        "(0,1,1)", SIMD3(0, 1, 1),
        SIMD3(0, 0.70710678118654757, -0.70710678118654757),
        SIMD3(-1, 0, 0)
    ),
]

func fmt(_ v: SIMD3<Double>) -> String {
    String(format: "(%+.4f,%+.4f,%+.4f)", v.x, v.y, v.z)
}

func angleDegrees(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    acos(max(-1, min(1, simd_dot(a, b)))) * 180 / .pi
}

print("=== step 1: the copy of perpendicularBasis(to:) against gp_Ax2 ground truth ===")
var copyFaithful = true
for (name, axis, gpX, gpY) in truth {
    let (right, up) = perpendicularBasis(to: axis)
    let dRight = simd_length(right - gpX)
    let dUp = simd_length(up - gpY)
    if dRight > 1e-12 || dUp > 1e-12 { copyFaithful = false }
    print(
        "\(name.padding(toLength: 9, withPad: " ", startingAt: 0))"
            + " |right - gp_Ax2.X| = \(String(format: "%.3e", dRight))"
            + "   |up - gp_Ax2.Y| = \(String(format: "%.3e", dUp))")
}
print(copyFaithful ? "copy matches gp_Ax2 on every axis" : "COPY HAS DRIFTED, stop here")

print("")
print("=== step 2: orthonormalRadial against each element ===")
for (name, axis, _, _) in truth {
    let o = orthonormalRadial(axis: axis)
    let (right, up) = perpendicularBasis(to: axis)
    print(
        "\(name.padding(toLength: 9, withPad: " ", startingAt: 0))"
            + " orth=\(fmt(o)) right=\(fmt(right)) up=\(fmt(up))"
            + String(
                format: "  angle(orth,right)=%7.3f  angle(orth,up)=%7.3f",
                angleDegrees(o, right), angleDegrees(o, up)))
}

print("")
print("=== step 3: how often each element coincides, over a 200x200 sphere sample ===")
var agreeUp = 0
var agreeRight = 0
var total = 0
for i in 0..<200 {
    for j in 0..<200 {
        let theta = Double(i) * .pi / 199.0
        let phi = Double(j) * 2 * .pi / 200.0
        let a = SIMD3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))
        if simd_length(a) < 1e-12 { continue }
        let o = orthonormalRadial(axis: a)
        let (right, up) = perpendicularBasis(to: a)
        total += 1
        if simd_length(o - up) < 1e-9 { agreeUp += 1 }
        if simd_length(o - right) < 1e-9 { agreeRight += 1 }
    }
}
print("total=\(total)  orth == up: \(agreeUp)  orth == right: \(agreeRight)")
print("")
print("This last count is NOT the criterion. Agreement on an arbitrary axis is a coincidence of")
print("the two constructions' branch boundaries; what decides the element is which one leaves the")
print("clocking of the axes real callers pass (+Z above all) where it already shipped.")
