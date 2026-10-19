import Foundation
import Testing

@testable import OCCTSwift

// The BREP readers size an array from a count the file declares and trust it. A B-spline curve,
// surface or polygon with a negative count sized an array backwards, a count past the end of the
// file was looped over to its end, and a pole grid of 65536 by 65536 overflowed the product that
// sizes it; a face or an edge named a triangulation, polygon or node the file did not have, and a
// location raised to a power of 10^8 recursed to the end of the stack.
// Carried patch `0074` refuses a count the stream cannot supply before an array is sized from it,
// checks a reference against its table, and checks a triangle's nodes against the triangulation's.
//
// `fromBREPString` reads through a stream that throws where the text ends (the bridge guard), so
// a count that points past the end of a short file is half-refused by the guard on an unpatched
// kernel: the cases here are the ones the guard does not cover (a negative count, a product that
// overflows, a count the 2^31 loops of an unpatched kernel never reach the end of, a reference the
// file made up). They are gated on `OCCTSWIFT_LOCAL=1` while the pinned asset lacks `0074`;
// `kernel-integration.yml` runs them. The gate comes off at the repin that pins it.
//
// Every damaged file is a box this test writes with one record added to a table of it that no
// shape refers to, so the box reads whatever the record says; the record is then damaged with an
// edit that is checked to have changed the text. The undamaged file is the control: a reader that
// refused every record would pass the rest.
@Suite("BREP readers bound a declared count", .serialized)
struct BREPKernelRecordCountTests {

    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    /// The sections of the BREP text a record can be added to, in file order.
    private enum Table: String, CaseIterable {
        case curve2ds = "Curve2ds"
        case curves = "Curves"
        case polygon3D = "Polygon3D"
        case polygonOnTriangulations = "PolygonOnTriangulations"
        case surfaces = "Surfaces"
        case triangulations = "Triangulations"
    }

    /// Records the readers parse with a declared count, each a valid one (a copy of what the writer wrote).
    private enum Record {
        static let curve2dBSpline = "7 0 0  2 3 2  0 0  1 2  2 0 \n 0 3 1 3\n"
        static let curve3dBSpline = "7 0 0  2 3 2  0 0 0  1 2 0  2 0 0 \n 0 3 1 3\n"
        static let surfaceBSpline =
            "9 0 0 0 0 2 2 3 3 2 2 1 1 0  1 2 1  1 3 0  \n2 1 1  2 2 0  2 3 1  \n3 1 0  3 2 1  3 3 0  \n\n0 3\n1 3\n\n0 3\n1 3\n"
        static let surfaceBezier =
            "8 0 0 2 2 1 1 1  1 2 0  1 3 1  \n2 1 0  2 2 0  2 3 0  \n3 1 1  3 2 0  3 3 1  \n"
        static let polygon3D =
            "5 1\n1\n4 0 0 3.82 1.18 0 3.3 2.25 0 2.48 3.13 0 1.44 3.72 0 \n0 0.3 0.6 0.9 1.2 \n"
        static let polygonOnTriangulation = "2 1 2 \np 10 1 0 4 \n"
        static let triangulation = "3 1 1 0 0\n0 0 0 4 0 0 0 3 0 -1.5 -1 2.5 -1 -1.5 2 2 3 1 \n"
    }

    private static func boxText() -> String? {
        Shape.box(width: 10, height: 20, depth: 30)?.toBREPString()
    }

    /// `text` with the first `old` replaced by `new`, or nil when `old` is not there.
    private static func edited(_ text: String, replacing old: String, with new: String) -> String? {
        guard let range = text.range(of: old) else { return nil }
        return text.replacingCharacters(in: range, with: new)
    }

