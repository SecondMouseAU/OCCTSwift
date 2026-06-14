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


// MARK: - v0.115.0 Tests

@Suite("v0.115.0 - Interpolation Expansion 3D")
struct InterpolationExpansion3DTests {

    @Test func interpolateWithEndpointTangents() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let curve = Curve3D.interpolate(points: points,
                                         startTangent: SIMD3(1, 1, 0),
                                         endTangent: SIMD3(1, -1, 0))
        #expect(curve != nil)
    }

    @Test func interpolateWithAllTangents() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let tangents = [SIMD3(1.0, 1.0, 0.0), SIMD3(1.0, 0.0, 0.0), SIMD3(1.0, -1.0, 0.0)]
        let flags: [Bool] = [true, false, true] // only first and last constrained
        let curve = Curve3D.interpolate(points: points, tangents: tangents, tangentFlags: flags)
        #expect(curve != nil)
    }

    @Test func interpolateWithParameters() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let params = [0.0, 0.5, 1.0]
        let curve = Curve3D.interpolate(points: points, parameters: params)
        #expect(curve != nil)
    }

    @Test func interpolatePeriodic() {
        let points = [
            SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0),
            SIMD3(10.0, 10.0, 0.0), SIMD3(0.0, 10.0, 0.0)
        ]
        let curve = Curve3D.interpolatePeriodic(points: points)
        #expect(curve != nil)
    }
}

// MARK: - v0.142 / #72 Phase 3: ConstructionContext

@Suite("v0.142 ConstructionContext")
struct ConstructionContextTests {
    @Test("Add and retrieve entities by ID")
    func addRetrieve() {
        let ctx = ConstructionContext()
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(1, 0, 0))
        let point = ConstructionPoint.absolute(SIMD3(1, 2, 3))

        let pID = ctx.add(plane, name: "Top")
        let aID = ctx.add(axis, name: "XAxis")
        let ptID = ctx.add(point)

        #expect(ctx.name(pID) == "Top")
        #expect(ctx.plane(pID) == plane)
        #expect(ctx.axis(aID) == axis)
        #expect(ctx.point(ptID) == point)
        #expect(ctx.count.planes == 1)
        #expect(ctx.count.axes == 1)
        #expect(ctx.count.points == 1)
    }

    @Test("Resolve entities against a graph")
    func resolveAgainstGraph() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let pID = ctx.add(.absolute(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        switch ctx.resolve(pID, in: graph) {
        case .success(let placement):
            #expect(placement.origin == SIMD3(1, 2, 3))
        case .failure: Issue.record("resolve failed")
        }
    }

    @Test("allBroken detects unregistered references")
    func allBrokenDetection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        // Add a plane referencing a face by TopologyRef.createdBy for an op
        // that was never recorded — resolution will fail with .operationNotFound.
        let brokenFace = TopologyRef.createdBy(operationName: "NeverHappened", kind: .face)
        ctx.add(ConstructionPlane.offsetFromFace(face: brokenFace, distance: 5))

        let broken = ctx.allBroken(in: graph)
        #expect(broken.planes.count == 1)
        #expect(broken.axes.isEmpty)
        #expect(broken.points.isEmpty)
    }

    @Test("Remove an entity")
    func removal() {
        let ctx = ConstructionContext()
        let pID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(ctx.plane(pID) != nil)
        ctx.remove(plane: pID)
        #expect(ctx.plane(pID) == nil)
    }

    @Test("Document exposes a lazy construction context")
    func documentIntegration() {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        let ctx1 = doc.constructionContext
        let ctx2 = doc.constructionContext
        // Both accesses return the same instance.
        #expect(ctx1 === ctx2)
        let pID = ctx1.add(.absolute(origin: SIMD3(5, 5, 5), normal: SIMD3(0, 1, 0)))
        #expect(doc.constructionContext.plane(pID) != nil)
    }
}

// MARK: - v0.142 / #72 Phase 4: Sketch + buildProfile

