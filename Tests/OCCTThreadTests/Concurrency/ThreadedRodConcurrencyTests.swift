import Foundation
import Testing

@testable import OCCTSwift

@Suite("TMPSTRESS threaded rod concurrency")
struct TmpStressThreadedRodConcurrencyTests {
    static func cam(_ z: Double, pitch: Double, rMaj: Double, depth: Double) -> Wire? {
        let twoPi = 2 * Double.pi
        let al = z * twoPi / pitch
        func pt(_ r: Double, _ a: Double) -> SIMD3<Double> {
            SIMD3(r * cos(a), r * sin(a), z)
        }
        func arc(_ r: Double, _ a0: Double, _ a1: Double) -> Wire? {
            Wire.arc(start: pt(r, a0), midpoint: pt(r, (a0 + a1) / 2), end: pt(r, a1))
        }
        func flank(_ r0: Double, _ r1: Double, _ a0: Double, _ a1: Double) -> Wire? {
            var pts: [SIMD3<Double>] = []
            for i in 0...8 {
                let f = Double(i) / 8
                pts.append(pt(r0 + (r1 - r0) * f, a0 + (a1 - a0) * f))
            }
            return Wire.interpolate(through: pts)
        }
        let rRoot = rMaj - depth
        guard let w0 = arc(rMaj, al, al + 0.125 * twoPi),
            let w1 = flank(rMaj, rRoot, al + 0.125 * twoPi, al + 0.4375 * twoPi),
            let w2 = arc(rRoot, al + 0.4375 * twoPi, al + 0.6875 * twoPi),
            let w3 = flank(rRoot, rMaj, al + 0.6875 * twoPi, al + twoPi)
        else { return nil }
        return Wire.join([w0, w1, w2, w3])
    }

    static func work(_ mode: String, _ i: Int) -> Int {
        let pitches = [1.0, 1.25, 1.5, 1.75, 0.8, 2.0]
        let pitch = pitches[i % pitches.count]
        var n = 0
        for _ in 0..<4 {
            switch mode {
            case "full":
                guard let blank = Shape.cylinder(radius: 6, height: 18) else { continue }
                let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: pitch)
                if blank.threadedShaft(
                    axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, length: 16) != nil
                {
                    n += 1
                }
            case "wires":
                for k in 0..<40 {
                    if cam(Double(k) * 0.1, pitch: pitch, rMaj: 6, depth: 0.6 * pitch) != nil {
                        n += 1
                    }
                }
            case "loft":
                var ws: [Wire] = []
                for k in 0...100 {
                    if let w = cam(Double(k) * 0.16, pitch: pitch, rMaj: 6, depth: 0.6 * pitch) {
                        ws.append(w)
                    }
                }
                if Shape.loft(profiles: ws, solid: false, ruled: false) != nil { n += 1 }
            case "face":
                for k in 0..<20 {
                    if let w = cam(Double(k) * 0.1, pitch: pitch, rMaj: 6, depth: 0.6 * pitch),
                        Shape.face(from: w, planar: true) != nil
                    {
                        n += 1
                    }
                }
            case "cyl":
                for k in 0..<20 {
                    if Shape.faceFromCylinder(
                        origin: SIMD3(0, 0, Double(k)), axis: SIMD3(0, 0, 1), radius: 6,
                        uRange: 0...(2 * Double.pi), vRange: 0...2) != nil
                    {
                        n += 1
                    }
                }
            case "props":
                for _ in 0..<20 {
                    guard let blank = Shape.cylinder(radius: 6, height: 18) else { continue }
                    if blank.bounds != nil, blank.volume != nil, blank.isValid { n += 1 }
                }
            case "sew":
                for _ in 0..<3 {
                    guard let bx = Shape.box(width: 4, height: 3, depth: 2) else { continue }
                    let faces = bx.subShapes(ofType: .face)
                    if let shell = Shape.sew(shapes: faces, tolerance: 1e-6),
                        let solid = Shape.solidFromShell(shell)
                    {
                        _ = solid.orientClosedSolid()
                        n += 1
                    }
                }
            default:
                break
            }
        }
        return n
    }

    @Test("TMPSTRESS concurrent threadedShaft")
    func stress() async {
        let env = ProcessInfo.processInfo.environment
        let mode = env["TMPSTRESS_MODE"] ?? "full"
        let serial = env["TMPSTRESS_SERIAL"] != nil
        let tasks = Int(env["TMPSTRESS_TASKS"] ?? "24") ?? 24
        if serial {
            var total = 0
            for i in 0..<tasks { total += Self.work(mode, i) }
            #expect(total > 0)
            return
        }
        let built = await withTaskGroup(of: Int.self) { group -> Int in
            for i in 0..<tasks {
                group.addTask { Self.work(mode, i) }
            }
            var total = 0
            for await n in group { total += n }
            return total
        }
        #expect(built > 0)
    }
}
