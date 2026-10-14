import Foundation
import Testing

@testable import OCCTSwift

/// #2759: vector operations and matrix values the package computes itself.
///
/// They are plain Swift on every platform. These tests pin the one decision that mattered (a zero or non-finite vector normalises to
/// NaNs, on both platforms) and the matrix indexing consumers rely on.
@Suite("Vector operations")
struct VectorOpsTests {

    @Test("dot, cross, length and distance match hand-computed values")
    func basicOperations() {
        let a = SIMD3<Double>(1, 2, 3)
        let b = SIMD3<Double>(4, -5, 6)
        #expect(dotProduct(a, b) == 12)
        #expect(crossProduct(a, b) == SIMD3(27, 6, -13))
        #expect(vectorLengthSquared(SIMD3<Double>(1, 2, 2)) == 9)
        #expect(vectorLength(SIMD3<Double>(1, 2, 2)) == 3)
        #expect(vectorDistance(SIMD3<Double>(1, 1, 1), SIMD3(1, 4, 5)) == 5)
        #expect(vectorDistanceSquared(SIMD3<Double>(1, 1, 1), SIMD3(1, 4, 5)) == 25)
        // The same functions serve every width and both scalar types.
        #expect(vectorLength(SIMD2<Double>(3, 4)) == 5)
        #expect(vectorLength(SIMD4<Float>(2, 2, 2, 2)) == 4)
        #expect(dotProduct(SIMD2<Float>(1, 2), SIMD2(3, 4)) == 11)
    }

    @Test("normalising a finite vector gives a unit vector in the same direction")
    func normaliseFinite() {
        let n = normalizedVector(SIMD3<Double>(0, 3, 4))
        #expect(abs(n.x) < 1e-15)
        #expect(abs(n.y - 0.6) < 1e-15)
        #expect(abs(n.z - 0.8) < 1e-15)
        let f = normalizedVector(SIMD2<Float>(0, -2))
        #expect(f == SIMD2(0, -1))
    }

    @Test("A zero vector normalises to NaNs, and so does a non-finite one")
    func normaliseZeroAndNonFinite() {
        // The decision: IEEE division, identical on every platform. Not the zero vector, which is
        // what the WASI stand-in returned before #2764, and not a platform-specific result.
        let zero = normalizedVector(SIMD3<Double>.zero)
        #expect(zero.x.isNaN && zero.y.isNaN && zero.z.isNaN)
        let infinite = normalizedVector(SIMD3<Double>(.infinity, 0, 0))
        // inf / inf is NaN in the infinite component; the others are 0 / inf = 0. Not a unit vector.
        #expect(infinite.x.isNaN)
        #expect(infinite.y == 0 && infinite.z == 0)
        let nan = normalizedVector(SIMD3<Double>(.nan, 1, 0))
        #expect(nan.x.isNaN && nan.y.isNaN && nan.z.isNaN)
        let zero2 = normalizedVector(SIMD2<Double>.zero)
        #expect(zero2.x.isNaN && zero2.y.isNaN)
    }

    @Test("normalizedVectorOrNil refuses exactly what normalizedVector turns into NaN")
    func normaliseOrNil() {
        #expect(normalizedVectorOrNil(SIMD3<Double>.zero) == nil)
        #expect(normalizedVectorOrNil(SIMD3<Double>(.infinity, 0, 0)) == nil)
        #expect(normalizedVectorOrNil(SIMD3<Double>(.nan, 1, 0)) == nil)
        #expect(normalizedVectorOrNil(SIMD3<Double>(0, 0, 5)) == SIMD3(0, 0, 1))
    }

    // MARK: - The call sites that neither guarded nor fed OCCT (#2759 audit)

