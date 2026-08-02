import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Regression coverage for #609: zero-mass `BRepGProp` results were returned as successful answers
/// across the whole mass-property surface, and the value handed back was not a recognisable zero.
///
/// Sibling of `CenterOfMassTests` (#605), which fixed the same two mechanisms on `centerOfMass` and
/// `properties()`. Ground truth for everything asserted here is in `Scripts/repro/609-zero-mass/`.
@Suite("Zero-mass GProp results (#609)")
struct ZeroMassResultsTests {

    /// A 10x20x30 box, and the pieces of it that have no volume.
    private func box() -> Shape? { Shape.box(width: 10, height: 20, depth: 30) }

    private func faceShape() throws -> Shape {
        let b = try #require(box())
        let f = try #require(b.faces().first)
        return try #require(Shape.fromFace(f))
    }

    private func edgeShape() throws -> Shape {
        let b = try #require(box())
        let e = try #require(b.edges().first)
        return try #require(Shape.fromEdge(e))
    }

    /// Five of the box's six faces, sewn. Closed everywhere except one opening.
    private func openShell() throws -> Shape {
        let b = try #require(box())
        let five = b.faces().dropLast().compactMap { Shape.fromFace($0) }
        #expect(five.count == 5)
        return try #require(Shape.sew(shapes: five, tolerance: 1e-6))
    }

    // MARK: - volume / signedVolume

    /// The inconsistency this issue exists to close. `properties()` returned nil for an open shell
    /// after #605 while `volume` still reported the divergence integral over a surface that
    /// encloses nothing: 4800, where the closed answer is 6000.
    @Test("an open shell has no volume, and does not report 4800")
    func openShellHasNoVolume() throws {
        let open = try openShell()

        // Name the wrong answer so a regression cannot pass quietly. 4800 is what OCCT returns
        // with OnlyClosed left at its default.
        #expect(open.volume == nil,
                "open shell reported a volume of \(String(describing: open.volume)); 4800 means OnlyClosed was dropped")
        #expect(open.properties() == nil)
        #expect(open.volumeInertia == nil)
        #expect(open.centroid == nil)

