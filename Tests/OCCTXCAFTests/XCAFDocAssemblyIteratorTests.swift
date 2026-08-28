import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc AssemblyIterator Tests")
struct XCAFDocAssemblyIteratorTests {

    @Test func iterateAssembly() {
        guard let doc = Document.create() else { return }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        doc.addShape(box)
        // #964: nil means the 100,000-item bound was reached, which a one-box document cannot do.
        let count = doc.assemblyItemCount()
        #expect(count != nil)
        if let count { #expect(count >= 1) }
    }

    /// #964: a document small enough to walk completely reports a count, never `nil`. Before the
    /// fix this could not be asserted at all, the method returned `Int`, so "counted 100,001" and
    /// "gave up at 100,001" were the same value.
    @Test func smallAssemblyCountIsComplete() {
        guard let doc = Document.create() else { return }
        for i in 1...3 {
            guard let box = Shape.box(width: Double(i), height: 1, depth: 1) else { return }
            doc.addShape(box)
        }
        let count = doc.assemblyItemCount()
        #expect(
            count != nil,
            "a 3-shape document is far inside the bound, so it must not report truncation")
        if let count { #expect(count >= 3) }
    }
}
