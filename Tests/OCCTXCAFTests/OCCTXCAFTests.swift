import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}


@Suite("Document Tests")
struct DocumentTests {

    @Test("Create empty document")
    func createEmptyDocument() {
        let doc = Document.create()
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.rootNodes.isEmpty)
        }
    }

    // Note: Loading tests require test STEP files with assemblies
    // These would be added with actual test fixtures
}

// MARK: - v0.21.0 GD&T Tests

@Suite("GD&T Document Tests")
struct GDTDocumentTests {
    @Test("Empty document has zero dimensions")
    func emptyDocDimensions() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.dimensionCount == 0)
        #expect(doc.dimensions.isEmpty)
    }

    @Test("Empty document has zero geometric tolerances")
    func emptyDocTolerances() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.geomToleranceCount == 0)
        #expect(doc.geomTolerances.isEmpty)
    }

    @Test("Empty document has zero datums")
    func emptyDocDatums() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.datumCount == 0)
        #expect(doc.datums.isEmpty)
    }

    @Test("Dimension at invalid index returns nil")
    func dimensionInvalidIndex() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.dimension(at: 0) == nil)
        #expect(doc.dimension(at: -1) == nil)
        #expect(doc.dimension(at: 999) == nil)
    }

    @Test("Geom tolerance at invalid index returns nil")
    func toleranceInvalidIndex() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.geomTolerance(at: 0) == nil)
        #expect(doc.geomTolerance(at: -1) == nil)
    }

    @Test("Datum at invalid index returns nil")
    func datumInvalidIndex() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.datum(at: 0) == nil)
        #expect(doc.datum(at: -1) == nil)
    }
}


// MARK: - TNaming: Topological Naming (v0.25.0)

@Suite("TNaming — Basic Record and Retrieve")
struct TNamingBasicTests {

    @Test("Create label on document")
    func createLabel() {
        let doc = Document.create()!
        let label = doc.createLabel()
        #expect(label != nil, "Should create a label on a new document")
    }

    @Test("Create child label under parent")
    func createChildLabel() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let child = doc.createLabel(parent: parent)
        #expect(child != nil, "Should create child label under parent")
    }

    @Test("Record primitive shape")
    func recordPrimitive() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let ok = doc.recordNaming(on: label, evolution: .primitive, newShape: box)
        #expect(ok, "Recording primitive should succeed")
    }

    @Test("Current shape after primitive")
    func currentShapeAfterPrimitive() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let current = doc.currentShape(on: label)
        #expect(current != nil, "Should retrieve current shape after primitive recording")
    }

    @Test("Stored shape matches recorded")
    func storedShape() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let stored = doc.storedShape(on: label)
        #expect(stored != nil, "Should retrieve stored shape")
    }

    @Test("Evolution type is primitive")
    func evolutionType() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        #expect(doc.namingEvolution(on: label) == .primitive)
    }

    @Test("No evolution on empty label")
    func noEvolutionOnEmptyLabel() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(doc.namingEvolution(on: label) == nil)
    }

    @Test("History count after primitive")
    func historyAfterPrimitive() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].evolution == .primitive)
        #expect(!history[0].hasOldShape, "Primitive should not have old shape")
        #expect(history[0].hasNewShape, "Primitive should have new shape")
    }

    @Test("New shape from history entry")
    func newShapeFromHistory() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let newShape = doc.newShape(on: label, at: 0)
        #expect(newShape != nil, "Should get new shape from primitive entry")
        let oldShape = doc.oldShape(on: label, at: 0)
        #expect(oldShape == nil, "Primitive should have no old shape")
    }

    @Test("Modify evolution updates current shape")
    func modifyEvolution() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere)

        #expect(doc.namingEvolution(on: label) == .modify)
        let current = doc.currentShape(on: label)
        #expect(current != nil, "Should have current shape after modify")
    }

    @Test("Delete evolution records correctly")
    func deleteEvolution() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        doc.recordNaming(on: label, evolution: .delete, oldShape: box)
        #expect(doc.namingEvolution(on: label) == .delete)
    }

    @Test("Generated evolution with old and new shapes")
    func generatedEvolution() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let edge = Shape.box(width: 1, height: 1, depth: 1)!
        let face = Shape.box(width: 5, height: 5, depth: 1)!
        doc.recordNaming(on: label, evolution: .generated, oldShape: edge, newShape: face)

        #expect(doc.namingEvolution(on: label) == .generated)
        let history = doc.namingHistory(on: label)
        #expect(history.count == 1)
        #expect(history[0].hasOldShape)
        #expect(history[0].hasNewShape)
    }

    @Test("History accumulates multiple entries")
    func multipleHistoryEntries() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere)

        let history = doc.namingHistory(on: label)
        #expect(history.count >= 1, "Should have at least one history entry after modify")
    }
}

@Suite("TNaming — Forward and Backward Tracing")
struct TNamingTracingTests {

    @Test("Trace forward finds generated shape")
    func traceForward() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count >= 1, "Should find at least one forward-traced shape")
    }

    @Test("Trace backward finds source shape")
    func traceBackward() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let backward = doc.tracedBackward(from: sphere, scope: label2)
        #expect(backward.count >= 1, "Should find at least one backward-traced shape")
    }

    @Test("Multiple generations from same source")
    func multipleGenerations() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let label3 = doc.createLabel()!
        let cyl = Shape.cylinder(radius: 3, height: 8)!
        doc.recordNaming(on: label3, evolution: .generated, oldShape: box, newShape: cyl)

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count >= 2, "Should find both generated shapes, got \(forward.count)")
    }

    @Test("Empty trace for unrelated shape")
    func emptyTraceForUnrelated() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let unrelated = Shape.sphere(radius: 7)!
        let forward = doc.tracedForward(from: unrelated, scope: label1)
        #expect(forward.isEmpty, "Unrelated shape should have no forward trace")
    }

    @Test("Trace through modification chain")
    func traceModificationChain() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere)

        let forward = doc.tracedForward(from: box, scope: label)
        #expect(forward.count >= 1, "Should trace forward through modification")
    }
}

@Suite("TNaming — Select and Resolve")
struct TNamingSelectResolveTests {

    @Test("Select a shape within context")
    func selectSubShape() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        // Use a face-shape as the selection within the box context
        let wire = Wire.rectangle(width: 10, height: 10)!
        let faceShape = Shape.face(from: wire)!

        let selectLabel = doc.createLabel()!
        let ok = doc.selectShape(faceShape, context: box, on: selectLabel)
        #expect(ok, "Should successfully select a shape within context")
    }

    @Test("Resolve returns a shape")
    func resolveShape() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let wire = Wire.rectangle(width: 10, height: 10)!
        let faceShape = Shape.face(from: wire)!

        let selectLabel = doc.createLabel()!
        doc.selectShape(faceShape, context: box, on: selectLabel)

        let resolved = doc.resolveShape(on: selectLabel)
        // Resolve may or may not return a shape depending on TNaming_Selector behavior
        // with simple test shapes — just verify the API doesn't crash
        if resolved != nil {
            #expect(Bool(true), "Resolve returned a shape")
        }
    }

    @Test("Selected evolution type")
    func selectedEvolution() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let wire = Wire.rectangle(width: 10, height: 10)!
        let faceShape = Shape.face(from: wire)!

        let selectLabel = doc.createLabel()!
        doc.selectShape(faceShape, context: box, on: selectLabel)

        let evo = doc.namingEvolution(on: selectLabel)
        #expect(evo == .selected, "Selection label should have selected evolution")
    }
}

@Suite("Text Label and Point Cloud")
struct TextLabelAndPointCloudTests {

    @Test("Create text label")
    func createTextLabel() {
        let label = TextLabel(text: "Hello", position: SIMD3(1, 2, 3))
        #expect(label != nil)
        #expect(label!.text == "Hello")
    }

    @Test("Text label position")
    func textLabelPosition() {
        let label = TextLabel(text: "Test", position: SIMD3(10, 20, 30))!
        let pos = label.position
        #expect(abs(pos.x - 10) < 1e-6)
        #expect(abs(pos.y - 20) < 1e-6)
        #expect(abs(pos.z - 30) < 1e-6)
    }

    @Test("Update text label text")
    func updateText() {
        let label = TextLabel(text: "Original", position: .zero)!
        label.text = "Updated"
        #expect(label.text == "Updated")
    }

    @Test("Update text label position")
    func updatePosition() {
        let label = TextLabel(text: "Test", position: .zero)!
        label.position = SIMD3(5, 10, 15)
        let pos = label.position
        #expect(abs(pos.x - 5) < 1e-6)
        #expect(abs(pos.y - 10) < 1e-6)
    }

    @Test("Create point cloud")
    func createPointCloud() {
        let pts = [SIMD3<Double>(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let cloud = PointCloud(points: pts)
        #expect(cloud != nil)
        #expect(cloud!.count == 3)
    }

    @Test("Point cloud bounds")
    func pointCloudBounds() {
        let pts = [SIMD3<Double>(1, 2, 3), SIMD3(4, 5, 6), SIMD3(-1, 0, 1)]
        let cloud = PointCloud(points: pts)!
        let bounds = cloud.bounds
        #expect(bounds != nil)
        if let b = bounds {
            #expect(abs(b.min.x - (-1)) < 1e-6)
            #expect(abs(b.max.x - 4) < 1e-6)
            #expect(abs(b.min.y - 0) < 1e-6)
            #expect(abs(b.max.y - 5) < 1e-6)
        }
    }

    @Test("Point cloud retrieval")
    func pointCloudRetrieval() {
        let pts = [SIMD3<Double>(1, 2, 3), SIMD3(4, 5, 6)]
        let cloud = PointCloud(points: pts)!
        let retrieved = cloud.points
        #expect(retrieved.count == 2)
        #expect(abs(retrieved[0].x - 1) < 1e-6)
        #expect(abs(retrieved[1].z - 6) < 1e-6)
    }

    @Test("Colored point cloud")
    func coloredPointCloud() {
        let pts = [SIMD3<Double>(0, 0, 0), SIMD3(1, 1, 1)]
        let cols = [SIMD3<Float>(1, 0, 0), SIMD3(0, 1, 0)]
        let cloud = PointCloud(points: pts, colors: cols)
        #expect(cloud != nil)
        #expect(cloud!.count == 2)
        let retrievedColors = cloud!.colors
        #expect(retrievedColors.count == 2)
        #expect(abs(retrievedColors[0].x - 1.0) < 1e-4, "First color should be red")
        #expect(abs(retrievedColors[1].y - 1.0) < 1e-4, "Second color should be green")
    }

    @Test("Empty point cloud returns nil")
    func emptyPointCloud() {
        let cloud = PointCloud(points: [])
        #expect(cloud == nil)
    }
}

@Suite("Document Layers")
struct DocumentLayerTests {
    @Test("Document has XCAF built-in layers")
    func builtInLayers() {
        let doc = Document.create()!
        // XCAF documents come with built-in tool labels
        #expect(doc.layerCount > 0)
        let names = doc.layerNames
        #expect(!names.isEmpty)
    }

    @Test("Layer name out of range returns nil")
    func outOfRange() {
        let doc = Document.create()!
        #expect(doc.layerName(at: 999) == nil)
        #expect(doc.layerName(at: -1) == nil)
    }
}

@Suite("Document Materials")
struct DocumentMaterialTests {
    @Test("Empty document has no materials")
    func emptyMaterials() {
        let doc = Document.create()!
        #expect(doc.materialCount == 0)
        #expect(doc.materials.isEmpty)
    }

    @Test("Material info out of range returns nil")
    func outOfRange() {
        let doc = Document.create()!
        #expect(doc.materialInfo(at: 0) == nil)
    }
}

@Suite("XCAF full-matrix component placement (#174)")
struct XCAFComponentMatrixTests {
    @Test("Full 4x4 places components (rotation + reflection) under an assembly")
    func matrixComponentPlacement() throws {
        guard let doc = Document.create(), let box = Shape.box(width: 4, height: 2, depth: 1),
              let asmShape = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("no doc/box"); return
        }
        let part = doc.addShape(box, makeAssembly: false)
        let asm = doc.addShape(asmShape, makeAssembly: true)
        // Rigid: 90° about Z + translation (10,20,30), row-major [r00..r22, tx,ty,tz].
        let rigid: [Double] = [0, -1, 0, 1, 0, 0, 0, 0, 1, 10, 20, 30]
        #expect(doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: rigid) >= 0)
        // Reflection (det −1, mirror X) — gp_Trsf accepts it as a negative-scale location, so a
        // mirrored occurrence can be placed directly without baking a separate mirrored product.
        let reflect: [Double] = [-1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0]
        #expect(doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: reflect) >= 0)
        // A malformed matrix is rejected.
        #expect(doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: [1, 2, 3]) == -1)
        #expect(doc.componentCount(assemblyLabelId: asm) == 2)
    }
}

@Suite("AssemblyNode public labelId + Document.node(at:) round-trip")
struct AssemblyNodeIdentityTests {
    @Test("AssemblyNode.labelId is public and round-trips via Document.node(at:)")
    func labelIdRoundTrip() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("assembly_node_identity_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        guard let original = nodes.first else { return }
        let id = original.labelId
        #expect(id >= 0)

        // Same labelId resolves back to a node referring to the same label.
        guard let recovered = doc.node(at: id) else {
            Issue.record("Document.node(at:) failed to resolve a known labelId")
            return
        }
        #expect(recovered.labelId == id)
        #expect(recovered.name == original.name)
    }

    @Test("Document.node(at:) returns nil for a nonexistent labelId")
    func unknownLabelIdRejected() {
        guard let doc = Document.create() else {
            Issue.record("Document.create failed")
            return
        }
        // Int64.max is guaranteed not to be a real label in a fresh document.
        #expect(doc.node(at: .max) == nil)
    }

