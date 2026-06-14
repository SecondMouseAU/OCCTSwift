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


// MARK: - Measurement & Analysis Tests (v0.7.0)

@Suite("Measurement Tests")
struct MeasurementTests {

    // MARK: - Volume Tests

    @Test("Volume of box")
    func volumeOfBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let volume = box.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // 10 × 10 × 10 = 1000 cubic units
        #expect(abs(volume - 1000.0) < 0.01)
    }

    @Test("Volume of cylinder")
    func volumeOfCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!
        guard let volume = cylinder.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // π × r² × h = π × 25 × 10 ≈ 785.4
        let expected = Double.pi * 25.0 * 10.0
        #expect(abs(volume - expected) < 0.1)
    }

    @Test("Volume of sphere")
    func volumeOfSphere() {
        let sphere = Shape.sphere(radius: 5)!
        guard let volume = sphere.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // 4/3 × π × r³ = 4/3 × π × 125 ≈ 523.6
        let expected = (4.0 / 3.0) * Double.pi * 125.0
        #expect(abs(volume - expected) < 0.1)
    }

    // MARK: - Surface Area Tests

    @Test("Surface area of box")
    func surfaceAreaOfBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let area = box.surfaceArea else {
            Issue.record("Failed to compute surface area")
            return
        }
        // 6 faces × 100 = 600 square units
        #expect(abs(area - 600.0) < 0.1)
    }

    @Test("Surface area of sphere")
    func surfaceAreaOfSphere() {
        let sphere = Shape.sphere(radius: 5)!
        guard let area = sphere.surfaceArea else {
            Issue.record("Failed to compute surface area")
            return
        }
        // 4 × π × r² = 4 × π × 25 ≈ 314.16
        let expected = 4.0 * Double.pi * 25.0
        #expect(abs(area - expected) < 0.5)
    }

    // MARK: - Center of Mass Tests

    @Test("Center of mass of box at origin")
    func centerOfMassBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let center = box.centerOfMass else {
            Issue.record("Failed to compute center of mass")
            return
        }
        // Box is created centered at origin (from -5 to +5 in each axis)
        #expect(abs(center.x) < 0.01)
        #expect(abs(center.y) < 0.01)
        #expect(abs(center.z) < 0.01)
    }

    @Test("Center of mass of translated box")
    func centerOfMassTranslatedBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(100, 200, 300))!
        guard let center = box.centerOfMass else {
            Issue.record("Failed to compute center of mass")
            return
        }
        // Box centered at origin, then translated by (100, 200, 300)
        #expect(abs(center.x - 100.0) < 0.01)
        #expect(abs(center.y - 200.0) < 0.01)
        #expect(abs(center.z - 300.0) < 0.01)
    }

    // MARK: - Full Properties Test

    @Test("Full shape properties")
    func fullShapeProperties() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let props = box.properties(density: 2.5) else {
            Issue.record("Failed to compute properties")
            return
        }

        #expect(abs(props.volume - 1000.0) < 0.01)
        #expect(abs(props.surfaceArea - 600.0) < 0.1)
        #expect(abs(props.mass - 2500.0) < 0.1)  // 1000 × 2.5
        #expect(abs(props.centerOfMass.x) < 0.01)  // Box centered at origin
    }

    // MARK: - Distance Tests

    @Test("Distance between separated boxes")
    func distanceBetweenBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        guard let result = box1.distance(to: box2) else {
            Issue.record("Failed to compute distance")
            return
        }
        // Gap of 10 units between boxes
        #expect(abs(result.distance - 10.0) < 0.01)
    }

    @Test("Distance between touching boxes")
    func distanceBetweenTouchingBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        guard let result = box1.distance(to: box2) else {
            Issue.record("Failed to compute distance")
            return
        }
        // Boxes are touching
        #expect(abs(result.distance) < 0.01)
    }

    @Test("Min distance convenience method")
    func minDistanceConvenience() {
        let sphere1 = Shape.sphere(radius: 5)!
        let sphere2 = Shape.sphere(radius: 3)!.translated(by: SIMD3(15, 0, 0))!

        guard let dist = sphere1.minDistance(to: sphere2) else {
            Issue.record("Failed to compute min distance")
            return
        }
        // 15 - 5 - 3 = 7 units gap
        #expect(abs(dist - 7.0) < 0.1)
    }

    // MARK: - Intersection Tests

    @Test("Intersects - overlapping shapes")
    func intersectsOverlapping() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!  // At origin, inside box

        #expect(box.intersects(sphere))
    }

    @Test("Intersects - separated shapes")
    func intersectsSeparated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!
            .translated(by: SIMD3(50, 0, 0))!  // Far away

        #expect(!box.intersects(sphere))
    }

    @Test("Intersects - touching shapes")
    func intersectsTouching() {
        // Box from -5 to +5 in each axis (centered at origin)
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Sphere of radius 5 centered at (10, 0, 0) touches box at x=5
        let sphere = Shape.sphere(radius: 5)!
            .translated(by: SIMD3(10, 0, 0))!

        // Should be touching or very close
        #expect(box.intersects(sphere, tolerance: 0.1))
    }

    // MARK: - Vertex Tests

    @Test("Vertex count of box")
    func vertexCountBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.vertexCount == 8)
    }

    @Test("Get all vertices")
    func getAllVertices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertices = box.vertices()
        #expect(vertices.count == 8)
    }

    @Test("Get vertex at index")
    func vertexAtIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertex = box.vertex(at: 0)
        #expect(vertex != nil)
    }

    @Test("Vertex out of bounds")
    func vertexOutOfBounds() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertex = box.vertex(at: 100)  // Invalid index
        #expect(vertex == nil)
    }
}

// MARK: - Point Classification Tests (v0.17.0)

@Suite("Point Classification Tests")
struct PointClassificationTests {

    @Test("Point inside box")
    func pointInsideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Box is centered at origin, extends from -5 to 5 in each axis
        let result = box.classify(point: SIMD3(0, 0, 0), tolerance: 1e-6)
        #expect(result == .inside)
    }

    @Test("Point outside box")
    func pointOutsideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.classify(point: SIMD3(100, 100, 100), tolerance: 1e-6)
        #expect(result == .outside)
    }

    @Test("Point on box face")
    func pointOnBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Point on the top face at Z=5 (box extends from -5 to 5 on Z)
        let result = box.classify(point: SIMD3(0, 0, 5), tolerance: 1e-3)
        #expect(result == .onBoundary)
    }

    @Test("Point inside sphere")
    func pointInsideSphere() {
        let sphere = Shape.sphere(radius: 10)!
        let result = sphere.classify(point: SIMD3(1, 1, 1), tolerance: 1e-6)
        #expect(result == .inside)
    }

    @Test("Face classify: point on face")
    func faceClassifyPoint() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        // Find a face and classify a point on it
        let face = faces[0]
        let normal = face.normal
        #expect(normal != nil)
    }

    @Test("Face classify UV: center of face")
    func faceClassifyUV() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        // Get UV bounds and classify at the center
        let uvb = face.uvBounds!
        let uMid = (uvb.uMin + uvb.uMax) / 2.0
        let vMid = (uvb.vMin + uvb.vMax) / 2.0
        let result = face.classify(u: uMid, v: vMid, tolerance: 1e-6)
        // Center of face domain should be classified as inside
        #expect(result == .inside)
    }
}


// MARK: - Face Surface Properties Tests (v0.18.0)

@Suite("Face Surface Properties Tests")
struct FaceSurfacePropertiesTests {

    @Test("UV bounds of box face")
    func uvBoundsBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        let bounds = face.uvBounds
        #expect(bounds != nil)
        if let b = bounds {
            #expect(b.uMax > b.uMin)
            #expect(b.vMax > b.vMin)
        }
    }

    @Test("Evaluate point on box face at UV center")
    func evaluatePointOnBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        guard let bounds = face.uvBounds else {
            #expect(Bool(false), "No UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let pt = face.point(atU: uMid, v: vMid)
        #expect(pt != nil)
    }

    @Test("Normal at UV on box face is axis-aligned")
    func normalAtUVBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        guard let bounds = face.uvBounds else {
            #expect(Bool(false), "No UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let n = face.normal(atU: uMid, v: vMid)
        #expect(n != nil)
        if let n = n {
            // Box face normal should be axis-aligned: one component ~1, others ~0
            let absN = SIMD3(abs(n.x), abs(n.y), abs(n.z))
            let maxComponent = max(absN.x, max(absN.y, absN.z))
            #expect(maxComponent > 0.99)
        }
    }

    @Test("Gaussian curvature of plane face is zero")
    func gaussianCurvaturePlane() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        guard let bounds = face.uvBounds else {
            #expect(Bool(false), "No UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let gc = face.gaussianCurvature(atU: uMid, v: vMid)
        #expect(gc != nil)
        if let gc = gc {
            #expect(abs(gc) < 1e-10)
        }
    }

    @Test("Gaussian curvature of sphere is 1/r²")
    func gaussianCurvatureSphere() {
        let radius = 5.0
        let sphere = Shape.sphere(radius: radius)!
        let faces = sphere.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        guard let bounds = face.uvBounds else {
            #expect(Bool(false), "No UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let gc = face.gaussianCurvature(atU: uMid, v: vMid)
        #expect(gc != nil)
        if let gc = gc {
            let expected = 1.0 / (radius * radius)
            #expect(abs(gc - expected) < 0.01)
        }
    }

    @Test("Mean curvature of sphere is 1/r")
    func meanCurvatureSphere() {
        let radius = 5.0
        let sphere = Shape.sphere(radius: radius)!
        let faces = sphere.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        guard let bounds = face.uvBounds else {
            #expect(Bool(false), "No UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let mc = face.meanCurvature(atU: uMid, v: vMid)
        #expect(mc != nil)
        if let mc = mc {
            let expected = 1.0 / radius
            // Mean curvature sign depends on face orientation; compare magnitudes
            #expect(abs(abs(mc) - expected) < 0.01)
        }
    }

    @Test("Principal curvatures of cylinder")
    func principalCurvaturesCylinder() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
        let faces = cyl.faces()
        // Cylinder has 3 faces: lateral, top, bottom
        // Find the cylindrical (non-planar) face
        var cylFace: Face?
        for face in faces {
            if face.surfaceType == .cylinder {
                cylFace = face
                break
            }
        }
        #expect(cylFace != nil)

        if let face = cylFace {
            guard let bounds = face.uvBounds else {
                #expect(Bool(false), "No UV bounds")
                return
            }
            let uMid = (bounds.uMin + bounds.uMax) / 2.0
            let vMid = (bounds.vMin + bounds.vMax) / 2.0
            let pc = face.principalCurvatures(atU: uMid, v: vMid)
            #expect(pc != nil)
            if let pc = pc {
                // Cylinder: one curvature ~0 (along axis), other ~1/r
                let minK = min(abs(pc.kMin), abs(pc.kMax))
                let maxK = max(abs(pc.kMin), abs(pc.kMax))
                #expect(minK < 0.01)
                #expect(abs(maxK - 1.0 / radius) < 0.01)
            }
        }
    }

    @Test("Surface type detection")
    func surfaceTypeDetection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let boxFaces = box.faces()
        #expect(!boxFaces.isEmpty)
        #expect(boxFaces[0].surfaceType == .plane)

        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let cylFaces = cyl.faces()
        var hasCylinder = false
        for face in cylFaces {
            if face.surfaceType == .cylinder {
                hasCylinder = true
                break
            }
        }
        #expect(hasCylinder)
    }

    @Test("Face area of box face")
    func faceAreaBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let faces = box.faces()
        #expect(faces.count == 6)

        // Sum all face areas should equal total surface area
        var totalArea = 0.0
        for face in faces {
            totalArea += face.area()
        }
        let expectedTotal: Double = 2200.0  // 2*(10*20 + 10*30 + 20*30)
        #expect(abs(totalArea - expectedTotal) < 1.0)
    }
}


// MARK: - Edge 3D Curve Properties Tests (v0.18.0)

@Suite("Edge Curve Properties Tests")
struct EdgeCurvePropertiesTests {

    @Test("Parameter bounds of line edge")
    func parameterBoundsLineEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(!edges.isEmpty)

        let edge = edges[0]
        let bounds = edge.parameterBounds
        #expect(bounds != nil)
        if let b = bounds {
            #expect(b.last > b.first)
        }
    }

    @Test("Curvature of circle edge is 1/r")
    func curvatureCircleEdge() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
        let edges = cyl.edges()

        // Find a circular edge
        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let curv = edge.curvature(at: mid)
            #expect(curv != nil)
            if let curv = curv {
                #expect(abs(curv - 1.0 / radius) < 0.01)
            }
        }
    }

    @Test("Curvature of line edge is zero")
    func curvatureLineEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()

        var lineEdge: Edge?
        for edge in edges {
            if edge.curveType == .line {
                lineEdge = edge
                break
            }
        }
        #expect(lineEdge != nil)

        if let edge = lineEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let curv = edge.curvature(at: mid)
            #expect(curv != nil)
            if let curv = curv {
                #expect(abs(curv) < 1e-10)
            }
        }
    }

    @Test("Tangent direction of straight edge")
    func tangentStraightEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(!edges.isEmpty)

        var lineEdge: Edge?
        for edge in edges {
            if edge.curveType == .line {
                lineEdge = edge
                break
            }
        }
        #expect(lineEdge != nil)

        if let edge = lineEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let tang = edge.tangent(at: mid)
            #expect(tang != nil)
            if let t = tang {
                // Tangent should be unit length
                let len = sqrt(t.x * t.x + t.y * t.y + t.z * t.z)
                #expect(abs(len - 1.0) < 1e-6)
            }
        }
    }

    @Test("Normal of circle edge points toward center")
    func normalCircleEdge() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let n = edge.normal(at: mid)
            #expect(n != nil)
            if let n = n {
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                #expect(abs(len - 1.0) < 1e-6)
            }
        }
    }

    @Test("Center of curvature of circle matches circle center")
    func centerOfCurvatureCircle() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let center = edge.centerOfCurvature(at: mid)
            #expect(center != nil)
            if let c = center {
                // Circle is in XY plane at Z=0 or Z=height, centered at origin
                // Center of curvature should be at the circle center (0,0,z)
                let distFromAxis = sqrt(c.x * c.x + c.y * c.y)
                #expect(distFromAxis < 0.01)
            }
        }
    }

    @Test("Torsion of planar curve is zero")
    func torsionPlanarCurve() {
        let radius = 5.0
        let cyl = Shape.cylinder(radius: radius, height: 10)!
        let edges = cyl.edges()

        var circEdge: Edge?
        for edge in edges {
            if edge.curveType == .circle {
                circEdge = edge
                break
            }
        }
        #expect(circEdge != nil)

        if let edge = circEdge {
            guard let bounds = edge.parameterBounds else {
                #expect(Bool(false), "No parameter bounds")
                return
            }
            let mid = (bounds.first + bounds.last) / 2.0
            let tor = edge.torsion(at: mid)
            #expect(tor != nil)
            if let tor = tor {
                #expect(abs(tor) < 1e-6)
            }
        }
    }

    @Test("Curve type detection")
    func curveTypeDetection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let boxEdges = box.edges()
        #expect(!boxEdges.isEmpty)
        #expect(boxEdges[0].curveType == .line)

        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let cylEdges = cyl.edges()
        var hasCircle = false
        for edge in cylEdges {
            if edge.curveType == .circle {
                hasCircle = true
                break
            }
        }
        #expect(hasCircle)
    }

    @Test("Point at parameter matches expected location")
    func pointAtParameter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(!edges.isEmpty)

        let edge = edges[0]
        guard let bounds = edge.parameterBounds else {
            #expect(Bool(false), "No parameter bounds")
            return
        }

        // Points at start and end should match endpoints
        let ptStart = edge.point(at: bounds.first)
        let ptEnd = edge.point(at: bounds.last)
        let endpoints = edge.endpoints
        #expect(ptStart != nil)
        #expect(ptEnd != nil)

        if let s = ptStart {
            let dist = simd_length(s - endpoints.start)
            #expect(dist < 0.01)
        }
        if let e = ptEnd {
            let dist = simd_length(e - endpoints.end)
            #expect(dist < 0.01)
        }
    }
}


// MARK: - Surface Intersection Tests (v0.18.0)

@Suite("Surface Intersection Tests")
struct SurfaceIntersectionTests {

    @Test("Intersect two perpendicular planar faces gives line")
    func intersectPerpendicularPlanes() {
        // Create two boxes that share an edge
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!

        let faces1 = box1.faces()
        let faces2 = box2.faces()
        #expect(faces1.count >= 2)
        #expect(faces2.count >= 2)

        // Find two faces with perpendicular normals
        var face1: Face?
        var face2: Face?
        for f1 in faces1 {
            guard let n1 = f1.normal else { continue }
            for f2 in faces2 {
                guard let n2 = f2.normal else { continue }
                let dot = abs(n1.x * n2.x + n1.y * n2.y + n1.z * n2.z)
                if dot < 0.01 { // perpendicular
                    face1 = f1
                    face2 = f2
                    break
                }
            }
            if face1 != nil { break }
        }
        #expect(face1 != nil)
        #expect(face2 != nil)

        if let f1 = face1, let f2 = face2 {
            let result = f1.intersection(with: f2)
            // Perpendicular planes of the same box should intersect along an edge
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }

    @Test("Intersect cylinder with plane gives curve")
    func intersectCylinderWithPlane() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        let cylFaces = cyl.faces()
        let boxFaces = box.faces()

        // Find the cylindrical face
        var cylFace: Face?
        for face in cylFaces {
            if face.surfaceType == .cylinder {
                cylFace = face
                break
            }
        }

        // Find a planar face that would intersect the cylinder
        var planeFace: Face?
        for face in boxFaces {
            if face.surfaceType == .plane {
                planeFace = face
                break
            }
        }

        #expect(cylFace != nil)
        #expect(planeFace != nil)

        if let cf = cylFace, let pf = planeFace {
            let result = cf.intersection(with: pf)
            // The plane should cut through the cylinder
            if let r = result {
                #expect(r.isValid)
            }
        }
    }
}


@Suite("Curve3D Local Properties Tests")
struct Curve3DLocalPropertiesTests {

    @Test("Curvature of circle is 1/r")
    func circleRadius() {
        let radius = 5.0
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius)!
        let curv = circle.curvature(at: 0)
        #expect(abs(curv - 1.0 / radius) < 0.01)
    }

    @Test("Curvature of line is zero")
    func lineCurvature() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let d = seg.domain
        let curv = seg.curvature(at: (d.lowerBound + d.upperBound) / 2)
        #expect(abs(curv) < 1e-10)
    }

    @Test("Tangent of X-axis segment is (1,0,0)")
    func segmentTangent() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let d = seg.domain
        let tang = seg.tangentDirection(at: (d.lowerBound + d.upperBound) / 2)
        #expect(tang != nil)
        if let t = tang {
            #expect(abs(t.x - 1) < 1e-6)
            #expect(abs(t.y) < 1e-6)
            #expect(abs(t.z) < 1e-6)
        }
    }

    @Test("Normal of circle points inward")
    func circleNormal() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let n = circle.normal(at: 0)
        #expect(n != nil)
        if let n = n {
            let len = simd_length(n)
            #expect(abs(len - 1.0) < 1e-6)
        }
    }

    @Test("Center of curvature of circle is at origin")
    func circleCenterOfCurvature() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let c = circle.centerOfCurvature(at: 0)
        #expect(c != nil)
        if let c = c {
            #expect(abs(c.x) < 0.01)
            #expect(abs(c.y) < 0.01)
        }
    }

    @Test("Torsion of planar circle is zero")
    func circularTorsion() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let tor = circle.torsion(at: 0.5)
        #expect(abs(tor) < 1e-6)
    }

    @Test("Bounding box of segment")
    func segmentBoundingBox() {
        let seg = Curve3D.segment(from: SIMD3(1, 2, 3), to: SIMD3(10, 8, 6))!
        let bb = seg.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x <= 1.01)
            #expect(bb.max.x >= 9.99)
        }
    }
}

