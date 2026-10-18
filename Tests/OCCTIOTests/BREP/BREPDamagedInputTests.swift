import Foundation
import Testing

@testable import OCCTSwift

#if os(WASI)
    private let hangLimit: ConditionTrait = .enabled(if: true)
#else
    private let hangLimit: TimeLimitTrait = .timeLimit(.minutes(1))
#endif

// #3487: `BRepTools::Read` faulted, or never returned, on a BREP text that ends early. It reads a
// token into a `char buffer[255]` it never initialises, and when the stream is at its end the
// extraction fails and leaves that stale value behind; `TopTools_ShapeSet::Read` then indexes its
// shape table with it (an unchecked `NCollection_IndexedMap` access, OCCT's range check being
// compiled out of the pinned kernel), and the vertex and edge loops `while (val > 0)` spin on a
// stale positive `val`. `OCC_CATCH_SIGNALS` is inert in this build, so the SIGSEGV is not catchable
// in process: without the bridge's stream guard these tests kill the test process (a crash) or hang
// it, and with it every prefix is refused. The crash is the failure signal, as it is for the OCAF
// readers in `OCAFMalformedKernelReadTests`; the spin is caught by `hangLimit` where the trait
// applies (a synchronous OCCT loop cannot be interrupted by it, so the prove-the-test-fails run
// reports the timeout and kills the process from outside, see `Issue3100BuilderHangTests`).
//
// The inputs are generated from real shapes, not shipped as fixtures, so the suite also runs
// wherever a shape can be written. What the guard does not cover (a complete file with a wrong
// index or count) is not tested here as a refusal; see `Scripts/repro/3487/README.md`.
@Suite("BREP text that is cut short is refused instead of faulting")
struct BREPDamagedInputTests {

    // MARK: - Sources

    private struct Sample {
        let name: String
        let text: String
        /// Cut every `stride`th byte; 1 is every strict prefix.
        let stride: Int
    }

    private func brepText(_ shape: Shape, withTriangles: Bool = false) throws -> String {
        let data = try shape.brepData(withTriangles: withTriangles)
        return try #require(String(data: data, encoding: .utf8), "BREP text is not UTF-8")
    }