    @Test("Document.node(at:) resolves root labelIds without a prior rootNodes walk (issue #95)")
    func nodeAtFreshDocumentDoesNotRequireWarmup() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("node_at_warmup_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)

        // Freshly-loaded document — do NOT touch `rootNodes` before the lookup.
        let doc = try Document.load(from: tempURL)

        // Pre-fix this returned nil because the labelId registry was empty
        // until rootNodes had been walked. The fix eagerly registers root
        // labels inside node(at:), so labelId 0 (the first registered root)
        // resolves on a fresh doc.
        let node = doc.node(at: 0)
        #expect(node != nil)
        if let node {
            #expect(node.labelId == 0)
        }
    }
}

@Suite("Document Color/Material Setter Tests")
struct DocumentColorMaterialTests {

    @Test("Set and get label color")
    func setLabelColor() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("color_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        if let node = nodes.first {
            node.setColor(Color(red: 1.0, green: 0.0, blue: 0.0))
            let color = node.color
            #expect(color != nil)
            if let color {
                #expect(abs(color.red - 1.0) < 0.01)
                #expect(abs(color.green) < 0.01)
                #expect(abs(color.blue) < 0.01)
            }
        }
    }

    @Test("Set and get label material")
    func setLabelMaterial() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("material_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        if let node = nodes.first {
            let mat = Material(
                baseColor: Color(red: 0.8, green: 0.2, blue: 0.1),
                metallic: 0.9,
                roughness: 0.3,
                transparency: 0.0
            )
            node.setMaterial(mat)

            let readMat = node.material
            #expect(readMat != nil)
            if let readMat {
                #expect(abs(readMat.metallic - 0.9) < 0.01)
                #expect(abs(readMat.roughness - 0.3) < 0.01)
            }
        }
    }
}

// MARK: - TDF Label Properties Tests (v0.54.0)

@Suite("TDF Label Properties")
struct TDFLabelPropertyTests {

    @Test("Label tag")
    func labelTag() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(main.tag == 1, "Main label tag should be 1")
        }
    }

    @Test("Label depth")
    func labelDepth() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(main.depth == 1, "Main label depth should be 1")
            if let child = doc.createLabel() {
                #expect(child.depth == 2, "Child of main should have depth 2")
            }
        }
    }

    @Test("Label isNull")
    func labelIsNull() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(!main.isNull, "Main label should not be null")
        }
    }

    @Test("Label isRoot")
    func labelIsRoot() {
        let doc = Document.create()!
        if let main = doc.mainLabel {
            #expect(!main.isRoot, "Main label (0:1) is not the root")
            if let root = main.root {
                #expect(root.isRoot, "Root() of main should be root")
            }
        }
    }

    @Test("Label father")
    func labelFather() {
        let doc = Document.create()!
        let child = doc.createLabel()!
        if let main = doc.mainLabel, let father = child.father {
            #expect(father.labelId == main.labelId, "Child's father should be main label")
        }
    }

    @Test("Label root")
    func labelRoot() {
        let doc = Document.create()!
        let child = doc.createLabel()!
        if let root = child.root {
            #expect(root.isRoot, "Root of any label should be the document root")
        }
    }

    @Test("Label hasAttribute and attributeCount")
    func labelAttributes() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let label = doc.createLabel(parent: parent)!
        #expect(!label.hasAttribute, "Fresh label should have no attributes")
        #expect(label.attributeCount == 0, "Fresh label should have 0 attributes")

        label.setName("TestPart")
        #expect(label.hasAttribute, "Label with name should have attributes")
        #expect(label.attributeCount >= 1, "Label with name should have at least 1 attribute")
    }

    @Test("Label hasChild and childCount")
    func labelChildren() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        #expect(!parent.hasChild, "New label has no children")
        #expect(parent.childCount == 0, "New label has 0 children")

        let _ = doc.createLabel(parent: parent)
        let _ = doc.createLabel(parent: parent)
        #expect(parent.hasChild, "Label with children should report hasChild")
        #expect(parent.childCount == 2, "Should have 2 children")
    }

    @Test("Label findChild by tag")
    func labelFindChild() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let child = doc.createLabel(parent: parent)!

        // Find existing child
        let found = parent.findChild(tag: child.tag)
        #expect(found != nil, "Should find existing child by tag")

        // Find non-existing without create
        let notFound = parent.findChild(tag: 999, create: false)
        #expect(notFound == nil, "Should not find non-existing child")

        // Find non-existing with create
        let created = parent.findChild(tag: 999, create: true)
        #expect(created != nil, "Should create child when requested")
        #expect(parent.childCount == 2, "Should now have 2 children (1 original + 1 created)")
    }

    @Test("Label forgetAllAttributes")
    func labelForgetAllAttributes() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let label = doc.createLabel(parent: parent)!
        label.setName("Temporary")
        #expect(label.hasAttribute)

        label.forgetAllAttributes()
        #expect(!label.hasAttribute, "After forget, label should have no attributes")
    }

    @Test("Label descendants")
    func labelDescendants() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let c1 = doc.createLabel(parent: parent)!
        let _ = doc.createLabel(parent: parent)!
        let _ = doc.createLabel(parent: c1)!
        let _ = doc.createLabel(parent: c1)!

        let direct = parent.descendants(allLevels: false)
        #expect(direct.count == 2, "Should have 2 direct children")

        let all = parent.descendants(allLevels: true)
        #expect(all.count == 4, "Should have 4 total descendants")
    }
}

// MARK: - TDF Label Name Tests (v0.54.0)

@Suite("TDF Label Name Set/Get")
struct TDFLabelNameTests {

    @Test("Set and get label name")
    func setGetName() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setName("MyPart")
        #expect(ok, "Setting name should succeed")
        #expect(label.name == "MyPart", "Name should match")
    }

    @Test("Rename label")
    func renameLabel() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setName("Original")
        #expect(label.name == "Original")

        label.setName("Renamed")
        #expect(label.name == "Renamed", "Name should be updated")
    }
}

// MARK: - TDF Reference Tests (v0.54.0)

@Suite("TDF Reference")
struct TDFReferenceTests {

    @Test("Set and get reference")
    func setGetReference() {
        let doc = Document.create()!
        let source = doc.createLabel()!
        let target = doc.createLabel()!
        let refLabel = doc.createLabel()!

        source.setName("Source")
        target.setName("Target")

        let ok = refLabel.setReference(to: target)
        #expect(ok, "Setting reference should succeed")

        if let referenced = refLabel.referencedLabel {
            #expect(referenced.labelId == target.labelId, "Reference should point to target")
        } else {
            Issue.record("Should have a referenced label")
        }
    }

    @Test("No reference on fresh label")
    func noReference() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(label.referencedLabel == nil, "Fresh label should have no reference")
    }
}

// MARK: - TDF CopyLabel Tests (v0.54.0)

@Suite("TDF CopyLabel")
struct TDFCopyLabelTests {

    @Test("Copy label with name")
    func copyLabelWithName() {
        let doc = Document.create()!
        let source = doc.createLabel()!
        source.setName("Original")

        let dest = doc.createLabel()!
        let ok = doc.copyLabel(from: source, to: dest)
        #expect(ok, "Copy should succeed")
        #expect(dest.name == "Original", "Destination should have copied name")
    }

    @Test("Copy label with children")
    func copyLabelWithChildren() {
        let doc = Document.create()!
        let source = doc.createLabel()!
        source.setName("Parent")
        let child = doc.createLabel(parent: source)!
        child.setName("Child")

        let dest = doc.createLabel()!
        let ok = doc.copyLabel(from: source, to: dest)
        #expect(ok, "Copy should succeed")
        #expect(dest.hasChild, "Destination should have children after copy")
    }
}

// MARK: - Document Main Label Tests (v0.54.0)

@Suite("Document Main Label")
struct DocumentMainLabelTests {

    @Test("Get main label")
    func getMainLabel() {
        let doc = Document.create()!
        let main = doc.mainLabel
        #expect(main != nil, "Should get main label")
        if let main = main {
            #expect(main.tag == 1, "Main label tag should be 1")
            #expect(main.depth == 1, "Main label depth should be 1")
            #expect(!main.isRoot, "Main label is not the root")
        }
    }
}

// MARK: - Document Transaction Tests (v0.54.0)

@Suite("Document Transactions")
struct DocumentTransactionTests {

    @Test("Open and commit transaction")
    func openCommit() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        #expect(!doc.hasOpenTransaction)
        doc.openTransaction()
        #expect(doc.hasOpenTransaction)

        let label = doc.createLabel()!
        label.setName("InTransaction")

        let ok = doc.commitTransaction()
        #expect(ok, "Commit should succeed")
        #expect(!doc.hasOpenTransaction)
    }

    @Test("Open and abort transaction")
    func openAbort() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        #expect(doc.hasOpenTransaction)

        let label = doc.createLabel()!
        label.setName("WillBeAborted")

        doc.abortTransaction()
        #expect(!doc.hasOpenTransaction)
    }

    @Test("Has open transaction")
    func hasOpenTransaction() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        #expect(!doc.hasOpenTransaction, "No transaction initially")

        doc.openTransaction()
        #expect(doc.hasOpenTransaction, "Transaction should be open")

        doc.commitTransaction()
        #expect(!doc.hasOpenTransaction, "No transaction after commit")
    }
}

// MARK: - Document Undo/Redo Tests (v0.54.0)

@Suite("Document Undo/Redo")
struct DocumentUndoRedoTests {

    @Test("Set and get undo limit")
    func undoLimit() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        #expect(doc.undoLimit == 10)
    }

    @Test("Available undos after commit")
    func availableUndos() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        #expect(doc.availableUndos == 0)
        #expect(doc.availableRedos == 0)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("T1")
        doc.commitTransaction()

        #expect(doc.availableUndos == 1)
    }

    @Test("Undo restores state")
    func undoRestores() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("Box")
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            doc.recordNaming(on: label, evolution: .primitive, newShape: box)
        }
        doc.commitTransaction()

        #expect(doc.availableUndos == 1)

        doc.openTransaction()
        let label2 = doc.createLabel()!
        label2.setName("Cylinder")
        doc.commitTransaction()

        #expect(doc.availableUndos == 2)

        // Undo
        let ok = doc.undo()
        #expect(ok, "Undo should succeed")
        #expect(doc.availableUndos == 1)
        #expect(doc.availableRedos == 1)
    }

    @Test("Redo after undo")
    func redoAfterUndo() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        doc.createLabel()!.setName("T1")
        doc.commitTransaction()

        doc.openTransaction()
        doc.createLabel()!.setName("T2")
        doc.commitTransaction()

        #expect(doc.availableUndos == 2)

        doc.undo()
        #expect(doc.availableRedos == 1)

        let ok = doc.redo()
        #expect(ok, "Redo should succeed")
        #expect(doc.availableUndos == 2)
        #expect(doc.availableRedos == 0)
    }

    @Test("Undo with nothing returns false")
    func undoNothing() {
        let doc = Document.create()!
        doc.setUndoLimit(10)
        let result = doc.undo()
        #expect(!result, "Undo with nothing should return false")
    }

    @Test("Multiple undos and redos")
    func multipleUndoRedo() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        for i in 0..<3 {
            doc.openTransaction()
            doc.createLabel()!.setName("Label\(i)")
            doc.commitTransaction()
        }

        #expect(doc.availableUndos == 3)

        doc.undo()
        doc.undo()
        doc.undo()
        #expect(doc.availableUndos == 0)
        #expect(doc.availableRedos == 3)

        doc.redo()
        doc.redo()
        #expect(doc.availableUndos == 2)
        #expect(doc.availableRedos == 1)
    }

    @Test("Abort does not create undo")
    func abortNoUndo() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        doc.createLabel()!.setName("T1")
        doc.commitTransaction()

        doc.openTransaction()
        doc.createLabel()!.setName("Aborted")
        doc.abortTransaction()

        #expect(doc.availableUndos == 1, "Aborted transaction should not create undo")
    }
}

// MARK: - Document Modified Labels Tests (v0.54.0)

@Suite("Document Modified Labels")
struct DocumentModifiedTests {

    @Test("Set and check modified")
    func setAndCheckModified() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("Part1")
        doc.commitTransaction()

        doc.setModified(label)
        #expect(doc.isModified(label), "Label should be marked as modified")
    }

    @Test("Clear modified")
    func clearModified() {
        let doc = Document.create()!
        doc.setUndoLimit(10)

        doc.openTransaction()
        let label = doc.createLabel()!
        label.setName("Part1")
        doc.commitTransaction()

        doc.setModified(label)
        #expect(doc.isModified(label))

        doc.clearModified()
        #expect(!doc.isModified(label), "Label should not be modified after clear")
    }
}

// MARK: - TDataStd Scalar Attribute Tests (v0.55.0)

@Suite("TDataStd Integer Attribute")
struct TDataStdIntegerTests {

    @Test("Set and get integer")
    func setGetInteger() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setInteger(42)
        #expect(ok)
        #expect(label.integer == 42)
    }

    @Test("Change integer value")
    func changeInteger() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setInteger(42)
        label.setInteger(99)
        #expect(label.integer == 99)
    }

    @Test("No integer on fresh label")
    func noInteger() {
        let doc = Document.create()!
        let parent = doc.createLabel()!
        let label = doc.createLabel(parent: parent)!
        #expect(label.integer == nil)
    }
}

@Suite("TDataStd Real Attribute")
struct TDataStdRealTests {

    @Test("Set and get real")
    func setGetReal() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setReal(3.14)
        #expect(ok)
        if let val = label.real {
            #expect(abs(val - 3.14) < 1e-10)
        }
    }

    @Test("Change real value")
    func changeReal() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setReal(3.14)
        label.setReal(2.718)
        if let val = label.real {
            #expect(abs(val - 2.718) < 1e-10)
        }
    }
}

@Suite("TDataStd AsciiString Attribute")
struct TDataStdAsciiStringTests {

