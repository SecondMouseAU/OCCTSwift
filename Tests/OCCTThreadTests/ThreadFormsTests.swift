import Testing
import Foundation
import simd
@testable import OCCTSwift

// Thread forms beyond ISO/Unified + custom profiles (the v1.6 thread-forms feature).
@Suite("Thread forms — Whitworth/BSP, ACME, trapezoidal, square, buttress, knuckle, taper, custom")
struct ThreadFormsTests {

    // Piecewise-linear parallel forms that take the smooth direct external build (≤2 straight flanks,
    // flat crest). Rounded forms (knuckle) route to the faceted cut path instead — see roundedExternalForm.
    static let smoothForms: [ThreadForm] = [
        .iso68, .unified, .whitworth, .bspParallel, .acme, .trapezoidal, .square, .buttress,
    ]

    @Test("each piecewise-linear form builds a valid, smooth external thread",
          arguments: ThreadFormsTests.smoothForms)
    func externalForm(_ form: ThreadForm) {
        guard let shank = Shape.cylinder(radius: 6, height: 24) else { Issue.record("shank"); return }
        let spec = ThreadSpec(form: form, nominalDiameter: 12, pitch: 2.0)
        guard let t = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                          spec: spec, length: 18) else {
            Issue.record("\(form) returned nil"); return
        }
        #expect(t.isValid)
        // Crest sits at the nominal radius. The optimal Bnd_Box pole-inflates for these BSpline thread
        // surfaces (OCCTSwift #213), so measure the actual meshed surface envelope instead.
        if let mesh = t.mesh(linearDeflection: 0.05) {
            var maxR = Float(0)
            for v in mesh.vertices {
                let r = (v.x * v.x + v.y * v.y).squareRoot()
                if r > maxR { maxR = r }
            }
            #expect(maxR <= 6.0 + 0.1)
        }
        if let v0 = shank.volume, let v1 = t.volume {
            #expect(v1 < v0)            // removed a thread's worth of material
            #expect(v1 > v0 * 0.5)      // but the rod is still substantially there
        }
        // Smooth: a handful of faces, not hundreds of facets.
        #expect(t.subShapes(ofType: .face).count < 40)
    }

    @Test("rounded forms (knuckle) build a valid external thread via the faceted cut path")
    func roundedExternalForm() {
        guard let shank = Shape.cylinder(radius: 6, height: 24) else { Issue.record("shank"); return }
        let spec = ThreadSpec(form: .knuckle, nominalDiameter: 12, pitch: 2.0)
        guard let t = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                          spec: spec, length: 18) else {
            Issue.record("knuckle returned nil"); return
        }
        #expect(t.isValid)
        // The faceted cut path keeps the crest exactly at the nominal radius (no ruled:false bulge).
        if let mesh = t.mesh(linearDeflection: 0.05) {
            var maxR = Float(0)
            for v in mesh.vertices {
                let r = (v.x * v.x + v.y * v.y).squareRoot()
                if r > maxR { maxR = r }
            }
            #expect(maxR <= 6.0 + 0.05)
        }
        if let v0 = shank.volume, let v1 = t.volume { #expect(v1 < v0); #expect(v1 > v0 * 0.5) }
    }

    @Test("each form builds a valid internal thread (cut path)",
          arguments: [ThreadForm.iso68, .whitworth, .acme, .square, .buttress, .knuckle])
    func internalForm(_ form: ThreadForm) {
        guard let outer = Shape.cylinder(radius: 12, height: 16),
              let bore = Shape.cylinder(radius: 6, height: 16),
              let block = outer.subtracting(bore) else { Issue.record("annulus"); return }
        let spec = ThreadSpec(form: form, nominalDiameter: 12, pitch: 2.0)
        guard let t = block.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, depth: 14) else {
            Issue.record("\(form) hole nil"); return
        }
        #expect(t.isValid)
        if let vb = block.volume, let vt = t.volume {
            #expect(vt < vb)            // tapping the bore removed some wall material
            #expect(vt > vb * 0.8)      // only the thread grooves, not most of the block
        }
    }

    @Test("tapered pipe threads (NPT, BSPT) build a valid thread",
          arguments: [ThreadForm.nptTapered, .bsptTapered])
    func taperedForm(_ form: ThreadForm) {
        guard let shank = Shape.cylinder(radius: 8, height: 24) else { Issue.record("shank"); return }
        let spec = ThreadSpec(form: form, nominalDiameter: 16, pitch: 2.0)
        guard let t = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                          spec: spec, length: 20) else {
            Issue.record("\(form) nil"); return
        }
        if let v0 = shank.volume, let v1 = t.volume { #expect(v1 < v0); #expect(v1 > v0 * 0.5) }
        #expect(spec.taperRatio == 1.0 / 16)
    }

    @Test("a custom cross-section threads a cylinder")
    func customProfile() {
        guard let prof = ThreadProfile(vertices: [
            .init(axial: 0, depth: 1), .init(axial: 0.1, depth: 1),
            .init(axial: 0.5, depth: 0), .init(axial: 0.6, depth: 0),
            .init(axial: 0.9, depth: 1), .init(axial: 1, depth: 1),
        ]) else { Issue.record("profile nil"); return }
        guard let shank = Shape.cylinder(radius: 6, height: 20) else { Issue.record("shank"); return }
        let spec = ThreadSpec(customProfile: prof, nominalDiameter: 12, pitch: 2.0, cutDepth: 1.0)
        guard let t = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                          spec: spec, length: 16) else {
            Issue.record("custom nil"); return
        }
        #expect(t.isValid)
        if let v0 = shank.volume, let v1 = t.volume { #expect(v1 < v0); #expect(v1 > v0 * 0.5) }
    }

    @Test("ThreadProfile validation + JSON round-trip")
    func profileValidationAndCodable() throws {
        // invalid: doesn't span a root
        #expect(ThreadProfile(vertices: [.init(axial: 0, depth: 0), .init(axial: 1, depth: 0)]) == nil)
        // invalid: doesn't start/end at 0/1
        #expect(ThreadProfile(vertices: [.init(axial: 0.1, depth: 1), .init(axial: 0.9, depth: 0)]) == nil)
        let prof = ThreadProfile.acme29
        let data = try JSONEncoder().encode(prof)
        let back = try JSONDecoder().decode(ThreadProfile.self, from: data)
        #expect(back == prof)
    }

    @Test("form geometry: cutDepth + segment shape")
    func formGeometry() {
        let p = 2.0
        // ISO unchanged: 5H/8
        #expect(abs(ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: p).cutDepth
                    - p * sqrt(3) / 2 * 5 / 8) < 1e-9)
        #expect(abs(ThreadSpec(form: .acme, nominalDiameter: 12, pitch: p).cutDepth - 0.5 * p) < 1e-9)
        #expect(abs(ThreadSpec(form: .whitworth, nominalDiameter: 12, pitch: p).cutDepth - 0.640327 * p) < 1e-6)
        #expect(ThreadProfile.whitworth55.hasCrestFlat)   // small land kept for the smooth build
        // DIN 513 buttress: depth 0.86777·P → core d3 = d − 2·0.86777·P (matches the standard table:
        // S 10 × 2 → d3 = 6.528).
        let din513 = ThreadSpec(form: .buttress, nominalDiameter: 10, pitch: 2.0)
        #expect(abs(din513.cutDepth - 0.86777 * 2.0) < 1e-9)
        #expect(abs(din513.minorDiameter - 6.528) < 2e-3)
        // DIN 405 knuckle: depth 0.55·P → minor d3 = d − 1.1·P (matches the standard table:
        // Rd 8 × 1/10", d = 8.254, P = 2.540 → d3 = 5.460).
        let din405 = ThreadSpec(form: .knuckle, nominalDiameter: 8.254, pitch: 2.540)
        #expect(abs(din405.cutDepth - 0.55 * 2.540) < 1e-9)
        #expect(abs(din405.minorDiameter - 5.460) < 1e-3)
        #expect(ThreadProfile.knuckle.hasCrestFlat)   // small land kept for the smooth build
        // square has two radial walls
        #expect(ThreadProfile.square.segments.filter { $0.kind == .wall }.count == 2)
        // iso V has a crest flat
        #expect(ThreadProfile.iso60V().hasCrestFlat)
    }

    @Test("parser recognises the new designations")
    func parserForms() {
        #expect(ThreadSpec.parse("Tr40x7")?.form == .trapezoidal)
        if let tr = ThreadSpec.parse("Tr40x7") { #expect(tr.nominalDiameter == 40); #expect(tr.pitch == 7) }
        #expect(ThreadSpec.parse("Tr40x7LH")?.leftHanded == true)
        #expect(ThreadSpec.parse("1.5-4 ACME")?.form == .acme)
        if let a = ThreadSpec.parse("1.5-4 ACME") {
            #expect(abs(a.nominalDiameter - 1.5 * 25.4) < 1e-6); #expect(abs(a.pitch - 25.4 / 4) < 1e-6)
        }
        #expect(ThreadSpec.parse("G1/2")?.form == .bspParallel)
        #expect(ThreadSpec.parse("R1/2")?.form == .bsptTapered)
        #expect(ThreadSpec.parse("Rc3/4")?.form == .bsptTapered)
        #expect(ThreadSpec.parse("W1/2")?.form == .whitworth)
        #expect(ThreadSpec.parse("1/2-14 NPT")?.form == .nptTapered)
        // existing designations still work
        #expect(ThreadSpec.parse("M10x1.5")?.form == .iso68)
        #expect(ThreadSpec.parse("1/4-20 UNC")?.form == .unified)
    }
}