    private func samples() throws -> [Sample] {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 12))
        let sphere = try #require(Shape.sphere(radius: 7))

        // B-spline curves and surfaces: a smooth loft through three different circles.
        let sections = try [
            Wire.circle(origin: SIMD3(0, 0, 0), radius: 6),
            Wire.circle(origin: SIMD3(1, 0, 5), radius: 4),
            Wire.circle(origin: SIMD3(0, 1, 10), radius: 5),
        ].map { try #require($0) }
        let loft = try #require(Shape.loft(profiles: sections, solid: true, ruled: false))

        // A triangulation and polygons on it: mesh, then write with triangles.
        let meshed = try #require(Shape.cylinder(radius: 5, height: 12))
        _ = try #require(meshed.mesh(linearDeflection: 1.0, angularDeflection: 0.8))

        // Several solids in one compound, and a located one (a non-empty Locations table).
        let box2 = try #require(box.translated(by: SIMD3(30, 0, 0)))
        let compound = try #require(Shape.compound([box, box2, cylinder]))
        let located = try #require(box.rotated(axis: SIMD3(0, 0, 1), angle: 0.7))

        let boxText = try brepText(box)
        return [
            Sample(name: "box", text: boxText, stride: 1),
            Sample(name: "cylinder", text: try brepText(cylinder), stride: 1),
            Sample(name: "sphere", text: try brepText(sphere), stride: 1),
            Sample(name: "bspline loft", text: try brepText(loft), stride: 1),
            Sample(name: "compound", text: try brepText(compound), stride: 7),
            Sample(name: "located", text: try brepText(located), stride: 3),
            Sample(name: "meshed", text: try brepText(meshed, withTriangles: true), stride: 13),
            // The older versions the writer can produce. V1 differs from V3 in the header line only
            // for a shape with no 2D end points (measured on a box and a cylinder); V2 adds them.
            Sample(
                name: "box V1",
                text: boxText.replacingOccurrences(
                    of: "CASCADE Topology V3, (c) Open Cascade",
                    with: "CASCADE Topology V1, (c) Matra-Datavision"),
                stride: 3),
            Sample(name: "cylinder V2", text: Self.cylinderV2, stride: 1),
        ]
    }

    // MARK: - Helpers

    private func tempPath(_ name: String) -> String {
        // Unique per call: the suite's tests run in parallel and would overwrite one another's file.
        NSTemporaryDirectory() + "brepdamaged_\(UUID().uuidString)_\(name).brep"
    }

    /// Whether either entry point loads `text` (the file one and the string one).
    private func loads(_ text: String) -> (file: Bool, string: Bool) {
        let path = tempPath("case")
        defer { try? FileManager.default.removeItem(atPath: path) }
        guard FileManager.default.createFile(atPath: path, contents: Data(text.utf8)) else {
            Issue.record("setup: could not write \(path)")
            return (true, true)
        }
        let file = (try? Shape.loadBREP(fromPath: path)) != nil
        let string = Shape.fromBREPString(text) != nil
        return (file, string)
    }

    // MARK: - Tests

    // Every strict prefix, through both entry points. The last cut drops only the trailing space
    // the writer ends the root reference with (`+1 0 `); the root's location token is then ended by
    // the end of the file, which a complete BREP never is, so it is refused with the rest.
    @Test("Every strict prefix of a written BREP is refused, through both entry points", hangLimit)
    func everyStrictPrefixIsRefused() throws {
        for sample in try samples() {
            let bytes = Array(sample.text.utf8)
            var cuts = Array(stride(from: 0, to: bytes.count, by: sample.stride))
            cuts.append(contentsOf: max(0, bytes.count - 40)..<bytes.count)  // the root reference
            var accepted: [Int] = []
            for cut in Set(cuts).sorted() {
                let prefix = String(decoding: bytes[0..<cut], as: UTF8.self)
                let result = loads(prefix)
                if result.file || result.string { accepted.append(cut) }
            }
            #expect(
                accepted.isEmpty,
                "\(sample.name): \(accepted.count) of \(bytes.count) prefixes loaded, first at \(accepted.first ?? -1)"
            )
        }
    }

    // The control for the test above: a prefix is refused because it is a prefix, not because the
    // reader refuses everything. Every sample loads whole, through both entry points, and the shape
    // comes back valid with the faces it was written with.
    @Test("Every written BREP loads whole, through both entry points")
    func everyCompleteSampleLoads() throws {
        for sample in try samples() {
            let path = tempPath("whole")
            defer { try? FileManager.default.removeItem(atPath: path) }
            try Data(sample.text.utf8).write(to: URL(fileURLWithPath: path))
            let fromFile = try Shape.loadBREP(fromPath: path)
            let fromString = try #require(Shape.fromBREPString(sample.text), "\(sample.name)")
            #expect(fromFile.isValid, "\(sample.name): file")
            #expect(fromString.isValid, "\(sample.name): string")
            #expect(fromFile.faces().count == fromString.faces().count, "\(sample.name)")
            #expect(!fromFile.faces().isEmpty, "\(sample.name)")
        }
    }

    // The bridge reads through a 64 KiB buffer that checks word lengths, so a file several times
    // that must cross its refills without losing or splitting a word.
    @Test("A large written BREP loads whole, across the word-length buffer's refills")
    func largeFileLoads() throws {
        let sphere = try #require(Shape.sphere(radius: 10))
        _ = try #require(sphere.mesh(linearDeflection: 0.02, angularDeflection: 0.1))
        let text = try brepText(sphere, withTriangles: true)
        let size = text.utf8.count
        try #require(size > 200_000, "setup: \(size) bytes is not several refills")
        let result = loads(text)
        #expect(result.file && result.string)
        let restored = try #require(Shape.fromBREPString(text))
        #expect(restored.isValid)
        if let volume = restored.volume {
            #expect(abs(volume - 4.0 / 3.0 * Double.pi * 1000.0) < 1e-6)
        }
        // And one cut across a refill boundary is still refused.
        let bytes = Array(text.utf8)
        let cut = String(decoding: bytes[0..<(65536 * 2)], as: UTF8.self)
        let refused = loads(cut)
        #expect(!refused.file && !refused.string)
    }

    // The meshed sample is only a test of the triangulation sections if it has them.
    @Test("The meshed sample carries a triangulation and polygons on it")
    func meshedSampleHasTheSections() throws {
        let meshed = try #require(Shape.cylinder(radius: 5, height: 12))
        _ = try #require(meshed.mesh(linearDeflection: 1.0, angularDeflection: 0.8))
        let text = try brepText(meshed, withTriangles: true)
        let triangulations = try #require(text.range(of: "Triangulations "))
        let digits = text[triangulations.upperBound...].prefix { $0.isNumber }
        #expect((Int(digits) ?? 0) > 0)
        let polygons = try #require(text.range(of: "PolygonOnTriangulations "))
        let polygonDigits = text[polygons.upperBound...].prefix { $0.isNumber }
        #expect((Int(polygonDigits) ?? 0) > 0)
    }

    @Test("A complete BREP followed by whitespace, or by nothing the reader asks for, still loads")
    func trailingWhitespaceIsFine() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let text = try brepText(box)
        let result = loads(text + "\n")
        #expect(result.file && result.string)
        let more = loads(text + "\n\n  \n")
        #expect(more.file && more.string)
    }

    @Test("A BREP whose trailing whitespace was stripped is refused, as a cut one is")
    func strippedTrailingWhitespaceIsRefused() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let text = try brepText(box)
        #expect(text.hasSuffix(" "))
        let stripped = String(text.dropLast())
        let result = loads(stripped)
        #expect(!result.file && !result.string)
    }

    @Test("Empty, text and header-only inputs are refused")
    func emptyAndText() {
        let cases = [
            "", "\n", "not a BREP at all", "DBRep_DrawableShape\n",
            "DBRep_DrawableShape\n\nCASCADE Topology V3, (c) Open Cascade\n",
            "DBRep_DrawableShape\n\nCASCADE Topology V3, (c) Open Cascade\nLocations 0\n",
        ]
        for text in cases {
            let result = loads(text)
            #expect(!result.file && !result.string, "\(text.debugDescription)")
        }
    }

    // The reader extracts a word into a `char[255]` with no width limit, so a word of 255 bytes or
    // more overflows the stack (SIGABRT and SIGBUS, measured). The bridge reads through a buffer
    // that refuses such a word; 254 bytes is what the array holds with its terminator, so the
    // boundary is pinned on both sides with the count of the `Curves` section padded with zeros:
    // `Curves 000...012` parses as 12 whatever its width.
    @Test("A word of 255 bytes or more is refused, one of 254 still loads", hangLimit)
    func overlongWordIsRefused() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let text = try brepText(box)
        let curves = try #require(text.range(of: "Curves 12"))
        func padded(_ width: Int) -> String {
            var copy = text
            copy.replaceSubrange(
                curves, with: "Curves " + String(repeating: "0", count: width - 2) + "12")
            return copy
        }
        let atLimit = loads(padded(254))
        #expect(atLimit.file && atLimit.string, "a 254 byte word is within the reader's buffer")
        let past = loads(padded(255))
        #expect(!past.file && !past.string, "a 255 byte word overflows the reader's buffer")

        // An overlong word wherever the reader takes one: a section name, a shape type and a flag
        // word. The rule is about the file, not the position: an overlong word anywhere is refused.
        for needle in ["Locations", "Curve2ds", "Curves", "Surfaces", "TShapes", "Ve", "0101000"] {
            let range = try #require(text.range(of: needle), "\(needle) is in the text")
            var copy = text
            copy.replaceSubrange(range, with: String(repeating: "Q", count: 400))
            let result = loads(copy)
            #expect(!result.file && !result.string, "\(needle) replaced by 400 bytes")
        }
    }

    // MARK: - Fixture

    // A V2 BREP of `Shape.cylinder(radius: 5, height: 12)`, as the writer produces it with
    // `TopTools_FormatVersion_VERSION_2`; the kernel's only V2 writer is not reachable from Swift.
    // One line per element: the writer ends most lines in a space, and an editor may not keep it.
    private static var cylinderV2: String {
        cylinderV2Lines.joined(separator: "\n")
    }

    private static let cylinderV2Lines: [String] = [
        "DBRep_DrawableShape",
        "",
        "CASCADE Topology V2, (c) Matra-Datavision",
        "Locations 0",
        "Curve2ds 7",
        "1 0 12 1 0 ",
        "2 0 0 1 0 -0 1 5",
        "1 6.2831853071795862 -0 0 1 ",
        "1 0 -0 0 1 ",
        "1 0 5 1 0 ",
        "1 0 0 1 0 ",
        "2 0 0 1 0 -0 1 5",
        "Curves 3",
        "2 0 0 12 0 0 1 1 0 -0 -0 1 0 5",
        "1 5 -1.2246467991473533e-15 0 0 0 1 ",
        "2 0 0 0 0 0 1 1 0 -0 -0 1 0 5",
        "Polygon3D 0",
        "PolygonOnTriangulations 0",
        "Surfaces 4",
        "2 0 0 0 0 0 1 1 0 0 0 1 0 5",
        "1 0 0 12 0 0 1 1 0 0 0 1 0 ",
        "1 0 0 0 -0 1 0 0 0 1 1 0 -0 ",
        "1 0 0 0 0 0 1 1 0 0 0 1 0 ",
        "Triangulations 0",
        "",
        "TShapes 13",
        "Ve",
        "1.50000001224647e-07",
        "5 -1.22464679914735e-15 12",
        "0 0",
        "",
        "0101101",
        "*",
        "Ed",
        " 1e-07 1 1 0",
        "1  1 0 0 6.28318530717959",
        "2  1 1 0 0 6.28318530717959",
        "0 12 6.28318530717959 12",
        "2  2 2 0 0 6.28318530717959",
        "5 0 5 -1.22464679914735e-15",
        "0",
        "",
        "0101000",
        "+13 0 -13 0 *",
        "Ve",
        "1.00000001224647e-07",
        "5 -1.22464679914735e-15 0",
        "0 0",
        "",
        "0101101",
        "*",
        "Ed",
        " 1.00000001224647e-07 1 1 0",
        "1  2 0 0 12",
        "3  3 4CN 1 0 0 12",
        "0 0 0 12",
        "2  5 3 0 0 12",
        "0 5 12 5",
        "0",
        "",
        "0101000",
        "-13 0 +11 0 *",
        "Ed",
        " 1e-07 1 1 0",
        "1  3 0 0 6.28318530717959",
        "2  6 1 0 0 6.28318530717959",
        "0 0 6.28318530717959 0",
        "2  7 4 0 0 6.28318530717959",
        "5 0 5 -1.22464679914735e-15",
        "0",
        "",
        "0101000",
        "+11 0 -11 0 *",
        "Wi",
        "",
        "0101100",
        "-12 0 +10 0 +9 0 -10 0 *",
        "Fa",
        "0  1e-07 1 0",
        "",
        "0111000",
        "+8 0 *",
        "Wi",
        "",
        "0101100",
        "+12 0 *",
        "Fa",
        "0  1e-07 2 0",
        "",
        "0111000",
        "+6 0 *",
        "Wi",
        "",
        "0101100",
        "-9 0 *",
        "Fa",
        "0  1e-07 4 0",
        "",
        "0111000",
        "-4 0 *",
        "Sh",
        "",
        "0101100",
        "+7 0 +5 0 -3 0 *",
        "So",
        "",
        "0100000",
        "+2 0 *",
        "",
        "+1 0 ",
    ]
}