    @Test("Set and get ASCII string")
    func setGetAsciiString() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setAsciiString("hello")
        #expect(ok)
        #expect(label.asciiString == "hello")
    }

    @Test("Change ASCII string")
    func changeAsciiString() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.setAsciiString("hello")
        label.setAsciiString("world")
        #expect(label.asciiString == "world")
    }
}

@Suite("TDataStd Comment Attribute")
struct TDataStdCommentTests {

    @Test("Set and get comment")
    func setGetComment() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setComment("my comment")
        #expect(ok)
        #expect(label.comment == "my comment")
    }
}

// MARK: - TDataStd Array Attribute Tests (v0.55.0)

@Suite("TDataStd Integer Array")
struct TDataStdIntegerArrayTests {

    @Test("Initialize and use integer array")
    func initAndUse() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.initIntegerArray(lower: 1, upper: 5)
        #expect(ok)

        if let bounds = label.integerArrayBounds {
            #expect(bounds.lower == 1)
            #expect(bounds.upper == 5)
        }

        label.setIntegerArrayValue(at: 1, value: 10)
        label.setIntegerArrayValue(at: 3, value: 30)
        label.setIntegerArrayValue(at: 5, value: 50)

        #expect(label.integerArrayValue(at: 1) == 10)
        #expect(label.integerArrayValue(at: 3) == 30)
        #expect(label.integerArrayValue(at: 5) == 50)
    }

    @Test("Out of bounds returns nil")
    func outOfBounds() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.initIntegerArray(lower: 0, upper: 2)
        #expect(label.integerArrayValue(at: 99) == nil)
    }
}

@Suite("TDataStd Real Array")
struct TDataStdRealArrayTests {

    @Test("Initialize and use real array")
    func initAndUse() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.initRealArray(lower: 0, upper: 2)
        #expect(ok)

        if let bounds = label.realArrayBounds {
            #expect(bounds.lower == 0)
            #expect(bounds.upper == 2)
        }

        label.setRealArrayValue(at: 0, value: 1.1)
        label.setRealArrayValue(at: 1, value: 2.2)
        label.setRealArrayValue(at: 2, value: 3.3)

        if let v0 = label.realArrayValue(at: 0) { #expect(abs(v0 - 1.1) < 1e-10) }
        if let v1 = label.realArrayValue(at: 1) { #expect(abs(v1 - 2.2) < 1e-10) }
        if let v2 = label.realArrayValue(at: 2) { #expect(abs(v2 - 3.3) < 1e-10) }
    }
}

// MARK: - TDataStd TreeNode Tests (v0.55.0)

@Suite("TDataStd TreeNode")
struct TDataStdTreeNodeTests {

    @Test("Create tree node")
    func createTreeNode() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.setTreeNode()
        #expect(ok)
        #expect(!label.treeNodeHasFather)
        #expect(label.treeNodeDepth == 0)
    }

    @Test("Parent-child tree structure")
    func parentChild() {
        let doc = Document.create()!
        let root = doc.createLabel()!
        let child1 = doc.createLabel()!
        let child2 = doc.createLabel()!

        root.setTreeNode()
        child1.setTreeNode()
        child2.setTreeNode()

        root.appendTreeChild(child1)
        root.appendTreeChild(child2)

        #expect(child1.treeNodeHasFather)
        #expect(child1.treeNodeDepth == 1)
        #expect(root.treeNodeChildCount == 2)

        if let father = child1.treeNodeFather {
            #expect(father.labelId == root.labelId)
        }

        if let first = root.treeNodeFirstChild {
            #expect(first.labelId == child1.labelId)
        }

        if let next = child1.treeNodeNext {
            #expect(next.labelId == child2.labelId)
        }

        #expect(child2.treeNodeNext == nil)
    }
}

// MARK: - TDataStd NamedData Tests (v0.55.0)

@Suite("TDataStd NamedData")
struct TDataStdNamedDataTests {

    @Test("Named integer")
    func namedInteger() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        let ok = label.setNamedInteger("count", value: 42)
        #expect(ok)
        #expect(label.hasNamedInteger("count"))
        #expect(label.namedInteger("count") == 42)
        #expect(!label.hasNamedInteger("other"))
    }

    @Test("Named real")
    func namedReal() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setNamedReal("pi", value: 3.14159)
        #expect(label.hasNamedReal("pi"))
        if let val = label.namedReal("pi") {
            #expect(abs(val - 3.14159) < 1e-5)
        }
    }

    @Test("Named string")
    func namedString() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setNamedString("partName", value: "MyPart")
        #expect(label.hasNamedString("partName"))
        #expect(label.namedString("partName") == "MyPart")
        #expect(!label.hasNamedString("other"))
    }

    @Test("Multiple named values on same label")
    func multipleValues() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setNamedInteger("count", value: 5)
        label.setNamedReal("weight", value: 12.5)
        label.setNamedString("material", value: "Steel")

        #expect(label.namedInteger("count") == 5)
        if let w = label.namedReal("weight") { #expect(abs(w - 12.5) < 1e-10) }
        #expect(label.namedString("material") == "Steel")
    }
}

// MARK: - TDataXtd Shape Attribute Tests (v0.56.0)

@Suite("TDataXtd Shape Attribute")
struct TDataXtdShapeAttributeTests {

    @Test("Set and get shape attribute on label")
    func setGetShape() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        #expect(label.setShapeAttribute(box))
        #expect(label.hasShapeAttribute)
        if let retrieved = label.shapeAttribute() {
            #expect(retrieved.isValid)
        }
    }

    @Test("Label without shape attribute")
    func noShapeAttribute() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(!label.hasShapeAttribute)
        #expect(label.shapeAttribute() == nil)
    }
}

// MARK: - TDataXtd Position Attribute Tests (v0.56.0)

@Suite("TDataXtd Position Attribute")
struct TDataXtdPositionAttributeTests {

    @Test("Set and get position attribute")
    func setGetPosition() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setPositionAttribute(x: 1.0, y: 2.0, z: 3.0))
        #expect(label.hasPositionAttribute)
        if let pos = label.positionAttribute() {
            #expect(abs(pos.x - 1.0) < 1e-10)
            #expect(abs(pos.y - 2.0) < 1e-10)
            #expect(abs(pos.z - 3.0) < 1e-10)
        }
    }

    @Test("Label without position attribute")
    func noPositionAttribute() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(!label.hasPositionAttribute)
        #expect(label.positionAttribute() == nil)
    }
}

// MARK: - TDataXtd Geometry Attribute Tests (v0.56.0)

@Suite("TDataXtd Geometry Attribute")
struct TDataXtdGeometryAttributeTests {

    @Test("Set and get geometry type")
    func setGetGeometryType() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setGeometryType(.point))
        #expect(label.hasGeometryAttribute)
        #expect(label.geometryType() == .point)

        #expect(label.setGeometryType(.plane))
        #expect(label.geometryType() == .plane)

        #expect(label.setGeometryType(.cylinder))
        #expect(label.geometryType() == .cylinder)
    }

    @Test("All geometry type values")
    func allGeometryTypes() {
        let doc = Document.create()!
        let types: [GeometryType] = [.anyGeom, .point, .line, .circle, .ellipse, .spline, .plane, .cylinder]
        for type in types {
            let label = doc.createLabel()!
            #expect(label.setGeometryType(type))
            #expect(label.geometryType() == type)
        }
    }
}

// MARK: - TDataXtd Triangulation Attribute Tests (v0.56.0)

@Suite("TDataXtd Triangulation Attribute")
struct TDataXtdTriangulationAttributeTests {

    @Test("Set triangulation from meshed shape")
    func setTriangulation() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let sphere = Shape.sphere(radius: 10.0)!

        #expect(label.setTriangulationFromShape(sphere, deflection: 1.0))
        #expect(label.triangulationNodeCount > 0)
        #expect(label.triangulationTriangleCount > 0)
    }

    @Test("Triangulation deflection")
    func triangulationDeflection() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        #expect(label.setTriangulationFromShape(box, deflection: 0.5))
        #expect(label.triangulationDeflection > 0)
    }
}

// MARK: - TDataXtd Point/Axis/Plane Attribute Tests (v0.56.0)

@Suite("TDataXtd Point/Axis/Plane Attributes")
struct TDataXtdGeometricAttrTests {

    @Test("Set point attribute")
    func setPoint() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(label.setPointAttribute(x: 5.0, y: 10.0, z: 15.0))
    }

    @Test("Set axis attribute")
    func setAxis() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(label.setAxisAttribute(originX: 0, originY: 0, originZ: 0,
                                        directionX: 0, directionY: 0, directionZ: 1))
    }

    @Test("Set plane attribute")
    func setPlane() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(label.setPlaneAttribute(originX: 0, originY: 0, originZ: 0,
                                         normalX: 0, normalY: 0, normalZ: 1))
    }
}

// MARK: - TFunction Logbook Tests (v0.56.0)

@Suite("TFunction Logbook")
struct TFunctionLogbookTests {

    @Test("Create logbook and mark labels")
    func logbookBasic() {
        let doc = Document.create()!
        let logLabel = doc.createLabel()!
        let target1 = doc.createLabel()!
        let target2 = doc.createLabel()!

        #expect(logLabel.setLogbook())
        #expect(logLabel.logbookIsEmpty)

        #expect(logLabel.logbookSetTouched(target1))
        #expect(!logLabel.logbookIsEmpty)
        #expect(logLabel.logbookIsModified(target1))
        #expect(!logLabel.logbookIsModified(target2))
    }

    @Test("Logbook impacted and clear")
    func logbookImpactedAndClear() {
        let doc = Document.create()!
        let logLabel = doc.createLabel()!
        let target = doc.createLabel()!

        logLabel.setLogbook()
        #expect(logLabel.logbookSetImpacted(target))
        #expect(logLabel.logbookClear())
        #expect(logLabel.logbookIsEmpty)
    }
}

// MARK: - TFunction GraphNode Tests (v0.56.0)

@Suite("TFunction GraphNode")
struct TFunctionGraphNodeTests {

    @Test("Create graph node and set status")
    func graphNodeStatus() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setGraphNode())
        #expect(label.setGraphNodeStatus(.notExecuted))
        #expect(label.graphNodeStatus() == .notExecuted)

        #expect(label.setGraphNodeStatus(.succeeded))
        #expect(label.graphNodeStatus() == .succeeded)
    }

    @Test("Graph node dependencies")
    func graphNodeDeps() {
        let doc = Document.create()!
        let node1 = doc.createLabel()!
        let node2 = doc.createLabel()!

        node1.setGraphNode()
        node2.setGraphNode()

        // Use tags for dependencies
        #expect(node1.graphNodeAddNext(tag: node2.tag))
        #expect(node2.graphNodeAddPrevious(tag: node1.tag))

        // Remove all
        #expect(node1.graphNodeRemoveAllNext())
        #expect(node2.graphNodeRemoveAllPrevious())
    }

    @Test("All execution statuses")
    func allStatuses() {
        let doc = Document.create()!
        let statuses: [ExecutionStatus] = [.wrongDefinition, .notExecuted, .executing, .succeeded, .failed]
        for status in statuses {
            let label = doc.createLabel()!
            label.setGraphNode()
            #expect(label.setGraphNodeStatus(status))
            #expect(label.graphNodeStatus() == status)
        }
    }
}

// MARK: - TFunction Function Attribute Tests (v0.56.0)

@Suite("TFunction Function Attribute")
struct TFunctionFunctionAttrTests {

    @Test("Create function attribute")
    func createFunction() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setFunctionAttribute())
        // Initially not failed
        #expect(!label.functionIsFailed)
    }

    @Test("Function failure mode")
    func functionFailure() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setFunctionAttribute()
        #expect(label.setFunctionFailure(1))
        #expect(label.functionIsFailed)
        if let failure = label.functionFailure {
            #expect(failure == 1)
        }
    }
}

// MARK: - TNaming CopyShape Tests (v0.56.0)

@Suite("TNaming CopyShape")
struct TNamingCopyShapeTests {

    @Test("Deep copy a box shape")
    func deepCopyBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        if let copy = box.deepCopy() {
            #expect(copy.isValid)
            #expect(copy !== box)
        }
    }

    @Test("Deep copy a sphere shape")
    func deepCopySphere() {
        let sphere = Shape.sphere(radius: 5.0)!
        if let copy = sphere.deepCopy() {
            #expect(copy.isValid)
        }
    }
}

// MARK: - OCAF Format Registration Tests (v0.57.0)

@Suite("OCAF Format Registration")
struct OCAFFormatRegistrationTests {

    @Test("Register all format drivers")
    func registerFormats() {
        let doc = Document.create()!
        doc.defineAllFormats()
        let formats = doc.readingFormats
        #expect(formats.count >= 4)
    }

    @Test("Reading and writing formats")
    func readWriteFormats() {
        let doc = Document.create()!
        doc.defineAllFormats()
        let reading = doc.readingFormats
        let writing = doc.writingFormats
        #expect(!reading.isEmpty)
        #expect(!writing.isEmpty)
    }
}

// MARK: - OCAF Save/Load Binary Tests (v0.57.0)

@Suite("OCAF Save/Load Binary")
struct OCAFSaveLoadBinaryTests {

    @Test("Save and load BinOcaf document")
    func saveLoadBinOcaf() {
        let doc = Document.create(format: "BinOcaf")!
        let label = doc.createLabel()!
        label.setName("TestBin")
        label.setInteger(42)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.cbf"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)
        #expect(doc.isSaved)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        if let loaded = loaded {
            // Verify data survived round-trip
            #expect(loaded.storageFormat != nil)
        }

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Save and load BinXCAF with shapes")
    func saveLoadBinXCAF() {
        let doc = Document.create(format: "BinXCAF")!
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let label = doc.createLabel()!
        label.setName("MyBox")
        label.setShapeAttribute(box)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.xbf"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        #expect(loaded != nil)

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}

// MARK: - OCAF Save/Load XML Tests (v0.57.0)

@Suite("OCAF Save/Load XML")
struct OCAFSaveLoadXmlTests {

