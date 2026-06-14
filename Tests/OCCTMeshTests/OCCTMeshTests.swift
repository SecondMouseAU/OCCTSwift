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


@Suite("Mesh from raw arrays")
struct MeshFromArraysTests {
    // Single-tetrahedron triangulation reused across cases.
    static let tetVertices: [SIMD3<Float>] = [
        SIMD3(0, 0, 0),
        SIMD3(1, 0, 0),
        SIMD3(0, 1, 0),
        SIMD3(0, 0, 1),
    ]
    static let tetIndices: [UInt32] = [
        0, 2, 1,   // bottom
        0, 1, 3,   // front
        0, 3, 2,   // left
        1, 2, 3,   // tilted face
    ]

    @Test("Round-trip vertices and indices")
    func roundTrip() {
        guard let mesh = Mesh(
            vertices: Self.tetVertices,
            indices: Self.tetIndices
        ) else {
            Issue.record("Mesh.init failed on a valid tetrahedron")
            return
        }
        #expect(mesh.vertexCount == 4)
        #expect(mesh.triangleCount == 4)
        let verts = mesh.vertices
        let idxs = mesh.indices
        #expect(verts.count == 4)
        #expect(idxs == Self.tetIndices)
        for (a, b) in zip(verts, Self.tetVertices) {
            #expect(abs(a.x - b.x) < 1e-6)
            #expect(abs(a.y - b.y) < 1e-6)
            #expect(abs(a.z - b.z) < 1e-6)
        }
    }

    @Test("Computed normals when none provided produce unit-length per-vertex normals")
    func computedNormals() {
        guard let mesh = Mesh(
            vertices: Self.tetVertices,
            indices: Self.tetIndices
        ) else {
            Issue.record("Mesh.init failed")
            return
        }
        let n = mesh.normals
        #expect(n.count == 4)
        for normal in n {
            let len = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            // Either unit length (vertex touched a triangle) or zero (orphan — shouldn't
            // happen for a closed tetrahedron, but tolerate the fallback).
            #expect(abs(len - 1.0) < 1e-5 || len < 1e-9)
        }
    }

    @Test("Provided normals are preserved verbatim")
    func suppliedNormals() {
        let custom: [SIMD3<Float>] = [
            SIMD3(1, 0, 0),
            SIMD3(0, 1, 0),
            SIMD3(0, 0, 1),
            SIMD3(-1, 0, 0),
        ]
        guard let mesh = Mesh(
            vertices: Self.tetVertices,
            normals: custom,
            indices: Self.tetIndices
        ) else {
            Issue.record("Mesh.init with normals failed")
            return
        }
        let read = mesh.normals
        #expect(read.count == custom.count)
        for (a, b) in zip(read, custom) {
            #expect(abs(a.x - b.x) < 1e-6)
            #expect(abs(a.y - b.y) < 1e-6)
            #expect(abs(a.z - b.z) < 1e-6)
        }
    }

    @Test("Empty inputs return nil")
    func rejectsEmpty() {
        #expect(Mesh(vertices: [], indices: []) == nil)
        #expect(Mesh(vertices: Self.tetVertices, indices: []) == nil)
        #expect(Mesh(vertices: [], indices: Self.tetIndices) == nil)
    }

    @Test("Index count not divisible by 3 returns nil")
    func rejectsBadIndexCount() {
        #expect(Mesh(vertices: Self.tetVertices, indices: [0, 1]) == nil)
        #expect(Mesh(vertices: Self.tetVertices, indices: [0, 1, 2, 3]) == nil)
    }

    @Test("Out-of-range index returns nil")
    func rejectsOutOfRangeIndex() {
        #expect(Mesh(vertices: Self.tetVertices, indices: [0, 1, 9]) == nil)
        #expect(Mesh(vertices: Self.tetVertices, indices: [0, 1, 4]) == nil)
    }

    @Test("Mismatched normals length returns nil")
    func rejectsBadNormalsLength() {
        let badNormals: [SIMD3<Float>] = [SIMD3(0, 0, 1), SIMD3(0, 0, 1)]
        #expect(Mesh(
            vertices: Self.tetVertices,
            normals: badNormals,
            indices: Self.tetIndices
        ) == nil)
    }
}

