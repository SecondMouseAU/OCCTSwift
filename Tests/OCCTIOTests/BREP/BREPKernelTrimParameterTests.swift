import Foundation
import Testing

@testable import OCCTSwift

// A trimmed curve or surface is built from two parameters the file declares, and the constructor
// trusted them. A parameter that is not a number (`nan`, `inf`) faulted or never returned: on a
// periodic basis `ElCLib::AdjustPeriodic` looped on it (`Geom_TrimmedCurve::SetTrim`), and on a
// periodic surface `Geom_RectangularTrimmedSurface::SetTrim` recursed until the stack ended; on a
// basis that is not periodic the comparisons against the range were all false for a `nan`, so the
// object was built with it and faulted on use.
// Carried patch `0075` refuses a parameter that is not finite, with `Standard_ConstructionError`,
// which `GeomTools_CurveSet`, `Curve2dSet` and `SurfaceSet` turn into a null record and so a
// refused file.
//
// Gated on `OCCTSWIFT_LOCAL=1` while the pinned asset lacks `0075`; `kernel-integration.yml` runs
// it. The gate comes off at the repin that pins it. On a kernel without the patch the cases on a
// periodic basis do not return a result at all (a spin, or a SIGSEGV), which is the failure.
//
// Every damaged file is the box with one trimmed record added to a table no shape refers to, so
// the box reads whatever the record says. The undamaged records are the control: a reader that
// refused every trimmed record would pass the rest.
@Suite("BREP trim parameters must be numbers", .serialized)
struct BREPKernelTrimParameterTests {

    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    private enum Table: String, CaseIterable {
        case curve2ds = "Curve2ds"
        case curves = "Curves"
        case polygon3D = "Polygon3D"
        case surfaces = "Surfaces"
    }

    /// Trimmed records: the parameters, then the basis.
    ///
    /// The `<p>` marks the parameters a case replaces.
    private enum Record {
        static let lineCurve = "8 <p>\n1 0 0 0 1 0 0 \n"
        static let circleCurve = "8 <p>\n2 0 0 0  0 0 1  1 0 0  0 1 0  5 \n"
        static let circleCurve2d = "8 <p>\n2 0 0  1 0  0 1  5 \n"
        static let planeSurface = "10 <p>\n1 0 0 0  0 0 1  1 0 0  0 1 0 \n"
        static let cylinderSurface = "10 <p>\n2 0 0 0  0 0 1  1 0 0  0 1 0  5 \n"
    }

    private static func boxText() -> String? {
        Shape.box(width: 10, height: 20, depth: 30)?.toBREPString()
    }

    /// The box with `record` appended to `table`, which gains one entry.
    private static func boxText(adding record: String, to table: Table) -> String? {
        guard var text = boxText() else { return nil }
        let order = Table.allCases.map(\.rawValue) + ["Triangulations"]
        guard let index = order.firstIndex(of: table.rawValue) else { return nil }
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

    private static func box(_ table: Table, _ record: String, parameters: String) -> String? {
        boxText(
            adding: record.replacingOccurrences(of: "<p>", with: parameters), to: table)
    }

    @Test(.enabled(if: BREPKernelTrimParameterTests.isLocalKernel))
    func trimmedRecordsWithNumbersReadBack() throws {
        let cases: [(Table, String, String)] = [
            (.curves, Record.lineCurve, "0 3"), (.curves, Record.circleCurve, "0 3"),
            (.curve2ds, Record.circleCurve2d, "0 3"),
            (.surfaces, Record.planeSurface, "0 1 0 1"),
            (.surfaces, Record.cylinderSurface, "0 3 0 1"),
        ]
        for (table, record, parameters) in cases {
            let text = try #require(Self.box(table, record, parameters: parameters), "\(table)")
            let volume = try #require(Self.volume(of: text), "\(table) \(record.prefix(4))")
            #expect(abs(volume - 6000) < 1e-6, "\(table) \(record.prefix(4))")
        }
    }

    /// Not periodic: a `nan` fails every comparison against the range, so the object was built.
    @Test(.enabled(if: BREPKernelTrimParameterTests.isLocalKernel))
    func aNonNumberOnABasisThatIsNotPeriodicIsRefused() throws {
        let cases: [(Table, String, String)] = [
            (.curves, Record.lineCurve, "nan nan"), (.curves, Record.lineCurve, "nan 3"),
            (.curves, Record.lineCurve, "0 nan"), (.curves, Record.lineCurve, "0 inf"),
            (.surfaces, Record.planeSurface, "nan nan 0 1"),
            (.surfaces, Record.planeSurface, "0 1 nan nan"),
            (.surfaces, Record.planeSurface, "0 inf 0 1"),
            (.surfaces, Record.planeSurface, "0 1 -inf 1"),
        ]
        for (table, record, parameters) in cases {
            let text = try #require(Self.box(table, record, parameters: parameters), "\(table)")
            #expect(Shape.fromBREPString(text) == nil, "\(table) \(record.prefix(4)) \(parameters)")
        }
    }

    /// Periodic: `AdjustPeriodic` looped on the parameter, and the surface recursed.
    ///
    /// The case in the issue, `10 nan nan 0 4`, is the cylinder one.
    @Test(.enabled(if: BREPKernelTrimParameterTests.isLocalKernel))
    func aNonNumberOnAPeriodicBasisIsRefused() throws {
        let cases: [(Table, String, String)] = [
            (.curves, Record.circleCurve, "nan nan"), (.curves, Record.circleCurve, "nan 3"),
            (.curves, Record.circleCurve, "0 inf"), (.curves, Record.circleCurve, "-inf inf"),
            (.curve2ds, Record.circleCurve2d, "nan nan"),
            (.curve2ds, Record.circleCurve2d, "0 inf"),
            (.surfaces, Record.cylinderSurface, "nan nan 0 4"),
            (.surfaces, Record.cylinderSurface, "inf 5 0 4"),
            (.surfaces, Record.cylinderSurface, "0 3 nan 1"),
            (.surfaces, Record.cylinderSurface, "0 3 0 inf"),
        ]
        for (table, record, parameters) in cases {
            let text = try #require(Self.box(table, record, parameters: parameters), "\(table)")
            #expect(Shape.fromBREPString(text) == nil, "\(table) \(record.prefix(4)) \(parameters)")
        }
    }
}
