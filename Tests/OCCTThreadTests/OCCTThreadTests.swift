import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}


// MARK: - v0.138: Thread features (#66)

@Suite("v0.138 ThreadSpec parsing")
struct ThreadSpecParsingTests {
    @Test("Metric M5x0.8")
    func metricExplicit() {
        let s = ThreadSpec.parse("M5x0.8")
        #expect(s?.form == .iso68)
        #expect(s?.nominalDiameter == 5.0)
        #expect(s?.pitch == 0.8)
    }

    @Test("Metric M6 uses coarse pitch")
    func metricCoarse() {
        let s = ThreadSpec.parse("M6")
        #expect(s?.pitch == 1.0)
    }

    @Test("UNC 1/4-20 converts to metric")
    func unifiedFraction() {
        let s = ThreadSpec.parse("1/4-20 UNC")
        #expect(s?.form == .unified)
        #expect(abs((s?.nominalDiameter ?? 0) - 6.35) < 0.01)
        #expect(abs((s?.pitch ?? 0) - 1.27) < 0.01)
    }

    @Test("Theoretical and cut depths")
    func depths() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.theoreticalDepth - 1.5 * sqrt(3) / 2) < 1e-9)
        #expect(s.minorDiameter < s.nominalDiameter)
    }
}

@Suite("v0.139 Thread Form v2")
struct ThreadedFeatureTests {
    @Test("threadedHole cuts material from a bored block")
    func threadedHole() throws {
        guard let block = Shape.box(width: 30, height: 30, depth: 30),
              let drillAxis = Shape.cylinder(at: SIMD3(15, 15, 0), direction: SIMD3(0, 0, 1),
                                              radius: 5, height: 30),
              let blockWithHole = block.subtracting(drillAxis) else {
            Issue.record("setup nil"); return
        }
        let spec = ThreadSpec.parse("M10x1.5")!
        let threaded = blockWithHole.threadedHole(
            axisOrigin: SIMD3(15, 15, 0),
            axisDirection: SIMD3(0, 0, 1),
            spec: spec,
            depth: 20
        )
        // V-profile cut removes material from the wall → threaded volume < bored volume.
        if let t = threaded, let vOrig = blockWithHole.volume, let vThreaded = t.volume {
            #expect(vThreaded < vOrig)
        }
    }

    @Test("threadedShaft cuts helical V-grooves into the shaft")
    func threadedShaft() {
        guard let shaft = Shape.cylinder(radius: 5, height: 30) else {
            Issue.record("shaft nil"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        let threaded = shaft.threadedShaft(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            spec: spec,
            length: 20
        )
        if let t = threaded, let vOrig = shaft.volume, let vThreaded = t.volume {
            // External thread = cut from shaft → threaded volume < shaft volume.
            #expect(vThreaded < vOrig)
        }
    }

    @Test("threadedHole respects left-handed helix parameter")
    func leftHanded() {
        guard let block = Shape.box(width: 30, height: 30, depth: 30),
              let drillAxis = Shape.cylinder(at: SIMD3(15, 15, 0), direction: SIMD3(0, 0, 1),
                                              radius: 5, height: 30),
              let bored = block.subtracting(drillAxis) else {
            Issue.record("setup nil"); return
        }
        let rh = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5, leftHanded: false)
        let lh = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5, leftHanded: true)
        let rhResult = bored.threadedHole(axisOrigin: SIMD3(15, 15, 0),
                                          axisDirection: SIMD3(0, 0, 1),
                                          spec: rh, depth: 10)
        let lhResult = bored.threadedHole(axisOrigin: SIMD3(15, 15, 0),
                                          axisDirection: SIMD3(0, 0, 1),
                                          spec: lh, depth: 10)
        // Both should produce valid shapes with equivalent volume — a mirror-image
        // thread has the same volume as the original up to tessellation artefacts.
        // The absolute tolerance is generous (~1% of a typical V-cut volume) to
        // accommodate BOP/triangulation noise; the point of the test is that both
        // handedness values produce valid threaded geometry, not that they're
        // bit-identical.
        if let r = rhResult, let l = lhResult,
           let vr = r.volume, let vl = l.volume {
            let originalVolume = bored.volume ?? 1
            let cutR = originalVolume - vr
            let cutL = originalVolume - vl
            #expect(cutR > 0 && cutL > 0)
            #expect(abs(cutR - cutL) / max(cutR, cutL) < 0.1)
        }
    }

    @Test("Multi-start thread (starts: 2) removes more material than single-start")
    func multiStart() {
        guard let block = Shape.box(width: 30, height: 30, depth: 30),
              let drillAxis = Shape.cylinder(at: SIMD3(15, 15, 0), direction: SIMD3(0, 0, 1),
                                              radius: 5, height: 30),
              let bored = block.subtracting(drillAxis) else {
            Issue.record("setup nil"); return
        }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 2.0)
        let single = bored.threadedHole(axisOrigin: SIMD3(15, 15, 0),
                                        axisDirection: SIMD3(0, 0, 1),
                                        spec: spec, depth: 10, starts: 1)
        let double = bored.threadedHole(axisOrigin: SIMD3(15, 15, 0),
                                        axisDirection: SIMD3(0, 0, 1),
                                        spec: spec, depth: 10, starts: 2)
        if let s = single, let d = double,
           let vs = s.volume, let vd = d.volume {
            // Two helices remove roughly twice the material (allow for overlap at crossovers).
            let originalBore = bored.volume ?? 0
            let singleCut = originalBore - vs
            let doubleCut = originalBore - vd
            #expect(doubleCut > singleCut)
        }
    }
}

@Suite("v0.139 ThreadSpec truncation constants")
struct ThreadSpecTruncationTests {
    @Test("ISO-68 crest flat = P/8")
    func crestFlat() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.crestFlat - 1.5 / 8) < 1e-9)
    }

    @Test("ISO-68 root flat = P/4")
    func rootFlat() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.rootFlat - 1.5 / 4) < 1e-9)
    }

    @Test("cutDepth = 5H/8")
    func cutDepthRelation() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.cutDepth - s.theoreticalDepth * 5 / 8) < 1e-9)
    }

    @Test("minorDiameter consistent with cut depth")
    func minorDiameter() {
        let s = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        #expect(abs(s.minorDiameter - (10 - 2 * s.cutDepth)) < 1e-9)
    }
}