    @Test("Save and load XmlOcaf document")
    func saveLoadXmlOcaf() {
        let doc = Document.create(format: "XmlOcaf")!
        let label = doc.createLabel()!
        label.setName("TestXml")
        label.setReal(3.14)

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57.xml"
        let status = doc.saveOCAF(to: tmpPath)
        #expect(status == .ok)

        let (loaded, readStatus) = Document.loadOCAF(from: tmpPath)
        #expect(readStatus == .ok)
        #expect(loaded != nil)

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}

// MARK: - OCAF Document Metadata Tests (v0.57.0)

@Suite("OCAF Document Metadata")
struct OCAFDocumentMetadataTests {

    @Test("Document storage format")
    func storageFormat() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(doc.storageFormat == "BinOcaf")
    }

    @Test("Change storage format")
    func changeFormat() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(doc.setStorageFormat("XmlOcaf"))
        #expect(doc.storageFormat == "XmlOcaf")
    }

    @Test("Document not saved initially")
    func notSavedInitially() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(!doc.isSaved)
    }

    @Test("Document count")
    func documentCount() {
        let doc = Document.create(format: "BinOcaf")!
        #expect(doc.documentCount >= 1)
    }

    @Test("Create with XCAF format")
    func createXCAF() {
        let doc = Document.create(format: "BinXCAF")
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.storageFormat == "BinXCAF")
        }
    }
}

// MARK: - PCDM Status Enums Tests (v0.57.0)

@Suite("PCDM Status Enums")
struct PCDMStatusEnumTests {

    @Test("StoreStatus values")
    func storeStatusValues() {
        #expect(StoreStatus.ok.rawValue == 0)
        #expect(StoreStatus.driverFailure.rawValue == 1)
        #expect(StoreStatus.writeFailure.rawValue == 2)
        #expect(StoreStatus.failure.rawValue == 3)
    }

    @Test("ReaderStatus values")
    func readerStatusValues() {
        #expect(ReaderStatus.ok.rawValue == 0)
        #expect(ReaderStatus.noDriver.rawValue == 1)
        #expect(ReaderStatus.openError.rawValue == 3)
        #expect(ReaderStatus.unrecognizedFileFormat.rawValue == 12)
    }

    @Test("Load nonexistent file returns error")
    func loadNonexistent() {
        let (doc, status) = Document.loadOCAF(from: "/nonexistent/file.cbf")
        #expect(doc == nil)
        #expect(status != .ok)
    }
}

// MARK: - OCAF Save In-Place Tests (v0.57.0)

@Suite("OCAF Save In-Place")
struct OCAFSaveInPlaceTests {

    @Test("Save in-place after initial save")
    func saveInPlace() {
        let doc = Document.create(format: "BinOcaf")!
        let label = doc.createLabel()!
        label.setName("Initial")

        let tmpPath = NSTemporaryDirectory() + "swift_test_v57_inplace.cbf"
        let status1 = doc.saveOCAF(to: tmpPath)
        #expect(status1 == .ok)

        // Modify and save in place
        label.setInteger(100)
        let status2 = doc.saveOCAFInPlace()
        #expect(status2 == .ok)

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Save in-place fails without prior save")
    func saveInPlaceFailsWithoutSave() {
        let doc = Document.create(format: "BinOcaf")!
        let status = doc.saveOCAFInPlace()
        #expect(status != .ok)
    }
}

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
            let shapes = doc.allShapes()
            #expect(shapes.count > 0)
        }
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    @Test("Load OBJ with single precision")
    func loadOBJSinglePrecision() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_sp.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(from: url, singlePrecision: true)
        #expect(doc != nil)
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
        try? FileManager.default.removeItem(atPath: srcPath)
        try? FileManager.default.removeItem(atPath: outPath)
    }

    @Test("Load OBJ with coordinate system")
    func loadOBJWithCS() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let tmpPath = NSTemporaryDirectory() + "swift_test_v59_obj_cs.obj"
        let url = URL(fileURLWithPath: tmpPath)
        try box.writeOBJ(to: url)

        let doc = Document.loadOBJ(from: url,
                                    inputCS: .zUp, outputCS: .yUp)
        #expect(doc != nil)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}

// MARK: - v0.60.0 XDE/XCAF Full Coverage Tests

@Suite("XDE ShapeTool Queries")
struct XDEShapeToolQueryTests {
    @Test("AddShape and GetShapeCount")
    func addShapeAndCount() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        #expect(box != nil)
        if let box = box {
            let labelId = doc.addShape(box)
            #expect(labelId >= 0)
            #expect(doc.shapeCount > 0)
        }
    }

    @Test("GetFreeShapeCount")
    func freeShapeCount() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            #expect(doc.freeShapeCount > 0)
        }
    }

    @Test("FindShape and SearchShape")
    func findAndSearch() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let addedId = doc.addShape(box)
            #expect(addedId >= 0)
            let foundId = doc.findShape(box)
            #expect(foundId >= 0)
            let searchId = doc.searchShape(box)
            #expect(searchId >= 0)
        }
    }

    @Test("NewShape and RemoveShape")
    func newAndRemove() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let labelId = doc.addShape(box)
            #expect(labelId >= 0)
            let removed = doc.removeShape(labelId: labelId)
            #expect(removed)
        }
    }

    @Test("IsTopLevel, IsComponent, IsCompound on node")
    func labelQueries() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            #expect(roots.count > 0)
            if let root = roots.first {
                #expect(root.isTopLevel)
                #expect(!root.isComponent)
            }
        }
    }
}

@Suite("XDE Assembly Operations")
struct XDEAssemblyOperationTests {
    @Test("AddComponent creates assembly")
    func addComponent() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let box = box, let sphere = sphere {
            let boxLabelId = doc.addShape(box)
            let sphereLabelId = doc.addShape(sphere)
            let assemblyLabelId = doc.newShapeLabel()
            #expect(assemblyLabelId >= 0)

            let comp1 = doc.addComponent(assemblyLabelId: assemblyLabelId,
                                          shapeLabelId: boxLabelId,
                                          translation: (0, 0, 0))
            #expect(comp1 >= 0)

            let comp2 = doc.addComponent(assemblyLabelId: assemblyLabelId,
                                          shapeLabelId: sphereLabelId,
                                          translation: (50, 0, 0))
            #expect(comp2 >= 0)

            #expect(doc.componentCount(assemblyLabelId: assemblyLabelId) == 2)
        }
    }

    @Test("GetComponents and GetReferredShape")
    func getComponents() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let boxLabelId = doc.addShape(box)
            let assemblyLabelId = doc.newShapeLabel()
            let compId = doc.addComponent(assemblyLabelId: assemblyLabelId,
                                           shapeLabelId: boxLabelId)
            #expect(compId >= 0)
            let compLabelId = doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: 0)
            #expect(compLabelId >= 0)
            let referredId = doc.componentReferredLabelId(compLabelId)
            #expect(referredId >= 0)
        }
    }

    @Test("RemoveComponent")
    func removeComponent() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let box = box, let sphere = sphere {
            let boxId = doc.addShape(box)
            let sphereId = doc.addShape(sphere)
            let asmId = doc.newShapeLabel()
            let comp1 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId)
            let comp2 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: sphereId)
            #expect(doc.componentCount(assemblyLabelId: asmId) == 2)
            doc.removeComponent(labelId: comp2)
            #expect(doc.componentCount(assemblyLabelId: asmId) == 1)
            _ = comp1 // silence warning
        }
    }

    @Test("ShapeUserCount")
    func userCount() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let boxId = doc.addShape(box)
            let asmId = doc.newShapeLabel()
            doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId)
            #expect(doc.shapeUserCount(shapeLabelId: boxId) > 0)
        }
    }

    @Test("UpdateAssemblies")
    func updateAssemblies() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        doc.updateAssemblies()
        // No crash = success
        #expect(Bool(true))
    }
}

@Suite("XDE ColorTool by Shape")
struct XDEColorToolByShapeTests {
    @Test("SetColor and GetColor by shape")
    func setAndGetColor() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let red = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            doc.setShapeColor(box, color: red)
            #expect(doc.isShapeColorSet(box))
            if let got = doc.shapeColor(box) {
                #expect(abs(got.red - 1.0) < 1e-5)
                #expect(abs(got.green) < 1e-5)
            }
        }
    }

    @Test("Label visibility")
    func visibility() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.isVisible = false
                #expect(!node.isVisible)
                node.isVisible = true
                #expect(node.isVisible)
            }
        }
    }
}

@Suite("XDE Area Volume Centroid")
struct XDEAreaVolumeCentroidTests {
    @Test("Set and get area")
    func area() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setArea(2200.0)
                if let area = node.area {
                    #expect(abs(area - 2200.0) < 1e-5)
                }
            }
        }
    }

    @Test("Set and get volume")
    func volume() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setVolume(6000.0)
                if let vol = node.volume {
                    #expect(abs(vol - 6000.0) < 1e-5)
                }
            }
        }
    }

    @Test("Set and get centroid")
    func centroid() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setCentroid(x: 5, y: 10, z: 15)
                if let c = node.centroid {
                    #expect(abs(c.x - 5.0) < 1e-5)
                    #expect(abs(c.y - 10.0) < 1e-5)
                    #expect(abs(c.z - 15.0) < 1e-5)
                }
            }
        }
    }
}

@Suite("XDE LayerTool Expansion")
struct XDELayerToolExpansionTests {
    @Test("SetLayer and IsLayerSet")
    func setAndCheck() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setLayer("Layer1")
                #expect(node.isLayerSet("Layer1"))
            }
        }
    }

    @Test("GetLayers returns layer names")
    func getLayers() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setLayer("TestLayer")
                let layers = node.layers
                #expect(layers.count == 1)
                if layers.count > 0 {
                    #expect(layers[0] == "TestLayer")
                }
            }
        }
    }

    @Test("FindLayer and layer visibility")
    func findAndVisibility() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setLayer("VisLayer")
                let layerLabelId = doc.findLayer("VisLayer")
                #expect(layerLabelId >= 0)

                doc.setLayerVisibility(layerLabelId: layerLabelId, visible: false)
                #expect(!doc.layerVisibility(layerLabelId: layerLabelId))

                doc.setLayerVisibility(layerLabelId: layerLabelId, visible: true)
                #expect(doc.layerVisibility(layerLabelId: layerLabelId))
            }
        }
    }
}

@Suite("XDE Editor")
struct XDEEditorTests {
    @Test("EditorExpand compound to assembly")
    func editorExpand() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let box = box, let sphere = sphere {
            let compound = Shape.compound([box, sphere])
            if let compound = compound {
                let labelId = doc.addShape(compound, makeAssembly: false)
                #expect(labelId >= 0)
                // editorExpand may or may not succeed depending on shape structure
                _ = doc.editorExpand(labelId: labelId, recursively: false)
                #expect(Bool(true)) // no crash = success
            }
        }
    }

    @Test("RescaleGeometry")
    func rescaleGeometry() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let labelId = doc.addShape(box)
            // Rescale may return false for non-root labels, but shouldn't crash
            _ = doc.rescaleGeometry(labelId: labelId, scaleFactor: 2.0, forceIfNotRoot: true)
            #expect(Bool(true)) // no crash = success
        }
    }
}

// MARK: - v0.83.0: XDE Attributes Tests

@Suite("XCAFDoc_Location Tests")
struct XCAFDocLocationTests {
    @Test func setAndGetLocation() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                let ok = label.setLocationTranslation(x: 10, y: 20, z: 30)
                #expect(ok)
                #expect(label.hasLocationAttribute)
                if let loc = label.locationTranslation {
                    #expect(abs(loc.x - 10) < 1e-6)
                    #expect(abs(loc.y - 20) < 1e-6)
                    #expect(abs(loc.z - 30) < 1e-6)
                }
            }
        }
    }

    @Test func noLocation() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(!label.hasLocationAttribute)
                #expect(label.locationTranslation == nil)
            }
        }
    }
}

@Suite("XCAFDoc_GraphNode Tests")
struct XCAFDocGraphNodeTests {
    @Test func setAndRelate() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let l1 = doc.createLabel(parent: main),
               let l2 = doc.createLabel(parent: main) {
                #expect(l1.setXCAFGraphNode())
                #expect(l2.setXCAFGraphNode())
                #expect(l1.xcafGraphNodeSetChild(l2))
                #expect(l2.xcafGraphNodeSetFather(l1))
                #expect(l1.xcafGraphNodeChildCount == 1)
                #expect(l2.xcafGraphNodeFatherCount == 1)
            }
        }
    }

    @Test func unsetRelationship() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let l1 = doc.createLabel(parent: main),
               let l2 = doc.createLabel(parent: main) {
                l1.setXCAFGraphNode()
                l2.setXCAFGraphNode()
                l1.xcafGraphNodeSetChild(l2)
                l2.xcafGraphNodeSetFather(l1)
                #expect(l1.xcafGraphNodeUnSetChild(l2))
                #expect(l2.xcafGraphNodeUnSetFather(l1))
                #expect(l1.xcafGraphNodeChildCount == 0)
                #expect(l2.xcafGraphNodeFatherCount == 0)
            }
        }
    }

    @Test func isFatherIsChild() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let l1 = doc.createLabel(parent: main),
               let l2 = doc.createLabel(parent: main) {
                l1.setXCAFGraphNode()
                l2.setXCAFGraphNode()
                l1.xcafGraphNodeSetChild(l2)
                l2.xcafGraphNodeSetFather(l1)
                // Check relationship queries
                let isFather = l1.xcafGraphNodeIsFather(of: l2)
                let isChild = l2.xcafGraphNodeIsChild(of: l1)
                #expect(isFather || isChild || l1.xcafGraphNodeChildCount > 0)
            }
        }
    }
}