    @Test("an absolute construction axis or plane with a zero or non-finite vector is degenerate")
    func absoluteEntitiesRefuseZeroVectors() {
        // OCCT: `gp_Dir(gp_Vec)` raises Standard_ConstructionError on a zero-norm vector
        // (gp_Dir.hxx), and OCCT's callers test the magnitude first
        // (PrsDim_AngleDimension::IsValidPoints, PrsDim_AngleDimension.cxx:1166).
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("setup nil")
            return
        }
        for vector in [SIMD3<Double>.zero, SIMD3(.infinity, 0, 0), SIMD3(.nan, 0, 1)] {
            if case .failure(.degenerate) = graph.resolve(
                ConstructionAxis.absolute(origin: .zero, direction: vector))
            {
            } else {
                Issue.record("axis: expected .degenerate for \(vector)")
            }
            if case .failure(.degenerate) = graph.resolve(
                ConstructionPlane.absolute(origin: .zero, normal: vector))
            {
            } else {
                Issue.record("plane: expected .degenerate for \(vector)")
            }
        }
        if case .success(let resolved) = graph.resolve(
            ConstructionAxis.absolute(origin: .zero, direction: SIMD3(0, 0, 4)))
        {
            #expect(resolved.direction == SIMD3(0, 0, 1))
        } else {
            Issue.record("a valid direction must still resolve")
        }
    }

    @Test("a hand-built placement from a zero normal is NaN, the documented IEEE result")
    func placementFromZeroNormalIsNaN() {
        // `resolve` refuses such a normal before a Placement is built (above); the initialiser
        // itself stays IEEE division and says so in its documentation.
        let placement = Placement(origin: .zero, normal: .zero)
        #expect(placement.zAxis.x.isNaN)
        #expect(placement.zAxis.y.isNaN)
        #expect(placement.zAxis.z.isNaN)
        // The origin is stored as given, and a valid normal does not take the NaN path: the
        // same initialiser normalises (0, 0, 4) to the unit z axis.
        #expect(placement.origin == .zero)
        let valid = Placement(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 4))
        #expect(valid.zAxis == SIMD3(0, 0, 1))
        #expect(valid.origin == SIMD3(1, 2, 3))
    }

    @Test(
        "an angular dimension follows PrsDim_AngleDimension: invalid points give isValid false, value 0"
    )
    func angularDimensionInvalidPoints() {
        // PrsDim_AngleDimension::IsValidPoints (PrsDim_AngleDimension.cxx:1166): both rays longer
        // than Precision::Confusion (1e-7) and the angle above Precision::Angular (1e-12);
        // ComputeValue (555-560) returns 0.0 for an invalid geometry.
        func angular(_ r1: SIMD2<Double>, _ r2: SIMD2<Double>) -> DrawingDimension.Angular {
            DrawingDimension.Angular(vertex: .zero, ray1: r1, ray2: r2)
        }
        let right = angular(SIMD2(1, 0), SIMD2(0, 1))
        #expect(right.isValid)
        #expect(abs(right.value - .pi / 2) < 1e-12)
        for bad in [
            angular(.zero, SIMD2(0, 1)),  // ray1 starts at the vertex
            angular(SIMD2(1, 0), SIMD2(1e-9, 0)),  // shorter than Precision::Confusion
            angular(SIMD2(1, 0), SIMD2(0, 1e-9)),  // perpendicular, but still too short
            angular(SIMD2(1, 0), SIMD2(2, 0)),  // parallel: angle 0, below Precision::Angular
            angular(SIMD2(.nan, 0), SIMD2(0, 1)),
            angular(SIMD2(.infinity, 0), SIMD2(0, 1)),
        ] {
            #expect(!bad.isValid)
            #expect(bad.value == 0)
        }
        // A reflex-free opposite pair is a valid angle of pi.
        #expect(abs(angular(SIMD2(1, 0), SIMD2(-1, 0)).value - .pi) < 1e-12)
    }

    @Test("a cutting-plane line refuses a zero or non-finite arrow direction")
    func cuttingPlaneLineRefusesZeroArrow() {
        func make(_ arrow: SIMD2<Double>) -> DrawingAnnotation.CuttingPlaneLine? {
            DrawingAnnotation.CuttingPlaneLine(
                label: "A", traceStart: SIMD2(0, 0), traceEnd: SIMD2(10, 0), arrowDirection: arrow)
        }
        #expect(make(.zero) == nil)
        #expect(make(SIMD2(.nan, 1)) == nil)
        #expect(make(SIMD2(.infinity, 0)) == nil)
        #expect(make(SIMD2(0, 3))?.arrowDirection == SIMD2(0, 1))
    }

    @Test("a break line between coincident points is empty, not NaN")
    func breakLineCoincidentPoints() {
        #expect(DrawingAnnotation.breakLine(from: SIMD2(3, 3), to: SIMD2(3, 3)).isEmpty)
        #expect(!DrawingAnnotation.breakLine(from: SIMD2(0, 0), to: SIMD2(10, 0)).isEmpty)
    }

    @Test("auto centrelines, centremarks and dimensions with a zero view direction add nothing")
    func autoFeaturesRefuseZeroViewDirection() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let drawing = Drawing.topView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        for direction in [SIMD3<Double>.zero, SIMD3(.nan, 0, 1)] {
            #expect(drawing.addAutoCentrelines(from: cyl, viewDirection: direction).added.isEmpty)
            #expect(drawing.addAutoCentermarks(from: cyl, viewDirection: direction).added.isEmpty)
            let dims = drawing.addAutoDimensions(from: cyl, viewDirection: direction)
            #expect(dims.added.isEmpty)
            #expect(dims.skipped.count == 1)
        }
    }

    @Test("axis-taking constructors refuse a zero axis instead of building from NaNs")
    func zeroAxisConstructorsReturnNil() {
        guard let profile = Wire.rectangle(width: 4, height: 4) else {
            Issue.record("setup nil")
            return
        }
        #expect(Shape.extrude(profile: profile, direction: .zero, length: 5) == nil)
        #expect(Wire.helix(axis: .zero, radius: 5, pitch: 2, turns: 3) == nil)
        #expect(
            Shape.helicalSweep(
                profiles: [profile], axisOrigin: .zero, axisDirection: .zero,
                radius: 5, pitch: 2, turns: 3) == nil)
    }

    @Test("threaded shafts and rods refuse a zero axis")
    func threadedFeaturesRefuseZeroAxis() {
        guard let shank = Shape.cylinder(radius: 6, height: 20),
            let profile = ThreadProfile(vertices: [
                .init(axial: 0.00, depth: 1), .init(axial: 0.15, depth: 1),
                .init(axial: 0.35, depth: 0), .init(axial: 0.65, depth: 0),
                .init(axial: 0.85, depth: 1), .init(axial: 1.00, depth: 1),
            ])
        else {
            Issue.record("setup nil")
            return
        }
        let spec = ThreadSpec(form: .square, nominalDiameter: 12, pitch: 2.0)
        for axis in [SIMD3<Double>.zero, SIMD3(.nan, 0, 1)] {
            #expect(
                shank.threadedShaft(axisOrigin: .zero, axisDirection: axis, spec: spec, length: 10)
                    == nil)
            #expect(
                Shape.threadedRod(
                    customProfile: profile, nominalDiameter: 12, pitch: 4, cutDepth: 3,
                    length: 12, axisDirection: axis) == nil)
        }
    }

    // MARK: - Matrix value types

    @Test("Matrix4x4F indexes by column, like simd_float4x4")
    func matrix4Indexing() {
        let m = Matrix4x4F(
            SIMD4(1, 2, 3, 4), SIMD4(5, 6, 7, 8), SIMD4(9, 10, 11, 12), SIMD4(13, 14, 15, 16))
        #expect(m[0] == SIMD4(1, 2, 3, 4))
        #expect(m[2][1] == 10)
        #expect(m.columns.3 == SIMD4(13, 14, 15, 16))
        #expect(m.columnMajorElements == (1...16).map { Float($0) })
        var edited = m
        edited[1] = SIMD4(0, 0, 0, 0)
        edited.columns.0.x = 99
        #expect(edited.column1 == SIMD4(0, 0, 0, 0))
        #expect(edited[0].x == 99)
        #expect(edited != m)
        #expect(m == m)
    }

    @Test("Matrix4x4F identity and zero are distinct, and the determinant is right")
    func matrix4Determinant() {
        #expect(Matrix4x4F.identity.determinant == 1)
        #expect(Matrix4x4F.zero.determinant == 0)
        #expect(Matrix4x4F.identity != Matrix4x4F.zero)
        // Non-symmetric, with a hand-computed determinant: the rows are (2,1,0,0), (0,3,1,0),
        // (1,0,1,0), (0,0,0,1), so det = 2*(3*1 - 1*0) - 1*(0*1 - 1*1) = 7.
        let m = Matrix4x4F(
            SIMD4(2, 0, 1, 0), SIMD4(1, 3, 0, 0), SIMD4(0, 1, 1, 0), SIMD4(0, 0, 0, 1))
        #expect(abs(m.determinant - 7) < 1e-6)
        // det(A) == det(Aᵀ): reading the columns as rows must not change it.
        let t = Matrix4x4F(
            SIMD4(m[0].x, m[1].x, m[2].x, m[3].x), SIMD4(m[0].y, m[1].y, m[2].y, m[3].y),
            SIMD4(m[0].z, m[1].z, m[2].z, m[3].z), SIMD4(m[0].w, m[1].w, m[2].w, m[3].w))
        #expect(abs(t.determinant - m.determinant) < 1e-6)
    }

    @Test("Matrix3x3D indexes by column, like simd_double3x3")
    func matrix3Indexing() {
        // Non-symmetric on purpose: a symmetric matrix cannot tell a column subscript from a row one.
        let m = Matrix3x3D(SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9))
        #expect(m[0] == SIMD3(1, 2, 3))
        #expect(m[1][0] == 4)
        #expect(m[2][1] == 8)
        #expect(m.columnMajorElements == [1, 2, 3, 4, 5, 6, 7, 8, 9])
        #expect(Matrix3x3D.identity.determinant == 1)
        #expect(Matrix3x3D.zero.determinant == 0)
        let n = Matrix3x3D(SIMD3(2, 0, 0), SIMD3(1, 3, 0), SIMD3(4, 5, 6))
        #expect(n.determinant == 36)
    }

    @Test("ShapeProperties.momentOfInertia keeps the column layout of the old simd_double3x3")
    func inertiaLayout() {
        guard let box = Shape.box(width: 2, height: 3, depth: 4),
            let p = box.properties()
        else {
            Issue.record("setup nil")
            return
        }
        // A solid box about its centre: Ixx = m(h^2 + d^2)/12 and so on, off-diagonals zero.
        let m = p.mass
        #expect(abs(p.momentOfInertia[0][0] - m * (9 + 16) / 12) < 1e-9 * m)
        #expect(abs(p.momentOfInertia[1][1] - m * (4 + 16) / 12) < 1e-9 * m)
        #expect(abs(p.momentOfInertia[2][2] - m * (4 + 9) / 12) < 1e-9 * m)
    }
}
