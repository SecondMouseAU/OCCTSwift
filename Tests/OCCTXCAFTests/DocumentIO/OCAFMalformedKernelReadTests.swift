import Foundation
import Testing

@testable import OCCTSwift

// #3330 (follow-up to #3318): the kernel's own OCAF readers faulted on a damaged file.
// `Document.loadOCAF(from:)` hides that behind a pre-open guard, so every case here goes through
// `Document.loadOCAFSkippingPreOpenGuard(from:)`, which hands the file straight to
// `TDocStd_Application::Open`. A fault is an uncatchable SIGSEGV or a loop that never ends, so
// "the call returns" is the regression signal and the statuses pin the contract.
//
// Three defects sit behind it, all fixed by carried patch 0069 (which `v4.0.0-kernel.7` is the
// first asset to hold; a kernel without it kills the test process):
//  - `BinLDrivers_DocumentRetrievalDriver::Read` dereferenced the null header of a file no storage
//    reader recognised (empty, text);
//  - `PCDM_ReadWriter::FileFormat(filename)` read `Types()->Value(1)` of an empty types table;
//  - `FSD_BinaryFile::ReadCompleteInfo` read sections of a damaged header through a null array,
//    and looped for ever on a position no section starts at.
//
// The inputs are generated from a real saved document, not shipped as fixtures, so the suite also
// runs wherever a document can be saved. No Process/Dispatch/Thread.
//
// Not covered, and not the same defect: an XML prefix that ends inside the XML declaration, or an
// XML file with binary garbage appended, spins LDOM (the hang #3318's bridge guard refuses), and a
// flipped byte in the object count of a binary header makes `Storage_InternalData` allocate an
// array of billions of handles.
@Suite("OCAF readers report a damaged file instead of faulting")
struct OCAFMalformedKernelReadTests {

    private static let binaryFormats = ["BinOcaf", "BinXCAF"]
    private static let xmlFormats = ["XmlOcaf", "XmlXCAF"]

    private func path(_ name: String) -> String {
        // Unique per call: the suite's tests run in parallel and would overwrite one another's file.
        NSTemporaryDirectory() + "ocafmalformed_\(UUID().uuidString)_\(name)"
    }

    /// The bytes of a document of `format` holding one integer attribute.
    ///
    /// The extension a format saves under is part of what `saveOCAF(to:)` accepts: BinOcaf is
    /// `.cbf` and BinXCAF `.xbf`, and a path with another extension is not written.
    private func savedBytes(format: String) throws -> [UInt8] {
        let ext = ["BinOcaf": "cbf", "BinXCAF": "xbf", "XmlOcaf": "xml", "XmlXCAF": "xml"][format]
        let fileExtension = try #require(ext, "no extension for \(format)")
        let doc = try #require(Document.create(format: format), "no \(format) document")
        let label = try #require(doc.createLabel(), "no label for \(format)")
        #expect(label.setInteger(7))
        let src = path("source_\(format).\(fileExtension)")
        defer { try? FileManager.default.removeItem(atPath: src) }
        #expect(doc.saveOCAF(to: src) == .ok)
        let data = try #require(FileManager.default.contents(atPath: src), "\(format): not saved")
        try #require(data.count > 120, "\(format): the saved file is too short")
        return Array(data)
    }

    private func open(_ bytes: [UInt8], ext: String) -> (loaded: Bool, status: ReaderStatus) {
        let p = path("case.\(ext)")
        defer { try? FileManager.default.removeItem(atPath: p) }
        FileManager.default.createFile(atPath: p, contents: Data(bytes))
        let (doc, status) = Document.loadOCAFSkippingPreOpenGuard(from: p)
        return (doc != nil, status)
    }

    private func expectRefused(_ bytes: [UInt8], ext: String, _ label: String) {
        let (loaded, status) = open(bytes, ext: ext)
        #expect(!loaded, "\(label): a damaged file must not load")
        #expect(status != .ok, "\(label): got \(status)")
    }

    @Test(
        "An empty, text or magic-only file is refused with a status")
    func emptyAndText() {
        let cases: [(name: String, bytes: [UInt8])] = [
            ("empty", []),
            ("text", Array("hello, this is not OCAF\n".utf8)),
            ("magic only", Array("BINFILE".utf8)),
            ("magic and newline", Array("BINFILE\n".utf8)),
            ("all 0xFF", [UInt8](repeating: 0xFF, count: 400)),
            ("all zero", [UInt8](repeating: 0x00, count: 400)),
            ("magic then every byte value", Array("BINFILE".utf8) + (0...255).map { UInt8($0) }),
            ("magic then 0xFF", Array("BINFILE\n".utf8) + [UInt8](repeating: 0xFF, count: 500)),
        ]
        for ext in ["xbf", "cbf", "dat"] {
            for c in cases {
                expectRefused(c.bytes, ext: ext, "\(c.name) .\(ext)")
            }
        }
        // The empty-file case is the null header: the reader's own status, not the guard's.
        let (_, status) = open([], ext: "xbf")
        #expect(status == .formatFailure, "empty .xbf: got \(status)")
    }

