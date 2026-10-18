import Foundation
import Testing

@testable import OCCTSwift

#if canImport(Darwin)
    import Darwin
#endif

// #3489 (follow-up to #3486): four hazards in the document data of a binary OCAF file, past the
// storage sections the bridge walks, that only a kernel change can bound. Carried patches
// `0070` to `0072` fix three of them; the fourth is recorded under "Not covered".
//
//  - `0071`: the array and list attribute drivers allocate `last - first + 1` elements before they
//    check the record holds them. A record of a few dozen bytes asked for 1 to 17 GiB. On a 32-bit
//    wasm module that is the failure #3477 describes: the allocation fails and every later
//    allocation in the process fails with it. The drivers now compare the span against the bytes
//    left in the record, by division, so the count times the element size is never formed.
//  - `0070`: `BinObjMgt_Persistent::GetLabel` tested `tagCount * 4` for room, and a count of 2^29 or
//    more overflows that product to a value that passes, so the loop that follows ran 2^29 times or
//    more past the data. The shared size comparison now cannot overflow.
//  - `0072`: five `BinTools` set readers read the name of their table into a `char[255]` with an
//    unbounded `>>`. The shape section of a file is reached through any TOC entry named
//    `SHAPE_SECTION_POS`, at any offset, and a 4 KB token terminated the process.
//
// The files are built here rather than shipped: `Blob` writes the layout
// `Scripts/repro/3489/ocaf.py` documents, which that script's `selftest` checks against a document
// the kernel itself saved. `recordedSpanLoads` is the control: a list and a byte array the builder
// wrote are read back with their values, so a builder that made files nothing reads could not pass
// for a fix.
//
// Gated on `OCCTSWIFT_LOCAL=1` while the pinned asset lacks the patches: three of the four classes
// below hang or kill the test process on an unpatched kernel, which is what a test of this fix is
// for, and not something `main` should run. `kernel-integration.yml` runs it. The gate comes off
// at the repin that pins `0070` to `0072`.
//
// Not covered: label nesting. A document whose labels nest 20000 deep overflows the stack of the
// recursive `ReadSubTree` (1000 loads), and the limit is a property of the thread, not of the
// file. OCCT has no depth guard to follow and any cap here would be an arbitrary constant, so it
// stays in `okf/references/known-occt-bugs.md`, not mitigated.
//
// Not covered either: how much a refused record allocated for the drivers that free what they
// allocated before they fail (`NamedData`, `DimTol`, `NoteBinData`, `GraphNode`, `Scope`,
// `VisMaterial`). Nothing remains to measure once the call returns. `Scripts/repro/3489` logs the
// allocation itself, under the #3477 interposer, and shows each of those at 0 bytes with the patch.
@Suite("Binary OCAF document data is bounded by the file", .serialized)
struct OCAFBinaryDocumentDataKernelReadTests {

    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    // MARK: - The file builder

    /// Little endian pieces of a `BinOcaf` file, storage version 12.
    private enum Blob {
        static func int(_ value: Int) -> [UInt8] {
            var v = Int32(truncatingIfNeeded: value).littleEndian
            return withUnsafeBytes(of: &v) { Array($0) }
        }

        static func uint64(_ value: Int) -> [UInt8] {
            var v = UInt64(value).littleEndian
            return withUnsafeBytes(of: &v) { Array($0) }
        }

        static func ints(_ values: Int...) -> [UInt8] { values.flatMap { int($0) } }