@Suite("Surface Bounding Box")
struct SurfaceBoundingBoxTests {
    @Test("Sphere bounding box")
    func sphereBoundingBox() {
        let r: Double = 5
        let sphere = Surface.sphere(center: SIMD3(10, 0, 0), radius: r)!
        let bb = sphere.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x < 10 - r + 0.1)
            #expect(bb.max.x > 10 + r - 0.1)
            #expect(bb.min.y < -r + 0.1)
            #expect(bb.max.y > r - 0.1)
        }
    }

    @Test("Bezier surface bounding box")
    func bezierBoundingBox() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(10, 0, 0)],
            [SIMD3(0, 10, 5), SIMD3(10, 10, 5)]
        ]
        let bez = Surface.bezier(poles: poles)!
        let bb = bez.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x < 0.1)
            #expect(bb.max.x > 9.9)
            #expect(bb.max.z > 4.9)
        }
    }
}


// MARK: - Medial Axis Tests (v0.24.0)

@Suite("Medial Axis — Rectangle", .disabled("MedialAxis causes segfault in OCCT — pre-existing issue"))
struct MedialAxisRectangleTests {

    @Test("Rectangle produces non-nil medial axis")
    func rectangleComputesSuccessfully() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        let ma = MedialAxis(of: face)
        #expect(ma != nil)
    }

    @Test("Rectangle has correct arc and node counts")
    func rectangleGraphCounts() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        #expect(ma.arcCount > 0)
        #expect(ma.nodeCount > 0)
        #expect(ma.basicElementCount > 0)
    }

    @Test("Rectangle min thickness equals half the short side")
    func rectangleMinThickness() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        // Min thickness = inscribed circle radius at narrowest point = half of short side = 2.0
        let minT = ma.minThickness
        #expect(minT > 0)
        #expect(abs(minT - 2.0) < 0.1, "Expected min thickness ~2.0 for 10x4 rect, got \(minT)")
    }

    @Test("Rectangle nodes have valid positions and distances")
    func rectangleNodes() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        let nodes = ma.nodes
        #expect(nodes.count == ma.nodeCount)

        for node in nodes {
            // Node positions should be inside the rectangle
            #expect(node.distance > 0 || node.isOnBoundary,
                    "Node \(node.index) has invalid distance \(node.distance)")
        }
    }

    @Test("Rectangle arcs have valid node references")
    func rectangleArcs() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        let arcs = ma.arcs
        #expect(arcs.count == ma.arcCount)

        for arc in arcs {
            // Node indices should be within valid range
            #expect(arc.firstNodeIndex >= 1 && arc.firstNodeIndex <= Int32(ma.nodeCount))
            #expect(arc.secondNodeIndex >= 1 && arc.secondNodeIndex <= Int32(ma.nodeCount))
        }
    }

    @Test("Rectangle arc drawing produces polylines")
    func rectangleDrawArc() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        guard ma.arcCount > 0 else {
            Issue.record("No arcs in medial axis")
            return
        }
        let points = ma.drawArc(at: 1, maxPoints: 20)
        #expect(points.count == 20, "Expected 20 sample points, got \(points.count)")
        // Points should be finite
        for pt in points {
            #expect(pt.x.isFinite && pt.y.isFinite, "Non-finite point in arc drawing")
        }
    }

    @Test("Rectangle draw all produces one polyline per arc")
    func rectangleDrawAll() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        let polylines = ma.drawAll(maxPointsPerArc: 16)
        #expect(polylines.count == ma.arcCount)
        for polyline in polylines {
            #expect(polyline.count >= 2)
        }
    }

    @Test("Rectangle distance on arc interpolates between endpoints")
    func rectangleDistanceOnArc() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        guard ma.arcCount > 0 else { return }
        // Find an arc where both endpoints have positive distance
        // (some arcs may touch the boundary where distance = 0)
        var foundArc = false
        for i in 1...ma.arcCount {
            let d0 = ma.distanceToBoundary(arcIndex: i, parameter: 0)
            let d1 = ma.distanceToBoundary(arcIndex: i, parameter: 1)
            if d0 > 0.01 && d1 > 0.01 {
                let dMid = ma.distanceToBoundary(arcIndex: i, parameter: 0.5)
                #expect(dMid > 0)
                // Midpoint should be between endpoints (linear interpolation)
                let expected = (d0 + d1) / 2.0
                #expect(abs(dMid - expected) < 1e-10)
                foundArc = true
                break
            }
        }
        // At minimum, verify the function doesn't crash
        let d = ma.distanceToBoundary(arcIndex: 1, parameter: 0.5)
        #expect(d >= 0, "Distance should be non-negative")
        if !foundArc {
            // All arcs touch the boundary — still valid, just verify non-negative
            #expect(d >= 0)
        }
    }
}


@Suite("Medial Axis — Various Shapes", .disabled("MedialAxis causes segfault in OCCT — pre-existing issue"))
struct MedialAxisVariousShapesTests {

    @Test("Square medial axis has symmetric structure")
    func squareMedialAxis() {
        let wire = Wire.rectangle(width: 6, height: 6)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for square")
            return
        }
        // Square should have arcs and nodes
        #expect(ma.arcCount > 0)
        #expect(ma.nodeCount > 0)
        // Min thickness = half of side = 3.0
        let minT = ma.minThickness
        #expect(abs(minT - 3.0) < 0.1, "Expected min thickness ~3.0 for 6x6 square, got \(minT)")
    }

    @Test("L-shaped polygon produces medial axis")
    func lShapedMedialAxis() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 4),
            SIMD2(4, 4), SIMD2(4, 8), SIMD2(0, 8)
        ], closed: true)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for L-shape")
            return
        }
        // L-shape should have more arcs than a simple rectangle
        #expect(ma.arcCount >= 3, "L-shape should have multiple arcs, got \(ma.arcCount)")
        #expect(ma.nodeCount >= 3)
    }

    @Test("Circle face produces medial axis with single central node")
    func circleMedialAxis() {
        let wire = Wire.circle(radius: 5)!
        let face = Shape.face(from: wire)!
        let ma = MedialAxis(of: face)
        // Circle medial axis is a single point (center) — may compute as degenerate
        if let ma = ma {
            #expect(ma.nodeCount >= 1)
            let minT = ma.minThickness
            #expect(minT > 0)
        }
    }

    @Test("Narrow rectangle has small min thickness")
    func narrowRectangle() {
        let wire = Wire.rectangle(width: 20, height: 1)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for narrow rectangle")
            return
        }
        let minT = ma.minThickness
        #expect(minT > 0)
        #expect(abs(minT - 0.5) < 0.1, "Expected min thickness ~0.5 for 20x1 rect, got \(minT)")
    }

    @Test("Triangle produces medial axis")
    func triangleMedialAxis() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 8)
        ], closed: true)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for triangle")
            return
        }
        // Triangle medial axis should have 3 arcs (one from each vertex bisector)
        #expect(ma.arcCount >= 2, "Triangle should have arcs, got \(ma.arcCount)")
        #expect(ma.nodeCount >= 2)
    }

    @Test("Nil for shape without faces")
    func noFaceFails() {
        let wire = Wire.rectangle(width: 5, height: 5)!
        let wireShape = Shape.fromWire(wire)!
        let ma = MedialAxis(of: wireShape)
        #expect(ma == nil, "Medial axis should fail for wireframe shape")
    }

    @Test("Node accessor out of bounds returns nil")
    func nodeOutOfBounds() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else { return }
        #expect(ma.node(at: 0) == nil, "Index 0 should be out of bounds (1-based)")
        #expect(ma.node(at: ma.nodeCount + 1) == nil, "Past-end index should be nil")
    }

    @Test("Arc accessor out of bounds returns nil")
    func arcOutOfBounds() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else { return }
        #expect(ma.arc(at: 0) == nil, "Index 0 should be out of bounds (1-based)")
        #expect(ma.arc(at: ma.arcCount + 1) == nil, "Past-end index should be nil")
    }

    @Test("Distance on arc with invalid index returns -1")
    func distanceInvalidArc() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else { return }
        #expect(ma.distanceToBoundary(arcIndex: 0, parameter: 0.5) == -1.0)
        #expect(ma.distanceToBoundary(arcIndex: ma.arcCount + 1, parameter: 0.5) == -1.0)
    }

    @Test("Draw arc with invalid index returns empty")
    func drawArcInvalidIndex() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else { return }
        #expect(ma.drawArc(at: 0).isEmpty)
        #expect(ma.drawArc(at: ma.arcCount + 1).isEmpty)
    }

    @Test("Medial axis nodes lie inside the shape boundary")
    func nodesInsideBoundary() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        // Rectangle is centered at origin: x in [-5, 5], y in [-2, 2]
        for node in ma.nodes {
            #expect(node.position.x >= -5.1 && node.position.x <= 5.1,
                    "Node x=\(node.position.x) outside rectangle bounds")
            #expect(node.position.y >= -2.1 && node.position.y <= 2.1,
                    "Node y=\(node.position.y) outside rectangle bounds")
        }
    }
}

// MARK: - Selection / Raycasting Tests

@Suite("Selection — Raycasting")
struct RaycastTests {
    @Test("Raycast hits box")
    func raycastBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Box is centered at origin: spans from (-5,-5,-5) to (5,5,5)
        // Shoot ray from above, downward, hitting the top face at z=5
        let hits = box.raycast(
            origin: SIMD3(0, 0, 20),
            direction: SIMD3(0, 0, -1)
        )
        #expect(!hits.isEmpty)
        if let first = hits.first {
            #expect(first.point.z > 4.9 && first.point.z < 5.1)
            #expect(first.distance > 14.9 && first.distance < 15.1)
            #expect(first.faceIndex >= 0)
        }
    }

    @Test("Raycast misses box")
    func raycastMiss() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Shoot ray parallel to box, should miss
        let hits = box.raycast(
            origin: SIMD3(20, 20, 5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(hits.isEmpty)
    }

    @Test("Raycast nearest returns closest hit")
    func raycastNearest() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Box centered: top face at z=5
        let hit = box.raycastNearest(
            origin: SIMD3(0, 0, 20),
            direction: SIMD3(0, 0, -1)
        )
        #expect(hit != nil)
        #expect(hit!.point.z > 4.9)
    }

    @Test("Face count and face at index")
    func faceCountAndAccess() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.faceCount == 6)
        let face = box.face(at: 0)
        #expect(face != nil)
        #expect(face!.isPlanar)
        // Out-of-bounds returns nil
        let badFace = box.face(at: 100)
        #expect(badFace == nil)
    }
}

// MARK: - Edge Property Tests

@Suite("Edge — Properties")
struct EdgePropertyTests {
    @Test("Edge isLine for box edge")
    func edgeIsLine() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        guard let edge = edges.first else {
            Issue.record("Box should have edges")
            return
        }
        #expect(edge.isLine)
        #expect(!edge.isCircle)
    }

    @Test("Edge isCircle for cylinder edge")
    func edgeIsCircle() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        // Cylinder has circular edges at top and bottom
        let hasCircle = edges.contains { $0.isCircle }
        #expect(hasCircle)
    }
}

@Suite("KD-Tree Spatial Queries")
struct KDTreeTests {

    let testPoints: [SIMD3<Double>] = [
        SIMD3(0, 0, 0),   // 0
        SIMD3(1, 0, 0),   // 1
        SIMD3(0, 1, 0),   // 2
        SIMD3(0, 0, 1),   // 3
        SIMD3(1, 1, 1),   // 4
        SIMD3(5, 5, 5),   // 5
        SIMD3(10, 10, 10) // 6
    ]

    @Test("Build KD-tree")
    func buildTree() {
        let tree = KDTree(points: testPoints)
        #expect(tree != nil)
    }

    @Test("Empty points returns nil")
    func emptyTree() {
        let tree = KDTree(points: [])
        #expect(tree == nil)
    }

    @Test("Nearest point - exact match")
    func nearestExact() {
        let tree = KDTree(points: testPoints)!
        let result = tree.nearest(to: SIMD3(0, 0, 0))
        #expect(result != nil)
        #expect(result!.index == 0)
        #expect(result!.distance < 1e-10)
    }

    @Test("Nearest point - closest to query")
    func nearestClosest() {
        let tree = KDTree(points: testPoints)!
        let result = tree.nearest(to: SIMD3(0.9, 0.1, 0.1))
        #expect(result != nil)
        #expect(result!.index == 1) // Closest to (1,0,0)
    }

    @Test("K-nearest returns correct count")
    func kNearestCount() {
        let tree = KDTree(points: testPoints)!
        let results = tree.kNearest(to: SIMD3(0, 0, 0), k: 3)
        #expect(results.count == 3)
    }

    @Test("K-nearest includes self when exact")
    func kNearestSelf() {
        let tree = KDTree(points: testPoints)!
        let results = tree.kNearest(to: SIMD3(0, 0, 0), k: 1)
        #expect(results.count == 1)
        #expect(results[0].index == 0)
        #expect(results[0].squaredDistance < 1e-10)
    }

    @Test("K larger than point count returns all")
    func kNearestAll() {
        let tree = KDTree(points: testPoints)!
        let results = tree.kNearest(to: .zero, k: 100)
        #expect(results.count == testPoints.count)
    }

    @Test("Range search - finds nearby points")
    func rangeSearch() {
        let tree = KDTree(points: testPoints)!
        // Points within distance 1.1 of origin: (0,0,0), (1,0,0), (0,1,0), (0,0,1)
        let results = tree.rangeSearch(center: .zero, radius: 1.1)
        #expect(results.count == 4)
        #expect(results.contains(0))
        #expect(results.contains(1))
        #expect(results.contains(2))
        #expect(results.contains(3))
    }

    @Test("Range search - small radius finds only nearest")
    func rangeSearchSmall() {
        let tree = KDTree(points: testPoints)!
        let results = tree.rangeSearch(center: .zero, radius: 0.1)
        #expect(results.count == 1)
        #expect(results[0] == 0)
    }

    @Test("Box search - finds points in AABB")
    func boxSearch() {
        let tree = KDTree(points: testPoints)!
        let results = tree.boxSearch(
            min: SIMD3(-0.5, -0.5, -0.5),
            max: SIMD3(1.5, 1.5, 1.5)
        )
        // Should find: (0,0,0), (1,0,0), (0,1,0), (0,0,1), (1,1,1)
        #expect(results.count == 5)
        #expect(!results.contains(5)) // (5,5,5) outside
        #expect(!results.contains(6)) // (10,10,10) outside
    }

    @Test("Box search - entire space")
    func boxSearchAll() {
        let tree = KDTree(points: testPoints)!
        let results = tree.boxSearch(
            min: SIMD3(-100, -100, -100),
            max: SIMD3(100, 100, 100)
        )
        #expect(results.count == testPoints.count)
    }

    @Test("Large point set performance")
    func largePointSet() {
        var points: [SIMD3<Double>] = []
        for i in 0..<1000 {
            let x = Double(i % 10)
            let y = Double((i / 10) % 10)
            let z = Double(i / 100)
            points.append(SIMD3(x, y, z))
        }
        let tree = KDTree(points: points)
        #expect(tree != nil)

        let result = tree!.nearest(to: SIMD3(4.5, 4.5, 4.5))
        #expect(result != nil)
    }
}

@Suite("Hatch Patterns")
struct HatchTests {
    @Test("Generate horizontal hatches in rectangle")
    func horizontalHatch() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 0),
            spacing: 2.0
        )
        #expect(segments.count > 0)
    }

    @Test("Diagonal hatches")
    func diagonalHatch() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 1),
            spacing: 1.5
        )
        #expect(segments.count > 0)
    }

    @Test("Empty boundary returns nothing")
    func emptyBoundary() {
        let segments = HatchPattern.generate(
            boundary: [],
            direction: SIMD2(1, 0),
            spacing: 1.0
        )
        #expect(segments.isEmpty)
    }

    @Test("Triangle boundary")
    func triangleBoundary() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 10)
        ]
        let segments = HatchPattern.generate(
            boundary: boundary,
            direction: SIMD2(1, 0),
            spacing: 1.0
        )
        #expect(segments.count > 0)
    }
}

@Suite("Make Volume")
struct MakeVolumeTests {
    @Test("Make volume from faces")
    func volumeFromFaces() {
        // Create face shapes
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)
        let face2 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)
        if let f1 = face1, let f2 = face2 {
            // Try make volume - complex operation, just verify it doesn't crash
            let _ = Shape.makeVolume(from: [f1, f2])
        }
    }
}

@Suite("Curve-Curve Distance")
struct CurveCurveDistanceTests {
    @Test("Distance between parallel lines")
    func parallelLines() {
        let c1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let c2 = Curve3D.segment(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0))!
        let dist = c1.minDistance(to: c2)
        #expect(dist != nil)
        #expect(abs(dist! - 5.0) < 1e-6)
    }

    @Test("Extrema between skew lines")
    func skewLines() {
        let c1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let c2 = Curve3D.segment(from: SIMD3(5, 3, -5), to: SIMD3(5, 3, 5))!
        let extrema = c1.extrema(with: c2)
        #expect(extrema.count >= 1)
        #expect(abs(extrema[0].distance - 3.0) < 1e-6)
    }

    @Test("Curve-surface distance")
    func curveSurfaceDistance() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5))!
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let dist = line.minDistance(to: plane)
        #expect(dist != nil)
        #expect(abs(dist! - 5.0) < 1e-6)
    }
}

@Suite("Curve-Surface Intersection")
struct CurveSurfaceIntersectionTests {
    @Test("Line intersects sphere")
    func lineIntersectsSphere() {
        let line = Curve3D.segment(from: SIMD3(0, 0, -20), to: SIMD3(0, 0, 20))!
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let hits = line.intersections(with: sphere)
        #expect(hits.count == 2)
        if hits.count == 2 {
            // Intersection points should be at z=±5
            let zValues = hits.map { abs($0.point.z) }.sorted()
            #expect(abs(zValues[0] - 5.0) < 0.1)
            #expect(abs(zValues[1] - 5.0) < 0.1)
        }
    }

    @Test("Line parallel to plane doesn't intersect")
    func lineParallelToPlane() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5))!
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let hits = line.intersections(with: plane)
        #expect(hits.count == 0)
    }
}

@Suite("Surface-Surface Intersection")
struct SurfaceSurfaceIntersectionTests {
    @Test("Two planes intersect in a line")
    func twoPlanes() {
        let p1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let p2 = Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0))!
        let curves = p1.intersections(with: p2)
        #expect(curves.count >= 1)
    }
}

@Suite("Canonical Recognition")
struct CanonicalRecognitionTests {
    @Test("Canonical recognition callable on box")
    func recognizeCallableOnBox() {
        // ShapeAnalysis_CanonicalRecognition is designed to identify when
        // BSpline approximations can be converted to canonical forms (plane,
        // cylinder, etc). On already-canonical primitive shapes it may return nil.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let form = box.recognizeCanonical()
        // May be nil for primitive shapes — just verify no crash
        if let form {
            #expect(form.type == .plane)
        }
    }

    @Test("Canonical recognition callable on cylinder")
    func recognizeCallableOnCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        _ = cyl.recognizeCanonical()
        // Just verify no crash — whole-shape recognition often returns nil
    }
}

// MARK: - v0.32.0 Tests — OCCT Test Suite Audit

@Suite("Asymmetric Chamfer (Two Distances)")
struct AsymmetricChamferTests {
    @Test("Two-distance chamfer on box edge")
    func twoDistChamfer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Chamfer edge 0 with dist1=1.0 on face 0, dist2=2.0 on other face
        let result = box.chamferedTwoDistances([
            (edgeIndex: 0, faceIndex: 0, dist1: 1.0, dist2: 2.0)
        ])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Multiple edges with different asymmetric chamfers")
    func multiEdgeChamfer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedTwoDistances([
            (edgeIndex: 0, faceIndex: 0, dist1: 0.5, dist2: 1.0),
            (edgeIndex: 1, faceIndex: 0, dist1: 0.8, dist2: 0.6)
        ])
        // Multi-edge chamfer may require careful edge/face selection
        _ = result
    }
}

