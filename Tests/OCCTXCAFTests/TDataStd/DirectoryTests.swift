import Foundation
import Testing

@testable import OCCTSwift

// #766: all four tests sat inside `if let doc = Document.create()`, so a failure to build the
// document was a pass, and three of them asserted only a bare Bool or `!= nil`. The tags below
// were measured; see `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("TDataStd_Directory Tests")
struct DirectoryTests {
    @Test func createDirectory() throws {
        let doc = try #require(Document.create())
        #expect(!doc.hasDirectory(at: 100))
        #expect(doc.createDirectory(at: 100))
        // The Bool on its own proves nothing: read the attribute back, and confirm it landed on
        // the tag asked for and not on some other label.
        #expect(doc.hasDirectory(at: 100))
        #expect(!doc.hasDirectory(at: 101))
        #expect(!doc.hasDirectory(at: 0))
    }

    @Test func findDirectory() throws {
        let doc = try #require(Document.create())
        #expect(doc.createDirectory(at: 100))
        #expect(doc.hasDirectory(at: 100))
        #expect(!doc.hasDirectory(at: 99))
    }

    @Test func addSubDirectory() throws {
        let doc = try #require(Document.create())
        #expect(doc.createDirectory(at: 100))
        // Measured: children are tagged from 1 upward under the directory label, so the first
        // sub-directory is tag 1 and the second is tag 2. `childTag != nil` could not tell a
        // real child from a repeated one.
        #expect(doc.addSubDirectory(under: 100) == 1)
        #expect(doc.addSubDirectory(under: 100) == 2)
        // A label with no directory attribute is refused rather than given a child.
        #expect(doc.addSubDirectory(under: 200) == nil)
    }

    @Test func makeObjectLabel() throws {
        let doc = try #require(Document.create())
        #expect(doc.createDirectory(at: 100))
        // Object labels share the directory's child-tag counter with sub-directories.
        #expect(doc.makeObjectLabel(under: 100) == 1)
        #expect(doc.addSubDirectory(under: 100) == 2)
        #expect(doc.makeObjectLabel(under: 100) == 3)
        #expect(doc.makeObjectLabel(under: 201) == nil)
    }
}
