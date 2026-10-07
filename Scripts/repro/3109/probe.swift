// #3109 probe: one process per (builder, angle). Usage: probe <builder> <angle>
// Built by temporarily replacing Sources/OCCTTest/main.swift (see run.sh); never committed there.
import Foundation
import OCCTSwift

let args = CommandLine.arguments
guard args.count == 3, let angle = Double(args[2]) else {
    print("usage: probe <builder> <angle>"); exit(2)
}
let z = SIMD3<Double>(0, 0, 1)
let profileWire = Wire.polygon3D([SIMD3(2, 0, 0), SIMD3(4, 0, 0), SIMD3(4, 0, 5), SIMD3(2, 0, 5)])!
let face = Shape.face(from: Wire.rectangle(width: 2, height: 2)!)!
let base = Shape.box(width: 20, height: 20, depth: 20)!
let rib = Wire.polygon3D([SIMD3(3, 0, 10), SIMD3(6, 0, 10), SIMD3(6, 0, 12), SIMD3(3, 0, 12)])!
let line = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10))!

func describe(_ s: Shape?) -> String {
    guard let s else { return "nil" }
    return "shape valid=\(s.isValid) volume=\(s.volume ?? -1)"
}
let start = Date()
var out = ""
switch args[1] {
case "revolve": out = describe(Shape.revolve(profile: profileWire, axisOrigin: .zero, axisDirection: z, angle: angle))
case "revolved": out = describe(face.revolved(axisOrigin: SIMD3(30, 0, 0), axisDirection: z, angle: angle))
case "revolution": out = describe(Shape.revolution(meridian: line, angle: angle))
case "feature": out = describe(base.addingRevolvedFeature(profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10), axisDirection: z, angle: angle))
case "localRevolution": out = describe(face.localRevolution(axisOrigin: SIMD3(30, 0, 0), axisDirection: z, angle: angle))
case "localRevolutionOffset": out = describe(face.localRevolution(axisOrigin: SIMD3(30, 0, 0), axisDirection: z, angle: angle, angularOffset: 0.1))
case "localRevolutionForm": out = describe(face.localRevolutionForm(axisOrigin: SIMD3(30, 0, 0), axisDirection: z, angle: angle))
default: print("unknown builder"); exit(2)
}
print("\(args[1]) angle=\(args[2]) -> \(out) in \(String(format: "%.3f", Date().timeIntervalSince(start)))s")