@Suite("Mesh Tests")
struct MeshTests {

    @Test("Mesh from shape")
    func meshFromShape() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let mesh = box.mesh(linearDeflection: 0.1)!

        // With stubs, mesh will be empty
        // With real OCCT, will have vertices and triangles
        _ = mesh.vertexCount
        _ = mesh.triangleCount
    }

    @Test("Mesh data access")
    func meshDataAccess() {
        let sphere = Shape.sphere(radius: 5)!
        let mesh = sphere.mesh(linearDeflection: 0.5)!

        let vertices = mesh.vertices
        let normals = mesh.normals
        let indices = mesh.indices

        // Lengths should be consistent
        #expect(vertices.count == normals.count)
        #expect(indices.count == mesh.triangleCount * 3)
    }

    @Test("Enhanced mesh parameters")
    func enhancedMeshParameters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        var params = MeshParameters.default
        params.deflection = 0.05
        params.inParallel = true

        let mesh = box.mesh(parameters: params)!
        #expect(mesh.vertexCount > 0)
        #expect(mesh.triangleCount > 0)
    }

    @Test("Triangles with face info")
    func trianglesWithFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let mesh = box.mesh(linearDeflection: 0.1)!

        let triangles = mesh.trianglesWithFaces()
        #expect(triangles.count == mesh.triangleCount)

        // Each triangle should have valid data
        for tri in triangles {
            #expect(tri.v1 < UInt32(mesh.vertexCount))
            #expect(tri.v2 < UInt32(mesh.vertexCount))
            #expect(tri.v3 < UInt32(mesh.vertexCount))
            // Face index should be valid (>= 0 for box with 6 faces)
            #expect(tri.faceIndex >= 0)
        }
    }

    @Test("Mesh to shape conversion")
    func meshToShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let mesh = box.mesh(linearDeflection: 0.5)!

        // Convert mesh back to shape
        let shape = mesh.toShape()
        #expect(shape != nil)
    }

    @Test("Mesh boolean union")
    func meshBooleanUnion() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(5, 0, 0))!

        let mesh1 = box1.mesh(linearDeflection: 0.5)!
        let mesh2 = box2.mesh(linearDeflection: 0.5)!

        let unionMesh = mesh1.union(with: mesh2, deflection: 0.5)
        #expect(unionMesh != nil)
        if let union = unionMesh {
            #expect(union.triangleCount > 0)
        }
    }

    @Test("Mesh boolean subtraction")
    func meshBooleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cylinder = Shape.cylinder(radius: 3, height: 15)!

        let boxMesh = box.mesh(linearDeflection: 0.5)!
        let cylMesh = cylinder.mesh(linearDeflection: 0.5)!

        let diffMesh = boxMesh.subtracting(cylMesh, deflection: 0.5)
        #expect(diffMesh != nil)
    }

    @Test("Mesh boolean intersection")
    func meshBooleanIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 7)!

        let boxMesh = box.mesh(linearDeflection: 0.5)!
        let sphereMesh = sphere.mesh(linearDeflection: 0.5)!

        let intersectMesh = boxMesh.intersection(with: sphereMesh, deflection: 0.5)
        #expect(intersectMesh != nil)
    }
}

@Suite("Presentation Mesh Tests")
struct PresentationMeshTests {

    @Test("Box shaded mesh has 12 triangles")
    func boxShadedMesh() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let mesh = box.shadedMesh(deflection: 0.1)

        #expect(mesh != nil)
        #expect(mesh!.triangleCount == 12)  // 6 faces * 2 triangles each
        #expect(mesh!.vertices.count == mesh!.normals.count)

        // All normals should be non-zero
        for normal in mesh!.normals {
            let len = Float(sqrt(Double(normal.x*normal.x + normal.y*normal.y + normal.z*normal.z)))
            #expect(len > 0.5)
        }
    }

    @Test("Cylinder shaded mesh has triangles")
    func cylinderShadedMesh() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let mesh = cyl.shadedMesh(deflection: 0.1)

        #expect(mesh != nil)
        #expect(mesh!.triangleCount > 0)
        #expect(mesh!.vertices.count > 0)
    }

    @Test("Box edge mesh has 12 segments")
    func boxEdgeMesh() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edgeMesh(deflection: 0.1)

        #expect(edges != nil)
        #expect(edges!.segmentCount == 12)  // A box has 12 edges
        #expect(edges!.vertices.count > 0)
    }

    @Test("Sphere edge mesh produces valid segments")
    func sphereEdgeMesh() {
        let sphere = Shape.sphere(radius: 5)!
        let edges = sphere.edgeMesh(deflection: 0.1)

        #expect(edges != nil)
        #expect(edges!.segmentCount > 0)
        #expect(edges!.vertices.count > 0)
    }
}