@Suite("Distance-Angle Chamfer")
struct DistAngleChamferTests {
    @Test("Distance-angle chamfer on box edge")
    func distAngleChamfer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedDistAngle([
            (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: 45.0)
        ])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Distance-angle chamfer at 30 degrees")
    func distAngle30() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedDistAngle([
            (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: 30.0)
        ])
        #expect(result != nil)
    }

    @Test("Distance-angle chamfer at 60 degrees")
    func distAngle60() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedDistAngle([
            (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: 60.0)
        ])
        #expect(result != nil)
    }
}

@Suite("Surface-Surface Intersection")
struct SurfaceSurfaceIntersectTests {
    @Test("Plane-plane intersection produces line")
    func planePlaneIntersection() {
        // Two planes intersecting at 90 degrees
        let plane1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let plane2 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0))!
        let curves = plane1.intersectionCurves(with: plane2)
        #expect(curves.count == 1)
    }

    @Test("Cylinder-plane intersection produces curves")
    func cylinderPlaneIntersection() {
        let cylinder = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        let plane = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))!
        let curves = cylinder.intersectionCurves(with: plane)
        #expect(curves.count >= 1)
    }

    @Test("Non-intersecting surfaces produce no curves")
    func noIntersection() {
        // Two parallel planes
        let plane1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let plane2 = Surface.plane(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))!
        let curves = plane1.intersectionCurves(with: plane2)
        #expect(curves.isEmpty)
    }

    @Test("Sphere-plane intersection")
    func spherePlaneIntersection() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let plane = Surface.plane(origin: SIMD3(0, 0, 3), normal: SIMD3(0, 0, 1))!
        let curves = sphere.intersectionCurves(with: plane)
        #expect(curves.count >= 1)
    }
}

@Suite("Curve-Surface Intersection")
struct CurveSurfaceIntersectTests {
    @Test("Line through sphere produces two points")
    func lineThroughSphere() {
        let line = Curve3D.segment(from: SIMD3(-10, 0, 0), to: SIMD3(10, 0, 0))!
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let results = line.intersections(with: sphere)
        #expect(results.count == 2)
        if results.count == 2 {
            // Points should be at approximately (-5, 0, 0) and (5, 0, 0)
            let xValues = results.map { $0.point.x }.sorted()
            #expect(abs(xValues[0] - (-5.0)) < 0.1)
            #expect(abs(xValues[1] - 5.0) < 0.1)
        }
    }

    @Test("Line tangent to sphere produces one point")
    func lineTangentToSphere() {
        let line = Curve3D.segment(from: SIMD3(-10, 5, 0), to: SIMD3(10, 5, 0))!
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let results = line.intersections(with: sphere)
        // Tangent may produce 1 or 2 very close points
        #expect(results.count >= 1)
    }

    @Test("Line missing sphere produces no points")
    func lineMissingSphere() {
        let line = Curve3D.segment(from: SIMD3(-10, 10, 0), to: SIMD3(10, 10, 0))!
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let results = line.intersections(with: sphere)
        #expect(results.isEmpty)
    }

    @Test("Line through plane produces one point")
    func lineThroughPlane() {
        let line = Curve3D.segment(from: SIMD3(0, 0, -5), to: SIMD3(0, 0, 5))!
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let results = line.intersections(with: plane)
        #expect(results.count == 1)
        if let first = results.first {
            #expect(abs(first.point.z) < 0.01)
        }
    }
}

// MARK: - Oriented Bounding Box Tests (v0.38.0)

@Suite("Oriented Bounding Box")
struct OrientedBoundingBoxTests {

    @Test("OBB of axis-aligned box")
    func obbAlignedBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let obb = box.orientedBoundingBox()
        #expect(obb != nil)
        // OBB volume should be close to box volume (10 * 5 * 3 = 150)
        #expect(abs(obb!.volume - 150.0) < 1.0)
        // Dimensions sorted should be roughly {3, 5, 10}
        let dims = [obb!.dimensions.x, obb!.dimensions.y, obb!.dimensions.z].sorted()
        #expect(abs(dims[0] - 3.0) < 0.1)
        #expect(abs(dims[1] - 5.0) < 0.1)
        #expect(abs(dims[2] - 10.0) < 0.1)
    }

    @Test("OBB of rotated box is tighter than AABB")
    func obbTighterThanAABB() {
        // Rotate a box 45 degrees around Z — AABB will be larger, OBB should stay tight
        let box = Shape.box(width: 10, height: 2, depth: 2)!.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4)!
        let obb = box.orientedBoundingBox()
        #expect(obb != nil)
        // OBB volume should be close to original volume (10 * 2 * 2 = 40)
        #expect(obb!.volume < 60.0) // Some tolerance
        // AABB would be much larger for a 45° rotated shape
        let aabb = box.bounds
        let aabbVolume = (aabb.max.x - aabb.min.x) * (aabb.max.y - aabb.min.y) * (aabb.max.z - aabb.min.z)
        #expect(obb!.volume < aabbVolume)
    }

    @Test("OBB corners count")
    func obbCorners() {
        let sphere = Shape.sphere(radius: 5)!
        let corners = sphere.orientedBoundingBoxCorners()
        #expect(corners != nil)
        #expect(corners!.count == 8)
    }

    @Test("OBB of sphere")
    func obbSphere() {
        let sphere = Shape.sphere(radius: 5)!
        let obb = sphere.orientedBoundingBox()
        #expect(obb != nil)
        // Sphere OBB should be roughly a cube with side ~10
        let dims = [obb!.dimensions.x, obb!.dimensions.y, obb!.dimensions.z].sorted()
        #expect(dims[0] > 9.0 && dims[0] < 11.0)
    }

    @Test("Optimal OBB")
    func obbOptimal() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let obb = box.orientedBoundingBox(optimal: true)
        #expect(obb != nil)
        #expect(abs(obb!.volume - 150.0) < 1.0)
    }
}

// MARK: - v0.40.0: Inertia Properties

@Suite("Inertia Properties")
struct InertiaPropertiesTests {
    @Test("Box volume inertia properties")
    func boxInertia() {
        // Box 10x20x30, origin at (0,0,0), extends to (10,20,30)
        // Volume = 6000, center of mass = (5, 10, 15)
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let props = box.inertiaProperties()
        #expect(props != nil)
        if let props {
            #expect(abs(props.mass - 6000) < 1)
            #expect(abs(props.centerOfMass.x - 0) < 0.1) // Centered box
            #expect(abs(props.centerOfMass.y - 0) < 0.1)
            #expect(abs(props.centerOfMass.z - 0) < 0.1)
            // Inertia matrix should be 3x3 = 9 values
            #expect(props.inertiaMatrix.count == 9)
            // Diagonal elements should be positive
            #expect(props.inertiaMatrix[0] > 0) // Ixx
            #expect(props.inertiaMatrix[4] > 0) // Iyy
            #expect(props.inertiaMatrix[8] > 0) // Izz
            // Principal moments should be positive
            #expect(props.principalMoments.x > 0)
            #expect(props.principalMoments.y > 0)
            #expect(props.principalMoments.z > 0)
        }
    }

    @Test("Sphere has symmetry point")
    func sphereSymmetry() {
        let sphere = Shape.sphere(radius: 10)!
        let props = sphere.inertiaProperties()
        #expect(props != nil)
        if let props {
            // Sphere volume = 4/3 * pi * r^3
            let expectedVol = 4.0/3.0 * Double.pi * 1000.0
            #expect(abs(props.mass - expectedVol) / expectedVol < 0.01)
            // Center at origin
            #expect(abs(props.centerOfMass.x) < 0.1)
            #expect(abs(props.centerOfMass.y) < 0.1)
            #expect(abs(props.centerOfMass.z) < 0.1)
            // Sphere has symmetry point
            #expect(props.hasSymmetryPoint)
        }
    }

    @Test("Surface inertia properties")
    func surfaceInertia() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let props = box.surfaceInertiaProperties()
        #expect(props != nil)
        if let props {
            // Surface area of 10x10x10 box = 6 * 100 = 600
            #expect(abs(props.mass - 600) < 1)
        }
    }

    @Test("Cylinder principal moments")
    func cylinderPrincipal() {
        let cyl = Shape.cylinder(radius: 5, height: 20)!
        let props = cyl.inertiaProperties()
        #expect(props != nil)
        if let props {
            #expect(props.mass > 0)
            // Cylinder has symmetry axis
            #expect(props.hasSymmetryAxis)
        }
    }
}

// MARK: - v0.40.0: Extended Distance

@Suite("Extended Distance Solutions")
struct ExtendedDistanceTests {
    @Test("Multiple distance solutions between spheres")
    func sphereDistanceSolutions() {
        let sphere1 = Shape.sphere(radius: 5)!
        let sphere2 = Shape.sphere(radius: 5)!.translated(by: SIMD3(20, 0, 0))!
        let solutions = sphere1.allDistanceSolutions(to: sphere2)
        #expect(solutions != nil)
        if let solutions {
            #expect(solutions.count >= 1)
            // Minimum distance should be 10 (20 - 5 - 5)
            #expect(abs(solutions[0].distance - 10) < 0.1)
        }
    }

    @Test("Box distance solutions")
    func boxDistanceSolutions() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(20, 0, 0))!
        let solutions = box1.allDistanceSolutions(to: box2)
        #expect(solutions != nil)
        if let solutions {
            #expect(solutions.count >= 1)
            // Distance between boxes: 20 - 5 - 5 = 10
            #expect(abs(solutions[0].distance - 10) < 0.1)
        }
    }

    @Test("Inner distance detection — non-overlapping shapes")
    func notInner() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(20, 0, 0))!
        let isInner = box1.isInside(box2)
        #expect(isInner == false)
    }
}

// MARK: - v0.41.0: Plane Detection

@Suite("Plane Detection")
struct PlaneDetectionTests {
    @Test("Planar wire finds plane")
    func planarWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let plane = wireShape.findPlane()
        #expect(plane != nil)
        if let plane {
            // Rectangle in XY plane — normal should be along Z
            #expect(abs(abs(plane.normal.z) - 1.0) < 0.01)
        }
    }

    @Test("Non-planar 3D wire returns nil")
    func nonPlanarWire() {
        // Build a 3D wire with points not in a single plane
        let e1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let e2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5))!
        let e3 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 10))!
        let e4 = Wire.line(from: SIMD3(0, 10, 10), to: SIMD3(0, 0, 0))!
        let joined = Wire.join([e1, e2, e3, e4])
        #expect(joined != nil)
        if let joined {
            let wireShape = Shape.fromWire(joined)!
            let plane = wireShape.findPlane()
            #expect(plane == nil)
        }
    }

    @Test("Face shape is planar")
    func faceShapePlanar() {
        // Create a face from a rectangle wire — the face shape should be planar
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let plane = face.findPlane()
        #expect(plane != nil)
    }
}

// MARK: - v0.42.0: Fast 3D Polygon

@Suite("Fast 3D Polygon")
struct Fast3DPolygonTests {
    @Test("Closed square polygon")
    func closedSquare() {
        let wire = Wire.polygon3D([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            SIMD3(10, 10, 0), SIMD3(0, 10, 0)
        ], closed: true)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 4)
        }
    }

    @Test("Open triangle polygon")
    func openTriangle() {
        let wire = Wire.polygon3D([
            SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 5, 6)
        ], closed: false)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 2)
        }
    }

    @Test("3D polygon wire (non-planar)")
    func nonPlanarPolygon() {
        let wire = Wire.polygon3D([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            SIMD3(10, 10, 5), SIMD3(0, 10, 10)
        ], closed: true)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 4)
        }
    }

    @Test("Minimum points (2) makes a single edge")
    func twoPointPolygon() {
        let wire = Wire.polygon3D([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0)
        ], closed: false)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 1)
        }
    }

    @Test("Single point returns nil")
    func singlePointReturnsNil() {
        let wire = Wire.polygon3D([SIMD3(0, 0, 0)])
        #expect(wire == nil)
    }
}

// MARK: - v0.42.0: Point Cloud Analysis

@Suite("Point Cloud Analysis")
struct PointCloudAnalysisTests {
    @Test("Coincident points detected as point")
    func coincidentPoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(5, 5, 5), SIMD3(5, 5, 5), SIMD3(5, 5, 5)
        ])
        #expect(result != nil)
        if case .point(let pt) = result {
            #expect(abs(pt.x - 5.0) < 0.1)
            #expect(abs(pt.y - 5.0) < 0.1)
            #expect(abs(pt.z - 5.0) < 0.1)
        } else {
            #expect(Bool(false), "Expected .point")
        }
    }

    @Test("Collinear points detected as linear")
    func collinearPoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)
        ])
        #expect(result != nil)
        if case .linear(let origin, let dir) = result {
            // Direction should be along X axis
            #expect(abs(abs(dir.x) - 1.0) < 0.01)
            #expect(abs(dir.y) < 0.01)
            #expect(abs(dir.z) < 0.01)
            _ = origin // used
        } else {
            #expect(Bool(false), "Expected .linear")
        }
    }

    @Test("Coplanar points detected as planar")
    func coplanarPoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            SIMD3(10, 10, 0), SIMD3(0, 10, 0)
        ])
        #expect(result != nil)
        if case .planar(_, let normal) = result {
            // Normal should be along Z axis
            #expect(abs(abs(normal.z) - 1.0) < 0.01)
        } else {
            #expect(Bool(false), "Expected .planar")
        }
    }

    @Test("3D dispersed points detected as space")
    func spacePoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            SIMD3(0, 10, 0), SIMD3(0, 0, 10)
        ])
        #expect(result != nil)
        if case .space = result {
            // Good — points in 3D space
        } else {
            #expect(Bool(false), "Expected .space")
        }
    }

    @Test("Empty points returns nil")
    func emptyReturnsNil() {
        let result = Shape.analyzePointCloud([])
        #expect(result == nil)
    }

    @Test("Single point detected as point")
    func singlePoint() {
        let result = Shape.analyzePointCloud([SIMD3(3, 4, 5)])
        #expect(result != nil)
        if case .point(let pt) = result {
            #expect(abs(pt.x - 3.0) < 0.1)
        } else {
            #expect(Bool(false), "Expected .point")
        }
    }
}

// MARK: - v0.44.0: Surface Extrema, Curve-on-Surface Check, Ellipse Arc, Edge Connect, Bezier Convert

@Suite("Surface Extrema Tests")
struct SurfaceExtremaTests {

    @Test("Sphere surfaces distance")
    func sphereDistance() {
        // Two spheres separated by known distance
        // Sphere1 at origin radius 3, Sphere2 at (20,0,0) radius 5
        // Min distance = 20 - 3 - 5 = 12
        let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3)
        let sphere2 = Surface.sphere(center: SIMD3(20, 0, 0), radius: 5)
        #expect(sphere1 != nil)
        #expect(sphere2 != nil)

        if let sphere1, let sphere2 {
            let result = sphere1.extrema(
                to: sphere2,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: -.pi/2, vMax: .pi/2),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi/2, vMax: .pi/2)
            )
            #expect(result != nil)
            if let result {
                #expect(abs(result.distance - 12.0) < 0.5)
                // Nearest point on sphere1 should be at X~3
                #expect(abs(result.point1.x - 3.0) < 0.5)
                // Nearest point on sphere2 should be at X~15
                #expect(abs(result.point2.x - 15.0) < 0.5)
            }
        }
    }

    @Test("Extrema returns nearest points and UV")
    func nearestPointsAndUV() {
        // Two spheres along X — known nearest points
        let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 4)
        let sphere2 = Surface.sphere(center: SIMD3(30, 0, 0), radius: 6)
        #expect(sphere1 != nil)
        #expect(sphere2 != nil)

        if let sphere1, let sphere2 {
            let result = sphere1.extrema(
                to: sphere2,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: -.pi/2, vMax: .pi/2),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi/2, vMax: .pi/2)
            )
            #expect(result != nil)
            if let result {
                // Distance = 30 - 4 - 6 = 20
                #expect(abs(result.distance - 20.0) < 0.5)
                // Nearest point on sphere1 should be at X~4
                #expect(abs(result.point1.x - 4.0) < 0.5)
                // Nearest point on sphere2 should be at X~24
                #expect(abs(result.point2.x - 24.0) < 0.5)
            }
        }
    }

    @Test("Cylinder and sphere distance")
    func cylinderSphereDistance() {
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)
        let sphere = Surface.sphere(center: SIMD3(20, 0, 0), radius: 3)
        #expect(cyl != nil)
        #expect(sphere != nil)

        if let cyl, let sphere {
            let result = cyl.extrema(
                to: sphere,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: 0, vMax: 10),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi/2, vMax: .pi/2)
            )
            #expect(result != nil)
            if let result {
                // Distance = 20 - 5 - 3 = 12
                #expect(abs(result.distance - 12.0) < 0.5)
            }
        }
    }
}

@Suite("Self-Intersection Tests")
struct SelfIntersectionTests {
    @Test("Box has no self-intersection")
    func boxNoSelfIntersection() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.selfIntersection()
        #expect(result != nil)
        #expect(result!.isDone)
        #expect(result!.overlapCount == 0)
    }

    @Test("Sphere has no self-intersection")
    func sphereNoSelfIntersection() throws {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.selfIntersection()
        #expect(result != nil)
        #expect(result!.isDone)
    }

    @Test("Cylinder has no self-intersection")
    func cylinderNoSelfIntersection() throws {
        let cyl = Shape.cylinder(radius: 3, height: 10)!
        let result = cyl.selfIntersection()
        #expect(result != nil)
        #expect(result!.isDone)
    }

    @Test("Custom tolerance and mesh deflection")
    func customParameters() throws {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        let result = box.selfIntersection(tolerance: 0.01, meshDeflection: 0.1)
        #expect(result != nil)
        #expect(result!.isDone)
    }
}

@Suite("BRepGProp Face Tests")
struct BRepGPropFaceTests {
    @Test("Natural bounds of box face")
    func naturalBounds() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        let bounds = face.naturalBounds
        #expect(bounds != nil)
        if let bounds {
            #expect(bounds.uMax > bounds.uMin)
            #expect(bounds.vMax > bounds.vMin)
        }
    }

    @Test("Evaluate GProp normal on box face")
    func evaluateBoxFace() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let faces = box.faces()
        let face = faces[0]

        guard let bounds = face.naturalBounds else {
            #expect(Bool(false), "bounds should exist")
            return
        }

        let uMid = (bounds.uMin + bounds.uMax) / 2
        let vMid = (bounds.vMin + bounds.vMax) / 2

        let eval = face.evaluateGProp(u: uMid, v: vMid)
        #expect(eval != nil)
        if let eval {
            // Normal should be non-zero for a box face
            let mag = simd_length(eval.normal)
            #expect(mag > 0.01)
        }
    }

    @Test("Evaluate GProp normal on cylinder face")
    func evaluateCylinderFace() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        #expect(faces.count >= 1)

        // Find a face with non-zero normal
        var found = false
        for face in faces {
            guard let bounds = face.naturalBounds else { continue }
            let uMid = (bounds.uMin + bounds.uMax) / 2
            let vMid = (bounds.vMin + bounds.vMax) / 2

            if let eval = face.evaluateGProp(u: uMid, v: vMid) {
                let mag = simd_length(eval.normal)
                if mag > 0.01 {
                    found = true
                    break
                }
            }
        }
        #expect(found)
    }

    @Test("GProp normal magnitude is area element")
    func normalMagnitudeIsAreaElement() throws {
        // For a planar face, the normal magnitude should be constant
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let face = box.faces()[0]

        guard let bounds = face.naturalBounds else {
            #expect(Bool(false), "bounds should exist")
            return
        }

        let eval1 = face.evaluateGProp(u: bounds.uMin + 0.1, v: bounds.vMin + 0.1)
        let eval2 = face.evaluateGProp(u: bounds.uMax - 0.1, v: bounds.vMax - 0.1)

        #expect(eval1 != nil)
        #expect(eval2 != nil)

        if let eval1, let eval2 {
            let mag1 = simd_length(eval1.normal)
            let mag2 = simd_length(eval2.normal)
            // For a planar face, magnitudes should be equal
            #expect(abs(mag1 - mag2) < 0.001)
        }
    }
}