@Suite("v0.142 Sketch buildProfile")
struct SketchBuildProfileTests {
    @Test("Profile excludes construction elements")
    func excludesConstruction() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        var sketch = Sketch(hostPlane: planeID)
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(10, 0), to: SIMD2(10, 10))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(10, 10), to: SIMD2(0, 10))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 10), to: SIMD2(0, 0))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 10)),
                                 isConstruction: true))
        #expect(sketch.elements.count == 5)
        #expect(sketch.profileElementCount == 4)

        let wire = sketch.buildProfile(in: ctx, graph: graph)
        #expect(wire != nil)
    }

    @Test("buildProfile returns nil if no profile elements present")
    func emptyProfileNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        var sketch = Sketch(hostPlane: planeID)
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(1, 1)),
                                 isConstruction: true))
        #expect(sketch.buildProfile(in: ctx, graph: graph) == nil)
    }

    @Test("buildProfile returns nil when host plane is unresolvable")
    func brokenHostPlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.offsetFromFace(
            face: .createdBy(operationName: "NeverHappened", kind: .face),
            distance: 5))
        var sketch = Sketch(hostPlane: planeID)
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(10, 0), to: SIMD2(0, 10))))
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 10), to: SIMD2(0, 0))))
        #expect(sketch.buildProfile(in: ctx, graph: graph) == nil)
    }
}

// MARK: - v0.143 M3: Angle helpers

@Suite("v0.143 Angle helpers")
struct AngleHelperTests {
    @Test("Angle between two perpendicular edges ≈ π/2")
    func perpendicularEdges() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let edges = box.edges()
        // A box has 12 edges; find two that are perpendicular (adjacent on a face).
        // First try: edges[0] and edges[1] — typically perpendicular for a box.
        if edges.count >= 2 {
            let angle = edges[0].angle(to: edges[1])
            // Box edges are all either parallel (angle 0/π) or perpendicular (π/2).
            if let a = angle {
                let near0 = a < 1e-3 || abs(a - .pi) < 1e-3
                let near90 = abs(a - .pi / 2) < 1e-3
                #expect(near0 || near90)
            }
        }
    }

    @Test("Box face pairs parallel-or-perpendicular")
    func boxFaceAngles() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let faces = box.faces()
        for i in 0..<faces.count {
            for j in (i+1)..<faces.count {
                if let a = faces[i].angle(to: faces[j]) {
                    let near0 = a < 1e-3 || abs(a - .pi) < 1e-3
                    let near90 = abs(a - .pi / 2) < 1e-3
                    #expect(near0 || near90)
                }
            }
        }
    }

    @Test("unsignedAngle between parallel vectors == 0")
    func unsignedAngleParallel() {
        let a = SIMD3<Double>(1, 0, 0)
        let b = SIMD3<Double>(2, 0, 0)
        #expect(unsignedAngle(between: a, and: b) < 1e-12)
    }

    @Test("unsignedAngle between antiparallel vectors == π")
    func unsignedAngleAntiparallel() {
        let a = SIMD3<Double>(1, 0, 0)
        let b = SIMD3<Double>(-1, 0, 0)
        #expect(abs(unsignedAngle(between: a, and: b) - .pi) < 1e-12)
    }

    @Test("ConstructionAxis angle between resolved axes")
    func constructionAxisAngle() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let xAxis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(1, 0, 0))
        let yAxis = ConstructionAxis.absolute(origin: .zero, direction: SIMD3(0, 1, 0))
        if let a = xAxis.angle(to: yAxis, in: graph) {
            #expect(abs(a - .pi / 2) < 1e-9)
        } else { Issue.record("angle nil") }
    }

    @Test("ConstructionPlane angle between normals")
    func constructionPlaneAngle() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let xy = ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 0, 1))
        let xz = ConstructionPlane.absolute(origin: .zero, normal: SIMD3(0, 1, 0))
        if let a = xy.angle(to: xz, in: graph) {
            #expect(abs(a - .pi / 2) < 1e-9)
        } else { Issue.record("angle nil") }
    }
}

// MARK: - v0.143 D4: Multi-leaf .createdBy

