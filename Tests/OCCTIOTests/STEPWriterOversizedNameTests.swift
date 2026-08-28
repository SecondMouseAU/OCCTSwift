import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #323 (OCCT#1318): STEP writer must not hang on an oversized unbroken name

@Suite("STEP writer survives an oversized unbroken name (#323, OCCT#1318)")
struct STEPWriterOversizedNameTests {

    /// `StepData_StepWriter::AddString` writes a raw token into a fixed 72-character line
    /// buffer, flushing and resetting the buffer whenever the pending text won't fit. A single
    /// unbroken token longer than 72 characters (e.g. a long, space-free part name) used to hang
    /// this check forever: no amount of flushing ever makes room for text that can't fit in a
    /// full, empty line either. Fixed upstream by splitting the token across as many lines as
    /// needed instead of looping on a flush check that can never succeed. No #expect needed for
    /// the hang itself, a regression would wedge the whole test process; reaching the assertions
    /// below is the real assertion.
    @Test("A STEP export with a >72-char unbroken name completes and preserves the name")
    func oversizedUnbrokenNameDoesNotHang() throws {
        let longName = String(
            (0..<150).map { i in
                Character(UnicodeScalar(65 + i % 26)!)
            })
        #expect(longName.count > 72)

        let box = Shape.box(width: 1, height: 1, depth: 1)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt-323-oversized-name-\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }

        try box.writeSTEP(to: url, name: longName)

        let text = try String(contentsOf: url, encoding: .utf8)
        let flattened = text.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        #expect(flattened.contains(longName), "name split/corrupted across continuation lines")
        _ = try Shape.load(from: url)
    }
}
