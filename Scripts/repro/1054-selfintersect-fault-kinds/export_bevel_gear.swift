// #1068's fixture, exported so the C++ probes can load it without rebuilding it each run.
//
// Not part of any package target. Drop it into a throwaway SwiftPM executable that depends on
// SecondMouseAU/OCCTParts (platforms: [.macOS(.v15)], products PartsGears and PartsCore) and run
// it once. Measured against OCCTParts at the OCCTSwift 3.0.0 pin: 82 s to build, volume
// 19272.592112059167, 1 solid, 1339 faces, 3938 edges, which matches the volume #1068 quotes.
//
//   swift run gearexport /tmp/bevel_gear_1068.brep
import Foundation
import OCCTSwift
import PartsGears

let params = BevelGear.Parameters(
    teeth: 36,
    mateTeeth: 36,
    circularPitch: 5,
    spiralAngle: .degrees(0),
    cutterRadius: .automatic,
    slices: 5,
    shaftDiameter: 5)

let start = Date()
let body = try BevelGear.build(params)
print("built in \(Date().timeIntervalSince(start))s")
print("volume = \(body.shape.volume ?? -1)")
print("solids = \(body.shape.subShapeCount(ofType: .solid))")
print("faces  = \(body.shape.faceCount)")
print("edges  = \(body.shape.edgeCount)")

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "bevel_gear_1068.brep"
// withTriangles: false keeps the file to the B-Rep itself, which is all the probes read.
try body.shape.writeBREP(to: URL(fileURLWithPath: out), withTriangles: false)
print("wrote \(out)")