@Suite("v0.143 Multi-leaf createdBy")
struct MultiLeafCreatedByTests {
    @Test("leafOccurrence picks among split descendants")
    func leafOccurrencePicksNth() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // Create → op1, then split into two leaves via op2.
        let seed = TopologyGraph.NodeRef(kind: .face, index: 1)
        let leaf1 = TopologyGraph.NodeRef(kind: .face, index: 11)
        let leaf2 = TopologyGraph.NodeRef(kind: .face, index: 22)
        graph.recordHistory(operationName: "Op1", original: .sentinel, replacements: [seed])
        graph.recordHistory(operationName: "Op2", original: seed, replacements: [leaf1, leaf2])

        let first = graph.resolve(.createdBy(operationName: "Op1", kind: .face, leafOccurrence: 0))
        let second = graph.resolve(.createdBy(operationName: "Op1", kind: .face, leafOccurrence: 1))
        switch (first, second) {
        case (.success(let a), .success(let b)):
            #expect(a != b)
            #expect([leaf1, leaf2].contains(a))
            #expect([leaf1, leaf2].contains(b))
        default:
            Issue.record("expected both leaves")
        }
    }

    @Test("currentForms returns both leaves of a split")
    func currentFormsReturnsAll() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let seed = TopologyGraph.NodeRef(kind: .edge, index: 3)
        let a = TopologyGraph.NodeRef(kind: .edge, index: 30)
        let b = TopologyGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "Split", original: seed, replacements: [a, b])
        let leaves = Set(graph.currentForms(of: seed))
        #expect(leaves.isSuperset(of: [a, b]))
    }

    @Test("leafOccurrence: nil returns seed without forward-walk")
    func leafOccurrenceNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let seed = TopologyGraph.NodeRef(kind: .face, index: 1)
        let leaf = TopologyGraph.NodeRef(kind: .face, index: 11)
        graph.recordHistory(operationName: "Op", original: .sentinel, replacements: [seed])
        graph.recordHistory(operationName: "Mod", original: seed, replacements: [leaf])
        let result = graph.resolve(.createdBy(operationName: "Op", kind: .face, leafOccurrence: nil))
        switch result {
        case .success(let r): #expect(r == seed)
        case .failure: Issue.record("unexpected failure")
        }
    }
}

// MARK: - v0.143 D1: Construction layer persistence

@Suite("v0.143 Construction layer persistence")
struct ConstructionLayerTests {
    @Test("addConstructionShape tags the shape with the CONSTRUCTION layer")
    func addConstructionShape() {
        guard let doc = Document.create() else { Issue.record("doc nil"); return }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let id = doc.addConstructionShape(box)
        #expect(id >= 0)
        let labels = doc.constructionShapeLabels
        #expect(labels.contains(id))
    }

    @Test("Materialize all ConstructionContext entities as shapes on the CONSTRUCTION layer")
    func materializeAll() {
        guard let doc = Document.create(),
              let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("setup nil"); return
        }
        let ctx = doc.constructionContext
        ctx.add(.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)), name: "XY")
        ctx.add(.absolute(origin: SIMD3(5, 5, 5), direction: SIMD3(1, 0, 0)), name: "X-line")
        ctx.add(.absolute(SIMD3(1, 2, 3)), name: "origin")

        let result = ctx.materialize(in: doc, graph: graph)
        #expect(result.totalMaterialized == 3)
        #expect(result.failures.isEmpty)
        // Each materialized shape shows up on the CONSTRUCTION layer.
        #expect(doc.constructionShapeLabels.count >= 3)
    }
}

// MARK: - v0.145 #76: Sheet templates, title blocks, projection symbols

@Suite("v0.145 ISO 5457 paper sizes")
struct PaperSizeTests {
    @Test("A0 landscape dimensions match ISO 5457")
    func a0Landscape() {
        let d = PaperSize.A0.size(in: .landscape)
        #expect(d == SIMD2(1189, 841))
    }

    @Test("A4 portrait is 210 × 297")
    func a4Portrait() {
        let d = PaperSize.A4.size(in: .portrait)
        #expect(d == SIMD2(210, 297))
    }

    @Test("Each paper size has half the area of the next size up")
    func paperSeriesHalving() {
        let a3 = PaperSize.A3.dimensions
        let a4 = PaperSize.A4.dimensions
        let a3Area = a3.x * a3.y
        let a4Area = a4.x * a4.y
        // A4 should be (approximately) half of A3.
        #expect(abs(a3Area / a4Area - 2.0) < 0.01)
    }
}