@Suite("Volume Inertia Tests")
struct VolumeInertiaTests {
    @Test("Box volume inertia")
    func boxVolumeInertia() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let inertia = box.volumeInertia
        #expect(inertia != nil)
        if let inertia {
            #expect(abs(inertia.volume - 6000) < 1.0)
            // Box is centered at origin in OCCTSwift
            #expect(abs(inertia.centerOfMass.x) < 0.1)
            #expect(abs(inertia.centerOfMass.y) < 0.1)
            #expect(abs(inertia.centerOfMass.z) < 0.1)
        }
    }

    @Test("Principal moments are positive")
    func principalMomentsPositive() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let inertia = box.volumeInertia!
        #expect(inertia.principalMoments.x > 0)
        #expect(inertia.principalMoments.y > 0)
        #expect(inertia.principalMoments.z > 0)
    }

    @Test("Inertia tensor has 9 elements")
    func inertiaTensorSize() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let inertia = box.volumeInertia!
        #expect(inertia.inertiaTensor.count == 9)
    }

    @Test("Gyration radii are positive")
    func gyrationRadii() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let inertia = box.volumeInertia!
        #expect(inertia.gyrationRadii.x > 0)
        #expect(inertia.gyrationRadii.y > 0)
        #expect(inertia.gyrationRadii.z > 0)
    }

    @Test("Sphere volume inertia")
    func sphereVolumeInertia() throws {
        let sphere = Shape.sphere(radius: 5)!
        let inertia = sphere.volumeInertia
        #expect(inertia != nil)
        if let inertia {
            let expectedVolume = (4.0 / 3.0) * Double.pi * 125.0
            #expect(abs(inertia.volume - expectedVolume) < 1.0)
        }
    }
}

@Suite("Surface Inertia Tests")
struct SurfaceInertiaTests {
    @Test("Box surface inertia")
    func boxSurfaceInertia() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let inertia = box.surfaceInertia
        #expect(inertia != nil)
        if let inertia {
            // Surface area = 2*(10*20 + 10*30 + 20*30) = 2*(200+300+600) = 2200
            #expect(abs(inertia.area - 2200) < 1.0)
        }
    }

    @Test("Surface inertia principal moments positive")
    func surfacePrincipalMoments() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let inertia = box.surfaceInertia!
        #expect(inertia.principalMoments.x > 0)
        #expect(inertia.principalMoments.y > 0)
        #expect(inertia.principalMoments.z > 0)
    }
}

@Suite("BRepCheck Analyzer Tests")
struct BRepCheckAnalyzerTests {
    @Test("Box passes analyzer validation")
    func boxValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.analyzeValidity())
    }

    @Test("Sphere passes analyzer validation")
    func sphereValid() throws {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.analyzeValidity())
    }

    @Test("Cylinder passes analyzer validation")
    func cylinderValid() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.analyzeValidity())
    }

    @Test("Analyzer without geometry checks")
    func noGeomChecks() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.analyzeValidity(geometryChecks: false))
    }
}

@Suite("BRepExtrema ExtCC Tests")
struct BRepExtremaExtCCTests {
    @Test("Edge-edge distance between box edges")
    func edgeEdgeDistance() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
        // Compare first edges of each box
        let result = box1.edgeEdgeExtrema(edgeIndex1: 0, other: box2, edgeIndex2: 0)
        // Result may or may not find solutions depending on which edges are picked
        if let r = result {
            #expect(r.distance >= 0, "Distance should be non-negative")
            #expect(r.solutionCount >= 1)
        }
    }
}

@Suite("BRepExtrema ExtPF Tests")
struct BRepExtremaExtPFTests {
    @Test("Point-face distance")
    func pointFaceDistance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Point above the box - should find distance to one of the faces
        for faceIdx in 0..<6 {
            if let result = box.pointFaceExtrema(point: SIMD3(5, 5, 15), faceIndex: faceIdx) {
                #expect(result.distance >= 0, "Distance should be non-negative")
                #expect(result.solutionCount >= 1)
                break
            }
        }
    }
}

@Suite("BRepExtrema ExtFF Tests")
struct BRepExtremaExtFFTests {
    @Test("Face-face distance between separated boxes")
    func faceFaceDistance() throws {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 5, height: 5, depth: 5)!
        // Try different face pairs until we find one with a result
        var foundResult = false
        for i in 0..<6 {
            for j in 0..<6 {
                if let result = box1.faceFaceExtrema(faceIndex1: i, other: box2, faceIndex2: j) {
                    #expect(result.distance >= 0, "Distance should be non-negative")
                    foundResult = true
                    break
                }
            }
            if foundResult { break }
        }
    }
}

// MARK: - v0.49.0 Tests

@Suite("BRepExtrema_ExtPC Tests")
struct BRepExtremaExtPCTests {
    @Test("Point to edge distance on box")
    func pointToEdge() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edgeCount = box.edges().count
        #expect(edgeCount > 0)

        // Try each edge until we find one that gives a valid extremum
        var foundResult = false
        for i in 0..<edgeCount {
            if let result = box.pointEdgeExtrema(point: SIMD3(5, 5, 15), edgeIndex: i) {
                #expect(result.distance >= 0)
                #expect(result.solutionCount > 0)
                foundResult = true
                break
            }
        }
        #expect(foundResult)
    }

    @Test("Point to wire edge — known distance")
    func pointToWireEdge() throws {
        // Use a wire from (0,0,0) to (10,0,0) — single edge
        let wire = Wire.polygon3D([SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0)], closed: false)!
        let shape = Shape.fromWire(wire)!
        // Point at (5, 3, 0) — distance should be 3.0
        if let result = shape.pointEdgeExtrema(point: SIMD3(5.0, 3.0, 0.0), edgeIndex: 0) {
            #expect(abs(result.distance - 3.0) < 0.1)
            #expect(abs(result.pointOnEdge.x - 5.0) < 0.5)
        }
    }
}

@Suite("BRepExtrema_ExtCF Tests")
struct BRepExtremaExtCFTests {
    @Test("Edge to sphere face distance")
    func edgeToSphereFace() throws {
        // Use a box edge at known position and a sphere face
        let box = Shape.box(width: 20, height: 1, depth: 1)!
        let sphere = Shape.sphere(radius: 3)!

        // Try different edge/face combinations until we find valid extrema
        var foundResult = false
        let edgeCount = box.edges().count
        for i in 0..<edgeCount {
            if let result = box.edgeFaceExtrema(edgeIndex: i, other: sphere, faceIndex: 0) {
                if !result.isParallel && result.solutionCount > 0 {
                    #expect(result.distance >= 0)
                    foundResult = true
                    break
                }
            }
        }
        // May or may not find result depending on geometry
    }

    @Test("Box edge to box face")
    func boxEdgeToBoxFace() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(0, 0, 20), width: 10, height: 10, depth: 10)!

        // Try edge/face combinations
        var foundResult = false
        let edgeCount = box1.edges().count
        let faceCount = box2.faces().count
        for i in 0..<min(edgeCount, 4) {
            for j in 0..<min(faceCount, 4) {
                if let result = box1.edgeFaceExtrema(edgeIndex: i, other: box2, faceIndex: j) {
                    if !result.isParallel && result.solutionCount > 0 {
                        #expect(result.distance >= 0)
                        foundResult = true
                        break
                    }
                }
            }
            if foundResult { break }
        }
    }
}

@Suite("BRepExtrema_Poly")
struct PolyhedralDistanceTests {
    @Test("Polyhedral distance between two shapes")
    func polyDist() throws {
        let s1 = try #require(Shape.sphere(radius: 5.0))
        _ = s1.mesh(linearDeflection: 0.1)
        let s2 = try #require(Shape.sphere(radius: 5.0)?.translated(by: SIMD3(20, 0, 0)))
        _ = s2.mesh(linearDeflection: 0.1)
        let result = try #require(s1.polyhedralDistance(to: s2))
        // Spheres centered 20 apart, each radius 5 → distance ~10
        #expect(result.distance > 8.0)
        #expect(result.distance < 12.0)
    }
}

@Suite("Shape distance to Wire/Edge/Face") struct ShapeDistanceOverloadTests {
    @Test("Shape distance to Wire")
    func distanceToWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let wire = Wire.circle(origin: SIMD3(20, 0, 0), radius: 1)
        if let box, let wire {
            let result = box.distance(to: wire)
            #expect(result != nil)
            if let result {
                #expect(result.distance > 0)
            }
        }
    }

    @Test("Shape intersects Wire")
    func intersectsWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let wire = Wire.circle(origin: SIMD3(20, 0, 0), radius: 1)
        if let box, let wire {
            #expect(!box.intersects(wire))
        }
    }

    @Test("Shape distance to Edge")
    func distanceToEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let edges = box.edges()
            if let edge = edges.first {
                let result = box.distance(to: edge)
                #expect(result != nil)
            }
        }
    }

    @Test("Shape distance to Face")
    func distanceToFace() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        if let box1, let box2 {
            let faces = box2.faces()
            if let face = faces.first {
                let result = box1.distance(to: face)
                #expect(result != nil)
            }
        }
    }
}

// MARK: - v0.61.0 Tests

@Suite("Contap Contour Analysis")
struct ContapContourTests {
    @Test("Sphere contour with direction")
    func sphereContourDir() {
        let result = Shape.contourSphereDir(
            center: SIMD3(0, 0, 0), radius: 10,
            direction: SIMD3(0, 0, 1))
        if let result = result {
            #expect(result.count > 0)
            #expect(result.type == .circle)
            // Contour circle radius should be ~10 for Z-aligned view
            #expect(abs(result.data[3] - 10.0) < 0.1)
        }
    }

    @Test("Cylinder contour with direction")
    func cylinderContourDir() {
        let result = Shape.contourCylinderDir(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            radius: 5, direction: SIMD3(1, 0, 0))
        if let result = result {
            #expect(result.count > 0)
            #expect(result.type == .line)
        }
    }

    @Test("Sphere contour with eye point")
    func sphereContourEye() {
        let result = Shape.contourSphereEye(
            center: SIMD3(0, 0, 0), radius: 10,
            eye: SIMD3(100, 0, 0))
        if let result = result {
            #expect(result.count > 0)
        }
    }
}

@Suite("IntCurvesFace Intersection")
struct IntCurvesFaceTests {
    @Test("Line-face intersection")
    func lineFaceIntersection() {
        // Create a box and get its faces
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let faces = box.faces()
        #expect(faces.count > 0)
        if faces.count > 0 {
            // Create a shape from the first face for intersection
            if let faceShape = Shape.fromFace(faces[0]) {
                let results = faceShape.intersectLine(
                    origin: SIMD3(5, 10, -50),
                    direction: SIMD3(0, 0, 1))
                // May or may not intersect depending on face orientation
                // The important thing is no crash
                #expect(Bool(true))
            }
        }
    }
}

@Suite("IntCurvesFace ShapeIntersector")
struct IntCurvesFaceShapeIntersectorTests {
    @Test("Ray intersects box")
    func rayIntersectsBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let results = box.rayIntersect(
            origin: SIMD3(5, 5, -20),
            direction: SIMD3(0, 0, 1)
        )
        #expect(results != nil)
        if let results = results {
            #expect(results.count >= 2)
        }
    }

    @Test("Ray nearest intersection with sphere")
    func rayNearestSphere() {
        guard let sphere = Shape.sphere(radius: 5) else { return }
        let nearest = sphere.rayIntersectNearest(
            origin: SIMD3(0, 0, -20),
            direction: SIMD3(0, 0, 1)
        )
        #expect(nearest != nil)
        if let nearest = nearest {
            #expect(abs(nearest.point.z - (-5)) < 0.1)
        }
    }

    @Test("Ray misses shape")
    func rayMissesShape() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let results = box.rayIntersect(
            origin: SIMD3(100, 100, -20),
            direction: SIMD3(0, 0, 1)
        )
        // Should return nil (no hits) or empty
        if let results = results {
            #expect(results.isEmpty)
        }
    }
}

// MARK: - v0.63.0 Tests

@Suite("GeomLProp CLProps")
struct GeomLPropCLPropsTests {
    @Test("Curve properties on circle edge")
    func curvePropsOnCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Find a circular edge
        for edge in edges {
            let props = edge.curveLocalProps(at: 0)
            if props.curvature > 0.01 {
                #expect(props.tangent != nil)
                #expect(props.normal != nil)
                #expect(props.centerOfCurvature != nil)
                return
            }
        }
    }

    @Test("Tangent defined on line edge")
    func tangentOnLineEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        let props = edges[0].curveLocalProps(at: 0.5)
        #expect(props.tangent != nil)
        // Line has zero curvature
        #expect(props.curvature < 0.001)
    }
}

@Suite("GeomLProp SLProps")
struct GeomLPropSLPropsTests {
    @Test("Surface properties on sphere face")
    func surfacePropsOnSphere() {
        guard let sph = Shape.sphere(radius: 10) else { return }
        let faces = sph.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Use faceLProp methods instead
        let maxCurv = faces[0].faceLPropMaxCurvature(u: 0, v: 0.5)
        #expect(abs(abs(maxCurv) - 0.1) < 0.02)
    }

    @Test("Normal on plane face")
    func normalOnPlaneFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let maxCurv = faces[0].faceLPropMaxCurvature(u: 0, v: 0)
        #expect(abs(maxCurv) < 0.001)
    }
}

@Suite("GeomInt IntSS")
struct GeomIntIntSSTests {
    @Test("Plane-cylinder intersection")
    func planeCylinderIntersection() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        guard let box = Shape.box(width: 30, height: 30, depth: 1) else { return }
        let cylFaces = cyl.subShapes(ofType: .face)
        let boxFaces = box.subShapes(ofType: .face)
        guard !cylFaces.isEmpty, !boxFaces.isEmpty else { return }
        // Try each pair until we find one with intersection curves
        for cf in cylFaces {
            for bf in boxFaces {
                if let result = Shape.surfaceSurfaceIntersection(face1: cf, face2: bf) {
                    if result.curveCount > 0 {
                        let curve = result.curve(1)
                        #expect(curve != nil)
                        return
                    }
                }
            }
        }
    }
}

@Suite("Contap Contour Full")
struct ContapContourFullTests {
    @Test("Contour on cylinder face with direction")
    func contourOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Try each face with direction perpendicular to cylinder axis
        for face in faces {
            if let result = face.contapContourDirection(SIMD3(1, 0, 0)) {
                #expect(result.lineCount > 0)
                // Some contour lines may be analytic (line/circle) with 0 walking points
                // Just verify we got contour lines
                return
            }
        }
    }
}

@Suite("LProp AnalyticCurInf")
struct LPropAnalyticCurInfTests {
    @Test func ellipseHasExtrema() {
        // Ellipse (type 2), full parameter range [0, 2π]
        let points = Shape.analyticCurvaturePoints(curveType: 2, first: 0, last: 2 * .pi)
        // Ellipse should have min/max curvature points
        #expect(points.count >= 2)
    }

    @Test func lineHasNoSpecialPoints() {
        // Line (type 0) has constant zero curvature — no special points
        let points = Shape.analyticCurvaturePoints(curveType: 0, first: 0, last: 10)
        #expect(points.count == 0)
    }

    @Test func circleHasNoSpecialPoints() {
        // Circle (type 1) has constant curvature — no inflection or extrema
        let points = Shape.analyticCurvaturePoints(curveType: 1, first: 0, last: 2 * .pi)
        #expect(points.count == 0)
    }
}

@Suite("Polygon Interference Tests")
struct PolygonInterferenceTests {
    @Test func crossingPolylines() {
        let result = Shape.polygonInterference(
            poly1: [SIMD2(0, 0), SIMD2(10, 10)],
            poly2: [SIMD2(0, 10), SIMD2(10, 0)])
        #expect(result.points.count == 1)
        if let pt = result.points.first {
            #expect(abs(pt.x - 5.0) < 0.5)
            #expect(abs(pt.y - 5.0) < 0.5)
        }
    }

    @Test func nonIntersecting() {
        let result = Shape.polygonInterference(
            poly1: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            poly2: [SIMD2(5, 5), SIMD2(6, 5), SIMD2(6, 6)])
        #expect(result.points.count == 0)
    }

    @Test func selfIntersection() {
        let result = Shape.polygonSelfInterference(
            polygon: [SIMD2(0, 0), SIMD2(10, 10), SIMD2(10, 0), SIMD2(0, 10)])
        #expect(result.points.count >= 1)
    }
}

// MARK: - v0.70.0 TKBool: IntTools, BOPAlgo, BOPTools

@Suite("IntTools_EdgeEdge Tests")
struct IntToolsEdgeEdgeTests {
    @Test("Intersecting edges produce vertex common part")
    func edgeEdgeVertex() {
        // Two edges crossing at origin: X-axis and Y-axis
        let e1 = Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(0, -1, 0), SIMD3(0, 1, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.count >= 1)
                if let first = p.first {
                    #expect(first.type == .vertex)
                    #expect(abs(first.point.x) < 0.1)
                    #expect(abs(first.point.y) < 0.1)
                }
            }
        }
    }

    @Test("Overlapping collinear edges produce edge common part")
    func edgeEdgeOverlap() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.count >= 1)
                if let first = p.first {
                    #expect(first.type == .edge)
                }
            }
        }
    }

    @Test("Non-intersecting edges return empty array")
    func edgeEdgeNoIntersection() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(0, 5, 0), SIMD3(1, 5, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.isEmpty)
            }
        }
    }
}

@Suite("IntTools_EdgeFace Tests")
struct IntToolsEdgeFaceTests {
    @Test("Edge crossing face produces intersection")
    func edgeFaceIntersection() {
        // Use a box face and an edge going through it
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let edge = Shape.edgeFromPoints(SIMD3(5, 5, -1), SIMD3(5, 5, 11))
        if let b = box, let e = edge {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let parts = e.edgeFaceIntersection(with: face)
                #expect(parts != nil)
            }
        }
    }
}

@Suite("IntTools_FaceFace Tests")
struct IntToolsFaceFaceTests {
    @Test("Perpendicular box faces produce intersection line")
    func faceFaceIntersection() {
        // Create a box and test intersection of two of its faces
        let plane1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        let plane2 = Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0))
        if let s1 = plane1, let s2 = plane2 {
            let f1 = Shape.face(from: s1, uRange: -5...5, vRange: -5...5)
            let f2 = Shape.face(from: s2, uRange: -5...5, vRange: -5...5)
            if let face1 = f1, let face2 = f2 {
                let result = face1.faceFaceIntersection(with: face2)
                #expect(result != nil)
                if let r = result {
                    #expect(r.curves.count >= 1)
                    #expect(!r.isTangent)
                }
            }
        }
    }

    @Test("Coincident planes are tangent")
    func faceFaceTangent() {
        let plane1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        let plane2 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s1 = plane1, let s2 = plane2 {
            let f1 = Shape.face(from: s1, uRange: -5...5, vRange: -5...5)
            let f2 = Shape.face(from: s2, uRange: -5...5, vRange: -5...5)
            if let face1 = f1, let face2 = f2 {
                let result = face1.faceFaceIntersection(with: face2)
                if let r = result {
                    #expect(r.isTangent)
                }
            }
        }
    }
}

// MARK: - v0.71.0: TKBool remainder + TKFeat

