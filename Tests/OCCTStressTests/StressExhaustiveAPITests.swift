// StressExhaustiveAPITests.swift
// Category 1: Smoke-call every major public method with standard fixtures.
// Goal: verify no crash and reasonable output for each API entry point.

import Foundation
import Testing
import OCCTSwift

// MARK: - Shape Factory Methods

@Suite("Stress: Shape Factories")
struct StressShapeFactoryTests {

    @Test func box() { #expect(Shape.box(width: 10, height: 20, depth: 30) != nil) }
    @Test func boxWithOrigin() { #expect(Shape.box(origin: SIMD3<Double>(1, 2, 3), width: 10, height: 20, depth: 30) != nil) }
    @Test func cylinder() { #expect(Shape.cylinder(radius: 5, height: 10) != nil) }
    @Test func cylinderAtPosition() { #expect(Shape.cylinder(at: SIMD2(0, 0), bottomZ: 0, radius: 5, height: 10) != nil) }
    @Test func sphere() { #expect(Shape.sphere(radius: 5) != nil) }
    @Test func cone() { #expect(Shape.cone(bottomRadius: 5, topRadius: 2, height: 10) != nil) }
    @Test func torus() { #expect(Shape.torus(majorRadius: 10, minorRadius: 3) != nil) }
    @Test func wedge() { #expect(Shape.wedge(dx: 10, dy: 10, dz: 10, ltx: 5) != nil) }

    @Test func fromWire() {
        let wire = standardWire()
        let shape = Shape.fromWire(wire)
        #expect(shape != nil)
    }

    @Test func face() {
        let wire = standardWire()
        let face = Shape.face(from: wire)
        #expect(face != nil)
    }

    @Test func extrude() {
        let wire = standardWire()
        let solid = Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 10)
        if let s = solid { #expect(s.isValid) }
    }

    @Test func revolve() {
        // Revolve a line segment to create a cylinder-like shape
        if let wire = Wire.line(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10)) {
            let rev = Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1))
            if let r = rev { _ = r.isValid } // Revolution of open wire may not be "valid" solid
        }
    }
}

// MARK: - Shape Boolean Operations

@Suite("Stress: Shape Booleans")
struct StressShapeBooleanTests {

    @Test func union() {
        let result = standardBox().union(with: standardSphere())
        if let r = result { #expect(r.isValid) }
    }

    @Test func subtract() {
        let result = standardBox().subtracting(standardSphere())
        if let r = result { #expect(r.isValid) }
    }

    @Test func intersect() {
        let result = standardBox().intersection(with: standardSphere())
        if let r = result { #expect(r.isValid) }
    }

    @Test func section() {
        let result = standardBox().section(with: standardSphere())
        if let r = result { #expect(r.isValid) }
    }

    @Test func split() {
        let result = standardBox().split(by: standardSphere())
        if let r = result { #expect(!r.isEmpty) }
    }

    @Test func splitAtPlane() {
        let result = standardBox().split(atPlane: .zero, normal: SIMD3(0, 0, 1))
        if let r = result { #expect(!r.isEmpty) }
    }
}

// MARK: - Shape Feature Operations

@Suite("Stress: Shape Features")
struct StressShapeFeatureTests {

    @Test func fillet() {
        let r = standardBox().filleted(radius: 1.0)
        if let r { #expect(r.isValid) }
    }

    @Test func chamfer() {
        let r = standardBox().chamfered(distance: 1.0)
        if let r { #expect(r.isValid) }
    }

    @Test func shell() {
        let r = standardBox().shelled(thickness: -1.0)
        if let r { #expect(r.isValid) }
    }

    @Test func drill() {
        let r = standardBox().drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 2, depth: 0)
        if let r { #expect(r.isValid) }
    }

    @Test func offset() {
        let r = standardBox().offset(by: 1.0)
        if let r { #expect(r.isValid) }
    }

    @Test func linearPattern() {
        let r = standardBox().linearPattern(direction: SIMD3(15, 0, 0), spacing: 15, count: 3)
        if let r { #expect(r.isValid) }
    }

    @Test func circularPattern() {
        let r = standardBox().circularPattern(axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 4)
        if let r { #expect(r.isValid) }
    }

    @Test func sectionWires() {
        let wires = standardBox().sectionWiresAtZ(0.0)
        #expect(!wires.isEmpty)
        for w in wires {
            if let len = w.length { #expect(len > 0) }
        }
    }
}

// MARK: - Shape Transforms

@Suite("Stress: Shape Transforms")
struct StressShapeTransformTests {

    @Test func translate() {
        let r = standardBox().translated(by: SIMD3(10, 20, 30))
        if let r { #expect(r.isValid) }
    }

    @Test func rotate() {
        let r = standardBox().rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4)
        if let r { #expect(r.isValid) }
    }

    @Test func scale() {
        let r = standardBox().scaled(by: 2.0)
        if let r { #expect(r.isValid) }
    }

    @Test func mirror() {
        let r = standardBox().mirrored(planeNormal: SIMD3(1, 0, 0))
        if let r { #expect(r.isValid) }
    }
}

// MARK: - Shape Queries

@Suite("Stress: Shape Queries")
struct StressShapeQueryTests {

    @Test func isValid() { #expect(standardBox().isValid) }
    @Test func volume() { if let v = standardBox().volume { #expect(v > 0) } }
    @Test func surfaceArea() { if let a = standardBox().surfaceArea { #expect(a > 0) } }
    @Test func bounds() {
        let b = standardBox().bounds
        #expect(b.max.x > b.min.x)
    }
    @Test func faceCount() { #expect(standardBox().subShapeCount(ofType: .face) == 6) }
    @Test func edgeCount() { #expect(standardBox().subShapeCount(ofType: .edge) == 12) }
    @Test func vertexCount() { #expect(standardBox().subShapeCount(ofType: .vertex) == 8) }

    @Test func subShapes() {
        let faces = standardBox().subShapes(ofType: .face)
        #expect(faces.count == 6)
    }

    @Test func mesh() {
        let m = standardBox().mesh(linearDeflection: 0.5)
        #expect(m != nil)
        if let m { #expect(m.vertexCount > 0) }
    }

    @Test func edgePolyline() {
        let box = standardBox()
        let pts = box.edgePolyline(at: 0, deflection: 0.1)
        if let pts { #expect(pts.count >= 2) }
    }

    @Test func faces() {
        let faces = standardBox().faces()
        #expect(faces.count == 6)
    }

    @Test func edges() {
        let edges = standardBox().edges()
        #expect(edges.count == 12)
    }

    @Test func distance() {
        let b1 = Shape.box(width: 10, height: 10, depth: 10)!
        let b2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
        let dist = b1.distance(to: b2)
        if let d = dist { #expect(d.distance > 0) }
    }

    @Test func boundingBoxOptimal() {
        let box = standardBox()
        let opt = box.boundingBoxOptimal()
        if let o = opt {
            #expect(o.max.x > o.min.x)
        }
    }

    @Test func orientedBoundingBox() {
        let box = standardBox()
        if let obb = box.orientedBoundingBox(optimal: false) {
            #expect(obb.volume > 0)
        }
    }

    @Test func toleranceValue() {
        let box = standardBox()
        let tol = box.toleranceValue(mode: .average)
        #expect(tol >= 0)
    }

    @Test func isBooleanValid() {
        let box = standardBox()
        let valid = box.isBooleanValid()
        #expect(valid)
    }

    @Test func brepString() {
        let box = standardBox()
        let brep = box.toBREPString()
        if let brep { #expect(!brep.isEmpty) }
    }

    @Test func typeName() {
        let box = standardBox()
        let name = box.typeName
        #expect(name != nil)
    }
}

// MARK: - Wire Operations

@Suite("Stress: Wire API")
struct StressWireAPITests {

    @Test func rectangle() { #expect(Wire.rectangle(width: 10, height: 5) != nil) }

    @Test func circle() {
        let w = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        #expect(w != nil)
    }

    @Test func polygon() {
        let w = Wire.polygon([SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)])
        #expect(w != nil)
    }

    @Test func polygon3D() {
        let w = Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)])
        #expect(w != nil)
    }

    @Test func line() {
        let w = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(w != nil)
    }

    @Test func wireLength() {
        let w = standardWire()
        if let len = w.length { #expect(len > 0) }
    }

    @Test func wireEdges() {
        let w = standardWire()
        let edges = w.edges()
        #expect(!edges.isEmpty)
    }

    @Test func wireOffset() {
        let w = standardWire()
        let offset = w.offset(by: -1.0)
        if let o = offset { if let len = o.length { #expect(len > 0) } }
    }
}

// MARK: - Edge Operations

@Suite("Stress: Edge API")
struct StressEdgeAPITests {

    @Test func edgeFromShape() {
        let box = standardBox()
        let edges = box.edges()
        #expect(!edges.isEmpty)
        if let edge = edges.first {
            _ = edge.curveType
            _ = edge.length
            _ = edge.length
        }
    }

    @Test func edgeFromWire() {
        let wire = standardWire()
        let edges = wire.edges()
        #expect(!edges.isEmpty)
    }
}

// MARK: - Face Operations

@Suite("Stress: Face API")
struct StressFaceAPITests {

    @Test func faceNormal() {
        let box = standardBox()
        let faces = box.faces()
        for face in faces {
            if let n = face.normal {
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                #expect(abs(len - 1.0) < 0.01)
            }
        }
    }

    @Test func faceArea() {
        let box = standardBox()
        let faces = box.faces()
        for face in faces {
            let area = face.area()
            #expect(area > 0)
        }
    }

    @Test func faceBounds() {
        let box = standardBox()
        let faces = box.faces()
        for face in faces {
            let b = face.bounds
            _ = b.min; _ = b.max
        }
    }

    @Test func faceSurfaceType() {
        let box = standardBox()
        let faces = box.faces()
        for face in faces {
            let st = face.surfaceType
            _ = st
        }
    }

    @Test func faceClassification() {
        let box = standardBox()
        let faces = box.faces()
        var up = 0; var down = 0; var vert = 0
        for face in faces {
            if face.isUpwardFacing() { up += 1 }
            if face.isDownwardFacing() { down += 1 }
            if face.isVertical() { vert += 1 }
        }
        #expect(up + down + vert == 6)
    }
}

// MARK: - Curve3D Operations

@Suite("Stress: Curve3D API")
struct StressCurve3DAPITests {

    @Test func circle() {
        let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        #expect(c != nil)
    }

    @Test func interpolate() {
        let c = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)])
        #expect(c != nil)
    }

    @Test func pointEval() {
        let c = standardCurve3D()
        let domain = c.domain
        let pt = c.point(at: (domain.lowerBound + domain.upperBound) / 2.0)
        #expect(pt.x.isFinite)
    }

    @Test func domainAndClosed() {
        let c = standardCurve3D()
        let domain = c.domain
        #expect(domain.upperBound > domain.lowerBound)
    }

    @Test func localCurvature() {
        let c = standardCurve3D()
        let k = c.localCurvature(at: 0)
        #expect(k.isFinite)
    }

    @Test func localTangent() {
        let c = standardCurve3D()
        let t = c.localTangent(at: 0)
        #expect(t != nil)
    }

    @Test func localNormal() {
        let c = standardCurve3D()
        let n = c.localNormal(at: 0)
        #expect(n != nil)
    }

    @Test func continuity() {
        let c = standardCurve3D()
        let cn = c.continuityOrder
        #expect(cn >= 0)
        #expect(c.isCN(2))
    }

    @Test func bsplineProperties() {
        let bsp = standardBSplineCurve()
        let props = bsp.bspline
        #expect(props.poleCount > 0)
        #expect(props.knotCount > 0)
        #expect(props.degree > 0)
    }

    @Test func arcLength() {
        if let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            let len = circle.arcLength(from: 0, to: .pi)
            #expect(abs(len - 5.0 * .pi) < 0.01)
        }
    }
}

// MARK: - Curve2D Operations

@Suite("Stress: Curve2D API")
struct StressCurve2DAPITests {

    @Test func circle() {
        let c = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        #expect(c != nil)
    }

    @Test func line() {
        let c = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1))
        #expect(c != nil)
    }

    @Test func interpolate() {
        let c = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)])
        #expect(c != nil)
    }

    @Test func pointEval() {
        let c = standardCurve2D()
        let domain = c.domain
        let pt = c.point(at: (domain.lowerBound + domain.upperBound) / 2.0)
        #expect(pt.x.isFinite)
    }

    @Test func continuity() {
        let c = standardCurve2D()
        #expect(c.continuityOrder >= 0)
    }
}

// MARK: - Surface Operations

@Suite("Stress: Surface API")
struct StressSurfaceAPITests {

    @Test func plane() {
        let s = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        #expect(s != nil)
    }

    @Test func cylinder() {
        let s = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)
        #expect(s != nil)
    }

    @Test func sphere() {
        let s = Surface.sphere(center: .zero, radius: 5)
        #expect(s != nil)
    }

    @Test func cone() {
        let s = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: .pi / 6)
        #expect(s != nil)
    }

    @Test func torus() {
        let s = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3)
        #expect(s != nil)
    }

    @Test func bezier() {
        let s = standardBezierSurface()
        let dom = s.domain
        #expect(dom.uMax > dom.uMin)
    }

    @Test func pointEval() {
        let s = standardBezierSurface()
        let dom = s.domain
        let pt = s.point(atU: (dom.uMin + dom.uMax) / 2.0, v: (dom.vMin + dom.vMax) / 2.0)
        #expect(pt.x.isFinite)
    }

    @Test func gaussianCurvature() {
        if let s = Surface.sphere(center: .zero, radius: 10) {
            let k = s.gaussianCurvature(atU: 1.0, v: 0.5)
            #expect(abs(k - 0.01) < 0.001)
        }
    }

    @Test func meanCurvature() {
        if let s = Surface.sphere(center: .zero, radius: 10) {
            let h = s.meanCurvature(atU: 1.0, v: 0.5)
            #expect(abs(abs(h) - 0.1) < 0.001)
        }
    }

    @Test func continuity() {
        if let s = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            #expect(s.isCNu(2))
            #expect(s.isCNv(2))
        }
    }
}

// MARK: - Document Operations

@Suite("Stress: Document API")
struct StressDocumentAPITests {

    @Test func create() {
        let doc = Document.create()
        #expect(doc != nil)
    }

    @Test func addShape() {
        guard let doc = Document.create() else { return }
        let label = doc.addShape(standardBox())
        #expect(label >= 0)
    }

    @Test func shapeCount() {
        let doc = standardDocument()
        #expect(doc.shapeCount >= 1)
    }

    @Test func colorToolAdd() {
        guard let doc = Document.create() else { return }
        let id = doc.colorToolAddColor(r: 1, g: 0, b: 0)
        _ = id
        #expect(doc.colorToolColorCount >= 1)
    }

    @Test func colorToolFind() {
        guard let doc = Document.create() else { return }
        doc.colorToolAddColor(r: 0.5, g: 0.5, b: 0.5)
        let found = doc.colorToolFindColor(r: 0.5, g: 0.5, b: 0.5)
        _ = found
    }

    @Test func shapeToolQueries() {
        guard let doc = Document.create() else { return }
        let label = doc.addShape(standardBox())
        _ = doc.shapeToolIsFree(labelId: label)
        _ = doc.shapeToolIsSimpleShape(labelId: label)
        _ = doc.shapeToolIsComponent(labelId: label)
    }

    @Test func stepExport() throws {
        let doc = standardDocument()
        let url = tempURL("step")
        defer { cleanupTemp(url) }
        try doc.writeSTEP(to: url)
    }
}

// MARK: - Math & Geometry Utilities

@Suite("Stress: Math Utilities")
struct StressMathUtilTests {

    @Test func polynomialSolverQuadratic() {
        let roots = PolynomialSolver.quadraticRc4(a: 1, b: -3, c: 2)
        #expect(roots != nil)
        if let r = roots { #expect(r.count == 2) }
    }

    @Test func polynomialSolverCubic() {
        let roots = PolynomialSolver.cubicRc4(a: 1, b: 0, c: -1, d: 0)
        #expect(roots != nil)
    }

    @Test func gaussIntegration() {
        let result = MathSolver.integGauss(over: 0...1, points: 10, function: { x in x * x })
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 1.0/3.0) < 0.001) }
    }

    @Test func planeGeometry() {
        let dist = PlaneGeometry.distanceToPoint(planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), point: SIMD3(0, 0, 5))
        #expect(abs(dist - 5.0) < 0.001)
    }

    @Test func lineGeometry() {
        let dist = LineGeometry.distanceToPoint(linePoint: .zero, lineDirection: SIMD3(1, 0, 0), point: SIMD3(5, 3, 0))
        #expect(abs(dist - 3.0) < 0.001)
    }

    @Test func vectorCrossMagnitude() {
        let mag = Shape.vecCrossMagnitude(SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        #expect(abs(mag - 1.0) < 0.001)
    }

    @Test func dirIsOpposite() {
        #expect(Shape.dirIsOpposite(SIMD3(1, 0, 0), SIMD3(-1, 0, 0)))
        #expect(!Shape.dirIsOpposite(SIMD3(1, 0, 0), SIMD3(1, 0, 0)))
    }

    @Test func dirIsNormal() {
        #expect(Shape.dirIsNormal(SIMD3(1, 0, 0), SIMD3(0, 1, 0)))
        #expect(!Shape.dirIsNormal(SIMD3(1, 0, 0), SIMD3(1, 0, 0)))
    }
}

// MARK: - Mesh Operations

@Suite("Stress: Mesh API")
struct StressMeshAPITests {

    @Test func meshGeneration() {
        let m = standardBox().mesh(linearDeflection: 0.5)
        #expect(m != nil)
        if let m {
            #expect(m.vertexCount > 0)
            #expect(m.triangleCount > 0)
        }
    }

    @Test func meshVertices() {
        if let m = standardSphere().mesh(linearDeflection: 0.5) {
            let verts = m.vertices
            #expect(!verts.isEmpty)
        }
    }

    @Test func meshNormals() {
        if let m = standardCylinder().mesh(linearDeflection: 0.5) {
            let normals = m.normals
            #expect(!normals.isEmpty)
        }
    }

    @Test func meshTriangles() {
        if let m = standardTorus().mesh(linearDeflection: 0.5) {
            #expect(m.triangleCount > 0)
        }
    }

    @Test func meshOnAllShapes() {
        for (name, shape) in allStandardShapes() {
            let m = shape.mesh(linearDeflection: 0.5)
            #expect(m != nil, "Mesh failed for \(name)")
        }
    }
}

// MARK: - Feature Recognition

@Suite("Stress: Feature Recognition")
struct StressFeatureRecognitionTests {

    @Test func aagOnBox() {
        let box = standardBox()
        let aag = AAG(shape: box)
        #expect(aag.nodes.count == 6)
    }

    @Test func aagOnFilletedBox() {
        let box = filletedBox()
        let aag = AAG(shape: box)
        #expect(aag.nodes.count > 6)
    }

    @Test func aagOnDrilledPlate() {
        let plate = drilledPlate()
        let aag = AAG(shape: plate)
        #expect(aag.nodes.count > 6)
    }
}