        // The measures that DO apply to an open shell still work.
        let area = try #require(open.surfaceArea)
        #expect(abs(area - 2000.0) < 1e-6, "five faces of a 10x20x30 box")
        #expect(open.surfaceInertia != nil)
    }

    @Test("volume is nil for every shape below a closed shell")
    func volumeIsNilOutsideItsDomain() throws {
        let b = try #require(box())
        #expect(abs((b.volume ?? 0) - 6000.0) < 1e-6)

        #expect(try faceShape().volume == nil, "a face encloses no volume")
        #expect(try edgeShape().volume == nil, "an edge encloses no volume")
        #expect(try #require(b.subShapes(ofType: .wire).first).volume == nil)
        #expect(try #require(b.subShapes(ofType: .vertex).first).volume == nil)
    }

    /// `signedVolume` is deliberately NOT given the strict treatment: it is an orientation signal,
    /// and the flux integral's sign is sound for an open surface even though its magnitude is not a
    /// volume. Measured: +4800 forward and -4800 reversed for five faces of this box.
    ///
    /// This is load-bearing. `Shape.sweep` normalises an inward-facing pipe through
    /// `orientedForward()` (#170), and a pipe sweep produces an *open shell*, so routing this
    /// through the strict volume would silently stop normalising the case #170 was filed about.
    @Test("signedVolume stays an orientation signal, while volume becomes a measurement")
    func signedVolumeIsAnOrientationSignal() throws {
        let b = try #require(box())
        #expect(abs(b.signedVolume - 6000.0) < 1e-6)
        let reversed = try #require(b.reversed)
        #expect(abs(reversed.signedVolume + 6000.0) < 1e-6, "a reversed solid keeps its sign")

        // The open shell is the case the two APIs answer differently, on purpose.
        let open = try openShell()
        #expect(open.volume == nil, "as a measurement there is no answer")
        #expect(open.signedVolume != 0, "as an orientation signal there is")
        let openReversed = try #require(open.reversed)
        #expect(abs(open.signedVolume + openReversed.signedVolume) < 1e-6,
                "reversing an open surface must negate the flux, or the signal is not a signal")
    }

    /// The concrete #170 shape, which is what made the distinction above necessary: a pipe sweep
    /// along a helix is an open shell with three faces and no solid, so every orientation check on
    /// it runs through the flux integral.
    @Test("a pipe sweep is an open shell and still comes out forward-oriented")
    func pipeSweepStaysNormalised() throws {
        let section = try #require(Wire.circle(radius: 1.5))
        let helix = try #require(Wire.helix(radius: 8, pitch: 6, turns: 3))
        let spring = try #require(Shape.sweep(profile: section, along: helix))

        #expect(spring.solidCount == 0, "a pipe sweep is a shell, not a solid")
        #expect(spring.volume == nil, "an open shell has no volume to measure")
        #expect(spring.signedVolume > 0, "but it is still normalised to face outward")
    }

    /// Measured at 6857.14 against a true 6000: a loose face in a compound was adding 857 to the
    /// volume of the solid beside it.
    @Test("a loose face in a compound does not inflate the solid's volume")
    func compoundWithLooseFaceIsNotInflated() throws {
        let b = try #require(box())
        let compound = try #require(Shape.compound([b, try faceShape()]))

        let v = try #require(compound.volume, "the compound still contains a closed solid")
        #expect(abs(v - 6000.0) < 1e-6, "want the solid's own volume, got \(v)")
    }

    /// The behaviour change with downstream teeth. `BRep_Tool::IsClosed` counts topological edge
    /// sharing, so faces that merely coincide geometrically are not a closed shell. Sewing is what
    /// makes them one.
    @Test("faces must be sewn before they have a volume")
    func unsewnFacesHaveNoVolume() throws {
        let b = try #require(box())
        let faces = b.faces().compactMap { Shape.fromFace($0) }
        #expect(faces.count == 6)

        let loose = try #require(Shape.compound(faces))
        #expect(loose.volume == nil, "six unsewn faces are not a closed shell")

        let sewn = try #require(Shape.sew(shapes: faces, tolerance: 1e-6))
        #expect(abs((sewn.volume ?? 0) - 6000.0) < 1e-6, "sewing shares the edges, closing the shell")
    }

    // MARK: - the sentinel

    /// The reason none of this could be papered over downstream with `if com == .zero`. A zero-mass
    /// framework seeds itself with the shape's *location*, so the wrong answer was a plausible
    /// point that followed the part around. `moved(dx:dy:dz:)` sets a real `TopLoc_Location`,
    /// unlike `translated(by:)` which bakes the transform into the geometry.
    @Test("the old zero-mass answer tracked the shape's location, so nil is the only sound signal")
    func sentinelWasTheLocationOrigin() throws {
        let face = try faceShape()
        let movedOnce = try #require(face.moved(dx: 100, dy: 200, dz: 300))
        let movedTwice = try #require(movedOnce.moved(dx: 100, dy: 200, dz: 300))

        // Before the fix these reported (0,0,0), (100,200,300) and (200,400,600) respectively:
        // three different "answers" for three copies of one face that has no centroid at all.
        #expect(face.centroid == nil)
        #expect(movedOnce.centroid == nil)
        #expect(movedTwice.centroid == nil)

        // The location really is set, so the fixture is exercising the mechanism and not just a
        // shape that happens to sit at the origin.
        let bounds = try #require(movedOnce.boundingBox)
        #expect(bounds.min.x > 90.0, "moved() should have relocated the face, got \(bounds.min.x)")
    }

    // MARK: - everything derived from a zero-mass framework

    @Test("centroid is nil outside the volume domain, and correct inside it")
    func centroidDomain() throws {
        let cone = try #require(Shape.cone(bottomRadius: 10, topRadius: 0, height: 20))
        let c = try #require(cone.centroid)
        #expect(abs(c.z - 5.0) < 1e-6, "a cone's centroid is a quarter of the way up, got \(c.z)")

        #expect(try faceShape().centroid == nil)
        #expect(try edgeShape().centroid == nil)
        #expect(try openShell().centroid == nil)
    }

    /// OCCT computes this as `sqrt(momentOfInertia / mass)` with no guard, so the old answer was
    /// NaN, which propagates silently through anything that consumes it.
    @Test("radiusOfGyration is nil rather than NaN")
    func radiusOfGyrationIsNilNotNaN() throws {
        let b = try #require(box())
        let real = try #require(b.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0, 0, 1)))
        #expect(real > 0 && real.isFinite)

        for shape in [try faceShape(), try edgeShape(), try openShell()] {
            let r = shape.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0, 0, 1))
            #expect(r == nil, "got \(String(describing: r)); NaN here would spread silently")
            #expect(!(r?.isNaN ?? false))
        }
    }

    /// `math_Jacobi` on a zero inertia matrix returns the identity basis, so the old answer was
    /// three orthonormal unit vectors that describe nothing.
    @Test("principalAxes is nil rather than the identity basis")
    func principalAxesIsNilNotIdentity() throws {
        let b = try #require(box())
        #expect(b.principalAxes() != nil)

        for shape in [try faceShape(), try edgeShape(), try openShell()] {
            #expect(shape.principalAxes() == nil)
        }
    }

    @Test("momentOfInertia and inertiaProperties are nil outside the volume domain")
    func volumeTensorsAreNil() throws {
        let b = try #require(box())
        #expect((b.momentOfInertia()?.ixx ?? 0) > 0)
        #expect(b.inertiaProperties() != nil)

        let face = try faceShape()
        #expect(face.momentOfInertia() == nil)
        #expect(face.inertiaProperties() == nil)

        // The area-based sibling still answers for the same face, which is the migration.
        let area = try #require(face.surfaceInertiaProperties())
        #expect(abs(area.mass - 600.0) < 1e-6)
    }

    /// Three equal moments read as spherical symmetry, and at zero mass all three are equal. Every
    /// shape below a solid used to claim it.
    @Test("symmetryAxes is empty outside the volume domain, and unchanged inside it")
    func symmetryAxesDomain() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.symmetryAxes().count == 3, "a sphere really is spherically symmetric")

        let cyl = try #require(Shape.cylinder(radius: 2, height: 9))
        #expect(cyl.symmetryAxes().count == 1, "a cylinder has one axis of revolution")

        let b = try #require(box())
        for shape in [try faceShape(), try edgeShape(), try openShell(),
                      try #require(b.subShapes(ofType: .wire).first),
                      try #require(b.subShapes(ofType: .vertex).first)] {
            #expect(shape.symmetryAxes().isEmpty,
                    "a zero-mass framework claims spherical symmetry; it should claim nothing")
        }
    }

    @Test("linearProperties is nil for a shape with no edges")
    func linearPropertiesDomain() throws {
        let b = try #require(box())
        let lp = try #require(b.linearProperties())
        #expect(abs(lp.length - 480.0) < 1e-6, "12 edges of a 10x20x30 box")

        let vertex = try #require(b.subShapes(ofType: .vertex).first)
        #expect(vertex.linearProperties() == nil, "a vertex has no length and no centroid")
    }

    @Test("surfaceInertia is nil for a shape with no faces")
    func surfaceInertiaDomain() throws {
        let face = try faceShape()
        #expect(abs((face.surfaceInertia?.area ?? 0) - 600.0) < 1e-6)

        #expect(try edgeShape().surfaceInertia == nil, "an edge has no area")
        #expect(try edgeShape().surfaceInertiaProperties() == nil)
    }

    // MARK: - per-face and per-edge GProp wrappers

    @Test("per-face inertia keeps its mass and drops only the centroid")
    func perFaceInertiaKeepsMass() throws {
        let b = try #require(box())
        let faces = b.faces()

        // Every face of a box has an area, so every centroid is present.
        for (i, f) in faces.enumerated() {
            #expect(f.surfaceInertia.centerOfMass != nil, "face \(i) has an area")
        }

        // The divergence decomposition still sums to the solid's volume, which is why the mass
        // stays non-optional even when a single face contributes nothing.
        let summed = faces.reduce(0.0) { $0 + $1.volumeInertia.volume }
        #expect(abs(summed - 6000.0) < 1e-3, "per-face contributions should sum to the volume, got \(summed)")
    }

    @Test("measure() reports a centroid per face, index-parallel with faces()")
    func measureFaceCentroids() throws {
        let b = try #require(box())
        let m = b.measure()
        #expect(m.faceCentroids.count == 6)
        #expect(m.faceCentroids.allSatisfy { $0 != nil }, "every face of a box has an area")
    }

    @Test("curveInertia keeps its length and drops only the centroid")
    func curveInertiaKeepsLength() throws {
        let b = try #require(box())
        let edge = try #require(b.edges().first)
        let ci = edge.curveInertia
        #expect(ci.length > 0)
        #expect(ci.centerOfMass != nil)
    }

    // MARK: - the nil branch of the per-element results

    /// The other half of `perFaceInertiaKeepsMass`, and the case the reproducer names
    /// (`Vinert(coplanar face) : mass=0.000000`). `BRepGProp_Vinert` integrates the volume between
    /// a face and its location point, which the bridge fixes at the origin, so a planar face whose
    /// own plane contains the origin contributes exactly nothing. The 0 is a real summand and stays;
    /// the centroid it has no basis for does not.
    @Test("a zero volume contribution keeps its 0 and drops its centroid")
    func perFaceVolumeInertiaRefusesAZeroContribution() throws {
        // Shape.box is centred on the origin, so shift it to put one face in the z = 0 plane.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10)?
            .translated(by: SIMD3(0, 0, 5)))

        let coplanar = try #require(b.faces().first { abs($0.volumeInertia.volume) < 1e-9 },
                                    "one face of this box lies in the z = 0 plane")
        let vi = coplanar.volumeInertia
        #expect(vi.volume == 0.0,
                "the guard is an exact test, so a residual of \(vi.volume) would leave the centroid in place")
        #expect(vi.centerOfMass == nil, "a zero contribution has no centroid")

        // The faces that do contribute keep both.
        let contributing = b.faces().filter { $0.volumeInertia.volume != 0 }
        #expect(!contributing.isEmpty)
        #expect(contributing.allSatisfy { $0.volumeInertia.centerOfMass != nil })
    }

    /// `OCCTMeshPropsCompute` returns a zeroed result when the face carries no triangulation, which
    /// used to surface as a centroid of (0,0,0).
    @Test("meshProps has no centroid until the face is triangulated")
    func meshPropsWithoutTriangulationHasNoCentroid() throws {
        let b = try #require(box())
        let face = try #require(b.faces().first)

        let bare = face.meshProps(type: .surface)
        #expect(bare.mass == 0.0, "an untriangulated face has no mesh to measure")
        #expect(bare.centerOfMass == nil, "and so no centroid; this used to be (0,0,0)")

        // Meshing attaches the triangulation to the shape's faces, and the answer arrives.
        #expect(b.mesh(linearDeflection: 0.1) != nil)
        let meshed = try #require(b.faces().first).meshProps(type: .surface)
        #expect(meshed.mass > 0, "a triangulated face has an area")
        #expect(meshed.centerOfMass != nil)
    }

    /// `BRepGProp_MeshCinert` needs at least two points. Below that the bridge returns a zeroed
    /// result, and the (0,0,0) in it was indistinguishable from a polygon centred on the origin.
    @Test("meshCinertCompute has no centroid below two points")
    func meshCinertBelowTwoPointsHasNoCentroid() {
        #expect(meshCinertCompute(points: []).centerOfMass == nil)
        #expect(meshCinertCompute(points: [(1, 2, 3)]).centerOfMass == nil,
                "one point is not a polyline")

        let real = meshCinertCompute(points: [(0, 0, 0), (10, 0, 0)])
        #expect(abs(real.mass - 10.0) < 1e-9)
        #expect(real.centerOfMass != nil)
    }

    /// `VinertGKResult.center` has two nil cases, and `computeCG: false` is the one with no
    /// counterpart anywhere else: nothing was computed, so reporting (0,0,0) claimed an answer the
    /// caller had explicitly declined to ask for.
    @Test("vinertGK reports no centre when none was asked for")
    func vinertGKWithoutCentreOfGravity() throws {
        let b = try #require(box())
        let firstFace = try #require(b.faces().first)
        let face = try #require(Shape.fromFace(firstFace))

        let asked = face.vinertGK(tolerance: 1e-4)
        #expect(asked.center != nil, "computeCG defaults to true")

        let declined = face.vinertGK(tolerance: 1e-4, computeCG: false)
        #expect(abs(declined.mass - asked.mass) < 1e-6, "the mass is computed either way")
        #expect(declined.center == nil, "nothing was computed, so there is nothing to report")
    }

    // MARK: - point sets

    /// `GProp_PGProps` reports (0,0,0) for an empty set, which is indistinguishable from the
    /// centroid of a set centred on the origin.
    @Test("an empty point set has no centroid")
    func emptyPointSetHasNoCentroid() {
        #expect(GeometryProperties.barycentre([]) == nil)
        #expect(GeometryProperties.pointSetCentroid([]).centroid == nil)

        let real = GeometryProperties.barycentre([SIMD3(0, 0, 0), SIMD3(4, 0, 0)])
        #expect(abs((real?.x ?? 0) - 2.0) < 1e-9)
    }

    /// `GProp_PGProps::AddPoint` throws `Standard_DomainError` on the first weight that is not
    /// strictly positive, discarding the whole set. That used to surface as mass 0 with a centroid
    /// of (0,0,0), which reads as success.
    @Test("a non-positive weight rejects the set rather than reporting the origin")
    func nonPositiveWeightIsRejected() {
        let pts = [SIMD3(0.0, 0, 0), SIMD3(10.0, 0, 0)]

        let good = GeometryProperties.weightedCentroid(points: pts, weights: [1, 3])
        #expect(abs(good.mass - 4.0) < 1e-9)
        #expect(abs((good.centroid?.x ?? 0) - 7.5) < 1e-9)

        for bad in [[1.0, 0.0], [1.0, -1.0], [0.0, 0.0]] {
            let r = GeometryProperties.weightedCentroid(points: pts, weights: bad)
            #expect(r.centroid == nil, "weights \(bad) were rejected by OCCT, so there is no centroid")
        }
    }

    /// The two zero-mass cases in the analytic helpers, which #609 treats differently. A valid
    /// element measured over an empty range keeps its correct answer; an input OCCT rejects has no
    /// answer at all.
    ///
    /// This distinction was found by a test, not by reading: the first draft of this suite asserted
    /// that a degenerate segment kept a correct centre, on the strength of a ground-truth
    /// measurement of `GProp_CelGProps` with `u1 == u2`. It fails, because coincident endpoints
    /// never reach `GProp_CelGProps` at all: `gp_Dir(gp_Vec(p, p))` throws first.
    @Test("a rejected analytic input is nil, but a valid zero-length one keeps its answer")
    func analyticRejectionVersusZeroLength() {
        let p = SIMD3(3.0, 4.0, 5.0)

        #expect(GeometryProperties.lineSegment(from: p, to: p) == nil,
                "coincident endpoints give no direction, so there is no segment to measure")
        #expect(GeometryProperties.circularArc(center: .zero, normal: .zero,
                                               radius: 5, u1: 0, u2: .pi) == nil,
                "a zero normal gives no plane, so there is no arc to measure")

        // A real segment still answers.
        let real = GeometryProperties.lineSegment(from: .zero, to: p)
        #expect(abs((real?.length ?? 0) - simd_length(p)) < 1e-9)

        // A valid circle sampled over an empty range answers with length 0 and a correct centre,
        // computed analytically rather than accumulated, so there is nothing to refuse.
        if let empty = GeometryProperties.circularArc(center: .zero, normal: SIMD3(0, 0, 1),
                                                      radius: 5, u1: 0, u2: 0) {
            #expect(abs(empty.arcLength) < 1e-9, "an empty parameter range has no arc length")
        } else {
            Issue.record("a valid circle sampled over an empty range is not a rejected input")
        }
    }
}