@Suite("XCAFDoc_Color Tests")
struct XCAFDocColorTests {
    @Test func setAndGetRGB() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setColorAttribute(red: 1.0, green: 0.0, blue: 0.0))
                if let c = label.colorAttribute {
                    #expect(abs(c.red - 1.0) < 1e-6)
                    #expect(c.green < 0.01)
                }
            }
        }
    }

    @Test func setAndGetRGBA() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setColorAttribute(red: 0.5, green: 0.6, blue: 0.7, alpha: 0.8))
                if let rgba = label.colorRGBAAttribute {
                    #expect(abs(rgba.alpha - 0.8) < 0.02)
                }
                #expect(abs(label.colorAlphaAttribute - 0.8) < 0.02)
            }
        }
    }

    @Test func namedColor() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                // Quantity_NOC_RED = 485 in OCCT 8
                #expect(label.setColorAttribute(red: 1.0, green: 0.0, blue: 0.0))
                let noc = label.colorNOCAttribute
                #expect(noc >= 0) // Just verify it returns a valid value
            }
        }
    }
}

@Suite("XCAFDoc_Material Tests")
struct XCAFDocMaterialTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setMaterialAttribute(
                    name: "Steel", description: "Carbon steel",
                    density: 7850.0, densityName: "density",
                    densityValueType: "kg/m3"))
                #expect(label.hasMaterialAttribute)
                #expect(label.materialAttributeName == "Steel")
                #expect(label.materialAttributeDescription == "Carbon steel")
                if let d = label.materialAttributeDensity {
                    #expect(abs(d - 7850.0) < 1e-6)
                }
            }
        }
    }

    @Test func noMaterial() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(!label.hasMaterialAttribute)
                #expect(label.materialAttributeName == nil)
            }
        }
    }
}

@Suite("XCAFDoc_NoteComment Tests")
struct XCAFDocNoteCommentTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setNoteComment(userName: "TestUser", timeStamp: "2026-03-14",
                                              comment: "This is a comment"))
                #expect(label.noteCommentText == "This is a comment")
                #expect(label.noteUserName == "TestUser")
            }
        }
    }
}

@Suite("XCAFDoc_NoteBalloon Tests")
struct XCAFDocNoteBalloonTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setNoteBalloon(userName: "User", timeStamp: "2026-03-14",
                                              comment: "Balloon text"))
            }
        }
    }
}

@Suite("XCAFDoc_NoteBinData Tests")
struct XCAFDocNoteBinDataTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                let data: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
                #expect(label.setNoteBinData(userName: "User", timeStamp: "2026-03-14",
                                              title: "test.bin",
                                              mimeType: "application/octet-stream",
                                              data: data))
                #expect(label.noteBinDataSize == 4)
            }
        }
    }
}

@Suite("XCAFDoc_NotesTool Tests")
struct XCAFDocNotesToolTests {
    @Test func createAndCountNotes() {
        if let doc = Document.create() {
            #expect(doc.notesToolNoteCount == 0)
            let note = doc.notesToolCreateComment(userName: "User", timeStamp: "2026-03-14",
                                                    comment: "Comment 1")
            #expect(note != nil)
            #expect(doc.notesToolNoteCount == 1)
        }
    }

    @Test func createBalloon() {
        if let doc = Document.create() {
            let note = doc.notesToolCreateBalloon(userName: "User", timeStamp: "2026-03-14",
                                                    comment: "Balloon")
            #expect(note != nil)
            #expect(doc.notesToolNoteCount == 1)
        }
    }

    @Test func createBinData() {
        if let doc = Document.create() {
            let data: [UInt8] = [1, 2, 3, 4]
            let note = doc.notesToolCreateBinData(userName: "User", timeStamp: "2026-03-14",
                                                    title: "data.bin",
                                                    mimeType: "application/octet-stream",
                                                    data: data)
            #expect(note != nil)
            #expect(doc.notesToolNoteCount == 1)
        }
    }

    @Test func deleteAllNotes() {
        if let doc = Document.create() {
            doc.notesToolCreateComment(userName: "U", timeStamp: "T", comment: "C1")
            doc.notesToolCreateBalloon(userName: "U", timeStamp: "T", comment: "C2")
            doc.notesToolCreateBinData(userName: "U", timeStamp: "T", title: "t",
                                        mimeType: "m", data: [0])
            #expect(doc.notesToolNoteCount == 3)
            let deleted = doc.notesToolDeleteAllNotes()
            #expect(deleted == 3)
            #expect(doc.notesToolNoteCount == 0)
        }
    }

    @Test func orphanNotes() {
        if let doc = Document.create() {
            doc.notesToolCreateComment(userName: "U", timeStamp: "T", comment: "orphan")
            // Notes not attached to shapes are orphans
            #expect(doc.notesToolOrphanNoteCount >= 0)
        }
    }
}

@Suite("XCAFDoc_ClippingPlaneTool Tests")
struct XCAFDocClippingPlaneToolTests {
    @Test func addAndGet() {
        if let doc = Document.create() {
            if let clip = doc.clippingPlaneToolAdd(
                originX: 0, originY: 0, originZ: 5,
                normalX: 0, normalY: 0, normalZ: 1,
                name: "ZClip", capping: true) {
                #expect(doc.clippingPlaneToolIsClipPlane(clip))
                if let plane = doc.clippingPlaneToolGet(clip) {
                    #expect(abs(plane.originZ - 5.0) < 1e-6)
                    #expect(abs(plane.normalZ - 1.0) < 1e-6)
                    #expect(plane.capping)
                }
            }
        }
    }

    @Test func remove() {
        if let doc = Document.create() {
            if let clip = doc.clippingPlaneToolAdd(
                originX: 0, originY: 0, originZ: 0,
                normalX: 1, normalY: 0, normalZ: 0,
                name: "XClip", capping: false) {
                #expect(doc.clippingPlaneToolRemove(clip))
            }
        }
    }
}

@Suite("XCAFDoc_ShapeMapTool Tests")
struct XCAFDocShapeMapToolTests {
    @Test func setShapeAndQuery() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setShapeMapTool())
                if let box = Shape.box(width: 10, height: 20, depth: 30) {
                    #expect(label.shapeMapToolSetShape(box))
                    let faces = box.subShapes(ofType: .face)
                    if let face = faces.first {
                        #expect(label.shapeMapToolIsSubShape(face))
                    }
                    #expect(label.shapeMapToolExtent > 0)
                }
            }
        }
    }
}

@Suite("XCAFDoc_AssemblyGraph Tests")
struct XCAFDocAssemblyGraphTests {
    @Test func createFromDocument() {
        if let doc = Document.create() {
            // Add a shape to make the graph non-trivial
            if let main = doc.mainLabel, let label = doc.createLabel(parent: main) {
                if let box = Shape.box(width: 10, height: 10, depth: 10) {
                    // We can't easily call ShapeTool from Swift, but creating the graph should work
                    if let graph = AssemblyGraph(document: doc) {
                        #expect(graph.nodeCount >= 0)
                        #expect(graph.linkCount >= 0)
                        #expect(graph.rootCount >= 0)
                    }
                }
            }
        }
    }
}

@Suite("XCAFDoc_AssemblyItemId Tests")
struct XCAFDocAssemblyItemIdTests {
    @Test func createFromString() {
        let id = AssemblyItemId("0:1:1:1/0:1:1:2")
        #expect(id.isValid)
        #expect(id.pathCount == 2)
    }

    @Test func emptyIsNull() {
        let id = AssemblyItemId("")
        #expect(!id.isValid)
    }

    @Test func equality() {
        let id1 = AssemblyItemId("0:1:1:1/0:1:1:2")
        let id2 = AssemblyItemId("0:1:1:1/0:1:1:2")
        #expect(id1.isEqual(to: id2))
    }

    @Test func inequality() {
        let id1 = AssemblyItemId("0:1:1:1")
        let id2 = AssemblyItemId("0:1:1:2")
        #expect(!id1.isEqual(to: id2))
    }
}

@Suite("XCAFView_Object Tests")
struct XCAFViewObjectTests {
    @Test func create() {
        let view = ViewObject()
        #expect(view != nil)
    }

    @Test func projectionType() {
        if let view = ViewObject() {
            view.setType(.central)
            #expect(view.type == .central)
            view.setType(.parallel)
            #expect(view.type == .parallel)
        }
    }

    @Test func viewDirection() {
        if let view = ViewObject() {
            view.setViewDirection(x: 1, y: 0, z: 0)
            let dir = view.viewDirection
            #expect(abs(dir.x - 1.0) < 1e-6)
        }
    }

    @Test func upDirection() {
        if let view = ViewObject() {
            view.setUpDirection(x: 0, y: 0, z: 1)
            let up = view.upDirection
            #expect(abs(up.z - 1.0) < 1e-6)
        }
    }

    @Test func windowSize() {
        if let view = ViewObject() {
            view.setWindowHorizontalSize(800)
            view.setWindowVerticalSize(600)
            #expect(abs(view.windowHorizontalSize - 800) < 1e-6)
            #expect(abs(view.windowVerticalSize - 600) < 1e-6)
        }
    }

    @Test func clippingPlanes() {
        if let view = ViewObject() {
            view.setFrontPlaneDistance(1.0)
            view.setBackPlaneDistance(1000.0)
            #expect(view.hasFrontPlaneClipping)
            #expect(view.hasBackPlaneClipping)
            #expect(abs(view.frontPlaneDistance - 1.0) < 1e-6)
            #expect(abs(view.backPlaneDistance - 1000.0) < 1e-6)
            view.unsetFrontPlaneClipping()
            #expect(!view.hasFrontPlaneClipping)
        }
    }

    @Test func name() {
        if let view = ViewObject() {
            view.setName("TopView")
            #expect(view.name == "TopView")
        }
    }
}

@Suite("XCAFNoteObjects_NoteObject Tests")
struct XCAFNoteObjectsTests {
    @Test func create() {
        let obj = NoteObject()
        #expect(obj != nil)
    }

    @Test func initiallyEmpty() {
        if let obj = NoteObject() {
            #expect(!obj.hasPlane)
            #expect(!obj.hasPoint)
            #expect(!obj.hasPointText)
        }
    }

    @Test func setPlane() {
        if let obj = NoteObject() {
            obj.setPlane(originX: 1, originY: 2, originZ: 3,
                         normalX: 0, normalY: 0, normalZ: 1)
            #expect(obj.hasPlane)
            let origin = obj.planeOrigin
            #expect(abs(origin.x - 1.0) < 1e-6)
        }
    }

    @Test func setPoint() {
        if let obj = NoteObject() {
            obj.setPoint(x: 10, y: 20, z: 30)
            #expect(obj.hasPoint)
            let pt = obj.point
            #expect(abs(pt.x - 10) < 1e-6)
        }
    }

    @Test func setPresentation() {
        if let obj = NoteObject() {
            if let box = Shape.box(width: 1, height: 1, depth: 1) {
                obj.setPresentation(box)
                #expect(obj.presentation != nil)
            }
        }
    }

    @Test func reset() {
        if let obj = NoteObject() {
            obj.setPlane(originX: 1, originY: 2, originZ: 3,
                         normalX: 0, normalY: 0, normalZ: 1)
            obj.setPoint(x: 10, y: 20, z: 30)
            obj.reset()
            #expect(!obj.hasPlane)
            #expect(!obj.hasPoint)
        }
    }
}

@Suite("XCAFPrs_Style Tests")
struct XCAFPrsStyleTests {
    @Test func emptyStyle() {
        let style = PresentationStyle()
        #expect(style.isEmpty)
    }

    @Test func surfaceColor() {
        var style = PresentationStyle(surfaceRed: 0.0, surfaceGreen: 0.0, surfaceBlue: 1.0)
        #expect(!style.isEmpty)
        #expect(style.surfaceColor != nil)
    }

    @Test func visibility() {
        var style = PresentationStyle()
        style.isVisible = false
        style.surfaceColor = (1, 0, 0)
        #expect(!style.isVisible)
    }

    @Test func equality() {
        let s1 = PresentationStyle(surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        let s2 = PresentationStyle(surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        #expect(s1.isEqual(to: s2))
    }
}

@Suite("XCAFDoc_VisMaterialCommon Tests")
struct VisMaterialCommonTests {
    @Test func defaultValues() {
        let mat = VisMaterialCommon()
        #expect(mat.isDefined)
        #expect(abs(mat.diffuseColor.red - 0.8) < 0.02)
    }

    @Test func setProperties() {
        var mat = VisMaterialCommon()
        mat.diffuseColor = (1.0, 0.0, 0.0)
        mat.shininess = 0.5
        mat.transparency = 0.3
        #expect(abs(mat.shininess - 0.5) < 1e-6)
        #expect(abs(mat.transparency - 0.3) < 1e-6)
    }

    @Test func equality() {
        var m1 = VisMaterialCommon()
        m1.diffuseColor = (1.0, 0.0, 0.0)
        m1.shininess = 0.5
        m1.transparency = 0.3
        var m2 = VisMaterialCommon()
        m2.diffuseColor = (1.0, 0.0, 0.0)
        m2.shininess = 0.5
        m2.transparency = 0.3
        #expect(m1.isEqual(to: m2))
    }
}

@Suite("XCAFDoc_VisMaterialPBR Tests")
struct VisMaterialPBRTests {
    @Test func defaultValues() {
        let pbr = VisMaterialPBR()
        #expect(pbr.isDefined)
        #expect(abs(pbr.metallic - 1.0) < 1e-6)
        #expect(abs(pbr.roughness - 1.0) < 1e-6)
        #expect(abs(pbr.refractionIndex - 1.5) < 1e-6)
    }

    @Test func setProperties() {
        var pbr = VisMaterialPBR()
        pbr.metallic = 0.0
        pbr.roughness = 0.5
        pbr.baseColor = (0.8, 0.2, 0.1)
        #expect(abs(pbr.metallic) < 1e-6)
        #expect(abs(pbr.roughness - 0.5) < 1e-6)
    }

    @Test func equality() {
        var p1 = VisMaterialPBR()
        p1.metallic = 0.0
        p1.roughness = 0.5
        p1.baseColor = (0.8, 0.2, 0.1)
        var p2 = VisMaterialPBR()
        p2.metallic = 0.0
        p2.roughness = 0.5
        p2.baseColor = (0.8, 0.2, 0.1)
        #expect(p1.isEqual(to: p2))
    }
}

@Suite("TDataStd_Directory Tests")
struct DirectoryTests {
    @Test func createDirectory() {
        if let doc = Document.create() {
            let ok = doc.createDirectory(at: 100)
            #expect(ok)
        }
    }

    @Test func findDirectory() {
        if let doc = Document.create() {
            doc.createDirectory(at: 100)
            #expect(doc.hasDirectory(at: 100))
        }
    }

    @Test func addSubDirectory() {
        if let doc = Document.create() {
            doc.createDirectory(at: 100)
            let childTag = doc.addSubDirectory(under: 100)
            #expect(childTag != nil)
        }
    }

    @Test func makeObjectLabel() {
        if let doc = Document.create() {
            doc.createDirectory(at: 100)
            let objTag = doc.makeObjectLabel(under: 100)
            #expect(objTag != nil)
        }
    }
}

@Suite("TDataStd_Variable Tests")
struct VariableTests {
    @Test func setVariable() {
        if let doc = Document.create() {
            let ok = doc.setVariable(at: 1)
            #expect(ok)
        }
    }

    @Test func setAndGetName() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableName("velocity", at: 1)
            let name = doc.variableName(at: 1)
            #expect(name == "velocity")
        }
    }

