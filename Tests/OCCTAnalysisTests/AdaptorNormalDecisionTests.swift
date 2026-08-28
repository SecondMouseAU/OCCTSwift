import Foundation
import Testing
import simd

@testable import OCCTSwift

/// The two `BRepLProp_SLProps` sites that are not curvature reporting: the midpoint normal behind
/// `Face.normal` (and so behind every `isHorizontal` / `isUpwardFacing` / `isVertical` predicate),
/// and the per-hit normal `Shape.raycast` returns.
///
/// The face-normal change is inert, which is a measurement rather than an assumption: `CSLib::Normal`
/// tests the two first derivatives for nullity against `gp::Resolution()`, a fixed ~1e-300 epsilon,
/// and uses the caller's value only as a **sine** tolerance on the angle between them. That test is
/// scale-invariant, so a surface whose derivatives merely shrink keeps a defined normal all the way
/// down. Swept over 662 faces of a real sewn solid plus every primitive here, not one face changed
/// definedness or direction (`Scripts/repro/529-breplprop-resolution/occt_529_face_normal_decisions.cpp`).
///
/// The raycast change is not inert at all. A sine tolerance is dimensionless and saturates, and
/// `raycast` was passing its caller's *intersection* tolerance into that slot.
@Suite("Midpoint and raycast normals under the shared resolution (#529)")
struct AdaptorNormalDecisionTests {

    @Test("Primitive face normals and orientation predicates are unchanged")
    func primitiveFaceNormalsUnchanged() {
        let cases: [(String, Shape?, Int, Int)] = [
            // shape, expected horizontal faces, expected upward faces
            ("box", Shape.box(width: 10, height: 20, depth: 30), 2, 1),
            ("cylinder", Shape.cylinder(radius: 5, height: 20), 2, 1),
            ("cone", Shape.cone(bottomRadius: 5, topRadius: 0, height: 12), 1, 0),
            ("sphere", Shape.sphere(radius: 7), 0, 0),
        ]
        for (name, solid, horizontal, upward) in cases {
            guard let solid else {
                Issue.record("\(name) returned nil")
                continue
            }
            let faces = solid.faces()
            #expect(
                faces.allSatisfy { $0.normal != nil || !$0.isPlanar },
                "\(name): a planar face with no normal")
            #expect(solid.horizontalFaces().count == horizontal, "\(name) horizontal")
            #expect(solid.upwardFaces().count == upward, "\(name) upward")
        }
    }

    /// A face whose two parametric directions are *nearly parallel* is the one shape the sine
    /// tolerance actually rejects. Skewing a linear extrusion by 5e-7 radians puts it between the
    /// two values: the normal is undefined at `1e-6` and defined at `Precision::Confusion()`.
    @Test("A nearly-degenerate parameterisation now reports its normal")
    func skewedExtrusionHasANormal() {
        guard let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) else {
            Issue.record("Curve3D.line returned nil")
            return
        }
        let skew = 5e-7
        guard
            let surface = Surface.extrusion(
                profile: line,
                direction: SIMD3(cos(skew), sin(skew), 0)),
            let shape = Shape.face(from: surface, uRange: 0...10, vRange: 0...10),
            let face = Face(shape)
        else {
            Issue.record("could not build the skewed extrusion face")
            return
        }
        guard let normal = face.normal else {
            Issue.record("the skewed extrusion face reports no normal")
            return
        }
        #expect(abs(abs(normal.z) - 1.0) < 1e-6, "normal \(normal)")
        #expect(face.isHorizontal())
    }

    /// The raycast regression. `tolerance` is documented as the intersection tolerance and it used
    /// to double as the props resolution, where it is a dimensionless sine tolerance, so any value
    /// at or above 1 rejected every normal there is, and `RayHit.normal` fell back to `(0, 0, 1)`
    /// for every hit on every shape.
    @Test("Raising the intersection tolerance does not erase the hit normals")
    func raycastNormalsSurviveALooseTolerance() {
        guard let sphere = Shape.sphere(radius: 5) else {
            Issue.record("Shape.sphere returned nil")
            return
        }
        for tolerance in [0.001, 0.1, 1.0, 2.0, 5.0] {
            let hits = sphere.raycast(
                origin: SIMD3(-20, 0, 0),
                direction: SIMD3(1, 0, 0),
                tolerance: tolerance)
            let label: Comment = "tolerance=\(tolerance)"
            #expect(hits.count == 2, label)
            for hit in hits {
                #expect(hit.normalDefined, label)
                // A sphere's normal is radial: parallel to the hit point itself.
                let radial = simd_normalize(hit.point)
                #expect(
                    abs(abs(simd_dot(radial, hit.normal)) - 1.0) < 1e-6,
                    "\(label) hit \(hit.point) normal \(hit.normal)")
            }
        }
    }

    @Test("A box's downward face still reports a downward normal at a loose tolerance")
    func raycastKeepsFaceOrientationAtALooseTolerance() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        for tolerance in [0.001, 1.0, 5.0] {
            let hits = box.raycast(
                origin: SIMD3(0, 0, 40),
                direction: SIMD3(0, 0, -1),
                tolerance: tolerance)
            let label: Comment = "tolerance=\(tolerance)"
            #expect(hits.count == 2, label)
            guard hits.count == 2 else { continue }
            #expect(hits.allSatisfy { $0.normalDefined }, label)
            // Nearest hit is the top face, pointing up; the far one is the bottom, pointing down.
            #expect(hits[0].normal.z > 0.99, "\(label) near \(hits[0].normal)")
            #expect(hits[1].normal.z < -0.99, "\(label) far \(hits[1].normal)")
        }
    }
}
