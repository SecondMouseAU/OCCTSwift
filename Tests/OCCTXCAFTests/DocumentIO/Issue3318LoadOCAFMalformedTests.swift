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
        FileManager.default.createFile(atPath: path, contents: Data(bytes))
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
    func headerThenGarbage() {
        guard let doc = Document.create(format: "BinOcaf"), let label = doc.createLabel() else {
            Issue.record("could not create a BinXCAF document")
            return
        }
        #expect(label.setInteger(7))
        let src = NSTemporaryDirectory() + "issue3318_real.cbf"
        defer { try? FileManager.default.removeItem(atPath: src) }
        #expect(doc.saveOCAF(to: src) == .ok)
        guard let full = FileManager.default.contents(atPath: src), full.count > 64 else {
            Issue.record("the saved file is missing or too short")
            return
        }
        // Keep the magic number and a few header bytes, then 200 bytes of 0xFF.
        let garbled = Array(full.prefix(16)) + [UInt8](repeating: 0xFF, count: 200)
        expectRefused(write(garbled, name: "garbled.xbf"), "header + garbage")
        // Truncated mid-header.
        expectRefused(write(Array(full.prefix(full.count / 2)), name: "truncated.xbf"), "truncated")
    }

    @Test("Garbage after an XML declaration does not crash")
    func xmlGarbage() {
        let path = write(Array("<?xml version=\"1.0\"?>\n<not-ocaf/>".utf8), name: "garbage.xml")
        defer { try? FileManager.default.removeItem(atPath: path) }
        // OCCT's XML retrieval answers this one itself; the contract here is that it returns.
        let (doc, status) = Document.loadOCAF(from: path)
        #expect(doc != nil || status != .ok)
    }

    @Test("A missing file still reports its own status and a valid file still loads")
    func unchangedPaths() {
        let (missing, status) = Document.loadOCAF(from: "/nonexistent/issue3318.xbf")
        #expect(missing == nil)
        #expect(status == .unknownDocument)

        for fmt in ["BinOcaf", "XmlOcaf"] {
            guard let doc = Document.create(format: fmt), let label = doc.createLabel() else {
                Issue.record("could not create a \(fmt) document")
                continue
            }
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