    /// The box with `record` appended to `table`, which gains one entry.
    private static func boxText(adding record: String, to table: Table) -> String? {
        guard var text = boxText() else { return nil }
        let order = Table.allCases.map(\.rawValue) + ["TShapes"]
        guard let index = order.firstIndex(of: table.rawValue) else { return nil }
        // The header line holds the count; the next section's header is where the record goes.
        guard let header = text.range(of: "\n\(table.rawValue) "),
            let lineEnd = text.range(of: "\n", range: header.upperBound..<text.endIndex),
            let count = Int(text[header.upperBound..<lineEnd.lowerBound])
        else { return nil }
        guard
            let next = text.range(
                of: "\n\(order[index + 1])", range: lineEnd.lowerBound..<text.endIndex)
        else { return nil }
        // The later edit first, so the earlier indices stay valid.
        text.insert(contentsOf: record, at: text.index(after: next.lowerBound))
        text.replaceSubrange(header.upperBound..<lineEnd.lowerBound, with: String(count + 1))
        return text
    }

    private static func volume(of text: String) -> Double? {
        Shape.fromBREPString(text)?.volume
    }

    /// The box with `record` added and `old` in it replaced by `new`, or nil.
    private static func damaged(
        _ table: Table, _ record: String, replacing old: String, with new: String
    ) -> String? {
        guard let replaced = edited(record, replacing: old, with: new),
            let text = boxText(adding: replaced, to: table)
        else { return nil }
        return text
    }

    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func recordsWithDeclaredCountsReadBack() throws {
        let cases: [(Table, String)] = [
            (.curve2ds, Record.curve2dBSpline), (.curves, Record.curve3dBSpline),
            (.polygon3D, Record.polygon3D),
            (.polygonOnTriangulations, Record.polygonOnTriangulation),
            (.surfaces, Record.surfaceBSpline), (.surfaces, Record.surfaceBezier),
            (.triangulations, Record.triangulation),
        ]
        for (table, record) in cases {
            let text = try #require(Self.boxText(adding: record, to: table), "\(table)")
            let volume = try #require(Self.volume(of: text), "\(table) \(record.prefix(12))")
            #expect(abs(volume - 6000) < 1e-6, "\(table) \(record.prefix(12))")
        }
    }

    /// A negative pole, knot or node count sized an array backwards.
    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func aNegativeCountIsRefused() throws {
        let cases: [(Table, String, String, String)] = [
            (.curves, Record.curve3dBSpline, "7 0 0  2 3 2  ", "7 0 0  2 -1 2  "),
            (.curves, Record.curve3dBSpline, "7 0 0  2 3 2  ", "7 0 0  2 3 -1  "),
            (.curve2ds, Record.curve2dBSpline, "7 0 0  2 3 2  ", "7 0 0  2 -1 2  "),
            (.curve2ds, Record.curve2dBSpline, "7 0 0  2 3 2  ", "7 0 0  2 3 -1  "),
            (.surfaces, Record.surfaceBSpline, "9 0 0 0 0 2 2 3 3 2 2 ", "9 0 0 0 0 2 2 -1 3 2 2 "),
            (.surfaces, Record.surfaceBSpline, "9 0 0 0 0 2 2 3 3 2 2 ", "9 0 0 0 0 2 2 3 -1 2 2 "),
            (.surfaces, Record.surfaceBSpline, "9 0 0 0 0 2 2 3 3 2 2 ", "9 0 0 0 0 2 2 3 3 -1 2 "),
            (.polygon3D, Record.polygon3D, "5 1\n", "-1 1\n"),
            (.triangulations, Record.triangulation, "3 1 1 0 0\n", "3 -1 1 0 0\n"),
        ]
        for (table, record, old, new) in cases {
            let text = try #require(Self.damaged(table, record, replacing: old, with: new))
            #expect(Shape.fromBREPString(text) == nil, "\(table): \(new.prefix(24))")
        }
    }

