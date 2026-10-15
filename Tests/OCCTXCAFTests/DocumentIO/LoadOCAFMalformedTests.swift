import Foundation
import Testing

@testable import OCCTSwift

// #3318: Document.loadOCAF(from:) took the process down with SIGSEGV on an empty or non-OCAF file,
// inside BinLDrivers_DocumentRetrievalDriver::Read (null Storage_HeaderData). A crash cannot be
// caught in-process, so each case below is simply "the call returns": reaching the #expect at all
// is the regression signal, and the statuses pin the contract. No Process/Dispatch/Thread, so the
// suite also runs on WASI.
@Suite("Issue 3318 loadOCAF on malformed files")
struct Issue3318LoadOCAFMalformedTests {

    private func write(_ bytes: [UInt8], name: String) -> String {
        let path = NSTemporaryDirectory() + "issue3318_\(name)"
        // A failed write would make the malformed-file read below meaningless.
        #expect(
            FileManager.default.createFile(atPath: path, contents: Data(bytes)),
            "setup: write \(name)")
        return path
    }

    private func expectRefused(_ path: String, _ label: String) {
        let (doc, status) = Document.loadOCAF(from: path)
        #expect(doc == nil, "\(label): a malformed file must not load")
        #expect(status == .driverFailure, "\(label): got \(status)")
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("Empty files of every OCAF extension return driverFailure")
    func emptyFile() {
        for ext in ["xbf", "cbf", "xml", "dat"] {
            expectRefused(write([], name: "empty.\(ext)"), "empty .\(ext)")
        }
    }

    @Test("A plain text file returns driverFailure")
    func textFile() {
        for ext in ["xbf", "xml"] {
            expectRefused(
                write(Array("hello, this is not OCAF\n".utf8), name: "text.\(ext)"), "text .\(ext)")
        }
    }

    @Test("A bare BINFILE header returns driverFailure")
    func headerOnly() {
        expectRefused(write(Array("BINFILE".utf8), name: "header.xbf"), "bare header")
    }

    @Test("A real binary header followed by garbage returns driverFailure")
    func headerThenGarbage() throws {
        let doc = try #require(
            Document.create(format: "BinOcaf"), "could not create a BinOcaf document")
        let label = try #require(doc.createLabel(), "could not create label")
        #expect(label.setInteger(7))
        let src = NSTemporaryDirectory() + "issue3318_real.cbf"
        defer { try? FileManager.default.removeItem(atPath: src) }
        #expect(doc.saveOCAF(to: src) == .ok)
        let full = try #require(
            FileManager.default.contents(atPath: src), "the saved file is missing")
        try #require(full.count > 64, "the saved file is too short")
        // Keep the magic number and a few header bytes, then 200 bytes of 0xFF.
        let garbled = Array(full.prefix(16)) + [UInt8](repeating: 0xFF, count: 200)
        expectRefused(write(garbled, name: "garbled.xbf"), "header + garbage")
        // Truncated mid-header.
        expectRefused(write(Array(full.prefix(full.count / 2)), name: "truncated.xbf"), "truncated")
    }

    // Measured against OCCT with the guard off (Scripts/repro/3318/probe.mm): an XML file whose root
    // `format` names a Bin* format is handed to the binary reader and dies with SIGSEGV (null
    // Storage_HeaderData), and an XML declaration with no closing `?>` makes LDOM spin forever.
    // Every case here must come back as driverFailure; one test walks a list of plain Strings.
    @Test("XML that is not an OCAF document returns driverFailure")
    func xmlNotOcaf() {
        let cases: [String] = [
            "<?xml version=\"1.0\"?>\n<not-ocaf/>",
            "<?xml version=\"1.0\"?>",
            "<?xml version=\"1.0\"?>\n<document format=\"BinOcaf\"><label tag=\"0\"/></document>",
            "<?xml version=\"1.0\"?>\n<document format=\"BinXCAF\"></document>",
            "<?xml version=\"1.0\"?>\n<!-- <document format=\"XmlOcaf\"> -->\n<document format=\"BinOcaf\"></document>",
            "<?xml version=\"1.0\"?>\n<document><label tag=\"0\"/></document>",
            "<?xml version=\"1.0\"?>\n<document format=\"\"></document>",
            "<?xml version=\"1.0\"?>\n<document format=\"Unknown\"></document>",
            "<?xml version=\"1.0\"?>\n<!-- never closed",
            "<?xml version=\"1.0\"?>\n<document format=\"XmlOcaf\"",
            "<?xml",
            "<?xml version=\"1.0\"",
            "<document format=\"BinOcaf\"><label tag=\"0\"/></document>",
            "<document format=\"XmlOcaf\"",
            "<!DOCTYPE document [ <!ENTITY e \"unterminated",
        ]
        for (index, text) in cases.enumerated() {
            expectRefused(write(Array(text.utf8), name: "notocaf\(index).xml"), "xml case \(index)")
        }
    }

    @Test("Every prefix of a saved XML document returns without hanging or crashing")
    func xmlTruncations() throws {
        let doc = try #require(
            Document.create(format: "XmlOcaf"), "could not create an XmlOcaf document")
        let label = try #require(doc.createLabel(), "could not create label")
        #expect(label.setInteger(7))
        let src = NSTemporaryDirectory() + "issue3318_prefix_src.xml"
        defer { try? FileManager.default.removeItem(atPath: src) }
        #expect(doc.saveOCAF(to: src) == .ok)
        let full = try #require(
            FileManager.default.contents(atPath: src), "the saved file is missing")
        try #require(full.count > 64, "the saved file is too short")
        let path = NSTemporaryDirectory() + "issue3318_prefix.xml"
        defer { try? FileManager.default.removeItem(atPath: path) }
        // Prefixes that end inside the declaration used to hang LDOM. Only a prefix that reaches the
        // closing tag is a complete document; the complete file itself (length == count) is included.
        for length in 0...full.count {
            #expect(
                FileManager.default.createFile(atPath: path, contents: full.prefix(length)),
                "setup: write prefix of length \(length)")
            let text = String(decoding: full.prefix(length), as: UTF8.self)
            let complete = text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(
                "</document>")
            let (loaded, status) = Document.loadOCAF(from: path)
            #expect(
                (loaded != nil && status == .ok) == complete,
                "prefix \(length) of \(full.count): complete=\(complete), got \(status)")
        }
        let (whole, wholeStatus) = Document.loadOCAF(from: src)
        #expect(
            whole != nil && wholeStatus == .ok, "the complete saved file must load: \(wholeStatus)")
    }

    // The guard must never refuse an XML OCAF file OCCT loads. Each variant below was measured to
    // load (status ok) through TDocStd_Application::Open with the guard absent: a prolog far past
    // 64 KB, a DOCTYPE with an internal subset (and a '>' inside a quoted entity), a BOM, CRLF,
    // single-quoted attributes, and no XML declaration at all.
    @Test("Valid XML OCAF documents with unusual prologs still load")
    func xmlValidVariants() throws {
        let doc = try #require(
            Document.create(format: "XmlOcaf"), "could not create an XmlOcaf document")
        let label = try #require(doc.createLabel(), "could not create label")
        #expect(label.setInteger(7))
        let src = NSTemporaryDirectory() + "issue3318_variants_src.xml"
        defer { try? FileManager.default.removeItem(atPath: src) }
        #expect(doc.saveOCAF(to: src) == .ok)
        let data = try #require(
            FileManager.default.contents(atPath: src), "the saved file is missing")
        let original = String(decoding: data, as: UTF8.self)
        let newline = try #require(original.firstIndex(of: "\n"), "no newline in the saved file")
        let declaration = String(original[..<newline])
        let body = String(original[original.index(after: newline)...])
        let bigComment = "<!--" + String(repeating: "x", count: 100_000) + "-->"
        let variants: [String] = [
            declaration + "\n" + bigComment + "\n" + body,
            declaration + "\n<!-- note -->\n" + body,
            declaration + "\n<!DOCTYPE document>\n" + body,
            declaration + "\n<!DOCTYPE document [ <!ELEMENT document ANY> ]>\n" + body,
            declaration + "\n<!DOCTYPE document [ <!ENTITY e \"a>b\"> ]>\n" + body,
            declaration + "\n<?note kept?>\n" + body,
            declaration + "\n"
                + body.replacingOccurrences(of: "format=\"XmlOcaf\"", with: "format = 'XmlOcaf'"),
            original.replacingOccurrences(of: "\n", with: "\r\n"),
            "\u{FEFF}" + original,
            "\n\n" + original,
            body,
        ]
        for (index, text) in variants.enumerated() {
            let path = write(Array(text.utf8), name: "variant\(index).xml")
            defer { try? FileManager.default.removeItem(atPath: path) }
            let (loaded, status) = Document.loadOCAF(from: path)
            #expect(status == .ok, "variant \(index): got \(status)")
            #expect(loaded != nil, "variant \(index) must load")
        }
    }

    @Test("A missing file still reports its own status and a valid file still loads")
    func unchangedPaths() throws {
        let (missing, status) = Document.loadOCAF(from: "/nonexistent/issue3318.xbf")
        #expect(missing == nil)
        #expect(status == .unknownDocument)

        for fmt in ["BinOcaf", "XmlOcaf"] {
            let doc = try #require(
                Document.create(format: fmt), "could not create a \(fmt) document")
            let label = try #require(doc.createLabel(), "could not create label for \(fmt)")
            let path =
                NSTemporaryDirectory() + "issue3318_valid_\(fmt)."
                + (fmt == "BinOcaf" ? "cbf" : "xml")
            defer { try? FileManager.default.removeItem(atPath: path) }
            #expect(label.setInteger(7))
            #expect(doc.saveOCAF(to: path) == .ok)
            let (loaded, readStatus) = Document.loadOCAF(from: path)
            #expect(readStatus == .ok, "\(fmt)")
            #expect(loaded != nil, "\(fmt)")
        }
    }
}