@Suite("v0.145 Sheet rendering")
struct SheetRenderingTests {
    @Test("Sheet render emits border + inner frame polylines")
    func sheetEmitsBorders() {
        let sheet = Sheet(size: .A3, orientation: .landscape, projection: .first,
                          title: TitleBlock(title: "Test Drawing",
                                            drawingNumber: "T-001",
                                            owner: "ACME Co"))
        let writer = DXFWriter()
        sheet.render(into: writer)
        // Should have at least 2 polylines (outer border + inner frame) plus some tick lines.
        let counts = writer.entityCounts
        #expect(counts.polylines >= 2)
        #expect(counts.lines >= 4)   // centring ticks
        #expect(counts.texts >= 1)   // title block field labels
    }

    @Test("Sheet innerFrame respects ISO 5457 margins")
    func innerFrameInsets() {
        let sheet = Sheet(size: .A3, orientation: .landscape)
        let frame = sheet.innerFrame
        #expect(frame.min.x == 20)          // 20 mm binding left
        #expect(frame.min.y == 10)
        #expect(frame.max.x == 420 - 10)    // 10 mm right
        #expect(frame.max.y == 297 - 10)
    }

    @Test("Projection symbol renders two circles for both conventions")
    func projectionSymbolCircles() {
        let writer = DXFWriter()
        ProjectionSymbol.render(.first, at: SIMD2(0, 0), into: writer)
        let firstCount = writer.entityCounts.circles
        #expect(firstCount == 2)

        let writer2 = DXFWriter()
        ProjectionSymbol.render(.third, at: SIMD2(0, 0), into: writer2)
        #expect(writer2.entityCounts.circles == 2)
    }

    @Test("TitleBlock fields are emitted as text")
    func titleBlockFields() {
        let tb = TitleBlock(title: "Test Part",
                            drawingNumber: "ABC-123",
                            owner: "Widget Corp",
                            creator: "Jane Engineer",
                            dateOfIssue: "2026-04-22")
        let sheet = Sheet(size: .A3, title: tb)
        let writer = DXFWriter()
        sheet.render(into: writer)
        #expect(writer.entityCounts.texts >= 5)   // at least label/value pairs
    }
}

// MARK: - v0.151 SheetMetal composition API (issue #85)

@Suite("v0.151 SheetMetal — flange + bend composition")
struct SheetMetalTests {