    /// A pole grid whose two counts are fine and whose product is not.
    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func aPoleGridWhoseSizeOverflowsIsRefused() throws {
        let text = try #require(
            Self.damaged(
                .surfaces, Record.surfaceBSpline, replacing: "9 0 0 0 0 2 2 3 3 2 2 ",
                with: "9 0 0 0 0 2 2 65536 65536 2 2 "))
        #expect(Shape.fromBREPString(text) == nil)
    }

    /// A count of 2^31 - 1 sized a 50 GB array and was looped over, on a stream that had failed at its
    /// first item.
    ///
    /// The bridge guard ends that read at the end of the file in the end, so the file is refused
    /// either way; an unpatched kernel takes 42 s to get there, which is what the time limit
    /// records. A reader that sizes nothing from the count refuses it in milliseconds.
    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func aCountFarBeyondTheFileIsRefusedAtOnce() throws {
        let cases: [(Table, String, String, String)] = [
            (.curves, Record.curve3dBSpline, "7 0 0  2 3 2  ", "7 0 0  2 2147483647 2  "),
            (
                .surfaces, Record.surfaceBSpline, "9 0 0 0 0 2 2 3 3 2 2 ",
                "9 0 0 0 0 2 2 2147483647 3 2 2 "
            ),
            (.polygon3D, Record.polygon3D, "5 1\n", "2147483647 1\n"),
        ]
        let clock = ContinuousClock()
        let start = clock.now
        for (table, record, old, new) in cases {
            let text = try #require(Self.damaged(table, record, replacing: old, with: new))
            #expect(Shape.fromBREPString(text) == nil, "\(table): \(new.prefix(24))")
        }
        #expect(clock.now - start < .seconds(10))
    }

    /// A triangle names the nodes of its triangulation by index.
    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func aTriangleWithANodeTheTriangulationLacksIsRefused() throws {
        for triangle in ["2 3 99 \n", "2 3 -1 \n", "0 3 1 \n"] {
            let text = try #require(
                Self.damaged(
                    .triangulations, Record.triangulation, replacing: "2 3 1 \n", with: triangle))
            #expect(Shape.fromBREPString(text) == nil, "triangle \(triangle)")
        }
    }

    /// A location is built from others, each raised to a power.
    ///
    /// A composed location is raised one multiplication at a time and recursively, so a power of
    /// 10^8 is the stack; a written file never raises a composed location (a composed entry names
    /// single ones), so the table is written in: two translations, a location composed of both, and
    /// a power of that (`2 3 5 0`: entry 3, power 5).
    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func aLargePowerOfAComposedLocationIsRefused() throws {
        let text = try #require(Self.boxText())
        let translation = "1\n1 0 0 5 \n0 1 0 0 \n0 0 1 0 \n"
        let other = "1\n1 0 0 0 \n0 1 0 7 \n0 0 1 0 \n"
        func withPower(_ power: Int) throws -> String {
            let table = "Locations 4\n" + translation + other + "2 1 1 2 1 0\n2 3 \(power) 0\n"
            return try #require(Self.edited(text, replacing: "Locations 0\n", with: table))
        }
        let small = try #require(Self.volume(of: try withPower(5)))
        #expect(abs(small - 6000) < 1e-6)
        for power in [100_000_000, -100_000_000, Int(Int32.max), Int(Int32.min)] {
            #expect(Shape.fromBREPString(try withPower(power)) == nil, "power \(power)")
        }
    }

    /// A face that holds only a triangulation names it by index into the table.
    ///
    /// The box has no triangulations, so any index is outside the table. The face is left without a
    /// surface, which the reader does not refuse; what it must not do is look the index up.
    @Test(.enabled(if: BREPKernelRecordCountTests.isLocalKernel))
    func aFaceNamingATriangulationOutsideTheTableDoesNotLookItUp() throws {
        let text = try #require(Self.boxText())
        let damaged = try #require(
            Self.edited(text, replacing: "Fa\n0  1e-07 1 0\n", with: "Fa\n2  9999\n"))
        _ = Shape.fromBREPString(damaged)
    }
}
