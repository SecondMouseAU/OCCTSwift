import Testing
import Foundation
@testable import OCCTSwift

// #613, site 5, the one of the six where converting to the deduplicated enumeration would have
// introduced a second bug rather than only fixing the first.
//
// Both mesh entry points walked a bare `TopExp_Explorer` over faces and stamped the walk's counter
// onto every triangle as `faceIndex`. That counter is an OCCURRENCE number, while `Shape.faces()`,
// `faceCount` and `face(at:)` have all read the deduplicated `TopExp::MapShapes` enumeration since
// #541, so a triangle's `faceIndex` named a different face than `faces()` did, and could exceed
// `faceCount` outright.
//
// But the same walk also decides triangle WINDING: `if (face.Orientation() == TopAbs_REVERSED)
// std::swap(n2, n3)`, which sets the sign of every emitted triangle normal. Meshing off the map
// instead would have kept only the orientation a shared face was first seen with (the map keys on
// `TopoDS_Shape::IsSame`, orientation ignored), #614's defect, one level down, inverting the shared
// wall's normal for one of the two owners and losing its facet entirely.
//
// Measured on the pinned kernel, one `BRepAlgoAPI_Splitter` cut of a 20×10×10 block at x = 10:
//
//   face occurrences (TopExp_Explorer)  12
//   distinct faces  (TopExp::MapShapes) 11
//   faces present in both orientations   1   (the shared wall, map index 5, stored FORWARD)
//   mesh faceIndices emitted before      0…11 on an 11-face shape
//   shared wall's two occurrences        one wound +x, one wound −x
//
// So neither enumeration alone is right, and the fix uses both: winding from the occurrence, index
// from the map. `occtForEachOrientedFace` (OCCTBridge_Internal.h) hands out both from one traversal.
//
// Also here: the unlisted sibling `OCCTPolyMergeNodes`, which carries the same winding hazard and
// must NOT be converted, it emits no index at all, so the only correct action was to pin its
// winding against a future sweep.

@Suite("Mesh face indices address faces(), and winding survives a shared wall (#613)")
struct Issue613MeshIndexContractTests {

    // MARK: - Fixture

    /// Two solids sharing one cut face, from one ordinary modelling operation.
    ///
    /// Returns nil on any construction failure; every caller `#require`s it, so a kernel that
    /// stopped sharing the wall fails these tests rather than skipping them silently, which is
    /// what we want, since the shared wall IS the fixture.
    static func splitBoxCompound() -> Shape? {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
              let rect = Wire.rectangle(width: 60, height: 60),
              let plate = Shape.face(from: rect),
              let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
              let knife = upright.translated(by: SIMD3(10, 0, 0)),
              let pieces = block.split(by: knife),
              pieces.count == 2,
              let compound = Shape.compound(pieces)
        else { return nil }
        return compound
    }

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    /// The geometric normal of a triangle, from its winding, deliberately recomputed from the
    /// vertex order rather than read from `Triangle.normal`, so the assertion lands on the winding
    /// itself and would survive the normal being computed some other way.
    static func windingNormal(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> SIMD3<Double> {
        let ab = SIMD3<Double>(Double(b.x - a.x), Double(b.y - a.y), Double(b.z - a.z))
        let ac = SIMD3<Double>(Double(c.x - a.x), Double(c.y - a.y), Double(c.z - a.z))
        return SIMD3(ab.y * ac.z - ab.z * ac.y,
                     ab.z * ac.x - ab.x * ac.z,
                     ab.x * ac.y - ab.y * ac.x)
    }

    // MARK: - The premise

    @Test("the fixture really does share one face between two solids")
    func fixtureSharesAWall() throws {
        let compound = try #require(Self.splitBoxCompound())
        #expect(compound.faceCount == 11, "distinct faces: \(compound.faceCount)")
        #expect(compound.orientedFaces().count == 12, "occurrences: \(compound.orientedFaces().count)")

        // Exactly one index appears twice, once per orientation.
        var byIndex: [Int: [Shape.Orientation]] = [:]
        for f in compound.orientedFaces() { byIndex[f.index, default: []].append(f.orientation) }
        let shared = byIndex.filter { $0.value.count > 1 }
        #expect(shared.count == 1, "expected one shared face, got \(shared.count)")
        if let orientations = shared.first?.value {
            #expect(Set(orientations) == [.forward, .reversed],
                    "the two occurrences should be opposed, got \(orientations)")
        }
    }

