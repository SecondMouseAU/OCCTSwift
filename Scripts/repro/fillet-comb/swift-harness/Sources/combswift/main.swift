import Foundation
import OCCTSwift

// combswift <file.brep> <op> <args...>   one case, through the public API (the #3200 guard included).
//   fillet R e,e,...            Shape.filleted(edges:radius:)
//   fillet_all R                Shape.filleted(radius:)
//   chamfer_all D               Shape.chamfered(distance:)
//   chamfer2m e:f:d1:d2 ...     Shape.chamferedTwoDistances
//   chamferda e:f:d:angle ...   Shape.chamferedDistAngle
// Edge and face numbers are the 0-based indices `cprobe list` prints. Output: one RESULT line, nil or the shape's numbers.
let args = CommandLine.arguments
guard args.count >= 3, let shape = try? Shape.loadBREP(from: URL(fileURLWithPath: args[1])) else {
    print("RESULT swift=LOADFAIL")
    exit(0)
}
let op = args[2]
var result: Shape? = nil
switch op {
case "fillet":
    let r = Double(args[3])!
    // in the order given: the order the edges are added is part of the case (see order_check.py)
    let all = shape.edges()
    let edges = args[4].split(separator: ",").map { all[Int($0)!] }
    result = shape.filleted(edges: edges, radius: r)
case "fillet_all":
    result = shape.filleted(radius: Double(args[3])!)
case "chamfer_all":
    result = shape.chamfered(distance: Double(args[3])!)
case "chamfer2m":
    let t = args[3...].map { $0.split(separator: ":").map { Double($0)! } }
    result = shape.chamferedTwoDistances(t.map { (edgeIndex: Int($0[0]), faceIndex: Int($0[1]), dist1: $0[2], dist2: $0[3]) })
case "chamferda":
    let t = args[3...].map { $0.split(separator: ":").map { Double($0)! } }
    result = shape.chamferedDistAngle(t.map { (edgeIndex: Int($0[0]), faceIndex: Int($0[1]), distance: $0[2], angleDegrees: $0[3]) })
default:
    print("RESULT swift=BADOP")
    exit(0)
}
if let r = result {
    print("RESULT swift=shape valid=\(r.isValid ? 1 : 0) vol=\(r.volume ?? -1) faces=\(r.faces().count)")
} else {
    print("RESULT swift=nil")
}