    @Test(
        "Every prefix of a saved binary document returns, and a short one is refused")
    func truncations() throws {
        for format in Self.binaryFormats {
            let full = try savedBytes(format: format)
            for length in 0..<full.count {
                let (loaded, status) = open(Array(full.prefix(length)), ext: "xbf")
                // A prefix that keeps the whole header can still load, as an empty document: OCCT
                // stops reading at the end of the stream and answers ok (measured from 59 bytes on).
                // Inside the header it must not.
                if length < 50 {
                    #expect(!loaded, "\(format) prefix \(length): loaded")
                    #expect(status != .ok, "\(format) prefix \(length): got \(status)")
                } else if loaded {
                    #expect(status == .ok, "\(format) prefix \(length): got \(status)")
                }
            }
            let (whole, wholeStatus) = open(full, ext: "xbf")
            #expect(whole && wholeStatus == .ok, "\(format): the whole file: \(wholeStatus)")
        }
    }

    @Test(
        "A real header followed by garbage is refused")
    func headerThenGarbage() throws {
        for format in Self.binaryFormats {
            let full = try savedBytes(format: format)
            for keep in [8, 16, 24, 40, 64, 100] {
                for fill: UInt8 in [0xFF, 0x00] {
                    let bytes = Array(full.prefix(keep)) + [UInt8](repeating: fill, count: 200)
                    let label = "\(format) header \(keep) + 0x\(String(fill, radix: 16))"
                    expectRefused(bytes, ext: "xbf", label)
                }
            }
        }
    }

    // A binary document under an XML name, an XML document under a binary name, and an XML file
    // whose `format` names a binary format. OCCT chooses the reader from the content, so the
    // first two load; the last reaches the binary reader with no header.
    @Test(
        "A document under the wrong extension, or in the wrong format, returns")
    func wrongFormat() throws {
        for format in Self.binaryFormats {
            let bytes = try savedBytes(format: format)
            for ext in ["xml", "cbf", "dat"] {
                let (loaded, status) = open(bytes, ext: ext)
                #expect(loaded == (status == .ok), "\(format) as .\(ext): got \(status)")
            }
        }
        for format in Self.xmlFormats {
            let bytes = try savedBytes(format: format)
            for ext in ["xbf", "cbf", "dat"] {
                let (loaded, status) = open(bytes, ext: ext)
                #expect(loaded == (status == .ok), "\(format) as .\(ext): got \(status)")
            }
        }
        let xmlNamingBinary: [String] = [
            "<?xml version=\"1.0\"?>\n<document format=\"BinOcaf\"><label tag=\"0\"/></document>",
            "<?xml version=\"1.0\"?>\n<document format=\"BinXCAF\"></document>",
        ]
        for text in xmlNamingBinary {
            expectRefused(Array(text.utf8), ext: "xml", "xml naming a binary format")
        }
    }

    // OCCT is lenient here too: a prefix that is only the declaration loads as an empty document, and
    // so does one cut mid-element, so the contract is that the call returns and that a document is
    // handed back only with status ok.
    @Test(
        "A prefix of a saved XML document that clears its declaration returns")
    func xmlPrefixes() throws {
        for format in Self.xmlFormats {
            let full = try savedBytes(format: format)
            let text = String(decoding: full, as: UTF8.self)
            let declarationEnd = try #require(
                text.range(of: "?>"), "\(format): no XML declaration"
            ).upperBound
            let start = text.utf8.distance(from: text.startIndex, to: declarationEnd)
            for length in start..<full.count {
                let (loaded, status) = open(Array(full.prefix(length)), ext: "xml")
                #expect(loaded == (status == .ok), "\(format) prefix \(length): got \(status)")
            }
        }
    }

    @Test(
        "A valid saved document still loads in every format")
    func validStillLoads() throws {
        for format in Self.binaryFormats {
            let (loaded, status) = open(try savedBytes(format: format), ext: "xbf")
            #expect(loaded && status == .ok, "\(format): got \(status)")
        }
        for format in Self.xmlFormats {
            let (loaded, status) = open(try savedBytes(format: format), ext: "xml")
            #expect(loaded && status == .ok, "\(format): got \(status)")
        }
    }
}
