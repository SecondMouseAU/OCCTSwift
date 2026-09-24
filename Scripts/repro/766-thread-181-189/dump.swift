import Foundation
import Testing
import simd

@testable import OCCTSwift

// Capture harness for the #1990 parity records of the #181-#222 thread suites. Not part of any
// target: copy it into Tests/OCCTThreadTests/ and run `swift test --filter ZZ766DumpC` to
// reproduce. It prints the values the tests observe (the BRIDGE rows of transcript.txt) and
// writes each shape to BREP (no triangles, written before any measurement) for probe.mm.
// dumpDir is the session scratch directory it was run from; point it anywhere writable.
private let dumpDir = FileManager.default.temporaryDirectory.appendingPathComponent("OCCTSwift_766_Thread_C_breps").path

private func out(_ s: String) { print("DUMP " + s) }

private func save(_ s: Shape?, _ name: String) {
    guard let s else { out("\(name) nil"); return }
    try? FileManager.default.createDirectory(atPath: dumpDir, withIntermediateDirectories: true)
    do {
        try s.writeBREP(to: URL(fileURLWithPath: dumpDir + name + ".brep"), withTriangles: false, allowInvalid: true)
    } catch { out("\(name) brepfail \(error)") }
}

private func f(_ d: Double?) -> String { d.map { String(format: "%.9g", $0) } ?? "nil" }
private func bb(_ b: (min: SIMD3<Double>, max: SIMD3<Double>)?) -> String {
    guard let b else { return "nil" }
    return [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z].map { String(format: "%.9g", $0) }.joined(separator: ",")
}

private func measure(_ s: Shape?, _ name: String) {
    save(s, name)
    guard let s else { return }
    out("\(name) valid=\(s.isValid) vol=\(f(s.volume)) faces=\(s.subShapes(ofType: .face).count) opt=\(bb(s.boundingBoxOptimal())) bounds=\(bb(s.bounds))")
}

