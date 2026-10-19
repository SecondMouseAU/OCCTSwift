import Foundation
import Testing

@testable import OCCTSwift

// The text BREP reader (`BRepTools::Read`, behind `Shape.fromBREPString`) used a stale value after
// an extraction that failed, and read a word into a fixed buffer without a limit. Carried patch
// `0073` fixes the three families of defect in the kernel itself:
//
//  - a file that ends inside a record: `TopTools_ShapeSet::Read` indexed the shape table with the
//    number a failed extraction left behind, and the vertex and edge loops
//    `do { IS >> val; ... } while (val > 0)` never ended (OCCT#1608);
//  - a word longer than 254 bytes where a section name or a shape type goes, which overwrote the
//    stack of a `char[255]`;
//  - a number of 32 characters or more, which `GeomTools::GetReal` cut and whose tail it then read
//    as the next number (OCCT#1560);
//  - a reference the file made up: a shape index outside the table, a location outside the
//    table, and a trimmed or offset curve whose basis did not read.
//
// `fromBREPString` reads through a stream that throws where the text ends (the bridge guard),
// which already refuses a cut file and an overlong word before the reader sees them. These tests
// therefore only fail on an unpatched kernel for what the guard does not cover: a reference the
// file made up, a number of 32 characters or more, and the loops that spin on a flag. They are
// gated on `OCCTSWIFT_LOCAL=1` while the pinned asset lacks `0073`; `kernel-integration.yml` runs
// them. The gate comes off at the repin that pins it.
//
// Every damaged file is made from a box this test writes, with an edit that is checked to have
// changed the text, so a stale pattern cannot turn a case into a test of the undamaged file. The
// undamaged round trip is the control: a reader that refused everything would pass the rest.
@Suite("BREP text reader keeps to the stream", .serialized)
struct BREPKernelDamagedReadTests {

    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    private static func boxText() -> String? {
        Shape.box(width: 10, height: 20, depth: 30)?.toBREPString()
    }

    /// `text` with the first `old` replaced by `new`, or nil when `old` is not there.
    private static func edited(_ text: String, replacing old: String, with new: String) -> String? {
        guard let range = text.range(of: old) else { return nil }
        return text.replacingCharacters(in: range, with: new)
    }

    private static func volume(of text: String) -> Double? {
        Shape.fromBREPString(text)?.volume
    }

    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func undamagedTextReadsBack() throws {
        let text = try #require(Self.boxText())
        let volume = try #require(Self.volume(of: text))
        #expect(abs(volume - 6000) < 1e-6)
    }

    /// Every prefix a transfer that stopped early can hand the reader.
    ///
    /// Almost all are refused; the few that drop only the white space after the root reference are
    /// the whole file.
    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func textCutAnywhereIsRefusedOrIsTheWholeShape() throws {
        let text = try #require(Self.boxText())
        let bytes = Array(text.utf8)
        var cuts = Set(stride(from: 0, to: bytes.count, by: 3))
        cuts.formUnion(max(0, bytes.count - 80)..<bytes.count)
        var refused = 0
        for cut in cuts.sorted() {
            let prefix = String(decoding: bytes[..<cut], as: UTF8.self)
            if let shape = Shape.fromBREPString(prefix) {
                if let volume = shape.volume { #expect(abs(volume - 6000) < 1e-6, "cut at \(cut)") }
            } else {
                refused += 1
            }
        }
        #expect(refused > cuts.count - 8, "only the prefixes that drop trailing white space read")
    }

    /// OCCT#1608: a record that ends after its flags. `val` kept its last value and the loop never ended.
    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func textEndingInsideAnEdgeOrAVertexIsRefused() {
        let head =
            "DBRep_DrawableShape\n\nCASCADE Topology V1, (c) Matra-Datavision\nLocations 0\n"
            + "Curve2ds 0\nCurves 0\nPolygon3D 0\nPolygonOnTriangulations 0\nSurfaces 0\n"
            + "Triangulations 0\n\nTShapes 1\n"
        #expect(Shape.fromBREPString(head + "Ed\n 1e-07 1 1 1\n") == nil)
        #expect(Shape.fromBREPString(head + "Ve\n1e-07\n0 0 0\n") == nil)
    }

    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func wordsLongerThanTheReadersBufferAreRefused() throws {
        let text = try #require(Self.boxText())
        for length in [255, 400, 70_000] {
            let word = String(repeating: "C", count: length)
            let inSection = try #require(Self.edited(text, replacing: "Curve2ds", with: word))
            #expect(Shape.fromBREPString(inSection) == nil, "section name of \(length)")
            let inType = try #require(Self.edited(text, replacing: "\nVe\n", with: "\n\(word)\n"))
            #expect(Shape.fromBREPString(inType) == nil, "shape type of \(length)")
        }
    }

    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func referencesOutsideTheTablesAreRefused() throws {
        let text = try #require(Self.boxText())
        // A sub-shape reference past the table, then roots past it, before it and far past it.
        let subShape = try #require(
            Self.edited(text, replacing: "+20 0 +13 0 *", with: "+9999 0 +13 0 *"))
        #expect(Shape.fromBREPString(subShape) == nil)
        let tail = try #require(text.range(of: "\n+1 0", options: .backwards))
        for root in ["+9999 0", "+0 0", "-9999 0", "+99999999999 0"] {
            let damaged = text.replacingCharacters(in: tail, with: "\n" + root)
            #expect(Shape.fromBREPString(damaged) == nil, "root \(root)")
        }
    }