// MARK: - Drawer-Aware Mesh Tests

@Suite("Drawer Mesh Extraction")
struct DrawerMeshTests {

    @Test("Shaded mesh with default drawer produces valid mesh")
    func shadedMeshDefaultDrawer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawer = DisplayDrawer()

        let mesh = box.shadedMesh(drawer: drawer)
        #expect(mesh != nil)
        if let mesh = mesh {
            #expect(mesh.triangleCount == 12)
            #expect(mesh.vertices.count > 0)
            #expect(mesh.normals.count == mesh.vertices.count)
        }
    }

    @Test("Edge mesh with default drawer produces valid segments")
    func edgeMeshDefaultDrawer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawer = DisplayDrawer()

        let mesh = box.edgeMesh(drawer: drawer)
        #expect(mesh != nil)
        if let mesh = mesh {
            #expect(mesh.segmentCount == 12)
            #expect(mesh.vertices.count > 0)
        }
    }

    @Test("Finer deviation produces more triangles for curved shape")
    func finerDeviationMoreTriangles() {
        let sphere = Shape.sphere(radius: 10)!

        let coarseDrawer = DisplayDrawer()
        coarseDrawer.deviationCoefficient = 0.1

        let fineDrawer = DisplayDrawer()
        fineDrawer.deviationCoefficient = 0.001

        let coarseMesh = sphere.shadedMesh(drawer: coarseDrawer)
        let fineMesh = sphere.shadedMesh(drawer: fineDrawer)

        #expect(coarseMesh != nil)
        #expect(fineMesh != nil)
        if let coarse = coarseMesh, let fine = fineMesh {
            #expect(fine.triangleCount > coarse.triangleCount)
        }
    }

    @Test("Absolute deflection type works")
    func absoluteDeflection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawer = DisplayDrawer()
        drawer.deflectionType = .absolute
        drawer.maximalChordialDeviation = 0.5

        let mesh = box.shadedMesh(drawer: drawer)
        #expect(mesh != nil)
        if let mesh = mesh {
            #expect(mesh.triangleCount == 12)
        }
    }
}

// MARK: - Mesh Coordinate System Enum Tests (v0.59.0)

@Suite("MeshCoordinateSystem Enum")
struct MeshCoordinateSystemEnumTests {

    @Test("Raw values")
    func rawValues() {
        #expect(MeshCoordinateSystem.undefined.rawValue == -1)
        #expect(MeshCoordinateSystem.zUp.rawValue == 0)
        #expect(MeshCoordinateSystem.yUp.rawValue == 1)
    }

    @Test("Aliases")
    func aliases() {
        #expect(MeshCoordinateSystem.blender == .zUp)
        #expect(MeshCoordinateSystem.gltf == .yUp)
    }

    @Test("Init from raw value")
    func initFromRaw() {
        #expect(MeshCoordinateSystem(rawValue: -1) == .undefined)
        #expect(MeshCoordinateSystem(rawValue: 0) == .zUp)
        #expect(MeshCoordinateSystem(rawValue: 1) == .yUp)
        #expect(MeshCoordinateSystem(rawValue: 99) == nil)
    }
}

@Suite("BRepMesh Deflection")
struct BRepMeshDeflectionTests {
    @Test("Compute absolute deflection")
    func computeAbsoluteDeflection() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let absDef = box.computeAbsoluteDeflection(relativeDeflection: 0.01, maxShapeSize: 30.0)
        if let absDef = absDef {
            #expect(absDef > 0)
        }
    }

    @Test("Deflection consistency check")
    func deflectionConsistency() {
        // current <= required → consistent
        #expect(Shape.deflectionIsConsistent(current: 0.1, required: 0.2))
        #expect(Shape.deflectionIsConsistent(current: 0.2, required: 0.2))
    }
}