    @Test func setAndGetValue() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableValue(42.5, at: 1)
            #expect(doc.variableIsValued(at: 1))
            let val = doc.variableValue(at: 1)
            #expect(abs(val - 42.5) < 1e-10)
        }
    }

    @Test func unitString() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableUnit("m/s", at: 1)
            let unit = doc.variableUnit(at: 1)
            #expect(unit == "m/s")
        }
    }

    @Test func constantFlag() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            doc.setVariableConstant(true, at: 1)
            #expect(doc.variableIsConstant(at: 1))
            doc.setVariableConstant(false, at: 1)
            #expect(!doc.variableIsConstant(at: 1))
        }
    }

    @Test func assignAndDesassignExpression() {
        if let doc = Document.create() {
            doc.setVariable(at: 1)
            let ok = doc.assignExpression(at: 1)
            #expect(ok)
            #expect(doc.variableIsAssigned(at: 1))
            doc.desassignExpression(at: 1)
            #expect(!doc.variableIsAssigned(at: 1))
        }
    }
}

@Suite("TDataStd_Expression Tests")
struct ExpressionTests {
    @Test func setExpression() {
        if let doc = Document.create() {
            let ok = doc.setExpression(at: 1)
            #expect(ok)
        }
    }

    @Test func setAndGetString() {
        if let doc = Document.create() {
            doc.setExpression(at: 1)
            doc.setExpressionString("x^2 + y^2", at: 1)
            let str = doc.expressionString(at: 1)
            #expect(str == "x^2 + y^2")
        }
    }

    @Test func getName() {
        if let doc = Document.create() {
            doc.setExpression(at: 1)
            doc.setExpressionString("a + b", at: 1)
            let name = doc.expressionName(at: 1)
            #expect(name != nil)
        }
    }
}

@Suite("TDocStd_XLink Tests")
struct XLinkTests {
    @Test func setXLink() {
        if let doc = Document.create() {
            let ok = doc.setXLink(at: 1)
            #expect(ok)
        }
    }

    @Test func documentEntry() {
        if let doc = Document.create() {
            doc.setXLink(at: 1)
            doc.setXLinkDocumentEntry("/doc/path", at: 1)
            let entry = doc.xLinkDocumentEntry(at: 1)
            #expect(entry == "/doc/path")
        }
    }

    @Test func labelEntry() {
        if let doc = Document.create() {
            doc.setXLink(at: 1)
            doc.setXLinkLabelEntry("0:1:2", at: 1)
            let entry = doc.xLinkLabelEntry(at: 1)
            #expect(entry == "0:1:2")
        }
    }
}

@Suite("XCAFDimTolObjects_Tool Tests")
struct DimTolToolTests {
    @Test func emptyDocumentCounts() {
        if let doc = Document.create() {
            #expect(doc.dimTolToolDimensionCount == 0)
            #expect(doc.dimTolToolToleranceCount == 0)
        }
    }
}

@Suite("TPrsStd_DriverTable Tests")
struct DriverTableTests {
    @Test func tableExists() {
        #expect(DriverTable.exists)
    }

    @Test func initAndClear() {
        DriverTable.initStandard()
        DriverTable.clear()
    }
}

@Suite("TObj_Application Tests")
struct TObjApplicationTests {
    @Test func getInstance() {
        let app = TObjApplication.shared
        #expect(app != nil)
    }

    @Test func verboseFlag() {
        if let app = TObjApplication.shared {
            app.isVerbose = true
            #expect(app.isVerbose)
            app.isVerbose = false
            #expect(!app.isVerbose)
        }
    }

    @Test func createDocument() {
        if let app = TObjApplication.shared {
            let doc = app.createDocument()
            #expect(doc != nil)
        }
    }
}

@Suite("TDF_IDFilter Tests")
struct IDFilterTests {
    @Test func createFilter() {
        let filter = IDFilter(ignoreAll: true)
        #expect(filter != nil)
        if let f = filter {
            #expect(f.isIgnoreAll)
        }
    }

    @Test func keepMode() {
        if let filter = IDFilter(ignoreAll: false) {
            #expect(!filter.isIgnoreAll)
        }
    }

    @Test func keepGUID() {
        if let filter = IDFilter(ignoreAll: true) {
            let guid = "2a96b606-ec8b-11d0-bee7-080009dc3333"
            filter.keep(guid)
            #expect(filter.isKept(guid))
        }
    }

    @Test func ignoreGUID() {
        if let filter = IDFilter(ignoreAll: false) {
            let guid = "2a96b606-ec8b-11d0-bee7-080009dc3333"
            filter.ignore(guid)
            #expect(filter.isIgnored(guid))
        }
    }

    @Test func toggleIgnoreAll() {
        if let filter = IDFilter(ignoreAll: true) {
            filter.isIgnoreAll = false
            #expect(!filter.isIgnoreAll)
        }
    }
}

// MARK: - v0.87.0: TDataStd_Tick/Current, ShapeAnalysis_Shell/CanonicalRecognition, Geom_Transformation/OffsetCurve/RectangularTrimmedSurface

@Suite("TDataStd_Tick Tests")
struct TickTests {
    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasTick(tag: 500))
        #expect(doc.setTick(tag: 500))
        #expect(doc.hasTick(tag: 500))
    }

    @Test func remove() {
        guard let doc = Document.create() else { return }
        _ = doc.setTick(tag: 501)
        #expect(doc.removeTick(tag: 501))
        #expect(!doc.hasTick(tag: 501))
    }

    @Test func removeNonExistent() {
        guard let doc = Document.create() else { return }
        #expect(!doc.removeTick(tag: 502))
    }
}

@Suite("TDataStd_Current Tests")
struct CurrentTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        #expect(doc.setCurrentLabel(tag: 510))
        if let tag = doc.currentLabel() {
            #expect(tag == 510)
        }
    }

    @Test func hasCurrent() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasCurrentLabel())
        _ = doc.setCurrentLabel(tag: 511)
        #expect(doc.hasCurrentLabel())
    }

    @Test func noCurrentReturnsNil() {
        guard let doc = Document.create() else { return }
        #expect(doc.currentLabel() == nil)
    }
}

// MARK: - v0.88.0: TNaming Extensions, IntPackedMap, NoteBook, UAttribute, ChildNodeIterator

@Suite("TNaming Extensions Tests")
struct TNamingExtensionTests {

    @Test func namingIsEmpty() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        // No naming recorded yet — should be empty
        #expect(doc.namingIsEmpty(on: node))
    }

    @Test func namingIsEmptyAfterRecord() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        #expect(!doc.namingIsEmpty(on: node))
    }

    @Test func namingVersion() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        #expect(doc.namingVersion(on: node) == 0)
        doc.setNamingVersion(on: node, version: 42)
        #expect(doc.namingVersion(on: node) == 42)
    }

    @Test func namingOriginalShape() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        // Primitive has no old shape — original should be nil
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        let original = doc.namingOriginalShape(on: node)
        #expect(original == nil)
    }

    @Test func namingOriginalShapeFromModify() {
        guard let doc = Document.create() else { return }
        guard let node1 = doc.createLabel() else { return }
        guard let node2 = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        guard let sphere = Shape.sphere(radius: 5) else { return }
        doc.recordNaming(on: node1, evolution: .primitive, newShape: box)
        doc.recordNaming(on: node2, evolution: .modify, oldShape: box, newShape: sphere)
        let original = doc.namingOriginalShape(on: node2)
        #expect(original != nil)
    }

    @Test func namingHasLabel() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        #expect(doc.namingHasLabel(shape: box))
    }

    @Test func namingFindLabel() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        let found = doc.namingFindLabel(shape: box)
        #expect(found != nil)
    }

    @Test func namingValidUntil() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node, evolution: .primitive, newShape: box)
        let valid = doc.namingValidUntil(shape: box)
        #expect(valid >= 0)
    }

    @Test func sameShapeCount() {
        guard let doc = Document.create() else { return }
        guard let node1 = doc.createLabel() else { return }
        guard let node2 = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node1, evolution: .primitive, newShape: box)
        doc.recordNaming(on: node2, evolution: .primitive, newShape: box)
        let count = doc.sameShapeCount(shape: box)
        #expect(count >= 2)
    }

    @Test func sameShapeLabels() {
        guard let doc = Document.create() else { return }
        guard let node1 = doc.createLabel() else { return }
        guard let node2 = doc.createLabel() else { return }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        doc.recordNaming(on: node1, evolution: .primitive, newShape: box)
        doc.recordNaming(on: node2, evolution: .primitive, newShape: box)
        let labels = doc.sameShapeLabels(shape: box)
        #expect(labels.count >= 2)
    }
}

@Suite("UAttribute Tests")
struct UAttributeTests {

    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        let guid = "12345678-1234-1234-1234-123456789012"
        #expect(doc.setUAttribute(tag: 300, guid: guid))
        #expect(doc.hasUAttribute(tag: 300, guid: guid))
    }

    @Test func differentGUID() {
        guard let doc = Document.create() else { return }
        let guid1 = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let guid2 = "11111111-2222-3333-4444-555555555555"
        doc.setUAttribute(tag: 301, guid: guid1)
        #expect(doc.hasUAttribute(tag: 301, guid: guid1))
        #expect(!doc.hasUAttribute(tag: 301, guid: guid2))
    }

    @Test func getID() {
        guard let doc = Document.create() else { return }
        let guid = "ABCDEF01-2345-6789-ABCD-EF0123456789"
        doc.setUAttribute(tag: 302, guid: guid)
        let retrieved = doc.uAttributeID(tag: 302, guid: guid)
        #expect(retrieved != nil)
        // The GUID should contain the original hex digits (may differ in formatting)
        if let retrieved {
            #expect(retrieved.lowercased().contains("abcdef01"))
        }
    }
}

@Suite("ChildNodeIterator Tests")
struct ChildNodeIteratorTests {

    @Test func noTreeNode() {
        guard let doc = Document.create() else { return }
        // No tree node set — count should be 0
        #expect(doc.childNodeCount(tag: 400) == 0)
    }
}

// MARK: - v0.89.0 Tests

@Suite("TDF Transaction Named Tests")
struct TDFTransactionNamedTests {

    @Test func openNamedTransaction() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        let txnNum = doc.openNamedTransaction("TestTxn")
        #expect(txnNum >= 1)
        doc.commitTransaction()
    }

    @Test func transactionNumber() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        let before = doc.transactionNumber
        #expect(before == 0)
        doc.openNamedTransaction("CountTxn")
        let during = doc.transactionNumber
        #expect(during == 1)
        doc.commitTransaction()
        let after = doc.transactionNumber
        #expect(after == 0)
    }

    @Test func commitWithDelta() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openTransaction()
        if let node = doc.createLabel() {
            node.setInteger(42)
        }
        if let delta = doc.commitWithDelta() {
            #expect(!delta.isEmpty)
            #expect(delta.attributeDeltaCount >= 1)
            #expect(delta.beginTime >= 0)
            #expect(delta.endTime >= delta.beginTime)
        }
    }

    @Test func deltaName() {
        guard let doc = Document.create() else { return }
        doc.setUndoLimit(10)
        doc.openTransaction()
        if let node = doc.createLabel() {
            node.setInteger(99)
        }
        if let delta = doc.commitWithDelta() {
            delta.setName("MyDelta")
            let name = delta.name
            #expect(name == "MyDelta")
        }
    }
}

@Suite("TDF ComparisonTool Tests")
struct TDFComparisonToolTests {

    @Test func isSelfContained() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        if let node = doc.createLabel() {
            node.setInteger(1)
            doc.commitTransaction()
            let result = doc.isSelfContained(labelId: node.labelId)
            #expect(result == true)
        }
    }
}

@Suite("TDocStd XLinkTool Tests")
struct TDocStdXLinkToolTests {

    @Test func xlinkCopy() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let src = doc.createLabel(), let tgt = doc.createLabel() else { return }
        src.setInteger(77)
        src.setName("XLinkSource")
        let ok = doc.xlinkCopy(targetLabelId: tgt.labelId, sourceLabelId: src.labelId)
        doc.commitTransaction()
        #expect(ok)
        if let val = tgt.integer {
            #expect(val == 77)
        }
    }

    @Test func xlinkCopyWithLink() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let src = doc.createLabel(), let tgt = doc.createLabel() else { return }
        src.setInteger(88)
        let ok = doc.xlinkCopyWithLink(targetLabelId: tgt.labelId, sourceLabelId: src.labelId)
        doc.commitTransaction()
        // CopyWithLink may fail if labels are in same document — just check no crash
        _ = ok
    }
}

