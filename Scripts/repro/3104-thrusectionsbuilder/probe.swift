import Foundation
import OCCTSwift
import simd
// probe <order> <nWires> <solid> <ruled> <opts>
// order: letters; W=addWire, V=addVertex (applied in sequence, W uses next wire). e.g. "VWW"
// opts: comma list of smooth0|smooth1|deg|cont|compat0|compat1|par|weight|twice|build0|nil
let a = CommandLine.arguments
let order = a[1]; let solid = a[2] == "1"; let ruled = a[3] == "1"
let opts = a.count > 4 ? a[4].split(separator: ",").map(String.init) : []
func sq(_ z: Double) -> Shape {
    let w = Wire.polygon3D([SIMD3(-2,-2,z), SIMD3(2,-2,z), SIMD3(2,2,z), SIMD3(-2,2,z)])!
    return Shape.fromWire(w)!
}
let b = ThruSectionsBuilder(isSolid: solid, isRuled: ruled)
if opts.contains("smooth1") { b.setSmoothing(true) }
if opts.contains("smooth0") { b.setSmoothing(false) }
if opts.contains("deg") { b.setMaxDegree(3) }
if opts.contains("cont") { b.setContinuity(2) }
if opts.contains("compat0") { b.checkCompatibility(false) }
if opts.contains("compat1") { b.checkCompatibility(true) }
if opts.contains("par") { b.setParType(1) }
if opts.contains("weight") { b.setCriteriumWeight(w1: 1, w2: 1, w3: 1) }
var z = 0.0
for c in order {
    if c == "W" { b.addWire(sq(z)); z += 3 }
    else if c == "V" { b.addVertex(Shape.vertex(at: SIMD3(0, 0, z))!); z += 3 }
}
if opts.contains("build0") { print("shape-before-build=\(b.shape == nil ? "nil" : "shape")") }
func report(_ tag: String) {
    let ok = b.build()
    if let s = b.shape { print("\(tag) build=\(ok) shape valid=\(s.isValid)") }
    else { print("\(tag) build=\(ok) shape=nil") }
}
report("first")
if opts.contains("twice") { report("second") }