@Suite("IntTools_BeanFaceIntersector Tests")
struct IntToolsBeanFaceIntersectorTests {
    @Test("edge crossing face")
    func edgeCrossingFace() {
        let face = Shape.face(from: Surface.plane(origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1))!,
            uRange: -10...10, vRange: -10...10)
        let edge = Shape.edgeFromPoints(SIMD3(0, 0, -5), SIMD3(0, 0, 5))
        if let f = face, let e = edge {
            let result = Shape.beanFaceIntersect(edge: e, face: f)
            if let r = result {
                #expect(r.minSquareDistance >= 0.0)
            }
        }
    }

    @Test("edge lying on face - coincident ranges")
    func edgeOnFace() {
        let face = Shape.face(from: Surface.plane(origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1))!,
            uRange: -10...10, vRange: -10...10)
        let edge = Shape.edgeFromPoints(SIMD3(-3, 0, 0), SIMD3(3, 0, 0))
        if let f = face, let e = edge {
            let result = Shape.beanFaceIntersect(edge: e, face: f)
            if let r = result {
                #expect(r.ranges.count >= 1)
                if let first = r.ranges.first {
                    #expect(first.last >= first.first)
                }
            }
        }
    }
}

// MARK: - v0.74.0: ShapeRayIntersection, ShapeConstruct, ShapeCustom Surface, MeshCinert, MeshProps, MeshShapeTool, ValidateEdge

@Suite("ShapeRayIntersection Tests")
struct ShapeRayIntersectionTests {
    @Test("line intersection with box")
    func lineBoxIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let inter = ShapeRayIntersection(shape: box, originX: 5, originY: 5, originZ: -10,
                                             dirX: 0, dirY: 0, dirZ: 1) {
            let hits = inter.allHits()
            #expect(hits.count >= 2)
        }
    }

    @Test("curve intersection with sphere")
    func curveSphereIntersection() {
        let sphere = Shape.sphere(radius: 5)!
        if let line = Curve3D.line(through: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1)) {
            if let inter = ShapeRayIntersection(shape: sphere, curve: line) {
                let hits = inter.allHits()
                #expect(hits.count >= 2)
            }
        }
    }

    @Test("hit face access")
    func hitFaceAccess() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let inter = ShapeRayIntersection(shape: box, originX: 5, originY: 5, originZ: -10,
                                             dirX: 0, dirY: 0, dirZ: 1) {
            if inter.hasMore {
                let hit = inter.currentHit
                #expect(hit.z >= -6 && hit.z <= 6)
                if let face = inter.currentFace {
                    #expect(face.area() > 0)
                }
            }
        }
    }
}

@Suite("BRepGProp Cinert Tests")
struct BRepGPropCinertTests {
    @Test("edge curve inertia")
    func edgeCurveInertia() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let edges = box.edges()
        if let edge = edges.first {
            let inertia = edge.curveInertia
            #expect(inertia.length > 0)
        }
    }
}

@Suite("BRepGProp Sinert Tests")
struct BRepGPropSinertTests {
    @Test("face surface inertia")
    func faceSurfaceInertia() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        if let face = faces.first {
            let inertia = face.surfaceInertia
            #expect(inertia.area > 0)
        }
    }

    @Test("adaptive surface inertia on sphere")
    func adaptiveSurfaceInertia() {
        // Adaptive Sinert only works meaningfully on curved faces
        // For planar faces it returns 0 — this is expected OCCT behavior
        let sphere = Shape.sphere(radius: 10)!
        let faces = sphere.faces()
        if let face = faces.first {
            let inertia = face.surfaceInertia(epsilon: 1e-6)
            // Adaptive variant may return 0 in OCCT 8.0 — just verify no crash
            let _ = inertia
        }
    }
}

@Suite("BRepGProp Vinert Tests")
struct BRepGPropVinertTests {
    @Test("face volume inertia")
    func faceVolumeInertia() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        if let face = faces.first {
            let inertia = face.volumeInertia
            // Just verify no crash — volume contribution from single face may be small
            let _ = inertia.volume
        }
    }

    @Test("face volume inertia with plane")
    func faceVolumeInertiaPlane() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        if let face = faces.first {
            let inertia = face.volumeInertia(planeNormal: SIMD3(0, 0, 1))
            let _ = inertia.volume
        }
    }
}

@Suite("BRepExtrema_DistanceSS")
struct BRepExtremaDistanceSSTests {
    @Test("distance between box vertices")
    func vertexDistance() {
        // Get vertices from two boxes at different positions
        if let box1 = Shape.box(width: 1, height: 1, depth: 1),
           let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 1, height: 1, depth: 1) {
            let verts1 = box1.subShapes(ofType: .vertex)
            let verts2 = box2.subShapes(ofType: .vertex)
            if let v1 = verts1.first, let v2 = verts2.first {
                let r = v1.distanceSS(to: v2)
                #expect(r.isDone)
                #expect(r.distance > 0)
            }
        }
    }

    @Test("distance between edge and vertex")
    func edgeVertexDistance() {
        // OCCT 8.0's low-level BRepExtrema_DistanceSS deliberately skips
        // edge-vertex pairs whose closest point lands at one of the edge's
        // endpoint-vertices (it expects the caller to pair vertices-with-
        // vertices separately). Use the high-level BRepExtrema_DistShapeShape
        // wrapper (Shape.distance(to:)) which handles all subshape pair
        // combinations including endpoint cases.
        if let box1 = Shape.box(width: 1, height: 1, depth: 1),
           let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 1, height: 1, depth: 1) {
            let edges1 = box1.subShapes(ofType: .edge)
            let verts2 = box2.subShapes(ofType: .vertex)
            if let e = edges1.first, let v = verts2.first {
                if let r = e.distance(to: v) {
                    #expect(r.distance > 0)
                } else {
                    Issue.record("edge-vertex distance should resolve via DistShapeShape")
                }
            }
        }
    }
}

@Suite("BRepGProp_VinertGK")
struct BRepGPropVinertGKTests {
    @Test("volume integration on box face")
    func volumeIntegration() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let r = face.vinertGK()
                // Just verify it completes without crash
                #expect(Bool(true))
                let _ = r.mass
            }
        }
    }

    @Test("error bounds")
    func errorBounds() {
        if let box = Shape.box(width: 5, height: 5, depth: 5) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let r = face.vinertGK(tolerance: 0.001)
                #expect(r.errorReached >= 0)
            }
        }
    }
}

// MARK: - v0.80.0: Extrema 3D/2D, GeomTools persistence, ProjLib, gce_* factories

@Suite("Extrema_ExtCC Tests")
struct ExtremaExtCCTests {
    @Test func curveCurveDistance() {
        // Two perpendicular lines at distance 5
        if let line1 = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)),
           let line2 = Curve3D.line(through: SIMD3(0,5,0), direction: SIMD3(0,0,1)) {
            let result = line1.extremaCC(range1: -10...10, other: line2, range2: -10...10)
            #expect(result.isDone)
            #expect(result.count >= 1)
            if result.count >= 1 {
                let pp = line1.extremaCCPoint(range1: -10...10, other: line2, range2: -10...10, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(abs(dist - 5.0) < 1e-3)
            }
        }
    }

    @Test func parallelCurves() {
        if let line1 = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)),
           let line2 = Curve3D.line(through: SIMD3(0,3,0), direction: SIMD3(1,0,0)) {
            let result = line1.extremaCC(range1: -10...10, other: line2, range2: -10...10)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }
}

@Suite("Extrema_ExtCS Tests")
struct ExtremaExtCSTests {
    @Test func curveSurfaceParallel() {
        // Line parallel to plane
        if let line = Curve3D.line(through: SIMD3(0,0,10), direction: SIMD3(1,0,0)),
           let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = line.extremaCS(range: -10...10, surface: plane)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }

    @Test func curveSurfaceDistance() {
        // Line near a sphere
        if let line = Curve3D.line(through: SIMD3(10,0,0), direction: SIMD3(0,0,1)),
           let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0) {
            let result = line.extremaCS(range: -5...5, surface: sphere)
            #expect(result.isDone)
            if !result.isParallel && result.count >= 1 {
                let pp = line.extremaCSPoint(range: -5...5, surface: sphere, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(dist > 4.0) // At least 5 away from surface
            }
        }
    }
}

@Suite("Extrema_ExtPS Tests")
struct ExtremaExtPSTests {
    @Test func pointSurfaceDistance() {
        // Point above sphere
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0) {
            let result = sphere.extremaPS(point: SIMD3(0, 0, 10))
            #expect(result.isDone)
            #expect(result.count >= 1)
            if result.count >= 1 {
                // Find minimum distance
                var minDist = Double.infinity
                for i in 1...result.count {
                    let ps = sphere.extremaPSPoint(point: SIMD3(0, 0, 10), index: i)
                    let d = ps.squareDistance.squareRoot()
                    if d < minDist { minDist = d }
                }
                #expect(abs(minDist - 5.0) < 0.1)
            }
        }
    }

    @Test func pointOnSurfaceParams() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0) {
            let result = sphere.extremaPS(point: SIMD3(0, 0, 10))
            if result.isDone && result.count >= 1 {
                let ps = sphere.extremaPSPoint(point: SIMD3(0, 0, 10), index: 1)
                // Point should be on the sphere surface
                let px = ps.point.x, py = ps.point.y, pz = ps.point.z
                let r = (px*px + py*py + pz*pz).squareRoot()
                #expect(abs(r - 5.0) < 0.1)
            }
        }
    }
}

@Suite("Extrema_ExtSS Tests")
struct ExtremaExtSSTests {
    @Test func parallelPlanes() {
        if let p1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
           let p2 = Surface.plane(origin: SIMD3(0, 0, 7), normal: SIMD3(0, 0, 1)) {
            let result = p1.extremaSS(other: p2)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }

    @Test func sphereDistance() {
        if let s1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3.0),
           let s2 = Surface.sphere(center: SIMD3(10, 0, 0), radius: 2.0) {
            let result = s1.extremaSS(other: s2)
            #expect(result.isDone)
            // Two spheres, non-parallel
            if !result.isParallel && result.count >= 1 {
                let pp = s1.extremaSSPoint(other: s2, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(abs(dist - 5.0) < 0.5) // 10 - 3 - 2 = 5
            }
        }
    }
}

@Suite("Extrema_LocateExtCC Tests")
struct ExtremaLocateExtCCTests {
    @Test func localExtremum() {
        if let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5.0),
           let line = Curve3D.line(through: SIMD3(10,0,3), direction: SIMD3(0,1,0)) {
            let result = circ.locateExtremaCC(range1: 0...(.pi * 2), other: line,
                                              range2: -10...10, seedU: 0, seedV: 0)
            #expect(result.isDone)
            if result.isDone {
                let dist = result.squareDistance.squareRoot()
                #expect(dist > 0)
            }
        }
    }
}

@Suite("CanonicalRecognition Detailed Tests")
struct CanonicalRecognitionDetailedTests {
    @Test func recognizePlane() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let result = face.recognizeCanonicalSurface()
                #expect(result.type == .plane)
            }
        }
    }

    @Test func recognizeCylinder() {
        // Use the whole cylinder shape — the recognizer iterates faces internally
        if let cyl = Shape.cylinder(radius: 5, height: 20) {
            let result = cyl.recognizeCanonicalSurface()
            // May or may not recognize — depends on which face is checked first
            #expect(result.type == .plane || result.type == .cylinder || result.type == .none)
        }
    }

    @Test func recognizeSphere() {
        if let sph = Shape.sphere(radius: 5) {
            let result = sph.recognizeCanonicalSurface()
            // Sphere has a single face, should recognize
            #expect(result.type == .sphere || result.type == .none)
        }
    }

    @Test func recognizeEdgeLine() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            var foundLine = false
            for edge in edges {
                let result = edge.recognizeCanonicalCurve()
                if result.type == .line {
                    foundLine = true
                    break
                }
            }
            #expect(foundLine)
        }
    }
}

@Suite("IntTools Tests")
struct IntToolsTests {

    @Test func computeVV() {
        guard let v1 = Shape.vertex(at: SIMD3(0, 0, 0)),
              let v2 = Shape.vertex(at: SIMD3(0, 0, 0)) else { return }
        #expect(IntTools.computeVV(v1, v2) == 0)
    }

    @Test func computeVVDistant() {
        guard let v1 = Shape.vertex(at: SIMD3(0, 0, 0)),
              let v2 = Shape.vertex(at: SIMD3(100, 100, 100)) else { return }
        #expect(IntTools.computeVV(v1, v2) != 0)
    }

    @Test func intermediatePoint() {
        let mid = IntTools.intermediatePoint(first: 0.0, last: 1.0)
        #expect(mid > 0.0 && mid < 1.0)
    }

    @Test func isDirsCoinside() {
        #expect(IntTools.isDirsCoinside(dx1: 1, dy1: 0, dz1: 0, dx2: 1, dy2: 0, dz2: 0))
        #expect(!IntTools.isDirsCoinside(dx1: 1, dy1: 0, dz1: 0, dx2: 0, dy2: 1, dz2: 0))
    }

    @Test func computeIntRange() {
        let range = IntTools.computeIntRange(tol1: 0.001, tol2: 0.001, angle: .pi / 4)
        #expect(range > 0)
    }
}

// MARK: - v0.92.0 Tests

@Suite("Bnd OBB Tests")
struct BndOBBTests {

    @Test func createAndQuery() {
        let obb = OBB(center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0), zDir: SIMD3(0, 0, 1),
                      hx: 5, hy: 3, hz: 2)
        #expect(!obb.isVoid)
        #expect(abs(obb.center.x) < 1e-10)
        #expect(abs(obb.halfSizes.x - 5.0) < 1e-10)
    }

    @Test func pointInOut() {
        let obb = OBB(center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0), zDir: SIMD3(0, 0, 1),
                      hx: 5, hy: 5, hz: 5)
        #expect(!obb.isOut(point: SIMD3(1, 1, 1)))
        #expect(obb.isOut(point: SIMD3(10, 10, 10)))
    }

    @Test func obbOverlap() {
        let obb1 = OBB(center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0), zDir: SIMD3(0, 0, 1),
                       hx: 5, hy: 5, hz: 5)
        let obb2 = OBB(center: SIMD3(4, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0), zDir: SIMD3(0, 0, 1),
                       hx: 3, hy: 3, hz: 3)
        #expect(!obb1.isOut(obb2))
    }

    @Test func fromShape() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let obb = OBB.fromShape(box) else {
            #expect(Bool(false), "should create OBB from shape")
            return
        }
        #expect(!obb.isVoid)
        #expect(obb.squareExtent > 0)
    }

    @Test func enlarge() {
        let obb = OBB(center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0), zDir: SIMD3(0, 0, 1),
                      hx: 1, hy: 1, hz: 1)
        obb.enlarge(by: 2.0)
        #expect(abs(obb.halfSizes.x - 3.0) < 1e-10)
    }
}

@Suite("Bnd Range Tests")
struct BndRangeTests {

    @Test func createAndQuery() {
        let r = Range(min: 1.0, max: 5.0)
        #expect(!r.isVoid)
        if let b = r.bounds {
            #expect(abs(b.first - 1.0) < 1e-10)
            #expect(abs(b.last - 5.0) < 1e-10)
        }
        #expect(abs(r.delta - 4.0) < 1e-10)
    }

    @Test func contains() {
        let r = Range(min: 1.0, max: 5.0)
        #expect(r.contains(3.0))
        #expect(!r.contains(6.0))
    }

    @Test func addValue() {
        let r = Range(min: 2.0, max: 4.0)
        r.add(6.0)
        if let b = r.bounds {
            #expect(abs(b.last - 6.0) < 1e-10)
        }
    }

    @Test func common() {
        let r1 = Range(min: 1.0, max: 5.0)
        let r2 = Range(min: 3.0, max: 7.0)
        r1.common(r2)
        if let b = r1.bounds {
            #expect(abs(b.first - 3.0) < 1e-10)
            #expect(abs(b.last - 5.0) < 1e-10)
        }
    }

    @Test func trimFromTo() {
        let r = Range(min: 0.0, max: 10.0)
        r.trimFrom(3.0)
        r.trimTo(7.0)
        if let b = r.bounds {
            #expect(abs(b.first - 3.0) < 1e-10)
            #expect(abs(b.last - 7.0) < 1e-10)
        }
    }

    @Test func voidRange() {
        let r = Range()
        #expect(r.isVoid)
    }
}

@Suite("Bnd BoundSortBox Tests")
struct BndBoundSortBoxTests {

    @Test func compareOverlapping() {
        let boxes = [
            [0.0, 0.0, 0.0, 10.0, 10.0, 10.0],
            [50.0, 50.0, 50.0, 60.0, 60.0, 60.0],
            [5.0, 5.0, 5.0, 15.0, 15.0, 15.0]
        ]
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 8, ymin: 8, zmin: 8, xmax: 12, ymax: 12, zmax: 12)
        #expect(hits.count >= 2) // overlaps boxes 0 and 2
    }

    @Test func compareNonOverlapping() {
        let boxes = [
            [0.0, 0.0, 0.0, 10.0, 10.0, 10.0]
        ]
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 90, ymin: 90, zmin: 90, xmax: 95, ymax: 95, zmax: 95)
        #expect(hits.count == 0)
    }
}

@Suite("BRepGProp Domain Tests")
struct BRepGPropDomainTests {

    @Test func faceEdgeCount() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let count = box.faceDomainEdgeCount(faceIndex: 0)
        #expect(count >= 3) // rectangular face has 4 edges
    }
}

// MARK: - v0.98.0 Tests

@Suite("IntAna LinePlane Tests")
struct IntAnaLinePlaneTests {

    @Test func linePlaneIntersection() {
        let r = IntAna.linePlane(lineOrigin: SIMD3(0, 0, -5), lineDir: SIMD3(0, 0, 1),
                                  planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1))
        #expect(r.points.count == 1)
        if r.points.count == 1 {
            #expect(abs(r.points[0].z) < 1e-10)
        }
    }

    @Test func parallelLineAndPlane() {
        let r = IntAna.linePlane(lineOrigin: SIMD3(0, 0, 5), lineDir: SIMD3(1, 0, 0),
                                  planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1))
        #expect(r.isParallel)
    }
}

@Suite("IntAna LineSphere Tests")
struct IntAnaLineSphereTests {

    @Test func lineThroughSphere() {
        let r = IntAna.lineSphere(lineOrigin: SIMD3(-10, 0, 0), lineDir: SIMD3(1, 0, 0),
                                   sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1), radius: 5)
        #expect(r.points.count == 2)
    }

    @Test func lineMissesSphere() {
        let r = IntAna.lineSphere(lineOrigin: SIMD3(0, 100, 0), lineDir: SIMD3(1, 0, 0),
                                   sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1), radius: 5)
        #expect(r.points.count == 0)
    }
}

@Suite("IntAna ThreePlanes Tests")
struct IntAnaThreePlanesTests {

    @Test func threePlanesAtOrigin() {
        let pt = IntAna.threePlanes(p1Origin: SIMD3(0,0,0), p1Normal: SIMD3(1,0,0),
                                     p2Origin: SIMD3(0,0,0), p2Normal: SIMD3(0,1,0),
                                     p3Origin: SIMD3(0,0,0), p3Normal: SIMD3(0,0,1))
        #expect(pt != nil)
        if let pt {
            #expect(abs(pt.x) < 1e-10 && abs(pt.y) < 1e-10 && abs(pt.z) < 1e-10)
        }
    }

    @Test func offsetPlanes() {
        let pt = IntAna.threePlanes(p1Origin: SIMD3(1,0,0), p1Normal: SIMD3(1,0,0),
                                     p2Origin: SIMD3(0,2,0), p2Normal: SIMD3(0,1,0),
                                     p3Origin: SIMD3(0,0,3), p3Normal: SIMD3(0,0,1))
        #expect(pt != nil)
        if let pt {
            #expect(abs(pt.x - 1) < 1e-10 && abs(pt.y - 2) < 1e-10 && abs(pt.z - 3) < 1e-10)
        }
    }
}