        /// A length (in units) then the bytes: the storage layer's string.
        static func string(_ text: String, utf16: Bool = false) -> [UInt8] {
            if utf16 {
                let units = Array(text.utf16)
                return int(units.count) + units.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] }
            }
            return int(text.utf8.count) + Array(text.utf8)
        }

        /// The info section: object count, five strings, the application strings, the user-info lines.
        static func info(types: [String]) -> [UInt8] {
            var out = int(1)
            for text in ["12", "10/18/2026", "", "1"] { out += string(text) }
            out += string("", utf16: true) + string("") + string("", utf16: true)
            let lines =
                [
                    "FILE_FORMAT: BinOcaf", "REFERENCE_COUNTER: 0", "MODIFICATION_COUNTER: 1",
                    "START_TYPES",
                ] + types + ["END_TYPES"]
            out += int(lines.count)
            for line in lines { out += string(line) }
            return out
        }

        /// One table-of-contents entry; the name is padded to a multiple of four like `WriteTOC`.
        static func toc(_ name: String = ":", values: (Int, Int, Int) = (0, 0, 0)) -> [UInt8] {
            var padded = Array(name.utf8)
            padded += [UInt8](repeating: 0, count: (4 - padded.count % 4) % 4)
            return int(padded.count) + padded + uint64(values.0) + uint64(values.1)
                + uint64(values.2)
        }

        static func record(type: Int, id: Int = 1, payload: [UInt8]) -> [UInt8] {
            int(type) + int(id) + int(payload.count) + payload
        }

        /// A label: its size (itself included), the records, the end of attributes, the children.
        static func label(records: [[UInt8]] = [], children: [(tag: Int, label: [UInt8])] = [])
            -> [UInt8]
        {
            var body = records.flatMap { $0 } + int(-1)
            for child in children { body += int(child.tag) + child.label }
            body += int(-2)
            return uint64(8 + body.count) + body
        }

        /// The whole file: header, info, an empty comment section, then `data` from `edata`.
        static func file(types: [String], data: [UInt8]) -> [UInt8] {
            let info = info(types: types)
            let endOfInfo = 7 + 13 * 4 + info.count
            let afterComment = endOfInfo + 4
            let header = [
                0x0403_0201, 7, endOfInfo, endOfInfo, afterComment, -1, -1, -1, -1, -1, -1, -1,
                afterComment,
            ]
            return Array("BINFILE".utf8) + header.flatMap { int($0) } + info + int(0) + data
        }
    }

    private static let types = [
        "TDataStd_Integer", "TDF_Reference", "TDataStd_IntegerArray", "TDataStd_RealArray",
        "TDataStd_ExtStringArray", "TDataStd_ByteArray", "TDataStd_BooleanArray",
        "TDataStd_ReferenceArray", "TDataStd_IntegerList", "TDataStd_RealList",
        "TDataStd_BooleanList",
        // The shape section is read through this attribute's driver, which the driver table holds
        // only for a type the file names.
        "TNaming_NamedShape",
    ]

    /// The 1-based type number a record uses.
    private static func typeNumber(_ name: String) -> Int {
        guard let index = types.firstIndex(of: name) else { fatalError("no type \(name)") }
        return index + 1
    }

    /// A document with `records` on one label: TOC end marker, root tag, the label tree.
    private static func document(records: [[UInt8]]) -> [UInt8] {
        let root = Blob.label(children: [(1, Blob.label(records: records))])
        return Blob.file(types: types, data: Blob.toc() + Blob.int(0) + root)
    }

    private static func document(kind: String, payload: [UInt8]) -> [UInt8] {
        document(records: [Blob.record(type: typeNumber(kind), payload: payload)])
    }

    /// A document whose only TOC entries name a shape section holding `section`.
    private static func document(shapeSection section: [UInt8]) -> [UInt8] {
        func build(_ offset: Int) -> [UInt8] {
            Blob.file(
                types: types,
                data: Blob.toc("SHAPE_SECTION_POS:", values: (offset, section.count, 0))
                    + Blob.toc() + Blob.int(0)
                    + Blob.label(
                        children: [
                            (1, Blob.label(records: [Blob.record(type: 1, payload: Blob.int(7))]))
                        ]))
        }
        return build(build(0).count) + section
    }

    private func path(_ name: String) -> String {
        NSTemporaryDirectory() + "ocafdata_\(UUID().uuidString)_\(name)"
    }

    private func write(_ bytes: [UInt8]) throws -> String {
        let p = path("case.cbf")
        try #require(FileManager.default.createFile(atPath: p, contents: Data(bytes)), "write \(p)")
        return p
    }

    private func load(_ bytes: [UInt8]) throws -> (document: Document?, status: ReaderStatus) {
        let p = try write(bytes)
        defer { try? FileManager.default.removeItem(atPath: p) }
        return Document.loadOCAFSkippingPreOpenGuard(from: p)
    }

    #if canImport(Darwin)
        /// Bytes the malloc zones hold now.
        ///
        /// A declared span that was allocated stays in this count for as long as the loaded
        /// document holds it.
        private func heapInUse() -> Int {
            var stats = malloc_statistics_t()
            malloc_zone_statistics(nil, &stats)
            return Int(stats.size_in_use)
        }
    #endif

    // MARK: - Declared spans (patch 0071)

    /// One array or list attribute whose record declares a span far larger than it holds.
    ///
    /// `retained` is the size, in bytes, an unpatched kernel leaves allocated in the loaded
    /// document: the attribute keeps the array it allocated, or the list nodes it appended.
    private struct SpanCase: Sendable {
        let kind: String
        let span: Int
        let retained: Int
    }

    /// What a refused record may allocate: far below the 128 MiB or more every unpatched case holds.
    private static let growthLimit = 64 << 20

    private static let spanCases: [SpanCase] = [
        SpanCase(
            kind: "TDataStd_IntegerArray", span: 1 << 26, retained: (1 << 26) * 4),
        SpanCase(
            kind: "TDataStd_RealArray", span: 1 << 25, retained: (1 << 25) * 8),
        SpanCase(
            kind: "TDataStd_ByteArray", span: 1 << 27, retained: 1 << 27),
        SpanCase(
            kind: "TDataStd_ExtStringArray", span: 1 << 24, retained: (1 << 24) * 16),
        SpanCase(
            kind: "TDataStd_ReferenceArray", span: 1 << 25, retained: (1 << 25) * 8),
        SpanCase(
            kind: "TDataStd_BooleanArray", span: 1 << 30, retained: 1 << 27),
        SpanCase(
            kind: "TDataStd_IntegerList", span: 1 << 23, retained: (1 << 23) * 16),
        SpanCase(
            kind: "TDataStd_RealList", span: 1 << 23, retained: (1 << 23) * 16),
        SpanCase(
            kind: "TDataStd_BooleanList", span: 1 << 23, retained: (1 << 23) * 16),
    ]

    @Test(
        "A declared array or list span the record cannot hold is refused before it is allocated",
        .enabled(if: OCAFBinaryDocumentDataKernelReadTests.isLocalKernel),
        .timeLimit(.minutes(2)))
    func declaredSpanIsBoundedByTheRecord() throws {
        for c in Self.spanCases {
            let bytes = Self.document(kind: c.kind, payload: Blob.ints(1, c.span))
            var result: (document: Document?, status: ReaderStatus) = (nil, .ok)
            #if canImport(Darwin)
                // The malloc zones are shared with every suite running beside this one, and their
                // allocations only ever add to the figure, so the smallest of three loads is the
                // one that measures this file. An unpatched kernel holds `retained` bytes on each.
                var smallest = Int.max
                for _ in 0..<3 {
                    result = (nil, .ok)  // release the last attempt's document before measuring
                    let before = heapInUse()
                    result = try load(bytes)
                    smallest = min(smallest, heapInUse() - before)
                    if smallest < Self.growthLimit { break }
                }
                #expect(
                    smallest < Self.growthLimit,
                    "\(c.kind) span \(c.span): the load allocated \(smallest) bytes (unpatched: \(c.retained))"
                )
            #else
                result = try load(bytes)
            #endif
            #expect(
                result.document != nil, "\(c.kind): the file still loads (the attribute is skipped)"
            )
            #expect(result.status == .ok, "\(c.kind): got \(result.status)")
            withExtendedLifetime(result.document) {}
        }
    }

    @Test(
        "A span the record does hold loads, so the bound is not a refusal of every array",
        .enabled(if: OCAFBinaryDocumentDataKernelReadTests.isLocalKernel))
    func recordedSpanLoads() throws {
        // The list and the byte array are read back through the document; the rest load. Tag 0 is
        // the document's Main label (`getLabelForTag`), 0:1, which is the child with tag 1 of the
        // root that `document(records:)` writes the records on.
        let list = try load(
            Self.document(kind: "TDataStd_IntegerList", payload: Blob.ints(1, 2, 5, 6)))
        let listed = try #require(list.document)
        #expect(list.status == .ok)
        #expect(listed.integerList(tag: 0) == [5, 6])

        let bytes = try load(
            Self.document(
                kind: "TDataStd_ByteArray", payload: Blob.ints(1, 4) + Array("abcd".utf8) + [0]))
        let bytesDoc = try #require(bytes.document)
        #expect(bytes.status == .ok)
        #expect(bytesDoc.byteArray(tag: 0) == Array("abcd".utf8))

        let others: [(kind: String, payload: [UInt8])] = [
            ("TDataStd_IntegerArray", Blob.ints(1, 3, 10, 20, 30) + [0]),
            ("TDataStd_RealArray", Blob.ints(1, 1) + [UInt8](repeating: 0, count: 8) + [0]),
            ("TDataStd_BooleanArray", Blob.ints(1, 11) + [0x24, 0x00]),
        ]
        for v in others {
            let (doc, status) = try load(Self.document(kind: v.kind, payload: v.payload))
            #expect(doc != nil && status == .ok, "\(v.kind): got \(status)")
        }
    }

    #if arch(wasm32)
        @Test(
            "A span no 32-bit address space can hold does not poison the allocator",
            .enabled(if: OCAFBinaryDocumentDataKernelReadTests.isLocalKernel))
        func spanPastTheAddressSpace() throws {
            for kind in [
                "TDataStd_IntegerArray", "TDataStd_RealArray", "TDataStd_ByteArray",
                "TDataStd_ExtStringArray", "TDataStd_ReferenceArray", "TDataStd_BooleanArray",
            ] {
                let (doc, status) = try load(
                    Self.document(kind: kind, payload: Blob.ints(1, Int(Int32.max))))
                #expect(doc != nil && status == .ok, "\(kind): got \(status)")
                // The failure #3477 describes: a refused allocation leaves every later one failing.
                #expect(Shape.box(width: 1, height: 1, depth: 1) != nil, "\(kind): allocator")
            }
        }
    #endif

    // MARK: - Tag counts (patch 0070)

    @Test(
        "A label with a tag count the record cannot hold returns",
        .enabled(if: OCAFBinaryDocumentDataKernelReadTests.isLocalKernel),
        .timeLimit(.minutes(1)))
    func tagCountIsBoundedByTheRecord() throws {
        // `count * 4` wraps from 2^29: to Int32.min, to 0 at 2^30, and to -4 at Int32.max. Each
        // passed the old test for room, and the loop then ran `count` times past the data.
        let reference = Self.typeNumber("TDF_Reference")
        for count in [1 << 20, 1 << 28, 1 << 29, 1 << 30, Int(Int32.max), -1] {
            let bytes = Self.document(records: [
                Blob.record(type: reference, payload: Blob.ints(count))
            ])
            let (doc, status) = try load(bytes)
            #expect(doc != nil && status == .ok, "tag count \(count): got \(status)")
        }
        // Control: no tags, and a tag list that is there in full.
        for payload in [Blob.ints(0), Blob.ints(2, 1, 1)] {
            let (doc, status) = try load(
                Self.document(records: [Blob.record(type: reference, payload: payload)]))
            #expect(doc != nil && status == .ok, "tag list \(payload.count) bytes: got \(status)")
        }
    }

    // MARK: - Table names (patch 0072)

    private static let shapeHeader = Array(
        "SHAPE_SECTION\nOpen CASCADE Topology V4, (c) Open Cascade\n".utf8)

    /// The tables a shape section holds, in the order the reader takes them, each empty.
    private static let shapeTables: [(name: String, text: String)] = [
        ("Locations", "Locations 0\n"), ("Curve2ds", "Curve2ds 0\n"), ("Curves", "Curves 0\n"),
        ("Polygon3D", "Polygon3D 0\n"), ("PolygonOnTriangulations", "PolygonOnTriangulations 0\n"),
        ("Surfaces", "Surfaces 0\n"), ("Triangulations", "Triangulations 0\n\n"),
        ("TShapes", ""),
    ]

    @Test(
        "A table name longer than the reader's buffer is refused, not written past it",
        .enabled(if: OCAFBinaryDocumentDataKernelReadTests.isLocalKernel),
        .timeLimit(.minutes(1)))
    func tableNameTokenIsBoundedByTheBuffer() throws {
        // Five of the eight tables read their own name into a 255 byte buffer: the ones named here.
        for name in ["Locations", "Curve2ds", "Curves", "Surfaces", "TShapes"] {
            let at = try #require(Self.shapeTables.firstIndex { $0.name == name })
            let before = Self.shapeTables[..<at].flatMap { Array($0.text.utf8) }
            for size in [4096, 1 << 16] {
                let section = Self.shapeHeader + before + [UInt8](repeating: 0x41, count: size)
                let (doc, status) = try load(Self.document(shapeSection: section))
                #expect(doc != nil, "\(size) byte token as the name of \(name): \(status)")
            }
        }
    }

    @Test(
        "A megabyte table name returns",
        .enabled(if: OCAFBinaryDocumentDataKernelReadTests.isLocalKernel),
        .timeLimit(.minutes(1)))
    func megabyteTableName() throws {
        let section = Self.shapeHeader + [UInt8](repeating: 0x41, count: 1 << 20)
        let (doc, status) = try load(Self.document(shapeSection: section))
        #expect(doc != nil, "got \(status)")
    }
}
