import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Regression coverage for #605: `centerOfMass` / `properties()` returned the bounding-box centre
/// instead of `BRepGProp::VolumeProperties`. Every pre-existing test used a box centred at the
/// origin, where the two answers coincide, so the suite agreed with both implementations and
/// distinguished neither. Each test here is chosen so the bbox centre is a *different* point.
@Suite("Centre of mass (#605)")
struct CenterOfMassTests {

    /// 10-cube at the origin plus a 2-cube 20 units out on X.
    /// Analytic centre of mass x = (1000*0 + 8*20) / 1008 = 0.158730159.
    /// The bounding box runs x = -5 to 21, so its centre is 8.0: off by a factor of 50.
    private func twoCubes() -> Shape? {
        guard let big = Shape.box(width: 10, height: 10, depth: 10),
              let small = Shape.box(width: 2, height: 2, depth: 2)?.translated(by: SIMD3(20, 0, 0)),
              let union = big.union(small) else { return nil }
        return union
    }

    @Test("centre of mass of an asymmetric solid is not the bounding-box centre")
    func asymmetricSolid() throws {
        let part = try #require(twoCubes())
        let com = try #require(part.centerOfMass)

        #expect(abs(com.x - 0.158730159) < 1e-6, "want the mass-weighted centroid, got \(com.x)")
        #expect(abs(com.y) < 1e-9)
        #expect(abs(com.z) < 1e-9)

        // Volume is unchanged by the fix and pins the shape itself.
        #expect(abs((part.volume ?? 0) - 1008.0) < 1e-6)

        // Name the wrong answer explicitly so a regression cannot pass quietly.
        let bbox = try #require(part.boundingBox)
        let boxCentre = (bbox.min.x + bbox.max.x) / 2
        #expect(abs(boxCentre - 8.0) < 1e-3, "fixture drifted: the bbox centre should be 8")
        #expect(abs(com.x - boxCentre) > 7.0, "centerOfMass is returning the bounding-box centre")
    }