    // MARK: - Site 5: the index

    /// A triangle's `faceIndex` must be an index into `faces()`, one a caller can hand to
    /// `face(at:)`. Before the fix it was the explorer's occurrence counter, so it ran to 11 on an
    /// 11-face shape and, from index 5 on, named a different face than `faces()` did.
    @Test("no triangle claims a face index faces() cannot address")
    func meshFaceIndicesAddressTheFaceEnumeration() throws {
        let compound = try #require(Self.splitBoxCompound())
        let mesh = try #require(compound.mesh(linearDeflection: 0.5))
        let triangles = mesh.trianglesWithFaces()
        #expect(!triangles.isEmpty)

        let indices = Set(triangles.map { Int($0.faceIndex) })
        #expect(!indices.isEmpty)
        for i in indices {
            #expect(compound.face(at: i) != nil,
                    "triangles claim faceIndex \(i), which face(at:) cannot address")
        }
        // Bound it via #require rather than `indices.max()!` inside #expect: Swift Testing does not
        // short-circuit, so the preceding emptiness check would not stop a force-unwrap from
        // crashing the process on an empty mesh instead of failing the test.
        let highest = try #require(indices.max())
        #expect(highest < compound.faceCount,
                "max faceIndex \(highest) vs faceCount \(compound.faceCount)")
    }

    /// Stronger than "in range": the index must name the face the triangle is actually ON.
    @Test("a triangle's faceIndex names the face that triangle lies on")
    func meshFaceIndexNamesTheOwningFace() throws {
        let compound = try #require(Self.splitBoxCompound())
        let mesh = try #require(compound.mesh(linearDeflection: 0.5))
        let vertices = mesh.vertices

        // Every face of this fixture is planar and axis-aligned; a triangle stamped with index n
        // must lie in the plane of faces()[n].
        var checked = 0
        for t in mesh.trianglesWithFaces() {
            let face = try #require(compound.face(at: Int(t.faceIndex)))
            guard let uv = face.uvBounds,
                  let origin = face.point(atU: (uv.uMin + uv.uMax) / 2, v: (uv.vMin + uv.vMax) / 2),
                  let normal = face.normal(atU: (uv.uMin + uv.uMax) / 2, v: (uv.vMin + uv.vMax) / 2)
            else { continue }
            for vi in [t.v1, t.v2, t.v3] {
                let p = vertices[Int(vi)]
                let offset = SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)) - origin
                #expect(abs(Self.dot(offset, normal)) < 1e-6,
                        "triangle stamped faceIndex \(t.faceIndex) sits \(Self.dot(offset, normal)) off that face's plane")
            }
            checked += 1
        }
        #expect(checked > 20, "only \(checked) triangles checked")
    }

    /// The shared wall's two sides carry the SAME index, they are two occurrences of one face,
    /// and that index is the one `faces()` gives it.
    @Test("both sides of the shared wall are stamped with the one index that names it")
    func sharedWallSidesShareOneIndex() throws {
        let compound = try #require(Self.splitBoxCompound())
        let mesh = try #require(compound.mesh(linearDeflection: 0.5))
        let vertices = mesh.vertices

        // The wall is the plane x = 10. Collect the mesh face indices of triangles lying in it.
        var wallIndices = Set<Int>()
        var plusX = 0, minusX = 0
        for t in mesh.trianglesWithFaces() {
            let a = vertices[Int(t.v1)], b = vertices[Int(t.v2)], c = vertices[Int(t.v3)]
            guard abs(a.x - 10) < 1e-4, abs(b.x - 10) < 1e-4, abs(c.x - 10) < 1e-4 else { continue }
            wallIndices.insert(Int(t.faceIndex))
            let n = Self.windingNormal(a, b, c)
            if n.x > 1e-9 { plusX += 1 } else if n.x < -1e-9 { minusX += 1 }
        }
        #expect(wallIndices.count == 1,
                "the shared wall's triangles carry \(wallIndices.count) different indices: \(wallIndices.sorted())")
        // And both sides are still meshed, the map walk would have dropped one.
        #expect(plusX > 0 && minusX > 0,
                "expected both sides of the shared wall, got +x=\(plusX) −x=\(minusX)")
        #expect(plusX == minusX, "the two sides should mesh identically: +x=\(plusX) −x=\(minusX)")
    }

    // MARK: - Site 5: the winding

    /// A **control**, not a detector, stated plainly because the inject-the-bug pass showed it
    /// does not fail under either mesh injection. Losing the shared wall's second occurrence
    /// removes a facet rather than inverting one, and the copy that survives on this fixture is
    /// stored FORWARD, which is outward for its own owner. So this guards against a future change
    /// that inverts winding globally; the shared-wall tests above are what catch #613 and #614.
    @Test("every mesh triangle is wound outward for the solid that owns it (control)")
    func meshWindingIsOutwardPerOwner() throws {
        let compound = try #require(Self.splitBoxCompound())
        let mesh = try #require(compound.mesh(linearDeflection: 0.5))
        let vertices = mesh.vertices

        // The two solids' interiors: the block spans x 0…20, cut at x = 10.
        let lowerInterior = SIMD3<Double>(5, 5, 5)
        let upperInterior = SIMD3<Double>(15, 5, 5)

        var outward = 0, inward = 0
        for t in mesh.trianglesWithFaces() {
            let a = vertices[Int(t.v1)], b = vertices[Int(t.v2)], c = vertices[Int(t.v3)]
            let n = Self.windingNormal(a, b, c)
            guard (n.x * n.x + n.y * n.y + n.z * n.z) > 1e-12 else { continue }
            let centre = SIMD3<Double>(Double(a.x + b.x + c.x) / 3,
                                       Double(a.y + b.y + c.y) / 3,
                                       Double(a.z + b.z + c.z) / 3)
            // Which solid owns this triangle? The one whose interior it is a boundary of.
            let owner = centre.x <= 10 + 1e-6 && Self.dot(n, centre - lowerInterior) > 0
                      ? lowerInterior
                      : (centre.x >= 10 - 1e-6 && Self.dot(n, centre - upperInterior) > 0
                         ? upperInterior : nil)
            if owner != nil { outward += 1 } else { inward += 1 }
        }
        #expect(outward > 0)
        #expect(inward == 0,
                "\(inward) of \(outward + inward) triangles are wound inward for both solids")
    }

    /// A control: on a shape with no shared face the winding was never in question, so this pins
    /// that the conversion did not disturb the ordinary case.
    @Test("a plain box still meshes entirely outward")
    func plainBoxWindingUnchanged() throws {
        let box = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let mesh = try #require(box.mesh(linearDeflection: 0.5))
        let vertices = mesh.vertices
        let centre = SIMD3<Double>(5, 5, 5)

        var outward = 0, inward = 0
        for t in mesh.trianglesWithFaces() {
            let a = vertices[Int(t.v1)], b = vertices[Int(t.v2)], c = vertices[Int(t.v3)]
            let n = Self.windingNormal(a, b, c)
            let mid = SIMD3<Double>(Double(a.x + b.x + c.x) / 3,
                                    Double(a.y + b.y + c.y) / 3,
                                    Double(a.z + b.z + c.z) / 3)
            if Self.dot(n, mid - centre) > 0 { outward += 1 } else { inward += 1 }
        }
        #expect(outward == 12, "a box meshes as 12 triangles, got \(outward) outward")
        #expect(inward == 0)
        // And its indices span exactly its 6 faces.
        #expect(Set(mesh.trianglesWithFaces().map { Int($0.faceIndex) }) == Set(0..<6))
    }

    /// The parameterised entry point is a near-duplicate of the default one and had the identical
    /// defect, so it gets the identical assertion.
    @Test("the parameterised mesh entry point holds the same index contract")
    func parameterisedMeshHoldsTheContract() throws {
        let compound = try #require(Self.splitBoxCompound())
        var params = MeshParameters.default
        params.deflection = 0.5
        let mesh = try #require(compound.mesh(parameters: params))
        let triangles = mesh.trianglesWithFaces()
        #expect(!triangles.isEmpty)
        for i in Set(triangles.map { Int($0.faceIndex) }) {
            #expect(compound.face(at: i) != nil,
                    "triangles claim faceIndex \(i), which face(at:) cannot address")
        }

        // Winding too: both sides of the shared wall, stamped with one index.
        let vertices = mesh.vertices
        var wallIndices = Set<Int>()
        var plusX = 0, minusX = 0
        for t in triangles {
            let a = vertices[Int(t.v1)], b = vertices[Int(t.v2)], c = vertices[Int(t.v3)]
            guard abs(a.x - 10) < 1e-4, abs(b.x - 10) < 1e-4, abs(c.x - 10) < 1e-4 else { continue }
            wallIndices.insert(Int(t.faceIndex))
            let n = Self.windingNormal(a, b, c)
            if n.x > 1e-9 { plusX += 1 } else if n.x < -1e-9 { minusX += 1 }
        }
        #expect(wallIndices.count == 1, "wall triangles carry \(wallIndices.sorted())")
        #expect(plusX > 0 && minusX > 0, "+x=\(plusX) −x=\(minusX)")
    }

    // MARK: - The unlisted sibling: Poly_MergeNodesTool

    /// `OCCTPolyMergeNodes` emits no index, so there was nothing to converge, but it derives a
    /// `reversed` flag per occurrence and hands it to `Poly_MergeNodesTool::AddTriangulation`, which
    /// winds that face's triangles by it. Deduplicating the walk would add the shared wall once, in
    /// whichever orientation was seen first, and the other solid would lose its wall.
    ///
    /// This is the "do not convert" pin: it fails if a later sweep moves this walk onto the map.
    @Test("merged mesh nodes keep both sides of a shared wall, oppositely wound")
    func mergedNodesKeepBothWallSides() throws {
        let compound = try #require(Self.splitBoxCompound())
        _ = compound.mesh(linearDeflection: 0.5)   // triangulate first
        let merged = try #require(mergedMeshNodes(from: compound, smoothAngle: 0.5))
        #expect(merged.triangleCount > 0)

        var plusX = 0, minusX = 0
        for t in 0..<merged.triangleCount {
            let a = merged.vertices[Int(merged.indices[t * 3])]
            let b = merged.vertices[Int(merged.indices[t * 3 + 1])]
            let c = merged.vertices[Int(merged.indices[t * 3 + 2])]
            guard abs(a.x - 10) < 1e-4, abs(b.x - 10) < 1e-4, abs(c.x - 10) < 1e-4 else { continue }
            let n = Self.windingNormal(a, b, c)
            if n.x > 1e-9 { plusX += 1 } else if n.x < -1e-9 { minusX += 1 }
        }
        #expect(plusX > 0, "the lower solid lost its side of the shared wall")
        #expect(minusX > 0, "the upper solid lost its side of the shared wall")
        #expect(plusX == minusX, "+x=\(plusX) −x=\(minusX)")
    }

    /// Control for the same walk: with nothing shared, every merged triangle faces out.
    @Test("merged mesh nodes on a plain box are entirely outward")
    func mergedNodesPlainBoxOutward() throws {
        let box = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        _ = box.mesh(linearDeflection: 0.5)
        let merged = try #require(mergedMeshNodes(from: box, smoothAngle: 0.5))
        let centre = SIMD3<Double>(5, 5, 5)

        var outward = 0, inward = 0
        for t in 0..<merged.triangleCount {
            let a = merged.vertices[Int(merged.indices[t * 3])]
            let b = merged.vertices[Int(merged.indices[t * 3 + 1])]
            let c = merged.vertices[Int(merged.indices[t * 3 + 2])]
            let n = Self.windingNormal(a, b, c)
            let mid = SIMD3<Double>(Double(a.x + b.x + c.x) / 3,
                                    Double(a.y + b.y + c.y) / 3,
                                    Double(a.z + b.z + c.z) / 3)
            if Self.dot(n, mid - centre) > 0 { outward += 1 } else { inward += 1 }
        }
        #expect(outward == 12, "got \(outward) outward of \(outward + inward)")
        #expect(inward == 0)
    }
}