    /// A trimmed or offset curve is built on the curve read after it.
    ///
    /// When that read gives nothing the constructor dereferenced a null basis. Type 9 is an offset
    /// curve, 8 a trimmed one, 99 a type nothing reads.
    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func curvesWithoutABasisAreRefused() throws {
        let text = try #require(Self.boxText())
        let curve3d = "1 -5 -10 -15 0 0 1 "
        let curve2d = "1 0 0 1 0 \n"
        for record in ["9 1 0 0 1 99 ", "8 0 1 99 "] {
            let damaged = try #require(Self.edited(text, replacing: curve3d, with: record))
            #expect(Shape.fromBREPString(damaged) == nil, "3D curve record \(record)")
        }
        for record in ["9 1 99 \n", "8 0 1 99 \n"] {
            let damaged = try #require(Self.edited(text, replacing: curve2d, with: record))
            #expect(Shape.fromBREPString(damaged) == nil, "2D curve record \(record)")
        }
    }

    /// A location built from others names them by index, and the index read the table unchecked.
    ///
    /// A table of two locations whose second is built from a first that is there reads; built from
    /// an index that is not, it is refused. The box has no location of its own, so the table is
    /// written in: one translation, then a location composed of it (`2 1 1 0`: entry 1, power 1).
    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func aComposedLocationOutsideTheTableIsRefused() throws {
        let text = try #require(Self.boxText())
        let translation = "1\n1 0 0 5 \n0 1 0 0 \n0 0 1 0 \n"
        func withComposed(_ record: String) throws -> String {
            let table = "Locations 2\n" + translation + record
            return try #require(Self.edited(text, replacing: "Locations 0\n", with: table))
        }
        let inTable = try #require(Self.volume(of: try withComposed("2 1 1 0\n")))
        #expect(abs(inTable - 6000) < 1e-6)
        #expect(Shape.fromBREPString(try withComposed("2 9999 1 0\n")) == nil)
        #expect(Shape.fromBREPString(try withComposed("2 -3 1 0\n")) == nil)
    }

    /// OCCT#1560: a number of 32 characters or more was cut and its tail read as the next number.
    ///
    /// The vertex at z = 15 is written with 43 characters as a decimal and 44 as an exponent; the box
    /// is the same box.
    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func aNumberLongerThanTheBufferIsReadWhole() throws {
        let text = try #require(Self.boxText())
        for number in [
            "15.0000000000000000000000000000000000000001",
            "1.5000000000000000000000000000000000000001e1",
        ] {
            let longer = try #require(
                Self.edited(text, replacing: "\n-5 -10 15\n", with: "\n-5 -10 \(number)\n"))
            let volume = try #require(Self.volume(of: longer), "\(number)")
            #expect(abs(volume - 6000) < 1e-6, "\(number)")
        }
    }

    /// The root reference is the last token of the file.
    ///
    /// The kernel reads a file whose trailing white space was stripped, since the last token still
    /// extracts, but the bridge's end-of-stream check refuses it: a written BREP ends in a space,
    /// and a number ended by the end of the file is the mark of a cut. Relaxing the bridge is a
    /// separate decision, so this records the refusal.
    @Test(.enabled(if: BREPKernelDamagedReadTests.isLocalKernel))
    func textWithoutTrailingWhiteSpaceIsRefusedByTheBridge() throws {
        let text = try #require(Self.boxText())
        let stripped = String(text.reversed().drop(while: { $0.isWhitespace }).reversed())
        #expect(Shape.fromBREPString(stripped) == nil)
    }
}