@Suite("ZZ766 dump C") struct ZZ766DumpC {
    @Test func dump() throws {
        // 181-C
        let blank181 = Shape.cylinder(radius: 6, height: 18)
        measure(blank181, "181_blank")
        for p in [1.0, 1.75, 2.0, 3.14159] {
            let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: p)
            measure(blank181?.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, length: 16), "181_p\(p)")
        }
        // 181-B
        let box = Shape.box(width: 4, height: 3, depth: 2)!
        let url = URL(fileURLWithPath: dumpDir + "181_box.step")
        try box.writeSTEP(to: url)
        out("181_step size=\((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1)")
        // 185
        let rib = Wire.polygon3D([SIMD3(3.7, 0, -1.26), SIMD3(6.0, 0, -0.63), SIMD3(6.0, 0, 0.63), SIMD3(3.7, 0, 1.26)], closed: true)!
        for cw in [false, true] {
            measure(Shape.helicalSweep(profile: rib, axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), radius: 5, pitch: .pi, turns: 4.77, clockwise: cw), "185_cw\(cw)")
        }
        out("185_guard_empty=\(Shape.helicalSweep(profiles: [], axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), radius: 5, pitch: .pi, turns: 2) == nil) guard_r0=\(Shape.helicalSweep(profile: rib, axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), radius: 0, pitch: .pi, turns: 2) == nil)")
        // 187 tight
        for (n, p) in [(6.0, 1.0), (8.0, 1.25), (10.0, 1.5), (12.0, 1.75), (12.0, 3.14159)] {
            let shank = Shape.cylinder(radius: n / 2, height: 22)
            measure(shank, "187_shank_\(n)_\(p)")
            measure(shank?.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: ThreadSpec(form: .iso68, nominalDiameter: n, pitch: p), length: 16, runout: .none), "187_tight_\(n)_\(p)")
        }
        // 187 deterministic
        let sh3 = Shape.cylinder(radius: 3, height: 20)!
        let s6 = ThreadSpec(form: .iso68, nominalDiameter: 6, pitch: 1.0)
        for i in 0..<2 { measure(sh3.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s6, length: 16), "187_det\(i)") }
        // 187 smooth
        measure(Shape.cylinder(radius: 6, height: 16)!.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75), length: 14), "187_smooth")
        // 187 hole
        let s12 = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
        let block = Shape.cylinder(radius: 12, height: 16)!.subtracting(Shape.cylinder(radius: s12.minorDiameter / 2, height: 16)!)!
        measure(block, "187_block")
        measure(block.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s12, depth: 14), "187_hole")
        // 189
        for (n, p) in [(6.0, 1.0), (8.0, 1.25), (10.0, 1.5), (5.0, 0.8)] {
            let shank = Shape.cylinder(radius: n / 2, height: 25)
            measure(shank, "189_shank_\(n)_\(p)")
            measure(shank?.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: ThreadSpec(form: .iso68, nominalDiameter: n, pitch: p), length: 18, runout: .none), "189_fast_\(n)_\(p)")
        }
        let wshank = Shape.cylinder(radius: 6, height: 15)!
        measure(wshank, "189_wshank")
        let wspec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 3.14159)
        out("189_worm cutDepth=\(f(wspec.cutDepth))")
        measure(wshank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: wspec, length: 15), "189_worm")
    }

    @Test func dump3() throws {
        // 196 fine: the HLR count from the BREP the probe read, and twice from fresh builds.
        let loaded = try Shape.loadBREP(from: URL(fileURLWithPath: dumpDir + "196_fine.brep"))
        out("196_fine_fromBREP edges=\(loaded.hlrPolyEdges(direction: SIMD3(1, 0, 0), category: .visibleSharp, deflection: 0.05).map { String($0.subShapes(ofType: .edge).count) } ?? "nil")")
        let sh = Shape.cylinder(radius: 5, height: 50)!
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.0)
        for i in 0..<2 {
            let t = sh.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s, length: 26, runout: .none)
            out("196_fine_fresh\(i) edges=\(t?.hlrPolyEdges(direction: SIMD3(1, 0, 0), category: .visibleSharp, deflection: 0.05).map { String($0.subShapes(ofType: .edge).count) } ?? "nil")")
        }
    }

    @Test func dump2() throws {
        // 193
        let sh = Shape.cylinder(radius: 5, height: 50)!
        measure(sh, "193_shank")
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.0)
        for L in [26.0, 40.0, 49.0] { measure(sh.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s, length: L, runout: .none), "193_long_\(L)") }
        measure(Shape.cylinder(radius: 5, height: 30)!.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s, length: 16, runout: .none), "193_short")
        // 196
        for (tag, d) in [("def", 0.1), ("fine", 0.05), ("coarse", 0.8)] {
            let t = sh.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s, length: 26, runout: .none)
            save(t, "196_\(tag)")
            let e = t?.hlrPolyEdges(direction: SIMD3(1, 0, 0), category: .visibleSharp, deflection: d)
            out("196_\(tag) defl=\(d) edges=\(e.map { String($0.subShapes(ofType: .edge).count) } ?? "nil")")
        }
        // 213
        let shaft = Shape.cylinder(radius: 5, height: 20)!
        measure(shaft, "213_shaft")
        let s15 = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        measure(shaft.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s15, length: 16), "213_thread")
        out("213 rootFlat=\(f(s15.rootFlat)) cutDepth=\(f(s15.cutDepth)) half=\(f(s15.halfFlankAngle))")
        // 219
        let su = ThreadSpec(form: .unified, nominalDiameter: 9.525, pitch: 25.4 / 16)
        let body0 = Shape.cylinder(radius: 8, height: 9)!.subtracting(Shape.cylinder(at: SIMD3(0, 0, -1), direction: SIMD3(0, 0, 1), radius: su.minorDiameter / 2, height: 11)!)!
        measure(body0, "219_body")
        measure(body0.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: su, depth: 9), "219_tapped")
        // 222
        let rod = Shape.cylinder(radius: 6, height: 40)!
        measure(rod, "222_rod")
        for (tag, sp) in [("iso", ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)), ("trap", ThreadSpec(form: .trapezoidal, nominalDiameter: 12, pitch: 3.0))] {
            let t = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: sp, length: 40, build: .direct)
            measure(t, "222_\(tag)")
            if let t { out("222_\(tag) meshcrest=\(f(meshMaxRadialExtent(t, deflection: 0.05)))") }
        }
        let rod5 = Shape.cylinder(radius: 5, height: 20)!
        measure(rod5.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: s15, length: 20), "222_auto")
    }
}