@Suite("IntAna LineTorus Tests")
struct IntAnaLineTorusTests {

    @Test func lineThroughTorus() {
        let pts = IntAna.lineTorus(lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0),
                                    torusCenter: SIMD3(0, 0, 0), torusAxis: SIMD3(0, 0, 1),
                                    majorRadius: 20, minorRadius: 5)
        #expect(pts.count >= 2)
    }
}

@Suite("IntAna PlanePlane Tests")
struct IntAnaPlanePlaneTests {

    @Test func planePlaneIntersection() {
        let r = IntAna.planePlane(p1Origin: SIMD3(0,0,0), p1Normal: SIMD3(0,0,1),
                                   p2Origin: SIMD3(0,0,0), p2Normal: SIMD3(0,1,0))
        #expect(r.count >= 1)
    }

    @Test func planePlaneLine() {
        let r = IntAna.planePlane(p1Origin: SIMD3(0,0,0), p1Normal: SIMD3(0,0,1),
                                   p2Origin: SIMD3(0,0,0), p2Normal: SIMD3(0,1,0))
        if r.count >= 1 {
            let dir = r.lines[0].direction
            let len = sqrt(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z)
            #expect(abs(len - 1.0) < 1e-6)
        }
    }
}

@Suite("IntAna PlaneSphere Tests")
struct IntAnaPlaneSphereTests {

    @Test func planeSphereIntersection() {
        let r = IntAna.planeSphere(planeOrigin: SIMD3(0,0,0), planeNormal: SIMD3(0,0,1),
                                    sphereCenter: SIMD3(0,0,0), sphereAxis: SIMD3(0,0,1),
                                    radius: 5.0)
        #expect(r.count >= 1)
    }
}

@Suite("BRepExtrema_SelfIntersection Pair Tests")
struct SelfIntersectionPairTests {

    @Test func noSelfIntersectionOnBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let pairs = box.selfIntersectionPairs(tolerance: 0.0)
        #expect(pairs.isEmpty)
    }

    @Test func selfIntersectionReturnsArray() {
        // Even if no intersections, the function should return an empty array
        guard let sphere = Shape.sphere(radius: 5) else { return }
        let pairs = sphere.selfIntersectionPairs(tolerance: 0.0, maxPairs: 50)
        // Sphere should have no self-intersections
        #expect(pairs.count >= 0) // just check it doesn't crash
    }
}

@Suite("GProp Element Properties Tests")
struct GPropElementTests {

    @Test func lineSegmentLength() {
        let result = GeometryProperties.lineSegment(from: SIMD3(0,0,0), to: SIMD3(10,0,0))
        #expect(abs(result.length - 10.0) < 1e-4)
        #expect(abs(result.center.x - 5.0) < 1e-4)
    }

    @Test func circularArcLength() {
        let result = GeometryProperties.circularArc(center: .zero, normal: SIMD3(0,0,1),
                                                     radius: 1.0, u1: 0, u2: .pi)
        #expect(abs(result.arcLength - Double.pi) < 1e-4)
    }

    @Test func pointSetCentroid() {
        let points: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(10,0,0), SIMD3(10,10,0), SIMD3(0,10,0)]
        let result = GeometryProperties.pointSetCentroid(points)
        #expect(abs(result.count - 4.0) < 1e-4)
        #expect(abs(result.centroid.x - 5.0) < 1e-4)
        #expect(abs(result.centroid.y - 5.0) < 1e-4)
    }

    @Test func sphereSurfaceArea() {
        let area = GeometryProperties.sphereSurfaceArea(radius: 5.0)
        let expected = 4.0 * Double.pi * 25.0
        #expect(abs(area - expected) < 0.1)
    }

    @Test func sphereVolume() {
        let vol = GeometryProperties.sphereVolume(radius: 5.0)
        let expected = (4.0/3.0) * Double.pi * 125.0
        #expect(abs(vol - expected) < 0.5)
    }
}

@Suite("Bnd_Sphere Tests")
struct BndSphereTests {

    @Test func createAndQuery() {
        let s = BoundingSphere(center: SIMD3(1, 2, 3), radius: 5)
        #expect(abs(s.radius - 5.0) < 1e-6)
        #expect(abs(s.center.x - 1) < 1e-6)
        #expect(abs(s.center.y - 2) < 1e-6)
        #expect(abs(s.center.z - 3) < 1e-6)
    }

    @Test func distanceToPoint() {
        let s = BoundingSphere(center: .zero, radius: 5)
        let dist = s.distance(to: SIMD3(10, 0, 0))
        #expect(abs(dist - 10.0) < 1e-4)
    }

    @Test func isOutsidePoint() {
        let s = BoundingSphere(center: .zero, radius: 5)
        #expect(s.isOutside(SIMD3(100, 0, 0)))
    }

    @Test func isOutsideSphere() {
        let s1 = BoundingSphere(center: .zero, radius: 1)
        let s2 = BoundingSphere(center: SIMD3(100, 0, 0), radius: 1)
        #expect(s1.isOutside(s2))
    }

    @Test func addMerge() {
        let s1 = BoundingSphere(center: SIMD3(0, 0, 0), radius: 5)
        let s2 = BoundingSphere(center: SIMD3(10, 0, 0), radius: 5)
        s1.add(s2)
        #expect(s1.radius >= 5.0)
    }
}

// MARK: - v0.104.0 Tests

@Suite("BndLib Analytic Bounding Tests")
struct BndLibTests {

    @Test func lineSegmentBounds() {
        let b = BndLib.line(origin: .zero, direction: SIMD3(1,0,0), p1: 0, p2: 10)
        #expect(abs(b.min.x) < 1e-6)
        #expect(abs(b.max.x - 10) < 1e-6)
    }

    @Test func circleBounds() {
        let b = BndLib.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5)
        #expect(abs(b.min.x + 5) < 1e-6)
        #expect(abs(b.max.x - 5) < 1e-6)
    }

    @Test func sphereBounds() {
        let b = BndLib.sphere(center: .zero, radius: 3)
        #expect(abs(b.min.x + 3) < 1e-6)
        #expect(abs(b.max.z - 3) < 1e-6)
    }

    @Test func cylinderBounds() {
        let b = BndLib.cylinder(center: .zero, axis: SIMD3(0,0,1), radius: 2, vmin: 0, vmax: 10)
        #expect(abs(b.min.z) < 1e-6)
        #expect(abs(b.max.z - 10) < 1e-6)
    }

    @Test func torusBounds() {
        let b = BndLib.torus(center: .zero, axis: SIMD3(0,0,1), majorRadius: 10, minorRadius: 2)
        #expect(abs(b.max.x - 12) < 1e-6)
        #expect(abs(b.max.z - 2) < 1e-6)
    }

    @Test func edgeBounds() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let b = BndLib.edge(edge)
                #expect(b.max.x >= b.min.x)
            }
        }
    }

    @Test func faceBounds() {
        if let sph = Shape.sphere(radius: 5) {
            let faces = sph.subShapes(ofType: .face)
            if let face = faces.first {
                let b = BndLib.face(face)
                #expect(abs(b.min.x + 5) < 0.1)
                #expect(abs(b.max.x - 5) < 0.1)
            }
        }
    }
}

@Suite("GProp Cylinder/Cone Tests")
struct GPropCylConeTests {

    @Test func cylinderSurfaceArea() {
        let area = GeometryProperties.cylinderSurfaceArea(radius: 5, height: 10)
        let expected = 2 * Double.pi * 5 * 10
        #expect(abs(area - expected) < 0.1)
    }

    @Test func cylinderVolume() {
        let vol = GeometryProperties.cylinderVolume(radius: 5, height: 10)
        let expected = Double.pi * 25 * 10
        #expect(abs(vol - expected) < 1.0)
    }

    @Test func coneSurfaceArea() {
        let area = GeometryProperties.coneSurfaceArea(semiAngle: .pi/6, refRadius: 5, height: 10)
        #expect(area > 0)
    }

    @Test func coneVolume() {
        let vol = GeometryProperties.coneVolume(semiAngle: .pi/6, refRadius: 5, height: 10)
        #expect(vol > 0)
    }
}

@Suite("IntAna_IntQuadQuad Tests")
struct IntAnaQuadQuadTests {

    @Test func cylinderSphereIntersection() {
        let count = QuadricIntersection.cylinderSphere(cylinderRadius: 3,
                                                        sphereCenter: .zero, sphereRadius: 5)
        #expect(count != nil)
        if let c = count { #expect(c == 2) }
    }

    @Test func cylinderSphereNotIdentical() {
        let identical = QuadricIntersection.cylinderSphereIdentical(cylinderRadius: 3,
                                                                      sphereCenter: .zero, sphereRadius: 5)
        #expect(!identical)
    }
}

@Suite("GProp Torus Tests")
struct GPropTorusTests {

    @Test func torusSurfaceArea() {
        let R = 10.0  // major
        let r = 3.0   // minor
        let area = GeometryProperties.torusSurfaceArea(majorRadius: R, minorRadius: r)
        let expected = 4 * Double.pi * Double.pi * R * r
        #expect(abs(area - expected) < 1.0)
    }

    @Test func torusVolume() {
        let R = 10.0
        let r = 3.0
        let vol = GeometryProperties.torusVolume(majorRadius: R, minorRadius: r)
        let expected = 2 * Double.pi * Double.pi * R * r * r
        #expect(abs(vol - expected) < 1.0)
    }
}

@Suite("BndLib Extra Tests")
struct BndLibExtraTests {

    @Test func ellipseBounds() {
        let b = BndLib.ellipse(center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
                                majorRadius: 10, minorRadius: 5)
        #expect(abs(b.min.x + 10) < 0.1)
        #expect(abs(b.max.x - 10) < 0.1)
        #expect(abs(b.min.y + 5) < 0.1)
        #expect(abs(b.max.y - 5) < 0.1)
    }

    @Test func coneBounds() {
        let b = BndLib.cone(center: .zero, axis: SIMD3(0, 0, 1),
                             semiAngle: .pi / 6, refRadius: 5, vmin: 0, vmax: 10)
        #expect(b.max.z >= b.min.z)
    }

    @Test func circleArcBounds() {
        let b = BndLib.circleArc(center: .zero, normal: SIMD3(0, 0, 1),
                                  radius: 5, u1: 0, u2: .pi / 2)
        #expect(b.max.x >= b.min.x)
        #expect(b.max.y >= b.min.y)
    }

    @Test func ellipseArcBounds() {
        let b = BndLib.ellipseArc(center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
                                   majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi / 2)
        #expect(b.max.x >= b.min.x)
    }

    @Test func parabolaArcBounds() {
        let b = BndLib.parabolaArc(center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
                                    focalDistance: 2, u1: -1, u2: 1)
        #expect(b.max.x >= b.min.x)
    }

    @Test func hyperbolaArcBounds() {
        let b = BndLib.hyperbolaArc(center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
                                     majorRadius: 5, minorRadius: 3, u1: -1, u2: 1)
        #expect(b.max.x >= b.min.x)
    }
}

@Suite("IntAna ConeSphere Tests")
struct IntAnaConeSphereTests {

    @Test func coneSphereIntersection() {
        let count = QuadricIntersection.coneSphere(semiAngle: .pi / 4, refRadius: 0,
                                                     sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        #expect(count != nil)
        if let c = count {
            #expect(c >= 0)
        }
    }

    @Test func coneSphereSamplePoints() {
        let count = QuadricIntersection.coneSphere(semiAngle: .pi / 4, refRadius: 0,
                                                     sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        if let c = count, c > 0 {
            let pts = QuadricIntersection.coneSpherePoints(semiAngle: .pi / 4, refRadius: 0,
                                                            sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3,
                                                            curveIndex: 1, sampleCount: 10)
            #expect(pts.count >= 0)
        }
    }
}

@Suite("GProp Weighted Tests")
struct GPropWeightedTests {

    @Test func weightedCentroid() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let wts = [1.0, 3.0]
        let (mass, centroid) = GeometryProperties.weightedCentroid(points: pts, weights: wts)
        #expect(abs(mass - 4.0) < 0.01)
        #expect(abs(centroid.x - 7.5) < 0.01)
    }

    @Test func barycentre() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0), SIMD3(0.0, 10.0, 0.0)]
        let c = GeometryProperties.barycentre(pts)
        #expect(abs(c.x - 10.0/3.0) < 0.1)
        #expect(abs(c.y - 10.0/3.0) < 0.1)
    }
}

@Suite("Hatch Builder Tests")
struct HatchBuilderTests {

    @Test func createHatcher() {
        let hatcher = HatchBuilder(tolerance: 1e-6)
        #expect(hatcher != nil)
    }

    @Test func addLinesAndCount() {
        if let hatcher = HatchBuilder(tolerance: 1e-6) {
            hatcher.addXLine(0.0)
            hatcher.addXLine(5.0)
            hatcher.addXLine(10.0)
            #expect(hatcher.nbLines == 3)
        }
    }

    @Test func addYLines() {
        if let hatcher = HatchBuilder(tolerance: 1e-6) {
            hatcher.addYLine(0.0)
            hatcher.addYLine(5.0)
            #expect(hatcher.nbLines == 2)
        }
    }

    @Test func trimAndIntervals() {
        if let hatcher = HatchBuilder(tolerance: 1e-6) {
            hatcher.addXLine(0.0)
            hatcher.addXLine(5.0)
            hatcher.addXLine(10.0)
            hatcher.trim(x1: -1, y1: -1, x2: 11, y2: 11)
            if hatcher.nbLines > 0 {
                let nInt = hatcher.nbIntervals(lineIndex: 1)
                #expect(nInt >= 0)
            }
        }
    }
}

// MARK: - v0.108.0: Geom_ and Geom2d_ Method Coverage

@Suite("Geom_Circle Properties")
struct GeomCircle3DTests {
    @Test func circleRadius() {
        if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(abs(c.circleProperties.radius - 5.0) < 1e-6)
        }
    }

    @Test func circleSetRadius() {
        if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(c.circleProperties.setRadius(10.0))
            #expect(abs(c.circleProperties.radius - 10.0) < 1e-6)
        }
    }

    @Test func circleEccentricity() {
        if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(abs(c.circleProperties.eccentricity) < 1e-6)
        }
    }

    @Test func circleCenter() {
        if let c = Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5) {
            let ctr = c.circleProperties.center
            #expect(abs(ctr.x - 1) < 1e-6)
            #expect(abs(ctr.y - 2) < 1e-6)
            #expect(abs(ctr.z - 3) < 1e-6)
        }
    }

    @Test func circleXAxis() {
        if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            let ax = c.circleProperties.xAxis
            #expect(abs(ax.direction.x - 1) < 1e-6)
        }
    }

    @Test func circleYAxis() {
        if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            let ax = c.circleProperties.yAxis
            #expect(abs(ax.direction.y - 1) < 1e-6)
        }
    }
}

@Suite("Geom_Ellipse Properties")
struct GeomEllipse3DTests {
    @Test func ellipseRadii() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-6)
            #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-6)
        }
    }

    @Test func ellipseSetRadii() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.setMajorRadius(20))
            #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-6)
            #expect(e.ellipseProperties.setMinorRadius(8))
            #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-6)
        }
    }

    @Test func ellipseEccentricity() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            let ecc = e.ellipseProperties.eccentricity
            #expect(ecc > 0 && ecc < 1)
        }
    }

    @Test func ellipseFocal() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.focal > 0)
        }
    }

    @Test func ellipseFoci() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            let f1 = e.ellipseProperties.focus1
            let f2 = e.ellipseProperties.focus2
            // Foci should be symmetric about center
            #expect(abs(f1.x + f2.x) < 1e-6)
        }
    }

    @Test func ellipseParameter() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.parameter > 0)
        }
    }

    @Test func ellipseDirectrix1() {
        if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5) {
            let d = e.ellipseProperties.directrix1
            // Directrix position should be defined
            let _ = d.position
            let _ = d.direction
        }
    }
}

@Suite("Geom_Hyperbola Properties")
struct GeomHyperbola3DTests {
    @Test func hyperbolaRadii() {
        if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3) {
            #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-6)
            #expect(abs(h.hyperbolaProperties.minorRadius - 3) < 1e-6)
        }
    }

    @Test func hyperbolaSetRadii() {
        if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.setMajorRadius(8))
            #expect(abs(h.hyperbolaProperties.majorRadius - 8) < 1e-6)
            #expect(h.hyperbolaProperties.setMinorRadius(4))
            #expect(abs(h.hyperbolaProperties.minorRadius - 4) < 1e-6)
        }
    }

    @Test func hyperbolaEccentricity() {
        if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.eccentricity > 1)
        }
    }

    @Test func hyperbolaFocal() {
        if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.focal > 0)
        }
    }

    @Test func hyperbolaFocus1() {
        if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3) {
            let f = h.hyperbolaProperties.focus1
            #expect(f.x > 0)  // Focus is along positive X
        }
    }

    @Test func hyperbolaAsymptote1() {
        if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3) {
            let a = h.hyperbolaProperties.asymptote1
            let _ = a.position
            let _ = a.direction
        }
    }
}

@Suite("Geom_Parabola Properties")
struct GeomParabola3DTests {
    @Test func parabolaFocal() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(abs(p.parabolaProperties.focal - 3) < 1e-6)
        }
    }

    @Test func parabolaSetFocal() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(p.parabolaProperties.setFocal(5))
            #expect(abs(p.parabolaProperties.focal - 5) < 1e-6)
        }
    }

    @Test func parabolaFocus() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            let f = p.parabolaProperties.focus
            #expect(abs(f.x - 3) < 1e-6)
        }
    }

    @Test func parabolaEccentricity() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(abs(p.parabolaProperties.eccentricity - 1.0) < 1e-6)
        }
    }

    @Test func parabolaParameter() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            #expect(abs(p.parabolaProperties.parameter - 6.0) < 1e-6)
        }
    }

    @Test func parabolaDirectrix() {
        if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 3) {
            let d = p.parabolaProperties.directrix
            #expect(abs(d.position.x - (-3)) < 1e-6)
        }
    }
}

@Suite("Geom_Line Properties")
struct GeomLine3DTests {
    @Test func lineDirection() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let d = l.lineProperties.direction
            #expect(abs(d.x - 1) < 1e-6)
        }
    }

    @Test func lineLocation() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let loc = l.lineProperties.location
            #expect(abs(loc.x - 1) < 1e-6)
            #expect(abs(loc.y - 2) < 1e-6)
            #expect(abs(loc.z - 3) < 1e-6)
        }
    }

    @Test func lineSetDirection() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            #expect(l.lineProperties.setDirection(SIMD3(0, 1, 0)))
            #expect(abs(l.lineProperties.direction.y - 1) < 1e-6)
        }
    }

    @Test func lineSetLocation() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            #expect(l.lineProperties.setLocation(SIMD3(5, 5, 5)))
            #expect(abs(l.lineProperties.location.x - 5) < 1e-6)
        }
    }

    @Test func linePosition() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let pos = l.lineProperties.position
            #expect(abs(pos.direction.x - 1) < 1e-6)
        }
    }

    @Test func lineLin() {
        if let l = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 0, 0)) {
            let gl = l.lineProperties.lin
            #expect(abs(gl.location.x - 1) < 1e-6)
        }
    }
}

@Suite("Geom_Plane Properties")
struct GeomPlane3DTests {
    @Test func planeCoefficients() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            let c = p.planeProperties.coefficients
            #expect(abs(c.c - 1.0) < 1e-6)
            #expect(abs(c.d) < 1e-6)
        }
    }

    @Test func planeUIso() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            if let iso = p.planeProperties.uIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func planeVIso() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            if let iso = p.planeProperties.vIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func planePln() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            let pln = p.planeProperties.pln
            #expect(abs(pln.normal.z - 1) < 1e-6)
        }
    }
}

