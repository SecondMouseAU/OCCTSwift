import Testing
import Foundation
@testable import OCCTSwift

// #173: Exporter.writeSTEPAssembly writes a product-structured (instanced) STEP —
// one part product referenced by N located occurrences, not N geometry copies.
@Suite("Issue #173 — instanced assembly STEP writer")
struct Issue173AssemblySTEP {

    /// Build a document with one unique part placed at `n` distinct X offsets.
    private func makeInstancedDoc(n: Int) -> Document? {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let partId = doc.addShape(box, makeAssembly: false)
        let asmId = doc.newShapeLabel()
        for i in 0..<n {
            let m: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1, Double(i) * 20, 0, 0]
            _ = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: partId, matrix: m)
        }
        doc.updateAssemblies()
        return doc
    }

    @Test("geometry is shared: 1 BREP + N occurrences, size scales with unique parts")
    func instancedStructure() throws {
        let n = 20
        guard let doc = makeInstancedDoc(n: n) else { #expect(Bool(false)); return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("issue173_asm.step")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTEPAssembly(doc, to: url)

        let text = try String(contentsOf: url, encoding: .utf8)
        func count(_ s: String) -> Int { text.components(separatedBy: s).count - 1 }
        // One unique part definition → exactly one solid BREP, regardless of placements.
        #expect(count("MANIFOLD_SOLID_BREP") == 1)
        // N located component occurrences.
        #expect(count("NEXT_ASSEMBLY_USAGE_OCCURRENCE") == n)
    }

    @Test("round-trips: written assembly reads back with the same occurrence count")
    func roundTrip() throws {
        let n = 8
        guard let doc = makeInstancedDoc(n: n) else { #expect(Bool(false)); return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("issue173_rt.step")
        defer { try? FileManager.default.removeItem(at: url) }

        try Exporter.writeSTEPAssembly(doc, to: url)

        let reloaded = try Document.loadSTEP(from: url)
        // The loaded tree should expose an assembly node whose component children
        // count equals the number of placements we wrote.
        var maxChildren = 0
        func walk(_ node: AssemblyNode) {
            maxChildren = max(maxChildren, node.children.count)
            for c in node.children { walk(c) }
        }
        for r in reloaded.rootNodes { walk(r) }
        #expect(maxChildren == n)
    }

    @Test("empty path throws, not crashes")
    func emptyPathThrows() throws {
        guard let doc = makeInstancedDoc(n: 2) else { #expect(Bool(false)); return }
        #expect(throws: Exporter.ExportError.self) {
            try Exporter.writeSTEPAssembly(doc, to: URL(fileURLWithPath: ""))
        }
    }
}