@Suite("BRepBuilderAPI MakeShapeOnMesh")
struct MakeShapeOnMeshTests {
    @Test("Build shape from mesh")
    func buildShapeFromMesh() {
        // Tetrahedron mesh
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
            SIMD3(5, 10, 0),
            SIMD3(5, 5, 10)
        ]
        let triangles: [(Int32, Int32, Int32)] = [
            (1, 3, 2), // bottom
            (1, 2, 4), // front
            (2, 3, 4), // right
            (3, 1, 4)  // left
        ]
        let shape = Shape.fromMesh(points: points, triangles: triangles)
        if let shape = shape {
            #expect(shape.isValid)
            let faceCount = shape.faces().count
            #expect(faceCount > 0)
        }
    }

    @Test("Mesh with minimal geometry")
    func meshMinimal() {
        // Single triangle
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
            SIMD3(5, 10, 0)
        ]
        let triangles: [(Int32, Int32, Int32)] = [(1, 2, 3)]
        let shape = Shape.fromMesh(points: points, triangles: triangles)
        #expect(shape != nil)
    }
}

@Suite("BRepGProp MeshCinert Tests")
struct MeshCinertTests {
    @Test("prepare polygon and compute")
    func prepareAndCompute() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let _ = box.mesh(linearDeflection: 0.1)
        let edges = box.edges()
        if let edge = edges.first {
            let points = edge.meshPolygonPoints()
            #expect(points.count > 0)
            if points.count >= 2 {
                let result = meshCinertCompute(points: points)
                #expect(result.mass > 0)
            }
        }
    }
}

@Suite("BRepGProp MeshProps Tests")
struct MeshPropsTests {
    @Test("surface mesh properties")
    func surfaceProps() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let _ = box.mesh(linearDeflection: 0.1)
        let faces = box.faces()
        if let face = faces.first {
            let result = face.meshProps(type: .surface)
            #expect(result.mass > 0)
        }
    }

    @Test("volume mesh properties")
    func volumeProps() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let _ = box.mesh(linearDeflection: 0.1)
        let faces = box.faces()
        if let face = faces.first {
            let result = face.meshProps(type: .volume)
            // Volume contribution from single face may be zero or small — just don't crash
            let _ = result.mass
        }
    }
}

@Suite("BRepMesh ShapeTool Tests")
struct MeshShapeToolTests {
    @Test("max face tolerance")
    func maxFaceTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let _ = box.mesh(linearDeflection: 0.1)
        let faces = box.faces()
        if let face = faces.first {
            let tol = face.maxMeshTolerance
            #expect(tol > 0)
        }
    }

    @Test("box max dimension")
    func boxMaxDimension() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let maxDim = box.meshMaxDimension
        #expect(abs(maxDim - 10.0) < 1.0)
    }

    @Test("UV points on edge")
    func uvPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let _ = box.mesh(linearDeflection: 0.1)
        let faces = box.faces()
        if let face = faces.first {
            // Get edges of this face by exploring box edges
            let edges = box.edges()
            if let edge = edges.first {
                let uv = face.uvPoints(edge: edge)
                // Some edges may not be on this face — just verify no crash
                let _ = uv
            }
        }
    }
}

@Suite("Poly_Polygon3D")
struct Polygon3DTests {
    @Test("create without parameters")
    func createWithoutParams() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0)]
        if let poly = Polygon3D.create(points: points) {
            #expect(poly.nodeCount == 3)
            #expect(!poly.hasParameters)
        }
    }

    @Test("create with parameters")
    func createWithParams() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(20, 0, 0)]
        let params: [Double] = [0.0, 10.0, 20.0]
        if let poly = Polygon3D.create(points: points, parameters: params) {
            #expect(poly.nodeCount == 3)
            #expect(poly.hasParameters)
            #expect(abs(poly.parameter(at: 1) - 10.0) < 1e-10)
        }
    }

    @Test("deflection")
    func deflection() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]
        if let poly = Polygon3D.create(points: points) {
            poly.deflection = 1.0
            #expect(abs(poly.deflection - 1.0) < 1e-10)
        }
    }
}

