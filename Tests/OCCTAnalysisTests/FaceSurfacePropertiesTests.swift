import Foundation
import Testing
import simd

@testable import OCCTSwift

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

    /// #1437: `OCCTFaceGetPrincipalCurvatures` paired `dirMin`/`dirMax` with the wrong OCCT
    /// output, exactly transposed (`GeomLProp_SLProps::CurvatureDirections(gp_Dir& MaxD, gp_Dir&
    /// MinD)` takes the MAXIMUM direction first). `principalCurvaturesCylinder` above only ever
    /// asserted the magnitudes, never the directions, so the swap went uncaught.
    ///
    /// The fix makes `kMin`/`dirMin` and `kMax`/`dirMax` internally consistent (each direction
    /// paired with its own curvature value), which is the property this test actually checks —
    /// **not** a fixed claim about which of `dirMin`/`dirMax` is axial. A first version of this
    /// test assumed `dirMin` is always axial, reasoning that axial curvature (0) is numerically
    /// smaller than circumferential (~1/r). That assumption is wrong: `MinCurvature()`/
    /// `MaxCurvature()` are signed, and a ground-truth probe against the pinned kernel
    /// (`BRepPrimAPI_MakeCylinder`'s own lateral face, r=5) shows the circumferential curvature
    /// comes back **negative** (-0.2) under OCCT's chosen normal convention, making it the true
    /// minimum, with axial (exactly 0) the true maximum — the reverse of the naive assumption.
    /// So this test locates the axial/circumferential pair by curvature magnitude instead of by
    /// position, and confirms each pairing is self-consistent (whichever curvature is ~0 has the
    /// ~Z direction; whichever is ~1/r has the in-plane direction), which is exactly what the
    /// swap being fixed makes true and what being transposed would make false.
    @Test("Principal curvature directions of cylinder are not transposed")
    func principalCurvatureDirectionsCylinderNotTransposed() throws {
        let radius = 5.0
        let cyl = try #require(Shape.cylinder(radius: radius, height: 10))
        let cylFace = try #require(cyl.faces().first { $0.surfaceType == .cylinder })
        let bounds = try #require(cylFace.uvBounds)
        let uMid = (bounds.uMin + bounds.uMax) / 2.0
        let vMid = (bounds.vMin + bounds.vMax) / 2.0
        let pc = try #require(cylFace.principalCurvatures(atU: uMid, v: vMid))

        // Identify the axial pair by curvature magnitude (~0), not by min/max position.
        let (axialCurv, axialDir, circumCurv, circumDir): (Double, SIMD3<Double>, Double, SIMD3<Double>) =
            abs(pc.kMin) < abs(pc.kMax)
            ? (pc.kMin, pc.dirMin, pc.kMax, pc.dirMax)
            : (pc.kMax, pc.dirMax, pc.kMin, pc.dirMin)

        #expect(abs(axialCurv) < 1e-6, "the near-zero curvature should be axial, got \(axialCurv)")
        #expect(
            abs(abs(axialDir.z) - 1.0) < 1e-6,
            "the direction paired with the near-zero curvature should be axial (|z| ~ 1), got \(axialDir)"
        )
        #expect(
            abs(abs(circumCurv) - 1.0 / radius) < 1e-6,
            "the other curvature should be circumferential (~1/r), got \(circumCurv)"
        )
        #expect(
            abs(circumDir.z) < 1e-6,
            "the direction paired with the circumferential curvature should lie in the XY plane (z ~ 0), got \(circumDir)"
        )
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
