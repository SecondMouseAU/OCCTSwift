import Foundation
import Testing

@testable import OCCTSwift

// MARK: - OBJ Document I/O Tests (v0.59.0)

@Suite("OBJ Document I/O")
struct OBJDocumentIOTests {

    @Test("Load OBJ into document")
    func loadOBJ() throws {
        // Write an OBJ file first
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_doc.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(from: url)
        #expect(doc != nil)
        if let doc = doc {
            // Exactly two, measured: RWObj_CafReader leaves one free shape whose
            // single component also carries a shape, and allShapes counts both.
            // See Scripts/repro/766-xcaf-obj-ocaf-evidence/ ("free shapes=1
            // allShapes count=2"). A lower bound of > 0 passed on any non-empty
            // read and would not have noticed the component going missing.
            let shapes = doc.allShapes()
            #expect(shapes.count == 2)
            // The mesh carries the box's own extents, so a load that dropped
            // the geometry and kept the label structure cannot pass.
            if let bb = shapes.first?.boundingBox {
                #expect(abs((bb.max.x - bb.min.x) - 10) < 1e-3)
                #expect(abs((bb.max.y - bb.min.y) - 20) < 1e-3)
                #expect(abs((bb.max.z - bb.min.z) - 30) < 1e-3)
            }
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load OBJ with single precision")
    func loadOBJSinglePrecision() throws {
        // #2802: the fixture is the whole point here. A box written by `Shape.writeOBJ` has
        // float-exact coordinates, so `RWObj_CafReader::SetSinglePrecision(true)` has nothing to
        // round and both loads returned the identical bounding box to 1e-7. This OBJ is written by
        // hand instead, with two vertices no `float` can hold: `0.1234567890123456`, which needs
        // more significant digits than a float's 24-bit mantissa, and a coordinate near 1e7, where
        // the float spacing is about 1.0 so a fractional part is lost outright.
        let obj = """
            v 0.1234567890123456 0.9876543210987654 0.3141592653589793
            v 10000000.1234567 0.5 0.25
            v 1.0 2.0 3.0
            f 1 2 3
            """
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_sp.obj"
        let url = URL(fileURLWithPath: tmpPath)
        // `atomically: false` because `atomically: true` cannot work on WASI: it writes a temp
        // file and renames it, and the rename is unsupported there (`NSCocoaErrorDomain Code=3328`).
        // Nothing is lost by dropping it. Atomicity protects a reader from seeing a half-written
        // file after a crash mid-write, and this is a fixture written and consumed by one test in
        // one process. Measured by #2793's wasm run, which failed these tests on the fixture write
        // rather than on anything they assert.
        try obj.write(to: url, atomically: false, encoding: .utf8)

        func firstFaceNodes(singlePrecision: Bool) throws -> [SIMD3<Double>] {
            let doc = try #require(Document.loadOBJ(from: url, singlePrecision: singlePrecision))
            let shapes = doc.allShapes()
            try #require(shapes.count == 1)
            let faces = shapes[0].faces()
            try #require(faces.count == 1)
            let faceShape = try #require(Shape.fromFace(faces[0]))
            let count = faceShape.triangulationNodeCount
            try #require(count == 3)
            // Read the stored triangulation nodes, not the bounding box: the box is inflated by
            // the shape's tolerance and hid the difference this test exists to see.
            return (1...count).map { faceShape.triangulationNode(at: $0) }
        }

        let single = try firstFaceNodes(singlePrecision: true)
        let double = try firstFaceNodes(singlePrecision: false)

        // The double-precision load keeps the file's own digits.
        #expect(double[0].x == 0.1234567890123456)
        #expect(double[0].y == 0.9876543210987654)
        #expect(double[0].z == 0.3141592653589793)
        #expect(double[1].x == 10_000_000.1234567)

        // The single-precision load stores each coordinate through a `float`, so it comes back as
        // exactly the nearest float. Written as `Double(Float(...))` rather than as the decimal
        // expansion so the assertion states the mechanism it is checking.
        #expect(single[0].x == Double(Float(0.1234567890123456)))
        #expect(single[0].y == Double(Float(0.9876543210987654)))
        #expect(single[0].z == Double(Float(0.3141592653589793)))
        #expect(single[1].x == 10_000_000.0)

        // And the headline: the two settings disagree, by 0.1234567 on the 1e7 coordinate, which is
        // five orders of magnitude above any tolerance either load applies. A bridge that stopped
        // passing the flag fails here.
        #expect(abs(single[1].x - double[1].x) > 1e-3)
        #expect(single[0].x != double[0].x)

        // The third vertex is float-exact, so it must NOT differ. Without this the test could pass
        // on a load that perturbed every coordinate rather than rounding to float.
        #expect(single[2] == double[2])

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Write OBJ from document")
    func writeOBJ() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let srcPath = NSTemporaryDirectory() + "swift_test_v59_obj_src.obj"
        try box.writeOBJ(to: URL(fileURLWithPath: srcPath))
        let doc = Document.loadOBJ(fromPath: srcPath)!

        let outPath = NSTemporaryDirectory() + "swift_test_v59_obj_out.obj"
        let ok = doc.writeOBJ(to: URL(fileURLWithPath: outPath))
        #expect(ok)
        #expect(FileManager.default.fileExists(atPath: outPath))

        // The file's existence says nothing about its contents, so read them.
        // Measured for this fixture: 24 vertex lines and 12 face lines, the
        // box's 6 quads triangulated with per-face corners.
        let text = try String(contentsOfFile: outPath, encoding: .utf8)
        let lines = text.split(separator: "\n")
        #expect(lines.filter { $0.hasPrefix("v ") }.count == 24)
        #expect(lines.filter { $0.hasPrefix("f ") }.count == 12)

        // And read it back through the kernel, so a syntactically plausible
        // file that OCCT itself cannot parse fails here too.
        let reloaded = Document.loadOBJ(fromPath: outPath)
        #expect(reloaded != nil)
        if let reloaded = reloaded {
            #expect(reloaded.allShapes().count == 2)
        }

        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: outPath)
    }

    @Test("Load OBJ with coordinate system")
    func loadOBJWithCS() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_cs.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(
            from: url,
            inputCS: .zUp, outputCS: .yUp)
        #expect(doc != nil)
        if let doc = doc {
            // The conversion is what this test exists to cover, so observe it:
            // a Z-up file read into a Y-up document swaps the box's Y and Z
            // extents, 10 x 20 x 30 becoming 10 x 30 x 20. Measured both ways,
            // outputCS: .zUp leaves 10 x 20 x 30, so the assertion separates
            // the two settings rather than merely proving the file parsed.
            let shapes = doc.allShapes()
            #expect(shapes.count == 2)
            if let bb = shapes.first?.boundingBox {
                #expect(abs((bb.max.x - bb.min.x) - 10) < 1e-3)
                #expect(abs((bb.max.y - bb.min.y) - 30) < 1e-3)
                #expect(abs((bb.max.z - bb.min.z) - 20) < 1e-3)
            }
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