    @Test("properties() reports the same centre of mass as centerOfMass")
    func propertiesAgreesWithCenterOfMass() throws {
        let part = try #require(twoCubes())
        let props = try #require(part.properties())
        let com = try #require(part.centerOfMass)

        #expect(abs(props.centerOfMass.x - 0.158730159) < 1e-6)
        #expect(simd_distance(props.centerOfMass, com) < 1e-9,
                "the two entry points disagree: \(props.centerOfMass) vs \(com)")
    }

    /// A single primitive, no boolean involved: a cone's centroid is at h/4, its bbox centre h/2.
    @Test("a cone's centre of mass is at a quarter of its height")
    func conePrimitive() throws {
        let cone = try #require(Shape.cone(bottomRadius: 10, topRadius: 0, height: 20))
        let com = try #require(cone.centerOfMass)

        #expect(abs(com.z - 5.0) < 1e-6, "a cone's centroid is h/4 = 5, got \(com.z)")
        #expect(abs(com.x) < 1e-6)
        #expect(abs(com.y) < 1e-6)
    }

    /// The inertia tensor is referenced to the centre of mass, so it must stay put when the shape
    /// is translated. This is what proves the tensor was never part of the #605 defect, and it
    /// guards the tensor against a future "fix" that re-references it to the origin.
    @Test("the inertia tensor is referenced to the centre of mass, not the origin")
    func inertiaIsAboutTheCentreOfMass() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10)?
            .translated(by: SIMD3(20, 0, 0)))
        let props = try #require(box.properties())

        // Iyy about the centre of mass = m(a^2 + c^2)/12 = 1000 * 200/12.
        // About the world origin it would pick up m*d^2 = 1000 * 400 on top of that.
        let aboutCentreOfMass = 1000.0 * 200.0 / 12.0
        #expect(abs(props.momentOfInertia[1][1] - aboutCentreOfMass) < 1.0,
                "tensor is referenced to the wrong point: \(props.momentOfInertia[1][1])")
        #expect(abs(props.centerOfMass.x - 20.0) < 1e-6)
    }

    // MARK: - Shapes that enclose no volume

    /// `BRepGProp::VolumeProperties` has nothing to report for these, and its zero-mass
    /// `CentreOfMass()` is the shape's *location origin*, not a recognisable (0,0,0) sentinel.
    /// Returning nil is the only sound answer.
    @Test("sub-shapes that enclose no volume have no centre of mass")
    func subShapesWithoutVolume() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30)?
            .translated(by: SIMD3(100, 200, 300)))

        let firstFace = try #require(box.faces().first)
        let face = try #require(Shape.fromFace(firstFace))
        #expect(face.centerOfMass == nil, "a face encloses no volume")
        #expect(face.properties() == nil)

        let firstEdge = try #require(box.edges().first)
        let edge = try #require(Shape.fromEdge(firstEdge))
        #expect(edge.centerOfMass == nil, "an edge encloses no volume")
        #expect(edge.properties() == nil)

        let wire = try #require(box.subShapes(ofType: .wire).first)
        #expect(wire.centerOfMass == nil, "a wire encloses no volume")

        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        #expect(vertex.centerOfMass == nil, "a vertex encloses no volume")

        // The measures that DO apply still work, and are the documented alternatives.
        #expect(abs((face.surfaceArea ?? 0) - 600.0) < 1e-6)
        #expect(abs((edge.linearProperties()?.length ?? 0) - 30.0) < 1e-6)
    }

    /// The case that decides the whole design. An open shell makes OCCT's divergence integral
    /// return a number (4800 for five faces of this box) that is not a volume, with a centroid
    /// 2.6 units adrift. `OnlyClosed = true` refuses instead, matching OCCT's own XDE property
    /// writer, and leaves closing the shape to the caller.
    @Test("an open shell has no centre of mass until it is closed")
    func openShellIsRefused() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30)?
            .translated(by: SIMD3(100, 200, 300)))
        let faces = box.faces()
        #expect(faces.count == 6)

        let fiveFaces = faces.dropLast().compactMap { Shape.fromFace($0) }
        let open = try #require(Shape.sew(shapes: Array(fiveFaces), tolerance: 1e-6))

        #expect(open.centerOfMass == nil, "an open shell encloses no volume")
        #expect(open.properties() == nil)

        // Closing it makes the answer available, and correct.
        let closed = try #require(Shape.sew(shapes: faces.compactMap { Shape.fromFace($0) },
                                            tolerance: 1e-6))
        let com = try #require(closed.centerOfMass)
        #expect(abs(com.x - 100.0) < 1e-6)
        #expect(abs(com.y - 200.0) < 1e-6)
        #expect(abs(com.z - 300.0) < 1e-6)
    }

    /// A closed shell that was never wrapped in a solid still has a volume: the dispatch key is
    /// `BRep_Tool::IsClosed`, not `ShapeType() == SOLID`.
    @Test("a closed shell outside a solid still has a centre of mass")
    func closedShellNotInASolid() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30)?
            .translated(by: SIMD3(100, 200, 300)))
        let shell = try #require(box.subShapes(ofType: .shell).first)

        let com = try #require(shell.centerOfMass, "a closed shell encloses a volume")
        #expect(abs(com.x - 100.0) < 1e-6)
        #expect(abs(com.y - 200.0) < 1e-6)
        #expect(abs(com.z - 300.0) < 1e-6)
    }

    /// `centerOfMass` and `centroid` are the same measure and used to disagree by 2x on a cone.
    @Test("centerOfMass agrees with centroid")
    func agreesWithCentroid() throws {
        for shape in [try #require(twoCubes()),
                      try #require(Shape.cone(bottomRadius: 10, topRadius: 0, height: 20))] {
            let com = try #require(shape.centerOfMass)
            let centroid = try #require(shape.centroid)
            #expect(simd_distance(com, centroid) < 1e-6,
                    "centerOfMass \(com) disagrees with centroid \(centroid)")
        }
    }

    /// The same measure reached through the inertia APIs, which were already correct. Guards
    /// against the fix landing on one entry point and not the other.
    @Test("centerOfMass agrees with volumeInertia and inertiaProperties")
    func agreesWithInertiaSurfaces() throws {
        let part = try #require(twoCubes())
        let com = try #require(part.centerOfMass)

        let vi = try #require(part.volumeInertia)
        #expect(simd_distance(com, vi.centerOfMass) < 1e-6)

        let ip = try #require(part.inertiaProperties())
        #expect(simd_distance(com, ip.centerOfMass) < 1e-6)
    }
}