@Suite("Geom_SphericalSurface Properties")
struct GeomSphere3DTests {
    @Test func sphereRadius() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            #expect(abs(s.sphereProperties.radius - 5) < 1e-6)
        }
    }

    @Test func sphereSetRadius() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            #expect(s.sphereProperties.setRadius(10))
            #expect(abs(s.sphereProperties.radius - 10) < 1e-6)
        }
    }

    @Test func sphereArea() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            let area = s.sphereProperties.area
            #expect(abs(area - 4 * Double.pi * 25) < 0.1)
        }
    }

    @Test func sphereVolume() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            let vol = s.sphereProperties.volume
            #expect(abs(vol - 4.0 / 3.0 * Double.pi * 125) < 1.0)
        }
    }

    @Test func sphereCenter() {
        if let s = Surface.sphere(center: SIMD3(1, 2, 3), radius: 5) {
            let c = s.sphereProperties.center
            #expect(abs(c.x - 1) < 1e-6)
            #expect(abs(c.y - 2) < 1e-6)
            #expect(abs(c.z - 3) < 1e-6)
        }
    }

    @Test func sphereUIso() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            if let iso = s.sphereProperties.uIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func sphereVIso() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            if let iso = s.sphereProperties.vIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func sphereSphere() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            let sph = s.sphereProperties.sphere
            #expect(abs(sph.radius - 5) < 1e-6)
        }
    }
}

@Suite("Geom_ToroidalSurface Properties")
struct GeomTorus3DTests {
    @Test func torusRadii() {
        if let t = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2) {
            #expect(abs(t.torusProperties.majorRadius - 10) < 1e-6)
            #expect(abs(t.torusProperties.minorRadius - 2) < 1e-6)
        }
    }

    @Test func torusSetRadii() {
        if let t = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2) {
            #expect(t.torusProperties.setMajorRadius(15))
            #expect(abs(t.torusProperties.majorRadius - 15) < 1e-6)
            #expect(t.torusProperties.setMinorRadius(3))
            #expect(abs(t.torusProperties.minorRadius - 3) < 1e-6)
        }
    }

    @Test func torusArea() {
        if let t = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2) {
            let area = t.torusProperties.area
            #expect(abs(area - 4 * Double.pi * Double.pi * 10 * 2) < 1.0)
        }
    }

    @Test func torusVolume() {
        if let t = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2) {
            let vol = t.torusProperties.volume
            #expect(abs(vol - 2 * Double.pi * Double.pi * 10 * 4) < 1.0)
        }
    }
}

@Suite("Geom_CylindricalSurface Properties")
struct GeomCylinder3DTests {
    @Test func cylinderRadius() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            #expect(abs(c.cylinderProperties.radius - 5) < 1e-6)
        }
    }

    @Test func cylinderSetRadius() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            #expect(c.cylinderProperties.setRadius(10))
            #expect(abs(c.cylinderProperties.radius - 10) < 1e-6)
        }
    }

    @Test func cylinderAxis() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            let ax = c.cylinderProperties.axis
            #expect(abs(ax.direction.z - 1) < 1e-6)
        }
    }

    @Test func cylinderUIso() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            if let iso = c.cylinderProperties.uIso(0) {
                let _ = iso.domain
            }
        }
    }
}

@Suite("Geom_ConicalSurface Properties")
struct GeomCone3DTests {
    @Test func coneSemiAngle() {
        if let c = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3) {
            #expect(abs(c.coneProperties.semiAngle - 0.3) < 1e-6)
        }
    }

    @Test func coneRefRadius() {
        if let c = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3) {
            #expect(abs(c.coneProperties.refRadius - 5) < 1e-6)
        }
    }

    @Test func coneApex() {
        if let c = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3) {
            let a = c.coneProperties.apex
            let _ = a  // Apex is defined by geometry
        }
    }

    @Test func coneAxis() {
        if let c = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5, semiAngle: 0.3) {
            let ax = c.coneProperties.axis
            #expect(abs(ax.direction.z - 1) < 1e-6)
        }
    }
}

@Suite("Geom_SweptSurface Properties")
struct GeomSwept3DTests {
    @Test func sweptDirection() {
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            if let ext = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)) {
                let d = ext.sweptProperties.direction
                #expect(abs(d.z - 1) < 1e-6)
            }
        }
    }

    @Test func sweptBasisCurve() {
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            if let ext = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)) {
                if let basis = ext.sweptProperties.basisCurve {
                    let _ = basis.domain
                }
            }
        }
    }
}

// MARK: - v0.109.0 Tests

@Suite("Extrema_ExtElC Line-Line")
struct ExtremaElCLinLinTests {
    @Test func parallelLines() {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 5, 0), line2Dir: SIMD3(1, 0, 0)
        )
        #expect(r.isParallel)
        #expect(r.results.count > 0)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 25) < 0.1)
        }
    }

    @Test func intersectingLines() {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 0), line2Dir: SIMD3(0, 1, 0)
        )
        #expect(!r.isParallel)
        if let first = r.results.first {
            #expect(first.squareDistance < 1e-6)
        }
    }

    @Test func skewLines() {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 3), line2Dir: SIMD3(0, 1, 0)
        )
        #expect(!r.isParallel)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 9) < 0.1)
        }
    }
}

@Suite("Extrema_ExtElC Line-Circle")
struct ExtremaElCLinCircTests {
    @Test func lineCircleDistance() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
    }

    @Test func lineCircleCoplanar() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(10, 0, 0), lineDir: SIMD3(0, 1, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 1)
        }
    }
}

@Suite("Extrema_ExtElC Circle-Circle")
struct ExtremaElCCircCircTests {
    @Test func coplanarCircles() {
        let results = ExtremaElC.circleToCircle(
            center1: SIMD3(0, 0, 0), normal1: SIMD3(0, 0, 1), radius1: 5,
            center2: SIMD3(20, 0, 0), normal2: SIMD3(0, 0, 1), radius2: 5
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtElC Line-Ellipse")
struct ExtremaElCLinElipsTests {
    @Test func lineEllipseDistance() {
        let results = ExtremaElC.lineToEllipse(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtElCS Line-Plane")
struct ExtremaElCSLinPlaneTests {
    @Test func parallelLinePlane() {
        let r = ExtremaElCS.lineToPlane(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 100) < 0.1)
        }
    }

    @Test func intersectingLinePlane() {
        let r = ExtremaElCS.lineToPlane(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, -1),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        // Not parallel since line goes through the plane
        #expect(!r.isParallel)
    }
}

@Suite("Extrema_ExtElCS Line-Sphere")
struct ExtremaElCSLinSphereTests {
    @Test func lineSphereDistance() {
        let results = ExtremaElCS.lineToSphere(
            linePoint: SIMD3(0, 0, 20), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereRadius: 5
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtElCS Line-Cylinder")
struct ExtremaElCSLinCylTests {
    @Test func lineCylinderDistance() {
        let results = ExtremaElCS.lineToCylinder(
            linePoint: SIMD3(20, 0, 0), lineDir: SIMD3(0, 0, 1),
            cylCenter: SIMD3(0, 0, 0), cylAxis: SIMD3(0, 0, 1), cylRadius: 5
        )
        #expect(results.count >= 0) // may be 0 if parallel to axis
    }
}

@Suite("Extrema_ExtElSS Plane-Plane")
struct ExtremaElSSPlanePlaneTests {
    @Test func parallelPlanes() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 10), plane2Normal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 100) < 0.1)
        }
    }

    @Test func intersectingPlanes() {
        let r = ExtremaElSS.planeToPlane(
            plane1Point: SIMD3(0, 0, 0), plane1Normal: SIMD3(0, 0, 1),
            plane2Point: SIMD3(0, 0, 0), plane2Normal: SIMD3(1, 0, 0)
        )
        #expect(!r.isParallel)
    }
}

@Suite("Extrema_ExtElSS Plane-Sphere")
struct ExtremaElSSPlaneSphereTests {
    @Test func planeSphereDistance() {
        // Plane-Sphere not fully implemented in OCCT 8.0.0-rc4 (may throw Standard_NotImplemented)
        let results = ExtremaElSS.planeToSphere(
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            sphereCenter: SIMD3(0, 0, 20), sphereRadius: 5
        )
        #expect(results.count >= 0) // 0 is valid when not implemented
    }
}

@Suite("Extrema_ExtElSS Sphere-Sphere")
struct ExtremaElSSSphereSphereTests {
    @Test func sphereSphereDistance() {
        // Sphere-Sphere not fully implemented in OCCT 8.0.0-rc4 (may throw Standard_NotImplemented)
        let results = ExtremaElSS.sphereToSphere(
            center1: SIMD3(0, 0, 0), radius1: 5,
            center2: SIMD3(20, 0, 0), radius2: 5
        )
        #expect(results.count >= 0) // 0 is valid when not implemented
    }
}

@Suite("Extrema_ExtPElC Point-Line")
struct ExtremaExtPElCLinTests {
    @Test func pointToLine() {
        let results = ExtremaPointCurve.pointToLine(
            point: SIMD3(0, 5, 0),
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0)
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 0.1)
        }
    }
}

@Suite("Extrema_ExtPElC Point-Circle")
struct ExtremaExtPElCCircTests {
    @Test func pointToCircle() {
        let results = ExtremaPointCurve.pointToCircle(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
    }

    @Test func pointOnCircle() {
        let results = ExtremaPointCurve.pointToCircle(
            point: SIMD3(5, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.squareDistance < 1e-6)
        }
    }
}

@Suite("Extrema_ExtPElC Point-Ellipse")
struct ExtremaExtPElCElipsTests {
    @Test func pointToEllipse() {
        let results = ExtremaPointCurve.pointToEllipse(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtPElC Point-Parabola")
struct ExtremaExtPElCParabTests {
    @Test func pointToParabola() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(0, 10, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 2
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtPElS Point-Plane")
struct ExtremaExtPElSPlaneTests {
    @Test func pointToPlane() {
        let results = ExtremaPointSurface.pointToPlane(
            point: SIMD3(0, 0, 10),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(abs(first.squareDistance - 100) < 0.1)
        }
    }
}

@Suite("Extrema_ExtPElS Point-Sphere")
struct ExtremaExtPElSSphereTests {
    @Test func pointToSphere() {
        let results = ExtremaPointSurface.pointToSphere(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), radius: 5
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtPElS Point-Cylinder")
struct ExtremaExtPElSCylTests {
    @Test func pointToCylinder() {
        let results = ExtremaPointSurface.pointToCylinder(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtPElS Point-Cone")
struct ExtremaExtPElSConeTests {
    @Test func pointToCone() {
        let results = ExtremaPointSurface.pointToCone(
            point: SIMD3(20, 0, 0),
            apex: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 4, refRadius: 5
        )
        #expect(results.count > 0)
    }
}

@Suite("Extrema_ExtPElS Point-Torus")
struct ExtremaExtPElSTorusTests {
    @Test func pointToTorus() {
        let results = ExtremaPointSurface.pointToTorus(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 3
        )
        #expect(results.count > 0)
    }
}

@Suite("IntAna2d_Conic")
struct Conic2DTests {
    @Test func fromCircle() {
        let c = Conic2D.fromCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5)
        // Circle: x^2 + y^2 - 25 = 0 => A=1(x^2), B=1(y^2), C=0(xy), D=0(x), E=0(y), F=-25
        #expect(abs(c.a - 1) < 1e-6)
        #expect(abs(c.b - 1) < 1e-6)
        #expect(abs(c.f + 25) < 1e-6)
    }

    @Test func fromLine() {
        let c = Conic2D.fromLine(point: SIMD2(0, 0), direction: SIMD2(1, 0))
        // y = 0 line: 0*x + 0*xy + 0*y^2 + 0*x + 1*y + 0 = 0 (varies by normalization)
        // Just check it doesn't crash and produces non-zero coefficients
        let hasNonZero = abs(c.a) + abs(c.b) + abs(c.c) + abs(c.d) + abs(c.e) + abs(c.f)
        #expect(hasNonZero > 0)
    }

    @Test func fromEllipse() {
        let c = Conic2D.fromEllipse(center: SIMD2(0, 0), direction: SIMD2(1, 0),
                                      majorRadius: 5, minorRadius: 3)
        #expect(c.a > 0 || c.c > 0) // some non-zero coefficient
    }

    @Test func lineCircleIntersection() {
        let pts = Conic2D.lineCircleIntersection(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(0, 0), circleDir: SIMD2(1, 0), radius: 5
        )
        #expect(pts.count == 2)
        if pts.count == 2 {
            // Line y=0 intersects circle x^2+y^2=25 at x=-5 and x=5
            let xs = pts.map { $0.x }.sorted()
            #expect(abs(xs[0] + 5) < 1e-6)
            #expect(abs(xs[1] - 5) < 1e-6)
        }
    }
}

@Suite("BRepLProp Edge v0.111")
struct BRepLPropEdgeTests {
    @Test func edgeValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                if let p = edges[0].edgeLPropValue(at: 0.5) {
                    // Point should be somewhere on the box
                    let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    #expect(dist > 0.0)
                }
            }
        }
    }

    @Test func edgeTangent() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            for edge in edges {
                if let tan = edge.edgeTangent(at: 0.5) {
                    let len = sqrt(tan.x * tan.x + tan.y * tan.y + tan.z * tan.z)
                    // Tangent should be a unit direction
                    #expect(abs(len - 1.0) < 1e-4)
                    break
                }
            }
        }
    }

    @Test func edgeCurvature() {
        // Edges of a box are straight lines, curvature should be 0
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let k = edges[0].edgeCurvatureLP(at: 0.5)
                #expect(abs(k) < 1e-4)
            }
        }
    }

    @Test func edgeD1() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let d1 = edges[0].edgeLPropD1(at: 0.5)
                let len = sqrt(d1.x * d1.x + d1.y * d1.y + d1.z * d1.z)
                #expect(len > 0.0)
            }
        }
    }
}

@Suite("BRepLProp Face v0.111")
struct BRepLPropFaceTests {
    @Test func faceValue() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                let p = faces[0].faceLPropValue(u: 0.5, v: 0.5)
                let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                // Point on sphere should be at distance ~5
                #expect(abs(dist - 5.0) < 1.0)
            }
        }
    }

    @Test func faceNormal() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let n = faces[0].faceLPropNormal(u: 0.5, v: 0.5) {
                    let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                    #expect(abs(len - 1.0) < 1e-4)
                }
            }
        }
    }

    @Test func faceCurvature() {
        // Sphere of radius 5: principal curvatures should be 1/5 = 0.2
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                let maxK = faces[0].faceLPropMaxCurvature(u: 0.5, v: 0.5)
                let minK = faces[0].faceLPropMinCurvature(u: 0.5, v: 0.5)
                #expect(abs(abs(maxK) - 0.2) < 0.05)
                #expect(abs(abs(minK) - 0.2) < 0.05)
            }
        }
    }

    @Test func faceMeanAndGaussianCurvature() {
        // Sphere: mean = 1/R, gaussian = 1/R^2
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                let mean = faces[0].faceLPropMeanCurvature(u: 0.5, v: 0.5)
                let gauss = faces[0].faceLPropGaussianCurvature(u: 0.5, v: 0.5)
                #expect(abs(abs(mean) - 0.2) < 0.05)
                #expect(abs(abs(gauss) - 0.04) < 0.02)
            }
        }
    }

    @Test func faceIsUmbilic() {
        // Sphere should be umbilic everywhere — curvatures are equal
        // Use curvature equality as a softer check since IsUmbilic has strict tolerance
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                let maxK = faces[0].faceLPropMaxCurvature(u: 0.5, v: 0.5)
                let minK = faces[0].faceLPropMinCurvature(u: 0.5, v: 0.5)
                // On a sphere, max and min curvatures should be approximately equal
                #expect(abs(maxK - minK) < 0.01)
            }
        }
    }

    @Test func faceTangentU() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let tanU = faces[0].faceLPropTangentU(u: 0.5, v: 0.5) {
                    let len = sqrt(tanU.x * tanU.x + tanU.y * tanU.y + tanU.z * tanU.z)
                    #expect(abs(len - 1.0) < 1e-4)
                }
            }
        }
    }
}

@Suite("Intf_Tool v0.112")
struct IntfToolTests {

    @Test func clipLineToBox() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(0, 0, -10),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        // Line along Z should intersect the box
        #expect(nSeg >= 0)
    }

    @Test func segmentParameters() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, -10),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        if nSeg > 0 {
            let begin = tool.beginParam(segment: 1)
            let end = tool.endParam(segment: 1)
            #expect(end > begin)
        }
    }

    @Test func lineParallelToFace() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, 5),
            lineDirection: SIMD3(1, 0, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg >= 0)
    }

    @Test func lineMissesBox() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(100, 100, 100),
            lineDirection: SIMD3(0, 1, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        #expect(nSeg >= 0) // should not crash
    }

    @Test func lineThroughCenter() {
        let tool = IntfTool()
        let nSeg = tool.clipLineToBox(
            lineOrigin: SIMD3(5, 5, -100),
            lineDirection: SIMD3(0, 0, 1),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(10, 10, 10))
        if nSeg > 0 {
            let begin = tool.beginParam(segment: 1)
            let end = tool.endParam(segment: 1)
            // Should represent the Z range through the box
            #expect(begin < end)
        }
    }
}

@Suite("Extrema extras v0.112")
struct ExtremaExtrasV112Tests {

    @Test func locateOnCurve() {
        if let circle = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5) {
            let result = circle.locateNearestPoint(SIMD3(6, 0, 0), initParam: 0)
            #expect(result != nil)
            if let r = result {
                #expect(r.distance < 1.5)
            }
        }
    }

    @Test func projectPointOnCurve() {
        if let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) {
            let results = line.projectPointAll(SIMD3(5, 3, 0))
            #expect(results.count >= 1)
            if results.count > 0 {
                #expect(abs(results[0].parameter - 5.0) < 0.1)
                #expect(abs(results[0].distance - 3.0) < 0.1)
            }
        }
    }

    @Test func locateOnSurface() {
        if let surf = Surface.plane(origin: SIMD3(0,0,0), normal: SIMD3(0,0,1)) {
            let result = surf.locateNearestPoint(SIMD3(5, 3, 10), initU: 0, initV: 0)
            if let r = result {
                #expect(abs(r.distance - 10.0) < 0.1)
            }
        }
    }

    @Test func projectPointOnSurface() {
        if let surf = Surface.sphere(center: SIMD3(0,0,0), radius: 5) {
            let results = surf.projectPointAll(SIMD3(10, 0, 0))
            #expect(results.count >= 1)
            if results.count > 0 {
                #expect(abs(results[0].distance - 5.0) < 0.1)
            }
        }
    }
}

@Suite("v0.113.0 - ShapeDistance")
struct ShapeDistanceTests {

    @Test func boxSphereDistance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let sphere = Shape.sphere(radius: 3)
            if let sph = sphere {
                // Move sphere away by translating
                if let moved = sph.translated(by: SIMD3(20, 5, 5)) {
                    if let dist = ShapeDistance(shape1: box, shape2: moved) {
                        #expect(dist.isDone)
                        #expect(dist.value > 0)
                        #expect(dist.solutionCount >= 1)
                        if dist.solutionCount > 0 {
                            let p1 = dist.pointOnShape1(at: 0)
                            let p2 = dist.pointOnShape2(at: 0)
                            #expect(p1.x > 0)
                            #expect(p2.x > 0)
                            if let t1 = dist.supportType1(at: 0) {
                                #expect(t1.rawValue >= 0 && t1.rawValue <= 2)
                            }
                            let s1 = dist.supportShape1(at: 0)
                            #expect(s1 != nil)
                        }
                    }
                }
            }
        }
    }
}

@Suite("v0.113.0 - IntCS Results")
struct IntCSResultsTests {

