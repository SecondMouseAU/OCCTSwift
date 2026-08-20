import Foundation
import Testing
import simd

@testable import OCCTSwift

// #989: `ThreadSpec.parse(_:)` fans out to six private parse methods. The two that read an
// imperial `"<diameter>-<threads per inch>"` designation, `parseAcme` and `parseUnified`, were the
// same parse written twice, down to the `* 25.4` and `25.4 / tpi` conversions; they now share
// `parseInchDesignation(_:form:)`, and the five `25.4` literals across the file are one
// `mmPerInch`.
//
// The expected millimetre values below come from each standard (an inch is 25.4 mm, a pitch is
// 25.4 / TPI, the BSP/BSW/NPT outside diameters are the table entries), not from running the
// parser. The table covers all six parse methods, not just the two that changed, because the
// pre-existing coverage checks `form` alone for most of these designations and would not notice a
// diameter or a pitch moving.
@Suite("Issue #989: thread designation parsing")
struct Issue989ThreadDesignationParseTests {

    struct Expected {
        let text: String
        let form: ThreadForm
        let diameter: Double
        let pitch: Double
        let leftHanded: Bool
        init(
            _ text: String, _ form: ThreadForm, _ diameter: Double, _ pitch: Double,
            leftHanded: Bool = false
        ) {
            self.text = text
            self.form = form
            self.diameter = diameter
            self.pitch = pitch
            self.leftHanded = leftHanded
        }
    }

    static let designations: [Expected] = [
        // metric, explicit and coarse-table pitch
        Expected("M5x0.8", .iso68, 5, 0.8),
        Expected("M6", .iso68, 6, 1.0),
        Expected("M12", .iso68, 12, 1.75),
        // ISO trapezoidal, both hands
        Expected("Tr40x7", .trapezoidal, 40, 7),
        Expected("Tr40x7LH", .trapezoidal, 40, 7, leftHanded: true),
        // imperial diameter and TPI: the two forms that now share one parse
        Expected("1.5-4 ACME", .acme, 1.5 * 25.4, 25.4 / 4),
        Expected("1/4-20 UNC", .unified, 0.25 * 25.4, 25.4 / 20),
        Expected("3/8-16", .unified, 0.375 * 25.4, 25.4 / 16),
        // BSP parallel and taper (BS 2779 outside diameters)
        Expected("G1/2", .bspParallel, 20.955, 25.4 / 14),
        Expected("R1/2", .bsptTapered, 20.955, 25.4 / 14),
        Expected("Rc3/4", .bsptTapered, 26.441, 25.4 / 14),
        // Whitworth, by prefix and by suffix (BS 84)
        Expected("W1/2", .whitworth, 12.7, 25.4 / 12),
        Expected("1/2 BSW", .whitworth, 12.7, 25.4 / 12),
        // NPT (ANSI B1.20.1)
        Expected("1/2-14 NPT", .nptTapered, 21.336, 25.4 / 14),
    ]

    @Test("every recognised designation keeps its form, diameter and pitch")
    func designationsParse() {
        for want in Self.designations {
            guard let got = ThreadSpec.parse(want.text) else {
                Issue.record("\(want.text): parse returned nil")
                continue
            }
            #expect(got.form == want.form, "\(want.text): form \(got.form)")
            #expect(
                abs(got.nominalDiameter - want.diameter) < 1e-9,
                "\(want.text): diameter \(got.nominalDiameter) != \(want.diameter)")
            #expect(
                abs(got.pitch - want.pitch) < 1e-9,
                "\(want.text): pitch \(got.pitch) != \(want.pitch)")
            #expect(got.leftHanded == want.leftHanded, "\(want.text): handedness")
        }
    }

    /// The property that makes one shared parse legitimate: ACME and Unified differ only in the
    /// suffix each method strips and the form it stamps on the result. A fix applied to one and
    /// not the other would show up here.
    @Test("the same imperial body parses identically as ACME and as Unified")
    func acmeAndUnifiedAgreeOnTheSameBody() {
        for body in ["1.5-4", "1/4-20", "3/8-16", "1-8"] {
            let acme = ThreadSpec.parse("\(body) ACME")
            let unified = ThreadSpec.parse(body)
            guard let acme, let unified else {
                Issue.record("\(body): ACME \(acme == nil ? "nil" : "ok"), Unified \(unified == nil ? "nil" : "ok")")
                continue
            }
            #expect(acme.form == .acme)
            #expect(unified.form == .unified)
            #expect(acme.nominalDiameter == unified.nominalDiameter, "\(body): diameter")
            #expect(acme.pitch == unified.pitch, "\(body): pitch")
        }
    }

    @Test(
        "unrecognised input is refused rather than guessed at",
        arguments: [
            "", "   ", "junk", "M", "Mx", "Tr40", "Tr40x", "TrLH",
            "G9/16",  // a size no BSP table has
            "1/4-0",  // zero threads per inch
            "1/4-",  // no thread count
            "1/4-abc",
            "-20",  // no diameter
        ])
    func unrecognisedInputIsRefused(_ text: String) {
        #expect(ThreadSpec.parse(text) == nil, "\(text) parsed to \(String(describing: ThreadSpec.parse(text)))")
    }

    /// Two measured facts about `parse` that this refactor did not set out to change, pinned so
    /// that a later change to either is a deliberate one.
    ///
    /// The first is a widening #989 did cause: `parseAcme` used to require the whole tail after
    /// the hyphen to be the thread count, and now reads to the first space, because that is what
    /// `parseUnified` has to do for `"1/4-20 UNC"` and the two share a parse. The only inputs that
    /// changed answer are malformed ones with a stray token, like `"1.5-4 x ACME"`.
    ///
    /// The second is untouched drift between two parse methods that #989 did not merge: the metric
    /// designation splits on a lowercase `x` only, while the trapezoidal one lowercases first, so
    /// `"Tr40X7"` is accepted and `"M10X1.5"` is not. Recorded as measured, not as desired.
    @Test("measured edge behaviour, pinned")
    func measuredEdgeBehaviour() {
        #expect(ThreadSpec.parse("1.5-4 x ACME")?.form == .acme)
        #expect(ThreadSpec.parse("Tr40X7")?.form == .trapezoidal)
        #expect(ThreadSpec.parse("M10X1.5") == nil)
        #expect(ThreadSpec.parse("M10x1.5")?.pitch == 1.5)
    }
}