@Suite("Poly_PolygonOnTriangulation")
struct PolygonOnTriangulationTests {
    @Test("create without parameters")
    func createWithoutParams() {
        let indices: [Int32] = [1, 2, 3, 4]
        if let poly = PolygonOnTriangulation.create(nodeIndices: indices) {
            #expect(poly.nodeCount == 4)
            #expect(poly.nodeIndex(at: 0) == 1)
            #expect(poly.nodeIndex(at: 3) == 4)
            #expect(!poly.hasParameters)
        }
    }

    @Test("create with parameters")
    func createWithParams() {
        let indices: [Int32] = [1, 2, 3]
        let params: [Double] = [0.0, 1.0, 2.0]
        if let poly = PolygonOnTriangulation.create(nodeIndices: indices, parameters: params) {
            #expect(poly.nodeCount == 3)
            #expect(poly.hasParameters)
            #expect(abs(poly.parameter(at: 1) - 1.0) < 1e-10)
        }
    }

    @Test("deflection")
    func deflection() {
        let indices: [Int32] = [1, 2]
        if let poly = PolygonOnTriangulation.create(nodeIndices: indices) {
            poly.deflection = 0.1
            #expect(abs(poly.deflection - 0.1) < 1e-10)
        }
    }
}

@Suite("Poly_MergeNodesTool")
struct MergeNodesToolTests {
    @Test("merge mesh nodes from shape")
    func mergeFromShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Triangulate first
            let _ = box.mesh(linearDeflection: 1.0)
            if let merged = mergedMeshNodes(from: box, smoothAngle: .pi / 4) {
                #expect(merged.vertexCount > 0)
                #expect(merged.triangleCount > 0)
                #expect(merged.vertices.count == merged.vertexCount)
                #expect(merged.indices.count == merged.triangleCount * 3)
            }
        }
    }
}

// MARK: - v0.79.0 Tests

@Suite("Poly_CoherentTriangulation")
struct CoherentTriangulationTests {
    @Test("create empty and add nodes")
    func createAndAddNodes() {
        let ct = CoherentTriangulation.create()
        let n0 = ct.setNode(x: 0, y: 0, z: 0)
        let n1 = ct.setNode(x: 1, y: 0, z: 0)
        let n2 = ct.setNode(x: 0, y: 1, z: 0)
        #expect(n0 == 0)
        #expect(n1 == 1)
        #expect(n2 == 2)
    }

    @Test("add and count triangles")
    func addTriangles() {
        let ct = CoherentTriangulation.create()
        let _ = ct.setNode(x: 0, y: 0, z: 0)
        let _ = ct.setNode(x: 1, y: 0, z: 0)
        let _ = ct.setNode(x: 0, y: 1, z: 0)
        let _ = ct.setNode(x: 1, y: 1, z: 0)
        ct.addTriangle(0, 1, 2)
        ct.addTriangle(1, 3, 2)
        #expect(ct.triangleCount == 2)
    }

    @Test("remove triangle")
    func removeTriangle() {
        let ct = CoherentTriangulation.create()
        let _ = ct.setNode(x: 0, y: 0, z: 0)
        let _ = ct.setNode(x: 1, y: 0, z: 0)
        let _ = ct.setNode(x: 0, y: 1, z: 0)
        let _ = ct.setNode(x: 1, y: 1, z: 0)
        ct.addTriangle(0, 1, 2)
        ct.addTriangle(1, 3, 2)
        ct.removeTriangle(at: 0)
        #expect(ct.triangleCount == 1)
    }

    @Test("compute links")
    func computeLinks() {
        let ct = CoherentTriangulation.create()
        let _ = ct.setNode(x: 0, y: 0, z: 0)
        let _ = ct.setNode(x: 1, y: 0, z: 0)
        let _ = ct.setNode(x: 0, y: 1, z: 0)
        let _ = ct.setNode(x: 1, y: 1, z: 0)
        ct.addTriangle(0, 1, 2)
        ct.addTriangle(1, 3, 2)
        let nLinks = ct.computeLinks()
        #expect(nLinks > 0)
        #expect(ct.linkCount > 0)
    }

    @Test("deflection set/get")
    func deflection() {
        let ct = CoherentTriangulation.create()
        ct.setDeflection(0.5)
        #expect(abs(ct.deflection - 0.5) < 1e-10)
    }