    /// L-bracket: horizontal base flange + vertical upright, one bend between them.
    ///
    /// The upright spans the full base width so the seam edge runs cleanly
    /// across both flanges without a step — a step would require a
    /// variable-radius fillet to close off, which is beyond this first cut.
    @Test("L-bracket: two orthogonal flanges with one bend")
    func lBracket() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let builder = SheetMetal.Builder(thickness: 3)
        let shape = try builder.build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "base", to: "upright", radius: 2.0)])

        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// U-channel: three flanges (bottom + two uprights) with two bends.
    ///
    /// Walls sit *outside* the bottom's footprint (x<0 and x>40) so they
    /// touch bottom edge-to-face rather than overlapping with it. This
    /// gives a clean seam edge along each bend.
    @Test("U-channel: three flanges, two bends")
    func uChannel() throws {
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let left = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(-1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let right = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(40, 0, 0),
            normal: SIMD3<Double>(1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let builder = SheetMetal.Builder(thickness: 2)
        let shape = try builder.build(
            flanges: [bottom, left, right],
            bends: [
                SheetMetal.Bend(from: "bottom", to: "left", radius: 1.5),
                SheetMetal.Bend(from: "bottom", to: "right", radius: 1.5)
            ])

        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// Bendless composition — builder should still fuse flanges if no bends are given.
    @Test("Flanges-only (no bends) still produces a fused solid")
    func flangesOnlyNoBends() throws {
        let a = SheetMetal.Flange(
            id: "a",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let b = SheetMetal.Flange(
            id: "b",
            profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 10, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let shape = try SheetMetal.Builder(thickness: 2).build(flanges: [a, b])
        #expect(shape.isValid)
    }

    @Test("Single flange with no bends returns a plain extrusion")
    func singleFlange() throws {
        let only = SheetMetal.Flange(
            id: "plate",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 25), SIMD2(0, 25)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let shape = try SheetMetal.Builder(thickness: 3).build(flanges: [only])
        #expect(shape.isValid)
        if let v = shape.volume {
            // 50 × 25 × 3 = 3750
            #expect(abs(v - 3750.0) < 1.0)
        }
    }

    @Test("Zero thickness is rejected")
    func zeroThicknessRejected() {
        let f = SheetMetal.Flange(
            id: "x", profile: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 0).build(flanges: [f])
        }
    }

    @Test("Empty flange list is rejected")
    func emptyFlangesRejected() {
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 3).build(flanges: [])
        }
    }

    @Test("Duplicate flange id is rejected")
    func duplicateFlangeIDRejected() {
        let f1 = SheetMetal.Flange(
            id: "same", profile: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let f2 = SheetMetal.Flange(
            id: "same", profile: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            origin: SIMD3<Double>(10, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 3).build(flanges: [f1, f2])
        }
    }

    @Test("Bend referencing unknown flange id is rejected")
    func unknownFlangeIDInBendRejected() {
        let f = SheetMetal.Flange(
            id: "a", profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 2).build(
                flanges: [f],
                bends: [SheetMetal.Bend(from: "a", to: "ghost", radius: 1.0)])
        }
    }

    /// Single-flange volume is thickness × profile area exactly.
    @Test("Single-flange volume matches thickness × profile area")
    func singleFlangeVolumeSanity() throws {
        let plate = SheetMetal.Flange(
            id: "plate",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let shape = try SheetMetal.Builder(thickness: 2.5).build(flanges: [plate])
        if let v = shape.volume {
            // 40 × 20 × 2.5 = 2000
            #expect(abs(v - 2000.0) < 0.5)
        } else {
            Issue.record("volume nil")
        }
    }

    /// Two-flange fused volume is base + upright minus shared overlap.
    @Test("Fused two-flange volume subtracts the overlap")
    func fusedTwoFlangeVolume() throws {
        // base body x∈[0,65], y∈[0,28], z∈[0,3]  → 65·28·3 = 5460
        // upright body x∈[0,65], y∈[28,31], z∈[0,40] → 65·3·40 = 7800
        // overlap: none (they touch on the y=28 face, zero-volume intersection)
        // fused volume = 5460 + 7800 = 13260
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let fused = try SheetMetal.Builder(thickness: 3).build(flanges: [base, upright])
        if let v = fused.volume {
            #expect(abs(v - 13260.0) < 1.0)
        } else {
            Issue.record("volume nil")
        }
    }

    /// Stepped seam (v0.151: throws filletFailed; v0.153: succeeds via
    /// flange splitting). #86. The builder splits the wider base at the
    /// upright's seam-extent endpoints; the matched-extent middle piece
    /// carries the bend, and the outer pieces stay flat.
    @Test("Stepped seam (narrow upright over wider base) succeeds in v0.153")
    func narrowUprightStepSucceeds() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "vertical",
            profile: [SIMD2(0, 0), SIMD2(28, 0), SIMD2(28, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let shape = try SheetMetal.Builder(thickness: 3).build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "base", to: "vertical", radius: 1.5)])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// L-bracket from issue #86: 80×40 base, 20×30 vertical mounting tab
    /// centred on the base's back edge. v0.151 threw; v0.153 succeeds.
    @Test("L-bracket: 80×40 base, 20×30 centred mounting tab")
    func lBracketStepSeamCentredTab() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let tab = SheetMetal.Flange(
            id: "tab",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(30, 40, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [base, tab],
            bends: [SheetMetal.Bend(from: "base", to: "tab", radius: 1.5)])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// Z-bracket from issue #86: 50×30 base, 50×30 mid (full seam),
    /// 20×30 top tab (stepped seam). Two bends.
    @Test("Z-bracket: full + stepped seams")
    func zBracket() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        // Mid is a vertical riser of full width, sharing the base's back
        // edge.
        let mid = SheetMetal.Flange(
            id: "mid",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 30, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        // Top tab (20×30) sits on top of the mid, stepped width.
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(15, 30, 20),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [base, mid, top],
            bends: [
                SheetMetal.Bend(from: "base", to: "mid", radius: 1.5),
                SheetMetal.Bend(from: "mid", to: "top", radius: 1.5)
            ])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    /// U-channel with narrower flanges (issue #86): 100×25 spine,
    /// 100×15 sides — the sides are NARROWER than the spine in the seam-
    /// direction (along Y), making them stepped.
    ///
    /// Concretely: spine along Y has 100 long edge; left/right side flanges
    /// only span Y ∈ [0, 80] of the spine (centred), so the seam is stepped
    /// at both ends.
    @Test("U-channel with stepped narrower side flanges")
    func uChannelStepped() throws {
        let spine = SheetMetal.Flange(
            id: "spine",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 100), SIMD2(0, 100)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let left = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(0, 10, 0),
            normal: SIMD3<Double>(-1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let right = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(40, 10, 0),
            normal: SIMD3<Double>(1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [spine, left, right],
            bends: [
                SheetMetal.Bend(from: "spine", to: "left", radius: 1.5),
                SheetMetal.Bend(from: "spine", to: "right", radius: 1.5)
            ])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }

    @Test("Parallel flanges cannot form a bend")
    func parallelFlangesRejected() {
        // Two coplanar flanges stacked in Z — same normal, so no seam direction.
        let a = SheetMetal.Flange(
            id: "a", profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let b = SheetMetal.Flange(
            id: "b", profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(0, 0, 10),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 2).build(
                flanges: [a, b],
                bends: [SheetMetal.Bend(from: "a", to: "b", radius: 1.0)])
        }
    }
}

@Suite("Issue #89: convex bends")
struct ConvexBendIssue89 {
    /// The issue's repro: Z-section with two opposite-direction 90° bends.
    /// v0.153 threw `filletFailed` for the second (convex) bend.
    @Test("Z-section with two opposite-direction 90° bends builds cleanly")
    func zBracketRepro() throws {
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0,0), SIMD2(18,0), SIMD2(18,45), SIMD2(0,45)],
            origin: SIMD3(0,0,0),
            normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [SIMD2(0,0), SIMD2(25,0), SIMD2(25,45), SIMD2(0,45)],
            origin: SIMD3(18,0,0),
            normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0,0), SIMD2(45,0), SIMD2(45,45), SIMD2(0,45)],
            origin: SIMD3(18,0,25),
            normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 3.2).build(
            flanges: [top, web, bottom],
            bends: [SheetMetal.Bend(from: "top", to: "web", radius: 3.2),
                    SheetMetal.Bend(from: "web", to: "bottom", radius: 3.2)])
        #expect(s.isValid)
        #expect((s.volume ?? 0) > 0)
        #expect(s.subShapes(ofType: .solid).count == 1, "Z-bracket should be a single solid")
        try Exporter.writeSTEP(shape: s, to: URL(fileURLWithPath: "/tmp/issue89-z-bracket.step"))
    }

    /// Symmetric Z-section: matched-width flanges, both bends 90° opposite.
    @Test("Symmetric Z-section (top 30, web 20, bottom 30, R=3)")
    func symmetricZ() throws {
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,45), SIMD2(0,45)],
            origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,45), SIMD2(0,45)],
            origin: SIMD3(30,0,0), normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,45), SIMD2(0,45)],
            origin: SIMD3(30,0,20), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 2).build(
            flanges: [top, web, bottom],
            bends: [SheetMetal.Bend(from: "top", to: "web", radius: 3),
                    SheetMetal.Bend(from: "web", to: "bottom", radius: 3)])
        #expect(s.isValid)
        #expect(s.subShapes(ofType: .solid).count == 1)
    }

    /// Offset L with a very short web (5mm). Stresses the radius-vs-web-
    /// length corner case for convex bends.
    @Test("Offset L with very short web (5mm) and 90° opposite bends")
    func offsetLShortWeb() throws {
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0,0), SIMD2(50,0), SIMD2(50,60), SIMD2(0,60)],
            origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [SIMD2(0,0), SIMD2(5,0), SIMD2(5,60), SIMD2(0,60)],
            origin: SIMD3(50,0,0), normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0,0), SIMD2(50,0), SIMD2(50,60), SIMD2(0,60)],
            origin: SIMD3(50,0,5), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 2).build(
            flanges: [top, web, bottom],
            bends: [SheetMetal.Bend(from: "top", to: "web", radius: 1.5),
                    SheetMetal.Bend(from: "web", to: "bottom", radius: 1.5)])
        #expect(s.isValid)
    }

    /// Mixed concave + convex chain. Spine 100×40, two walls 30×40 fold up
    /// (concave from spine), tab 20×40 folds back convex from one wall.
    @Test("Channel with flange — mixed concave + convex bends")
    func channelWithFlange() throws {
        let spine = SheetMetal.Flange(
            id: "spine",
            profile: [SIMD2(0,0), SIMD2(100,0), SIMD2(100,40), SIMD2(0,40)],
            origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let leftWall = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,40), SIMD2(0,40)],
            origin: SIMD3(0,0,0), normal: SIMD3(1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let rightWall = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0,0), SIMD2(30,0), SIMD2(30,40), SIMD2(0,40)],
            origin: SIMD3(100,0,0), normal: SIMD3(-1,0,0),
            uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
        let tab = SheetMetal.Flange(
            id: "tab",
            profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,40), SIMD2(0,40)],
            origin: SIMD3(100,0,30), normal: SIMD3(0,0,1),
            uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
        let s = try SheetMetal.Builder(thickness: 1.5).build(
            flanges: [spine, leftWall, rightWall, tab],
            bends: [
                SheetMetal.Bend(from: "spine", to: "left", radius: 2),
                SheetMetal.Bend(from: "spine", to: "right", radius: 2),
                SheetMetal.Bend(from: "right", to: "tab", radius: 2),
            ])
        #expect(s.isValid)
        #expect(s.subShapes(ofType: .solid).count == 1)
    }

    /// Auto-detection sanity: the same Z built with `direction: .auto`
    /// (default) and with explicit `direction: .convex` for the second
    /// bend should produce identical-volume solids. If auto-detection
    /// were broken, the explicit override would change behaviour.
    @Test("Explicit `.convex` matches auto-detected convex behaviour")
    func explicitDirectionMatchesAuto() throws {
        let make = { (direction: SheetMetal.BendDirection) throws -> Shape in
            let top = SheetMetal.Flange(
                id: "top", profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,30), SIMD2(0,30)],
                origin: SIMD3(0,0,0), normal: SIMD3(0,0,1),
                uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
            let web = SheetMetal.Flange(
                id: "web", profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,30), SIMD2(0,30)],
                origin: SIMD3(20,0,0), normal: SIMD3(-1,0,0),
                uAxis: SIMD3(0,0,1), vAxis: SIMD3(0,1,0))
            let bottom = SheetMetal.Flange(
                id: "bottom", profile: [SIMD2(0,0), SIMD2(20,0), SIMD2(20,30), SIMD2(0,30)],
                origin: SIMD3(20,0,20), normal: SIMD3(0,0,1),
                uAxis: SIMD3(1,0,0), vAxis: SIMD3(0,1,0))
            return try SheetMetal.Builder(thickness: 2).build(
                flanges: [top, web, bottom],
                bends: [
                    SheetMetal.Bend(from: "top", to: "web", radius: 2),
                    SheetMetal.Bend(
                        from: "web", to: "bottom",
                        insideRadius: 2, direction: direction),
                ])
        }
        let auto = try make(.auto)
        let explicit = try make(.convex)
        #expect(auto.isValid && explicit.isValid)
        let vAuto = auto.volume ?? 0
        let vExplicit = explicit.volume ?? 0
        #expect(abs(vAuto - vExplicit) < 1e-3 * max(vAuto, vExplicit),
                 "auto vol=\(vAuto), explicit vol=\(vExplicit)")
    }
}