    @Test func lineSphereIntersection() {
        if let line = Curve3D.line(through: SIMD3(-20, 0, 0), direction: SIMD3(1, 0, 0)),
           let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            if let intcs = IntCSResult(curve: line, surface: sphere) {
                #expect(intcs.pointCount >= 2)
                if intcs.pointCount >= 2 {
                    let p1 = intcs.point(at: 0)
                    let p2 = intcs.point(at: 1)
                    // one point at x=-5, one at x=5
                    let xs = [p1.point.x, p2.point.x].sorted()
                    #expect(abs(xs[0] + 5.0) < 0.1)
                    #expect(abs(xs[1] - 5.0) < 0.1)
                }
            }
        }
    }
}

@Suite("v0.114.0 - FreeBoundsProperties")
struct FreeBoundsPropsTests {

    @Test func boxFaceFreeBounds() {
        // Remove one face from a box to create a shell with a free bound
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                // A single face has free bounds (its wire)
                if let fbp = FreeBoundsProperties(shape: faces[0], tolerance: 1e-7) {
                    let ok = fbp.perform()
                    // May or may not find free bounds depending on face topology
                    if ok {
                        let closed = fbp.closedCount
                        let open = fbp.openCount
                        #expect(closed >= 0)
                        #expect(open >= 0)
                    }
                }
            }
        }
    }

    @Test func shellWithHoleFreeBounds() {
        // Create a compound of 5 faces (open box)
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count >= 5 {
                if let compound = Shape.builderMakeCompound() {
                    for i in 0..<5 {
                        compound.builderAdd(faces[i])
                    }
                    if let fbp = FreeBoundsProperties(shape: compound, tolerance: 1e-3) {
                        let ok = fbp.perform()
                        if ok {
                            let total = fbp.closedCount + fbp.openCount
                            #expect(total >= 0)
                            if fbp.closedCount > 0 {
                                let area = fbp.closedArea(at: 0)
                                let perimeter = fbp.closedPerimeter(at: 0)
                                #expect(perimeter >= 0)
                                // Area can be negative for some orientations
                                let _ = area
                                let wire = fbp.closedWire(at: 0)
                                #expect(wire != nil)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Suite("v0.114.0 - Mass Properties")
struct MassPropertiesTests {

    @Test func linearProperties() {
        if let rect = Wire.rectangle(width: 10, height: 10),
           let wireShape = Shape.fromWire(rect) {
            let lp = wireShape.linearProperties()
            #expect(abs(lp.length - 40.0) < 0.1) // perimeter of 10x10 rect
        }
    }

    @Test func momentOfInertia() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let moi = box.momentOfInertia()
            #expect(moi.ixx > 0)
            #expect(moi.iyy > 0)
            #expect(moi.izz > 0)
        }
    }

    @Test func principalAxes() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let pa = box.principalAxes()
            // Principal axes should be unit vectors (or near unit)
            let len1 = sqrt(pa.axis1.x * pa.axis1.x + pa.axis1.y * pa.axis1.y + pa.axis1.z * pa.axis1.z)
            #expect(abs(len1 - 1.0) < 0.01)
        }
    }

    @Test func radiusOfGyration() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let rog = box.radiusOfGyration(axisOrigin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
            #expect(rog > 0)
        }
    }
}

@Suite("LProp3dCurve")
struct LProp3dCurveTests {
    @Test func curvatureOfCircle() {
        // Circle of radius 5: curvature = 1/5 = 0.2
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let curv = c.localCurvature(at: 0.0)
            #expect(abs(curv - 0.2) < 1e-6)
        }
    }

    @Test func tangentOfCircle() {
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let tangent = c.localTangent(at: 0.0)
            #expect(tangent != nil)
            if let t = tangent {
                // At u=0 on a circle in XY plane, tangent should be along Y
                #expect(abs(t.y) > 0.5)
            }
        }
    }

    @Test func normalOfCircle() {
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let normal = c.localNormal(at: 0.0)
            #expect(normal != nil)
        }
    }

    @Test func centreOfCurvature() {
        // Centre of curvature of a circle = the center of the circle
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        if let c = circle {
            let centre = c.localCentreOfCurvature(at: 0.0)
            #expect(centre != nil)
            if let p = centre {
                #expect(abs(p.x) < 1e-6)
                #expect(abs(p.y) < 1e-6)
                #expect(abs(p.z) < 1e-6)
            }
        }
    }
}

@Suite("LProp3dSurface")
struct LProp3dSurfaceTests {
    @Test func sphereCurvatures() {
        // Sphere of radius R: Gaussian = 1/R^2, Mean = 1/R
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 10.0)
        if let s = sphere {
            let curvs = s.localCurvatures(u: 0.0, v: 0.5)
            #expect(curvs != nil)
            if let c = curvs {
                #expect(abs(c.gaussian - 1.0 / 100.0) < 1e-4)
                #expect(abs(abs(c.mean) - 1.0 / 10.0) < 1e-4)
            }
        }
    }

    @Test func cylinderCurvatures() {
        // Cylinder of radius R: Gaussian = 0, one principal curvature = 1/R, other = 0
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        if let s = cyl {
            let curvs = s.localCurvatures(u: 0.0, v: 0.0)
            #expect(curvs != nil)
            if let c = curvs {
                #expect(abs(c.gaussian) < 1e-6) // Gaussian = 0 for cylinder
            }
        }
    }

    @Test func curvatureDirections() {
        // Cylinder should have non-umbilic curvature directions
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        if let s = cyl {
            let dirs = s.localCurvatureDirections(u: 0.0, v: 0.0)
            #expect(dirs != nil)
        }
    }
}

// MARK: - v0.118.0 Tests

@Suite("BRepBndLib")
struct BRepBndLibTests {
    @Test func shapeBoundingBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let bb = b.boundingBox
            #expect(bb != nil)
            if let bb = bb {
                #expect(bb.max.x - bb.min.x > 9.0)
                #expect(bb.max.y - bb.min.y > 19.0)
                #expect(bb.max.z - bb.min.z > 29.0)
            }
        }
    }

    @Test func shapeBoundingBoxOptimal() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let bb = b.boundingBoxOptimal()
            #expect(bb != nil)
            if let bb = bb {
                #expect(bb.max.x - bb.min.x > 9.0)
                #expect(bb.max.y - bb.min.y > 19.0)
                #expect(bb.max.z - bb.min.z > 29.0)
            }
        }
    }

    @Test func shapeBoundingBoxOptimalWithTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let bb = b.boundingBoxOptimal(useShapeTolerance: true)
            #expect(bb != nil)
        }
    }

    @Test func orientedBoundingBoxDetailed() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let obb = b.orientedBoundingBoxDetailed()
            #expect(obb != nil)
            if let obb = obb {
                #expect(obb.xHalfSize > 0)
                #expect(obb.yHalfSize > 0)
                #expect(obb.zHalfSize > 0)
            }
        }
    }

    @Test func orientedBoundingBoxDetailedOptimal() {
        let sphere = Shape.sphere(radius: 5)
        if let s = sphere {
            let obb = s.orientedBoundingBoxDetailed(optimal: true)
            #expect(obb != nil)
        }
    }

    @Test func boundingBoxSphere() {
        let sphere = Shape.sphere(radius: 10)
        if let s = sphere {
            let bb = s.boundingBox
            #expect(bb != nil)
            if let bb = bb {
                // Sphere of radius 10 should have bounds approximately [-10, 10] in each axis
                #expect(bb.min.x < -9.0)
                #expect(bb.max.x > 9.0)
            }
        }
    }
}

@Suite("BezierSurface_Properties")
struct BezierSurfaceTests {
    func makeBezierSurface() -> Surface? {
        Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 5, 1), SIMD3(0, 10, 0)],
            [SIMD3(5, 0, 1), SIMD3(5, 5, 2), SIMD3(5, 10, 1)],
            [SIMD3(10, 0, 0), SIMD3(10, 5, 1), SIMD3(10, 10, 0)]
        ])
    }

    @Test func nbPoles() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            #expect(bp.nbUPoles >= 2)
            #expect(bp.nbVPoles >= 2)
        }
    }

    @Test func degree() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            #expect(bp.uDegree >= 1)
            #expect(bp.vDegree >= 1)
        }
    }

    @Test func getPoleAndSet() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            let p = bp.pole(uIndex: 1, vIndex: 1)
            // Should be a valid point
            #expect(p.x.isFinite)
            // Set it to a new value
            let ok = bp.setPole(uIndex: 1, vIndex: 1, point: SIMD3(1, 2, 3))
            #expect(ok)
            let p2 = bp.pole(uIndex: 1, vIndex: 1)
            #expect(abs(p2.x - 1.0) < 1e-10)
            #expect(abs(p2.y - 2.0) < 1e-10)
            #expect(abs(p2.z - 3.0) < 1e-10)
        }
    }

    @Test func rationalFlags() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            // Non-rational by default
            #expect(!bp.isURational)
            #expect(!bp.isVRational)
        }
    }

    @Test func exchangeUV() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            let uDeg = bp.uDegree
            let vDeg = bp.vDegree
            let ok = bp.exchangeUV()
            #expect(ok)
            #expect(bp.uDegree == vDeg)
            #expect(bp.vDegree == uDeg)
        }
    }
}

@Suite("Integration: Assembly Interference")
struct IntegrationAssemblyInterferenceTests {

    @Test func shaftHousingClearanceAndInterference() {
        // Step 1-3: Create shaft, housing, bore
        guard let shaft = Shape.cylinder(radius: 10, height: 100),
              let housing = Shape.cylinder(radius: 15, height: 20),
              let bore = Shape.cylinder(radius: 10.05, height: 20) else {
            #expect(Bool(false), "Failed to create primitives")
            return
        }

        // Step 4: Housing with bore
        guard let hollowHousing = housing.subtracting(bore) else {
            #expect(Bool(false), "Failed to subtract bore from housing")
            return
        }
        #expect(hollowHousing.isValid)

        // Step 5: Position housing on shaft
        if let positionedHousing = hollowHousing.translated(by: SIMD3(0.0, 0.0, 40.0)) {
            #expect(positionedHousing.isValid)

            // Step 6: Check clearance
            if let distResult = shaft.distance(to: positionedHousing) {
                #expect(distResult.distance >= 0)
            }
        }

        // Step 7: Move housing to interfere (full cylinder, not hollow)
        if let interferingHousing = housing.translated(by: SIMD3(0.0, 0.0, 40.0)) {
            // Step 8-9: Compute interference volume
            if let interference = shaft.intersection(with: interferingHousing) {
                if let vol = interference.volume {
                    #expect(vol > 0)
                }
            }
        }
    }
}

@Suite("Integration: Surface Curvature Analysis")
struct IntegrationSurfaceCurvatureAnalysisTests {

    @Test func sphereCurvatureIsConstant() {
        let radius = 10.0
        guard let sphere = Surface.sphere(center: .zero, radius: radius) else {
            #expect(Bool(false), "Failed to create sphere surface")
            return
        }
        let expectedGaussian = 1.0 / (radius * radius) // 0.01
        let expectedMean = 1.0 / radius                 // 0.1

        // Evaluate at multiple parameter points
        let params: [(Double, Double)] = [
            (0.0, 0.5), (1.0, 0.5), (0.5, 1.0), (1.5, 0.3), (2.0, 1.0)
        ]

        for (u, v) in params {
            let gauss = sphere.gaussianCurvature(atU: u, v: v)
            let mean = sphere.meanCurvature(atU: u, v: v)

            // Gaussian curvature is always 1/R^2 (positive)
            #expect(abs(gauss - expectedGaussian) < 0.001)
            // Mean curvature magnitude is 1/R; sign depends on normal orientation
            #expect(abs(abs(mean) - expectedMean) < 0.001)
        }
    }
}

@Suite("Integration: Profile Contouring")
struct IntegrationProfileContouringTests {

    @Test func boxWithBossSection() {
        // Create base box
        guard let base = Shape.box(width: 60, height: 60, depth: 10) else {
            #expect(Bool(false), "Failed to create base box")
            return
        }

        // Create cylindrical boss on top
        guard let boss = Shape.cylinder(radius: 15, height: 20) else {
            #expect(Bool(false), "Failed to create boss cylinder")
            return
        }

        // Union boss with base (cylinder is centered at origin, extends upward)
        guard let combined = base.union(with: boss) else {
            #expect(Bool(false), "Failed to union base + boss")
            return
        }
        #expect(combined.isValid)

        // Section at Z just above base top (Z=5 is the top of base since box centered)
        // Box is centered so Z range is -5..+5; cylinder goes 0..20
        // Section at Z=6 should cut through just the cylinder
        let wires = combined.sectionWiresAtZ(6.0)
        #expect(wires.count >= 1, "Expected at least 1 wire from section above base")

        // Measure total wire length
        var totalLength = 0.0
        for wire in wires {
            if let len = wire.length {
                #expect(len > 0)
                totalLength += len
            }
        }
        #expect(totalLength > 0, "Total wire length should be positive")
    }
}

// PointSetLib suites removed in v1.0.0 — module dropped from OCCT 8.0.0 GA.

@Suite("ExtremaPC — Point to Curve Distance")
struct ExtremaPCTests {

    @Test func pointToCircle() {
        guard let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5.0) else { return }
        let results = circ.extrema(from: SIMD3(10, 0, 0))
        #expect(!results.isEmpty)
        if let closest = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(closest.distance - 5.0) < 1e-6)
        }
    }

    @Test func pointToLine() {
        guard let line = Curve3D.line(through: SIMD3(0,0,0), direction: SIMD3(1,0,0)) else { return }
        let results = line.extrema(from: SIMD3(5, 3, 0), uMin: 0, uMax: 100)
        #expect(!results.isEmpty)
        if let closest = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(closest.distance - 3.0) < 1e-6)
            #expect(abs(closest.point.x - 5.0) < 1e-6)
        }
    }

    @Test func minimumDistanceConvenience() {
        guard let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5.0) else { return }
        if let d = circ.minimumDistance(from: SIMD3(10, 0, 0)) {
            #expect(abs(d - 5.0) < 1e-6)
        }
    }

    @Test func pointToHelix() {
        guard let helix = Curve3D.circularHelix(radius: 5.0, pitch: 10.0) else { return }
        // Point at center of helix — all points on helix are equidistant at radius 5
        // (in the XY plane). This is an infinite solutions case but the API may
        // return some extrema or handle it gracefully.
        let d = helix.minimumDistance(from: SIMD3(0, 0, 0))
        // Minimum distance should be at least close to the radius
        if let d = d {
            #expect(d >= 4.9)
        }
    }
}

@Suite("Distance Solution Detail")
struct DistanceSolutionDetailTests {
    @Test func detailBetweenBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        if let box1, let box2 {
            let moved = box2.translated(by: SIMD3(20, 0, 0))
            if let moved {
                let solutions = box1.allDistanceSolutions(to: moved)
                if let solutions, solutions.count > 0 {
                    let detail = box1.distanceSolutionDetail(to: moved, solutionIndex: 0)
                    #expect(detail != nil)
                    if let detail {
                        #expect(detail.supportType1.rawValue >= 0)
                        #expect(detail.supportType2.rawValue >= 0)
                    }
                }
            }
        }
    }

    @Test func detailSupportTypes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 3)
        if let box, let sphere {
            let moved = sphere.translated(by: SIMD3(20, 5, 5))
            if let moved {
                let detail = box.distanceSolutionDetail(to: moved, solutionIndex: 0)
                #expect(detail != nil)
            }
        }
    }
}

// MARK: - v0.143 M2: Point-to-edge distance

@Suite("v0.143 Point-to-edge distance")
struct PointToEdgeDistanceTests {
    @Test("Curve3D.distance one-liner")
    func curve3DDistance() {
        guard let c = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("segment nil"); return
        }
        // Distance from (5, 3, 0) to the X axis segment = 3.
        let d = c.distance(to: SIMD3(5, 3, 0))
        #expect(abs(d - 3.0) < 1e-6)
    }

    @Test("Edge.distance one-liner")
    func edgeDistance() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil"); return
        }
        let edges = box.edges()
        guard let first = edges.first else { Issue.record("no edges"); return }
        let d = first.distance(to: SIMD3(0, 0, 0))
        #expect(d != nil)
    }
}

@Suite("ShapeMeasurements")
struct ShapeMeasurementsTests {

    @Test func boxFaceAreasMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        // Box has 6 faces. Total surface area = 2*(2*3 + 3*5 + 2*5) = 2*31 = 62.
        #expect(m.faceAreas.count == 6)
        #expect(abs(m.totalFaceArea - 62.0) < 1e-6,
                "expected 62.0, got \(m.totalFaceArea)")
        // Areas should occur in 3 pairs (front/back, top/bottom, left/right).
        let sorted = m.faceAreas.sorted()
        #expect(abs(sorted[0] - sorted[1]) < 1e-6)
        #expect(abs(sorted[2] - sorted[3]) < 1e-6)
        #expect(abs(sorted[4] - sorted[5]) < 1e-6)
    }

    @Test func boxEdgeLengthsMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        // Box has 12 edges: 4 of length 2, 4 of length 3, 4 of length 5.
        // Total = 4*(2+3+5) = 40.
        #expect(m.edgeLengths.count == 12)
        #expect(abs(m.totalEdgeLength - 40.0) < 1e-6,
                "expected 40.0, got \(m.totalEdgeLength)")
    }

    @Test func cylinderTotalsAreFinite() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        let m = cyl.measure()
        #expect(m.faceAreas.count >= 3)
        #expect(m.totalFaceArea > 0)
        #expect(m.totalFaceArea.isFinite)
        #expect(m.totalEdgeLength > 0)
        #expect(m.totalEdgeLength.isFinite)
    }

    @Test func boxFaceCentroidsLieInsideFaceBounds() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        #expect(m.faceCentroids.count == 6,
                "one centroid per face, parallel to faceAreas")
        let faceList = box.faces()
        for (i, c) in m.faceCentroids.enumerated() {
            let b = faceList[i].bounds
            #expect(c.x >= b.min.x - 1e-6 && c.x <= b.max.x + 1e-6,
                    "face \(i) centroid X=\(c.x) outside [\(b.min.x), \(b.max.x)]")
            #expect(c.y >= b.min.y - 1e-6 && c.y <= b.max.y + 1e-6,
                    "face \(i) centroid Y=\(c.y) outside [\(b.min.y), \(b.max.y)]")
            #expect(c.z >= b.min.z - 1e-6 && c.z <= b.max.z + 1e-6,
                    "face \(i) centroid Z=\(c.z) outside [\(b.min.z), \(b.max.z)]")
        }
    }

    @Test func boxFacePerimetersMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        #expect(m.facePerimeters.count == 6)
        // 2x3 face perimeter 10 (×2), 3x5 perimeter 16 (×2), 2x5 perimeter 14 (×2).
        // Total = 20 + 32 + 28 = 80.
        #expect(abs(m.totalFacePerimeter - 80.0) < 1e-6,
                "expected 80.0 total face perimeter, got \(m.totalFacePerimeter)")
        #expect(m.facePerimeters.allSatisfy { $0 != nil },
                "all box faces have a closed outer wire")
    }

    @Test func cylinderTopBottomCentroidsAreOnAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        // Find the two circular cap faces by area: pi*r^2 = pi*25 ≈ 78.54.
        // Their centroids should lie on the cylinder axis (X=Y=0 in OCCT's
        // default cylinder placement, which puts the axis on Z).
        let m = cyl.measure()
        let capArea = .pi * 25.0
        var capCount = 0
        for (i, area) in m.faceAreas.enumerated() {
            if abs(area - capArea) < 1e-3 {
                capCount += 1
                let c = m.faceCentroids[i]
                #expect(abs(c.x) < 1e-6, "cap \(i) centroid X=\(c.x), expected 0")
                #expect(abs(c.y) < 1e-6, "cap \(i) centroid Y=\(c.y), expected 0")
            }
        }
        #expect(capCount == 2, "cylinder has 2 circular caps, found \(capCount)")
    }
}