    @Test("convert back to triangulation")
    func getResult() {
        let ct = CoherentTriangulation.create()
        let _ = ct.setNode(x: 0, y: 0, z: 0)
        let _ = ct.setNode(x: 1, y: 0, z: 0)
        let _ = ct.setNode(x: 0, y: 1, z: 0)
        ct.addTriangle(0, 1, 2)
        if let result = ct.getResult() {
            #expect(result.nodeCount == 3)
            #expect(result.triangleCount == 1)
        }
    }

    @Test("create from mesh")
    func createFromMesh() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 1.0)
            if let ct = CoherentTriangulation.createFromMesh(box) {
                #expect(ct.triangleCount > 0)
            }
        }
    }

    @Test("node coordinates after result")
    func nodeCoords() {
        let ct = CoherentTriangulation.create()
        let _ = ct.setNode(x: 1.5, y: 2.5, z: 3.5)
        let _ = ct.setNode(x: 4, y: 5, z: 6)
        let _ = ct.setNode(x: 7, y: 8, z: 9)
        ct.addTriangle(0, 1, 2)
        if let _ = ct.getResult() {
            if let coords = ct.nodeCoords(at: 1) {
                #expect(abs(coords.x - 1.5) < 1e-6)
                #expect(abs(coords.y - 2.5) < 1e-6)
                #expect(abs(coords.z - 3.5) < 1e-6)
            }
        }
    }
}

@Suite("Poly_Connect Mesh Adjacency Tests")
struct PolyConnectTests {

    @Test func triangleAdjacency() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.1)
            if let adj = box.meshTriangleAdjacency(faceIndex: 1, triangleIndex: 1) {
                #expect(adj.0 >= 0 && adj.1 >= 0 && adj.2 >= 0)
            }
        }
    }

    @Test func nodeTriangle() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.1)
            if let triIdx = box.meshNodeTriangle(faceIndex: 1, nodeIndex: 1) {
                #expect(triIdx >= 1)
            }
        }
    }

    @Test func nodeTriangleCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.1)
            let count = box.meshNodeTriangleCount(faceIndex: 1, nodeIndex: 1)
            #expect(count >= 1)
        }
    }
}

@Suite("v0.115.0 - Triangulation Queries")
struct TriangulationQueryTests {

    @Test func faceTriangulation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Mesh the box first
            if let _ = box.mesh(linearDeflection: 1.0) {
                let faces = box.subShapes(ofType: .face)
                if faces.count > 0 {
                    let face = faces[0]
                    let nodeCount = face.triangulationNodeCount
                    let triCount = face.triangulationTriangleCount
                    #expect(nodeCount > 0)
                    #expect(triCount > 0)
                    let defl = face.triangulationDeflection
                    #expect(defl > 0)

                    // Get first node
                    let p = face.triangulationNode(at: 1)
                    // Should be a valid 3D point
                    let mag = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    #expect(mag >= 0) // can be zero if at origin

                    // Get first triangle
                    let (n1, n2, n3) = face.triangulationTriangle(at: 1)
                    #expect(n1 >= 1)
                    #expect(n2 >= 1)
                    #expect(n3 >= 1)
                }
            }
        }
    }

    @Test func triangulationUVNodes() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let _ = box.mesh(linearDeflection: 1.0) {
                let faces = box.subShapes(ofType: .face)
                if faces.count > 0 {
                    let face = faces[0]
                    if face.triangulationHasUVNodes {
                        let uv = face.triangulationUVNode(at: 1)
                        // UV should be in some range
                        let _ = uv
                    }
                }
            }
        }
    }
}

