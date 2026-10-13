import Foundation
import Testing

@testable import OCCTSwift

// MARK: - STEPCAFControl Mode-Controlled Import/Export Tests (v0.58.0)

@Suite("STEP CAF Mode Control")
struct STEPCAFModeControlTests {

    /// A STEP file of a 10 x 20 x 30 box named "Bracket", coloured red, on layer "L1".
    ///
    /// The previous tests wrote a bare box, which has no name, colour or layer to keep or drop,
    /// so a reader mode could not be seen working (#3332). Each caller gets its own file.
    private func makeDecoratedSTEP() throws -> URL {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let source = try #require(Document.create())
        _ = source.addShape(box)
        let node = try #require(source.rootNodes.first)
        _ = node.setName("Bracket")
        node.setColor(Color(red: 1, green: 0, blue: 0))
        node.setLayer("L1")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swift_test_v58_caf_\(UUID()).step")
        try #require(source.writeSTEP(to: url, modelType: .asIs))
        return url
    }

    private func expectRed(_ color: Color?) {
        guard let color else {
            Issue.record("expected the red surface colour, got nil")
            return
        }
        #expect(abs(color.red - 1) < 1e-6)
        #expect(abs(color.green) < 1e-6)
        #expect(abs(color.blue) < 1e-6)
    }

    private func expectBox(_ doc: Document) throws {
        let shape = try #require(doc.allShapes().first)
        #expect(shape.shapeType == .solid)
        #expect(abs((shape.volume ?? 0) - 6000) < 1e-6)
    }

    @Test("Load STEP with default modes")
    func loadWithDefaultModes() throws {
        let url = try makeDecoratedSTEP()
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try #require(Document.loadSTEP(from: url, modes: STEPReaderModes()))
        #expect(doc.rootNodes.count == 1)
        let node = try #require(doc.rootNodes.first)
        // Defaults read the name, colour and layer back.
        #expect(node.name == "Bracket")
        expectRed(node.color)
        #expect(node.layers == ["L1"])
        try expectBox(doc)
    }

    @Test("Load STEP with GDT mode enabled")
    func loadWithGDTMode() throws {
        let url = try makeDecoratedSTEP()
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try #require(Document.loadSTEP(from: url, modes: STEPReaderModes(gdt: true)))
        // GD&T mode adds the dimension and tolerance reader; the file has none, so what comes
        // back is the same document as with the defaults.
        #expect(doc.rootNodes.count == 1)
        let node = try #require(doc.rootNodes.first)
        #expect(node.name == "Bracket")
        expectRed(node.color)
        try expectBox(doc)
    }

    @Test("Load STEP with names disabled")
    func loadWithNamesDisabled() throws {
        let url = try makeDecoratedSTEP()
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try #require(Document.loadSTEP(from: url, modes: STEPReaderModes(name: false)))
        let node = try #require(doc.rootNodes.first)
        // The name in the file is ignored and the reader's own fallback label is used, while the
        // colour and the geometry still arrive.
        #expect(node.name != "Bracket")
        #expect(node.name == "SOLID")
        expectRed(node.color)
        try expectBox(doc)
    }

    @Test("Write STEP with model type")
    func writeWithModelType() throws {
        // Load a STEP file to get a document with shapes
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_src.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_write.step"
        let url = URL(fileURLWithPath: tmpPath)
        let ok = doc.writeSTEP(to: url, modelType: .asIs)
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write STEP with custom modes")
    func writeWithCustomModes() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let srcPath = NSTemporaryDirectory() + "swift_test_v58_caf_src2.step"
        try box.writeSTEP(to: URL(fileURLWithPath: srcPath))
        let doc = try Document.load(from: URL(fileURLWithPath: srcPath))

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_custom.step"
        let url = URL(fileURLWithPath: tmpPath)
        let modes = STEPWriterModes(
            color: false, name: true, layer: false,
            dimTol: true, material: false)
        let ok = doc.writeSTEP(to: url, modelType: .manifoldSolidBrep, modes: modes)
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: tmpPath))
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Round-trip with mode control")
    func roundTrip() throws {
        let srcURL = try makeDecoratedSTEP()
        defer { try? FileManager.default.removeItem(at: srcURL) }
        let doc = try Document.load(from: srcURL)

        let named = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swift_test_v58_caf_rt_\(UUID()).step")
        let unnamed = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swift_test_v58_caf_rt_noname_\(UUID()).step")
        defer {
            try? FileManager.default.removeItem(at: named)
            try? FileManager.default.removeItem(at: unnamed)
        }

        // Writer modes: names on keeps the name through the file, names off drops it.
        #expect(
            doc.writeSTEP(
                to: named, modelType: .asIs, modes: STEPWriterModes(color: true, name: true)))
        #expect(
            doc.writeSTEP(
                to: unnamed, modelType: .asIs, modes: STEPWriterModes(color: true, name: false)))

        let readerModes = STEPReaderModes(color: true, name: true)
        let back = try #require(Document.loadSTEP(from: named, modes: readerModes))
        let node = try #require(back.rootNodes.first)
        #expect(back.rootNodes.count == 1)
        #expect(node.name == "Bracket")
        expectRed(node.color)
        try expectBox(back)

        let backUnnamed = try #require(Document.loadSTEP(from: unnamed, modes: readerModes))
        #expect(backUnnamed.rootNodes.first?.name != "Bracket")
        try expectBox(backUnnamed)
    }

    @Test("Load from path with modes")
    func loadFromPathWithModes() throws {
        let url = try makeDecoratedSTEP()
        defer { try? FileManager.default.removeItem(at: url) }

        // Colour off: the colour in the file is not read, the name still is.
        let doc = try #require(
            Document.loadSTEP(fromPath: url.path, modes: STEPReaderModes(color: false)))
        let node = try #require(doc.rootNodes.first)
        #expect(node.color == nil)
        #expect(node.name == "Bracket")
        try expectBox(doc)

        // And with the colour mode on, the same path gives the colour.
        let withColor = try #require(
            Document.loadSTEP(fromPath: url.path, modes: STEPReaderModes()))
        expectRed(withColor.rootNodes.first?.color)
    }

    @Test("Write to path with modes")
    func writeToPathWithModes() throws {
        let srcURL = try makeDecoratedSTEP()
        defer { try? FileManager.default.removeItem(at: srcURL) }
        let doc = try Document.load(from: srcURL)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v58_caf_wpath_\(UUID()).step"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }
        #expect(doc.writeSTEP(toPath: tmpPath, modelType: .asIs))
        #expect(FileManager.default.fileExists(atPath: tmpPath))

        // What was written is the document: reading it back gives the name and the solid.
        let back = try Document.load(from: URL(fileURLWithPath: tmpPath))
        let node = try #require(back.rootNodes.first)
        #expect(node.name == "Bracket")
        try expectBox(back)
    }
}