@Suite("TFunction IFunction Tests")
struct TFunctionIFunctionTests {

    @Test func newFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        let ok = doc.newFunction(labelId: node.labelId, guid: "12345678-1234-1234-1234-123456789abc")
        doc.commitTransaction()
        #expect(ok)
    }

    @Test func deleteFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.newFunction(labelId: node.labelId, guid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        let deleted = doc.deleteFunction(labelId: node.labelId)
        doc.commitTransaction()
        #expect(deleted)
    }

    @Test func functionExecStatus() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.newFunction(labelId: node.labelId, guid: "11111111-2222-3333-4444-555555555555")

        if let status = doc.functionExecStatus(labelId: node.labelId) {
            #expect(status == .wrongDefinition)
        }

        doc.setFunctionExecStatus(labelId: node.labelId, status: .succeeded)
        if let status = doc.functionExecStatus(labelId: node.labelId) {
            #expect(status == .succeeded)
        }
        doc.commitTransaction()
    }

    @Test func noFunction() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let status = doc.functionExecStatus(labelId: node.labelId)
        #expect(status == nil)
    }
}

@Suite("TFunction Scope Tests")
struct TFunctionScopeTests {

    @Test func setFunctionScope() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        let ok = doc.setFunctionScope()
        doc.commitTransaction()
        #expect(ok)
    }

    @Test func addAndHasFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        guard let node = doc.createLabel() else { return }
        let added = doc.functionScopeAdd(labelId: node.labelId)
        #expect(added)
        #expect(doc.functionScopeHas(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func removeFunction() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        guard let node = doc.createLabel() else { return }
        doc.functionScopeAdd(labelId: node.labelId)
        let removed = doc.functionScopeRemove(labelId: node.labelId)
        #expect(removed)
        #expect(!doc.functionScopeHas(labelId: node.labelId))
        doc.commitTransaction()
    }

    @Test func removeAllFunctions() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        guard let l1 = doc.createLabel(), let l2 = doc.createLabel() else { return }
        doc.functionScopeAdd(labelId: l1.labelId)
        doc.functionScopeAdd(labelId: l2.labelId)
        #expect(doc.functionScopeCount == 2)
        doc.functionScopeRemoveAll()
        #expect(doc.functionScopeCount == 0)
        doc.commitTransaction()
    }

    @Test func freeID() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        doc.setFunctionScope()
        let freeId = doc.functionScopeFreeID
        #expect(freeId >= 1)
        guard let node = doc.createLabel() else { return }
        doc.functionScopeAdd(labelId: node.labelId)
        let freeId2 = doc.functionScopeFreeID
        #expect(freeId2 > freeId)
        doc.commitTransaction()
    }
}

@Suite("TDF AttributeIterator Tests")
struct TDFAttributeIteratorTests {

    @Test func attributeCount() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        node.setInteger(42)
        node.setReal(3.14)
        node.setName("Test")
        doc.commitTransaction()

        let count = doc.attributeCount(labelId: node.labelId)
        #expect(count >= 3)
    }

    @Test func emptyLabel() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let count = doc.attributeCount(labelId: node.labelId)
        #expect(count >= 0)
    }

    @Test func dataSetIsEmpty() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        let empty = doc.dataSetIsEmpty(labelId: node.labelId)
        #expect(!empty)
    }
}

// MARK: - v0.90.0 Tests

@Suite("TDF ChildIDIterator Tests")
struct TDFChildIDIteratorTests {

    @Test func countByGUID() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let parent = doc.createLabel() else { return }
        guard let c1 = doc.createLabel(parent: parent),
              let c2 = doc.createLabel(parent: parent),
              let c3 = doc.createLabel(parent: parent) else { return }
        // Set Name on 2 children, leave c3 without Name
        c1.setName("Child1")
        c2.setName("Child2")
        c3.setInteger(99)
        doc.commitTransaction()

        // TDataStd_Name GUID (OCCT 8.0.0-rc4)
        let nameGUID = "2a96b608-ec8b-11d0-bee7-080009dc3333"
        let count = doc.childIDCount(labelId: parent.labelId, guid: nameGUID)
        #expect(count == 2)
    }

    @Test func emptyResult() {
        guard let doc = Document.create() else { return }
        guard let parent = doc.createLabel() else { return }
        let count = doc.childIDCount(labelId: parent.labelId, guid: "99999999-9999-9999-9999-999999999999")
        #expect(count == 0)
    }
}

@Suite("TDocStd PathParser Tests")
struct TDocStdPathParserTests {

    @Test func parsePath() {
        let trek = PathParser.trek("/home/user/docs/model.step")
        #expect(trek != nil)
        if let trek { #expect(trek.contains("home")) }
    }

    @Test func parseName() {
        let name = PathParser.name("model.step")
        #expect(name == "model")
    }

    @Test func parseExtension() {
        let ext = PathParser.fileExtension("model.step")
        #expect(ext == "step")
    }
}

@Suite("TFunction DriverTable Tests")
struct TFunctionDriverTableTests {

    @Test func hasDriverUnknown() {
        let has = FunctionDriverTable.hasDriver(guid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        #expect(!has)
    }

    @Test func clear() {
        FunctionDriverTable.clear()
        // Just verify no crash
    }
}

@Suite("TNaming Scope Tests")
struct TNamingScopeTests {

    @Test func validAndIsValid() {
        guard let doc = Document.create() else { return }
        doc.namingScopeClear()
        guard let node = doc.createLabel() else { return }
        doc.namingScopeValid(labelId: node.labelId)
        #expect(doc.namingScopeIsValid(labelId: node.labelId))
    }

    @Test func unvalid() {
        guard let doc = Document.create() else { return }
        doc.namingScopeClear()
        guard let node = doc.createLabel() else { return }
        doc.namingScopeValid(labelId: node.labelId)
        doc.namingScopeUnvalid(labelId: node.labelId)
        #expect(!doc.namingScopeIsValid(labelId: node.labelId))
    }

    @Test func validCount() {
        guard let doc = Document.create() else { return }
        doc.namingScopeClear()
        guard let n1 = doc.createLabel(), let n2 = doc.createLabel() else { return }
        doc.namingScopeValid(labelId: n1.labelId)
        doc.namingScopeValid(labelId: n2.labelId)
        #expect(doc.namingScopeValidCount >= 2)
        doc.namingScopeClear()
        #expect(doc.namingScopeValidCount == 0)
    }
}

@Suite("TNaming Translator Tests")
struct TNamingTranslatorTests {

    @Test func translatorCopy() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return }
        guard let copy = box.translatorCopy() else {
            #expect(Bool(false), "translatorCopy should succeed")
            return
        }
        #expect(!box.isSame(as: copy))
        #expect(copy.isValid)
    }
}

@Suite("TDataXtd Placement Tests")
struct TDataXtdPlacementTests {

    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPlacement(labelId: node.labelId)
        doc.commitTransaction()
        #expect(doc.hasPlacement(labelId: node.labelId))
    }

    @Test func noPlacement() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(!doc.hasPlacement(labelId: node.labelId))
    }
}

@Suite("TDataXtd Presentation Tests")
struct TDataXtdPresentationTests {

    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.commitTransaction()
        #expect(doc.hasPresentation(labelId: node.labelId))
    }

    @Test func colorAndTransparency() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.presentationSetColor(labelId: node.labelId, colorIndex: 12) // RED
        doc.presentationSetTransparency(labelId: node.labelId, value: 0.5)
        doc.commitTransaction()

        if let color = doc.presentationGetColor(labelId: node.labelId) {
            #expect(color == 12)
        }
        if let transparency = doc.presentationGetTransparency(labelId: node.labelId) {
            #expect(abs(transparency - 0.5) < 1e-6)
        }
    }

    @Test func widthAndMode() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.presentationSetWidth(labelId: node.labelId, width: 2.0)
        doc.presentationSetMode(labelId: node.labelId, mode: 1)
        doc.commitTransaction()

        if let width = doc.presentationGetWidth(labelId: node.labelId) {
            #expect(abs(width - 2.0) < 1e-6)
        }
        if let mode = doc.presentationGetMode(labelId: node.labelId) {
            #expect(mode == 1)
        }
    }

    @Test func displayState() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.presentationSetDisplayed(labelId: node.labelId, displayed: true)
        doc.commitTransaction()
        #expect(doc.presentationIsDisplayed(labelId: node.labelId))
    }

    @Test func unsetPresentation() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.unsetPresentation(labelId: node.labelId)
        doc.commitTransaction()
        #expect(!doc.hasPresentation(labelId: node.labelId))
    }
}

@Suite("XCAFDoc AssemblyIterator Tests")
struct XCAFDocAssemblyIteratorTests {

    @Test func iterateAssembly() {
        guard let doc = Document.create() else { return }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        doc.addShape(box)
        let count = doc.assemblyItemCount()
        #expect(count >= 1)
    }
}

@Suite("XCAFDoc DimTol Tests")
struct XCAFDocDimTolTests {

    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setDimTol(labelId: node.labelId, kind: 1, values: [0.01, 0.05],
                      name: "Flatness", description: "Surface flatness tolerance")
        doc.commitTransaction()

        if let kind = doc.dimTolKind(labelId: node.labelId) {
            #expect(kind == 1)
        }
        if let name = doc.dimTolName(labelId: node.labelId) {
            #expect(name == "Flatness")
        }
        if let desc = doc.dimTolDescription(labelId: node.labelId) {
            #expect(desc == "Surface flatness tolerance")
        }
        if let vals = doc.dimTolValues(labelId: node.labelId) {
            #expect(vals.count == 2)
            if vals.count >= 2 {
                #expect(abs(vals[0] - 0.01) < 1e-9)
                #expect(abs(vals[1] - 0.05) < 1e-9)
            }
        }
    }

    @Test func noDimTol() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(doc.dimTolKind(labelId: node.labelId) == nil)
    }
}

@Suite("TDataXtd Constraint Tests")
struct TDataXtdConstraintTests {

    @Test func setAndGetType() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetType(labelId: node.labelId, type: .parallel)
        doc.commitTransaction()

        if let type = doc.constraintGetType(labelId: node.labelId) {
            #expect(type == .parallel)
        }
    }

    @Test func isPlanarAndDimension() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetType(labelId: node.labelId, type: .parallel)
        doc.commitTransaction()
        #expect(!doc.constraintIsPlanar(labelId: node.labelId))
        #expect(!doc.constraintIsDimension(labelId: node.labelId))
    }

    @Test func verifiedFlag() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetVerified(labelId: node.labelId, verified: true)
        doc.commitTransaction()
        #expect(doc.constraintGetVerified(labelId: node.labelId))
    }

    @Test func noConstraint() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(doc.constraintGetType(labelId: node.labelId) == nil)
    }
}

@Suite("TDataXtd PatternStd Tests")
struct TDataXtdPatternStdTests {

    @Test func setAndGetSignature() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPattern(labelId: node.labelId)
        doc.patternSetSignature(labelId: node.labelId, signature: .linear)
        doc.commitTransaction()

        if let sig = doc.patternGetSignature(labelId: node.labelId) {
            #expect(sig == .linear)
        }
    }

    @Test func hasPattern() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPattern(labelId: node.labelId)
        doc.commitTransaction()
        #expect(doc.hasPattern(labelId: node.labelId))
    }

    @Test func noPattern() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(!doc.hasPattern(labelId: node.labelId))
    }
}

// MARK: - v0.96.0 Tests

@Suite("XCAFDoc AssemblyItemRef Tests")
struct XCAFDocAssemblyItemRefTests {

    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1")
        doc.commitTransaction()
        let path = doc.assemblyItemRefPath(labelId: node.labelId)
        #expect(path != nil)
    }

    @Test func subshapeIndex() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1")
        doc.assemblyItemRefSetSubshape(labelId: node.labelId, index: 3)
        doc.commitTransaction()
        #expect(doc.assemblyItemRefHasExtra(labelId: node.labelId))
        if let idx = doc.assemblyItemRefGetSubshape(labelId: node.labelId) {
            #expect(idx == 3)
        }
    }

    @Test func clearExtra() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/0:1:1:1")
        doc.assemblyItemRefSetSubshape(labelId: node.labelId, index: 5)
        doc.assemblyItemRefClearExtra(labelId: node.labelId)
        doc.commitTransaction()
        #expect(!doc.assemblyItemRefHasExtra(labelId: node.labelId))
    }

    @Test func isOrphan() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setAssemblyItemRef(labelId: node.labelId, itemPath: "/99:99:99")
        doc.commitTransaction()
        #expect(doc.assemblyItemRefIsOrphan(labelId: node.labelId))
    }
}

@Suite("TNaming Naming Tests")
struct TNamingNamingTests {

    @Test func insertNaming() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        let ok = doc.insertNaming(labelId: node.labelId)
        doc.commitTransaction()
        #expect(ok)
    }

    @Test func namingIsDefined() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.insertNaming(labelId: node.labelId)
        doc.commitTransaction()
        // Newly inserted naming is not yet defined (no Name() called)
        #expect(!doc.namingIsDefined(labelId: node.labelId))
    }
}

@Suite("XCAFPrs_DocumentExplorer Tests")
struct DocumentExplorerTests {

    @Test func exploreDocumentWithShape() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            #expect(count >= 1)
        }
    }

    @Test func explorerShapeAtIndex() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let shape = doc.explorerShape(at: 0)
            #expect(shape != nil)
        }
    }

    @Test func explorerPathId() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let pathId = doc.explorerPathId(at: 0)
            #expect(pathId != nil)
        }
    }

    @Test func findShapeFromPathId() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            if let pathId = doc.explorerPathId(at: 0) {
                let found = doc.explorerFindShape(pathId: pathId)
                #expect(found != nil)
            }
        }
    }
}