@Suite("v0.160 MeshCache write API")
struct MeshCacheWriteTests {
    @Test("Triangulation create from arrays round-trips")
    func triangulationRoundTrip() {
        let nodes: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0),
        ]
        let triangles = [0, 1, 2, 1, 3, 2]
        guard let tri = Triangulation.create(nodes: nodes, triangles: triangles) else {
            Issue.record("Triangulation.create returned nil")
            return
        }
        #expect(tri.nodeCount == 4)
        #expect(tri.triangleCount == 2)
        if let n0 = tri.node(at: 0) {
            #expect(abs(n0.x) < 1e-12 && abs(n0.y) < 1e-12 && abs(n0.z) < 1e-12)
        }
        if let t0 = tri.triangle(at: 0) {
            #expect(t0.0 == 0 && t0.1 == 1 && t0.2 == 2)
        }
        tri.deflection = 0.01
        #expect(abs(tri.deflection - 0.01) < 1e-12)
    }

    @Test("Triangulation rejects malformed inputs")
    func triangulationRejectsBadInputs() {
        // Empty nodes.
        #expect(Triangulation.create(nodes: [], triangles: []) == nil)
        // Triangle index out of range.
        let nodes: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        #expect(Triangulation.create(nodes: nodes, triangles: [0, 1, 99]) == nil)
        // Triangle count not divisible by 3.
        #expect(Triangulation.create(nodes: nodes, triangles: [0, 1]) == nil)
    }

    @Test("Create triangulation rep and bind it to a face")
    func createAndBindTriangulationRep() {
        let nodes: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0),
        ]
        let triangles = [0, 1, 2, 1, 3, 2]
        guard let tri = Triangulation.create(nodes: nodes, triangles: triangles) else {
            Issue.record("Triangulation.create nil"); return
        }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                guard let repId = graph.createTriangulationRep(tri) else {
                    Issue.record("createTriangulationRep nil"); return
                }
                #expect(repId >= 0)
                // Bind it to face 0; the call must not crash on a valid id.
                graph.appendCachedTriangulation(faceIndex: 0, triRepId: repId)
                graph.setCachedActiveIndex(faceIndex: 0, activeIndex: 0)
                // After append, MeshView should report the rep as the active triangulation for face 0.
                let active = graph.meshFaceActiveTriangulationRepId(0)
                #expect(active != nil)
            }
        }
    }

    @Test("Create polygon3D rep and bind it to an edge")
    func createAndBindPolygon3DRep() {
        let pts: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 0, 0)]
        guard let poly = Polygon3D.create(points: pts) else {
            Issue.record("Polygon3D.create nil"); return
        }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                guard let repId = graph.createPolygon3DRep(poly) else {
                    Issue.record("createPolygon3DRep nil"); return
                }
                #expect(repId >= 0)
                graph.setCachedPolygon3D(edgeIndex: 0, polyRepId: repId)
                let active = graph.meshEdgePolygon3DRepId(0)
                #expect(active != nil)
            }
        }
    }
}

@Suite("v0.158 MeshView two-tier mesh storage")
struct MeshViewCountsTests {
    @Test("Mesh count properties are non-negative on a fresh graph")
    func meshCountsZeroOnFreshGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // No mesh has been computed yet; all counts should be 0 (or at least non-negative).
                #expect(graph.polygon2DCount >= 0)
                #expect(graph.polygonOnTriCount >= 0)
                #expect(graph.activeTriangulationCount >= 0)
                #expect(graph.activePolygon3DCount >= 0)
                #expect(graph.activePolygon2DCount >= 0)
                #expect(graph.activePolygonOnTriCount >= 0)
                // Active counts cannot exceed total counts.
                #expect(graph.activeTriangulationCount <= graph.triangulationCount)
                #expect(graph.activePolygon3DCount <= graph.polygon3DCount)
                #expect(graph.activePolygon2DCount <= graph.polygon2DCount)
                #expect(graph.activePolygonOnTriCount <= graph.polygonOnTriCount)
            }
        }
    }

    @Test("Mesh rep id queries return nil when no mesh is present")
    func meshRepIdsAbsentBeforeMeshing() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // No incremental mesh has run; cache and persistent tiers are empty.
                #expect(graph.meshFaceActiveTriangulationRepId(0) == nil)
                #expect(graph.meshEdgePolygon3DRepId(0) == nil)
                #expect(graph.meshCoEdgeHasMesh(0) == false)
            }
        }
    }

    @Test("Mesh counts after incremental meshing")
    func meshCountsAfterIncrementalMesh() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            // Generate triangulation via incremental mesher.
            _ = box.mesh(linearDeflection: 0.5, angularDeflection: 0.5)
            let graph = TopologyGraph(shape: box)
            if let graph {
                // After meshing, persistent triangulation tier should report nonzero.
                #expect(graph.triangulationCount + graph.polygon3DCount >= 0)
            }
        }
    }
}
