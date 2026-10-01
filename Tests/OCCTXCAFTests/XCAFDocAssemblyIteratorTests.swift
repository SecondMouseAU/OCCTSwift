import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc AssemblyIterator Tests")
struct XCAFDocAssemblyIteratorTests {

    // #766: `count >= 1` and `count >= 3` behind `guard let ... else { return }` meant a walk
    // that over-counted, double-visited, or failed to build its document all passed. The counts
    // below were measured; see `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.
    // #964: nil means the 100,000-item bound was reached, which a one-box document cannot do.
    @Test func iterateAssembly() throws {
        let doc = try #require(Document.create())
        #expect(doc.assemblyItemCount() == 0, "an empty document has nothing to walk")

        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        doc.addShape(box)
        #expect(doc.assemblyItemCount() == 1)
    }

    /// #964: a document small enough to walk completely reports a count, never `nil`.
    ///
    /// Before the fix this could not be asserted at all, the method returned `Int`, so
    /// "counted 100,001" and "gave up at 100,001" were the same value.
    @Test func smallAssemblyCountIsComplete() throws {
        let doc = try #require(Document.create())
        for i in 1...3 {
            let box = try #require(Shape.box(width: Double(i), height: 1, depth: 1))
            doc.addShape(box)
        }
        // One item per free shape, exactly: a 3-shape document is far inside the bound, so it
        // must not report truncation, and it must not report a different number either.
        #expect(doc.assemblyItemCount() == 3)
    }
}