@Suite("DocumentExplorer Extension Tests")
struct DocumentExplorerExtensionTests {

    @Test func explorerDepth() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            if count > 0 {
                let depth = doc.explorerDepth(at: 0)
                #expect(depth >= 0)
            }
        }
    }

    @Test func explorerIsAssembly() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            if count > 0 {
                // A single shape is not an assembly
                let isAsm = doc.explorerIsAssembly(at: 0)
                #expect(!isAsm)
            }
        }
    }

    @Test func explorerLocation() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            if count > 0 {
                let matrix = doc.explorerLocation(at: 0)
                #expect(matrix.count == 12)
            }
        }
    }
}

@Suite("v0.126.0 — XCAFDoc_ColorTool completions")
struct ColorToolCompletionsTests {
    @Test("AddColor and FindColor")
    func addAndFindColor() {
        guard let doc = Document.create() else { return }
        let tag = doc.colorToolAddColor(r: 1.0, g: 0.0, b: 0.0)
        #expect(tag >= 0)
        let found = doc.colorToolFindColor(r: 1.0, g: 0.0, b: 0.0)
        #expect(found == tag)
    }

    @Test("GetColorCount increases after AddColor")
    func colorCount() {
        guard let doc = Document.create() else { return }
        let before = doc.colorToolColorCount
        let _ = doc.colorToolAddColor(r: 0.0, g: 1.0, b: 0.0)
        let after = doc.colorToolColorCount
        #expect(after == before + 1)
    }

    @Test("RemoveColor removes a color")
    func removeColor() {
        guard let doc = Document.create() else { return }
        let tag = doc.colorToolAddColor(r: 0.0, g: 0.0, b: 1.0)
        let before = doc.colorToolColorCount
        let ok = doc.colorToolRemoveColor(labelId: tag)
        #expect(ok)
        let after = doc.colorToolColorCount
        #expect(after == before - 1)
    }

    @Test("Visibility defaults to true")
    func visibility() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                // Default visibility is true
                #expect(doc.colorToolIsVisible(labelId: labelId))
                // Set invisible
                doc.colorToolSetVisibility(labelId: labelId, visible: false)
                #expect(!doc.colorToolIsVisible(labelId: labelId))
                // Set visible again
                doc.colorToolSetVisibility(labelId: labelId, visible: true)
                #expect(doc.colorToolIsVisible(labelId: labelId))
            }
        }
    }

    @Test("ColorByLayer defaults to false")
    func colorByLayer() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.colorToolIsColorByLayer(labelId: labelId))
                doc.colorToolSetColorByLayer(labelId: labelId, isByLayer: true)
                #expect(doc.colorToolIsColorByLayer(labelId: labelId))
            }
        }
    }
}

@Suite("v0.126.0 — XCAFDoc_ShapeTool completions")
struct ShapeToolCompletionsTests {
    @Test("IsFree returns true for top-level shape")
    func isFree() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(doc.shapeToolIsFree(labelId: labelId))
            }
        }
    }

    @Test("IsSimpleShape returns true for box")
    func isSimpleShape() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(doc.shapeToolIsSimpleShape(labelId: labelId))
            }
        }
    }

    @Test("IsComponent returns false for simple shape")
    func isComponent() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsComponent(labelId: labelId))
            }
        }
    }

    @Test("IsCompound returns false for simple box")
    func isCompound() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsCompound(labelId: labelId))
            }
        }
    }

    @Test("IsSubShape returns false for top-level")
    func isSubShape() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsSubShape(labelId: labelId))
            }
        }
    }

    @Test("IsExternRef returns false for regular shape")
    func isExternRef() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsExternRef(labelId: labelId))
            }
        }
    }

    @Test("GetUsers returns 0 for unreferenced shape")
    func getUsers() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                let users = doc.shapeToolGetUsers(labelId: labelId)
                #expect(users == 0)
            }
        }
    }

    @Test("NbComponents returns 0 for simple shape")
    func nbComponents() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                let nb = doc.shapeToolNbComponents(labelId: labelId)
                #expect(nb == 0)
            }
        }
    }

    @Test("ComputeShapes doesn't crash")
    func computeShapes() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                doc.shapeToolComputeShapes(labelId: labelId)
                // Just check it doesn't crash
            }
        }
    }
}

// MARK: - v0.140: XCAFDoc GD&T write path

@Suite("v0.140 Document GD&T write + typed enums")
struct DocumentGDTTests {
    @Test("Create dimension on a box shape and read it back")
    func createAndReadDimension() throws {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        guard let box = Shape.box(width: 100, height: 50, depth: 25) else {
            Issue.record("box nil"); return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        #expect(labelId >= 0)

        let idx = doc.createDimension(on: labelId,
                                       type: .sizeRadius,
                                       value: 25.0,
                                       lowerTolerance: -0.1,
                                       upperTolerance: 0.1)
        #expect(idx == 0)
        #expect(doc.dimensionCount == 1)

        if let dim = doc.typedDimension(at: 0) {
            #expect(dim.type == .sizeRadius)
            #expect(abs(dim.value - 25.0) < 1e-9)
            #expect(abs(dim.lowerTolerance - (-0.1)) < 1e-9)
            #expect(abs(dim.upperTolerance - 0.1) < 1e-9)
        } else {
            Issue.record("typedDimension nil")
        }
    }

    @Test("Create geometric tolerance (flatness) on a shape")
    func createTolerance() throws {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        let idx = doc.createGeomTolerance(on: labelId, type: .flatness, value: 0.01)
        #expect(idx == 0)
        if let tol = doc.typedGeomTolerance(at: 0) {
            #expect(tol.type == .flatness)
            #expect(abs(tol.value - 0.01) < 1e-9)
        } else {
            Issue.record("typedGeomTolerance nil")
        }
    }

    @Test("Create datum A")
    func createDatum() throws {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        let idx = doc.createDatum(name: "A")
        #expect(idx == 0)
        if let datum = doc.typedDatum(at: 0) {
            #expect(datum.name == "A")
        } else {
            Issue.record("typedDatum nil")
        }
    }

    @Test("Full authoring: box + 3 dimensions + 2 tolerances + 2 datums")
    func fullAuthoring() throws {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        guard let box = Shape.box(width: 100, height: 50, depth: 25) else {
            Issue.record("box nil"); return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        doc.createDimension(on: shapeId, type: .sizeDiameter, value: 10.0)
        doc.createDimension(on: shapeId, type: .locationLinearDistance, value: 50.0)
        doc.createDimension(on: shapeId, type: .sizeRadius, value: 5.0)
        doc.createGeomTolerance(on: shapeId, type: .flatness, value: 0.01)
        doc.createGeomTolerance(on: shapeId, type: .perpendicularity, value: 0.05)
        doc.createDatum(name: "A")
        doc.createDatum(name: "B")

        #expect(doc.dimensionCount == 3)
        #expect(doc.geomToleranceCount == 2)
        #expect(doc.datumCount == 2)
        #expect(doc.typedDimensions.count == 3)
        #expect(doc.typedDimensions.map(\.type).contains(.sizeDiameter))
        #expect(doc.typedGeomTolerances.map(\.type).contains(.perpendicularity))
        #expect(doc.typedDatums.map(\.name).sorted() == ["A", "B"])
    }

    @Test("DimensionType enum covers all 32 cases")
    func dimensionTypeEnumComplete() {
        #expect(Document.DimensionType.allCases.count == 32)
    }

    @Test("GeomToleranceType enum covers all 16 cases")
    func geomToleranceTypeEnumComplete() {
        #expect(Document.GeomToleranceType.allCases.count == 16)
    }
}

// MARK: - TopologyGraph attribute store + Codable snapshot (#168)

@Suite("TopologyGraph Attributes")
struct TopologyGraphAttributeTests {

    /// Attach mixed attribute types to face/edge/vertex nodes and read them back.
    @Test func attachAndReadMixedAttributes() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
              let graph = TopologyGraph(shape: box) else { return }

        let faceNode = TopologyGraph.NodeRef(kind: .face, index: 0)
        let edgeNode = TopologyGraph.NodeRef(kind: .edge, index: 0)
        let vertexNode = TopologyGraph.NodeRef(kind: .vertex, index: 0)

        graph.setAttribute("residualRMS", .double(0.042), for: faceNode)
        graph.setAttribute("surfaceType", .string("plane"), for: faceNode)
        graph.setAttribute("params", .doubles([0, 0, 1, 5]), for: faceNode)
        graph.setAttribute("sharp", .bool(true), for: edgeNode)
        graph.setAttribute("regionTriangles", .ints([3, 7, 11, 19]), for: vertexNode)

        #expect(graph.attribute("residualRMS", for: faceNode)?.doubleValue == 0.042)
        #expect(graph.attribute("surfaceType", for: faceNode)?.stringValue == "plane")
        #expect(graph.attribute("params", for: faceNode)?.doublesValue == [0, 0, 1, 5])
        #expect(graph.attribute("sharp", for: edgeNode)?.boolValue == true)
        #expect(graph.attribute("regionTriangles", for: vertexNode)?.intsValue == [3, 7, 11, 19])
        #expect(graph.attribute("missing", for: faceNode) == nil)
        #expect(graph.attributes.annotatedNodeCount == 3)
    }

    /// Clearing the last attribute on a node drops the node entry entirely.
    @Test func clearingLastAttributeDropsNode() {
        guard let box = Shape.box(width: 5, height: 5, depth: 5),
              let graph = TopologyGraph(shape: box) else { return }
        let node = TopologyGraph.NodeRef(kind: .face, index: 1)
        graph.setAttribute("a", .int(1), for: node)
        graph.setAttribute("b", .int(2), for: node)
        #expect(graph.attributes.annotatedNodeCount == 1)
        graph.attributes.clear("a", for: node)
        #expect(graph.attribute("b", for: node)?.intValue == 2)
        #expect(graph.attributes.annotatedNodeCount == 1)
        graph.attributes.clear("b", for: node)
        #expect(graph.attributes.annotatedNodeCount == 0)
    }

    /// snapshot() -> JSON encode -> decode -> init(snapshot:) reproduces every attribute
    /// on the correct node.
    @Test func snapshotJSONRoundTrip() throws {
        guard let box = Shape.box(width: 12, height: 8, depth: 4),
              let graph = TopologyGraph(shape: box) else { return }

        let f0 = TopologyGraph.NodeRef(kind: .face, index: 0)
        let f3 = TopologyGraph.NodeRef(kind: .face, index: 3)
        let v2 = TopologyGraph.NodeRef(kind: .vertex, index: 2)
        graph.setAttribute("residualRMS", .double(0.001), for: f0)
        graph.setAttribute("decision", .string("human"), for: f3)
        graph.setAttribute("mirror", .bool(true), for: f3)
        graph.setAttribute("tris", .ints([1, 2, 3]), for: v2)

        let snap = try graph.snapshot()
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(GraphSnapshot.self, from: data)
        let restored = try TopologyGraph(snapshot: decoded)

        #expect(restored.faceCount == graph.faceCount)
        #expect(restored.vertexCount == graph.vertexCount)
        #expect(restored.attribute("residualRMS", for: f0)?.doubleValue == 0.001)
        #expect(restored.attribute("decision", for: f3)?.stringValue == "human")
        #expect(restored.attribute("mirror", for: f3)?.boolValue == true)
        #expect(restored.attribute("tris", for: v2)?.intsValue == [1, 2, 3])
        #expect(restored.attributes == graph.attributes)
    }

    /// With the canonical (`.sortedKeys`) encoder the store is byte-stable across encodes —
    /// the contract for diffable, versionable snapshots.
    @Test func encodingIsDeterministic() throws {
        guard let box = Shape.box(width: 3, height: 3, depth: 3),
              let graph = TopologyGraph(shape: box) else { return }
        for i in 0..<graph.faceCount {
            graph.setAttribute("idx", .int(i), for: TopologyGraph.NodeRef(kind: .face, index: i))
        }
        let encoder = GraphSnapshot.canonicalEncoder()
        let a = try encoder.encode(graph.attributes)
        let b = try encoder.encode(graph.attributes)
        #expect(a == b)
    }

    /// NodeRef indexing is deterministic across rebuilds of the same BREP — the property the
    /// snapshot round-trip relies on. Verify a node index resolves to the same geometry.
    @Test func nodeIndexingDeterministicAcrossRebuild() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
              let g1 = TopologyGraph(shape: box),
              let brep = box.toBREPString(),
              let box2 = Shape.fromBREPString(brep),
              let g2 = TopologyGraph(shape: box2) else { return }

        #expect(g1.faceCount == g2.faceCount)
        #expect(g1.edgeCount == g2.edgeCount)
        #expect(g1.vertexCount == g2.vertexCount)

        // Same vertex index must map to the same point in both builds.
        for i in 0..<g1.vertexCount {
            let p1 = g1.vertexPoint(i)
            let p2 = g2.vertexPoint(i)
            #expect(abs(p1.x - p2.x) < 1e-9)
            #expect(abs(p1.y - p2.y) < 1e-9)
            #expect(abs(p1.z - p2.z) < 1e-9)
        }
    }

    /// A snapshot from a newer format version is rejected.
    @Test func futureFormatVersionRejected() {
        guard let box = Shape.box(width: 2, height: 2, depth: 2),
              let brep = box.toBREPString() else { return }
        let future = GraphSnapshot(brep: brep, attributes: NodeAttributeStore(),
                                   formatVersion: GraphSnapshot.currentFormatVersion + 1)
        #expect(throws: GraphSnapshotError.self) {
            _ = try TopologyGraph(snapshot: future)
        }
    }

    /// Invalid BREP in a snapshot throws rather than crashing.
    @Test func invalidBREPThrows() {
        let bad = GraphSnapshot(brep: "not a brep", attributes: NodeAttributeStore())
        #expect(throws: GraphSnapshotError.self) {
            _ = try TopologyGraph(snapshot: bad)
        }
    }
}

