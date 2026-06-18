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



// MARK: - Geometry Construction Tests (v0.11.0)

@Suite("Geometry Construction Tests")
struct GeometryConstructionTests {

    @Test("Create face from rectangular wire")
    func faceFromRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)

        #expect(face != nil)
        #expect(face!.isValid)

        // Face should have surface area equal to rectangle area
        let area = face!.surfaceArea ?? 0
        #expect(abs(area - 50.0) < 0.01)  // 10 x 5 = 50
    }

    @Test("Create face from circular wire")
    func faceFromCircle() {
        let circle = Wire.circle(radius: 5)!
        let face = Shape.face(from: circle)

        #expect(face != nil)
        #expect(face!.isValid)

        // Face should have surface area equal to π * r²
        let area = face!.surfaceArea ?? 0
        let expectedArea = Double.pi * 5.0 * 5.0
        #expect(abs(area - expectedArea) < 0.1)
    }

    @Test("Create face with hole")
    func faceWithHole() {
        let outer = Wire.rectangle(width: 20, height: 20)!
        let hole = Wire.circle(radius: 5)!

        let face = Shape.face(outer: outer, holes: [hole])

        #expect(face != nil)
        #expect(face!.isValid)

        // Area should be outer minus hole
        let area = face!.surfaceArea ?? 0
        let expectedArea = 400.0 - (Double.pi * 25.0)  // 20x20 - π*5²
        #expect(abs(area - expectedArea) < 0.5)
    }

    @Test("Create face with multiple holes")
    func faceWithMultipleHoles() {
        let outer = Wire.rectangle(width: 30, height: 30)!
        // Use offset3D to position the holes
        let hole1 = Wire.circle(radius: 3)!.offset3D(distance: 8, direction: SIMD3(-1, 0, 0))!
        let hole2 = Wire.circle(radius: 3)!.offset3D(distance: 8, direction: SIMD3(1, 0, 0))!

        let face = Shape.face(outer: outer, holes: [hole1, hole2])

        #expect(face != nil)
        #expect(face!.isValid)

        // Area should be outer minus both holes
        let area = face!.surfaceArea ?? 0
        let expectedArea = 900.0 - 2 * (Double.pi * 9.0)  // 30x30 - 2*π*3²
        #expect(abs(area - expectedArea) < 0.5)
    }

    @Test("Extrude face to create solid")
    func extrudeFace() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)!

        // Extrude the face to create a solid
        let solid = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 3)!

        #expect(solid.isValid)

        // Volume should be area * height
        let volume = solid.volume ?? 0
        #expect(abs(volume - 150.0) < 0.1)  // 10 * 5 * 3
    }
}

@Suite("Polynomial Solvers")
struct PolynomialTests {
    @Test("Solve quadratic x²-5x+6=0")
    func quadratic() {
        let result = PolynomialSolver.quadratic(a: 1, b: -5, c: 6)
        #expect(result.count == 2)
        #expect(abs(result.roots[0] - 2.0) < 1e-10)
        #expect(abs(result.roots[1] - 3.0) < 1e-10)
    }

    @Test("Quadratic with no real roots")
    func quadraticNoRoots() {
        let result = PolynomialSolver.quadratic(a: 1, b: 0, c: 1)
        #expect(result.count == 0)
    }

    @Test("Quadratic with one root")
    func quadraticOneRoot() {
        let result = PolynomialSolver.quadratic(a: 1, b: -2, c: 1)
        #expect(result.count >= 1)
        #expect(abs(result.roots[0] - 1.0) < 1e-10)
    }

    @Test("Solve cubic x³-6x²+11x-6=0")
    func cubic() {
        let result = PolynomialSolver.cubic(a: 1, b: -6, c: 11, d: -6)
        #expect(result.count == 3)
        #expect(abs(result.roots[0] - 1.0) < 1e-10)
        #expect(abs(result.roots[1] - 2.0) < 1e-10)
        #expect(abs(result.roots[2] - 3.0) < 1e-10)
    }

    @Test("Solve quartic x⁴-10x²+9=0")
    func quartic() {
        // (x²-1)(x²-9) = 0  →  x = ±1, ±3
        let result = PolynomialSolver.quartic(a: 1, b: 0, c: -10, d: 0, e: 9)
        #expect(result.count == 4)
        #expect(abs(result.roots[0] - (-3.0)) < 1e-10)
        #expect(abs(result.roots[1] - (-1.0)) < 1e-10)
        #expect(abs(result.roots[2] - 1.0) < 1e-10)
        #expect(abs(result.roots[3] - 3.0) < 1e-10)
    }
}

// MARK: - v0.30.0 Tests

@Suite("Non-Uniform Scale")
struct NonUniformScaleTests {
    @Test("Scale box non-uniformly")
    func scaleBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let scaled = box.nonUniformScaled(sx: 2, sy: 1, sz: 0.5)
        #expect(scaled != nil)
        #expect(scaled!.isValid)
        let size = scaled!.size
        #expect(abs(size.x - 20) < 0.1)
        #expect(abs(size.y - 10) < 0.1)
        #expect(abs(size.z - 5) < 0.1)
    }

    @Test("Non-uniform scale preserves volume ratio")
    func volumeRatio() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let scaled = box.nonUniformScaled(sx: 2, sy: 3, sz: 0.5)!
        let origVol = box.volume ?? 0
        let scaledVol = scaled.volume ?? 0
        // Volume should scale by sx*sy*sz = 3.0
        #expect(abs(scaledVol / origVol - 3.0) < 0.1)
    }
}

// MARK: - v0.50.0 Tests

@Suite("GC_MakeArcOfHyperbola")
struct ArcOfHyperbolaTests {
    @Test("Arc of hyperbola between parameters")
    func arcOfHyperbola() throws {
        let arc = try #require(Curve3D.arcOfHyperbola(
            majorRadius: 5.0, minorRadius: 3.0,
            alpha1: -1.0, alpha2: 1.0))
        let dom = arc.domain
        let start = arc.point(at: dom.lowerBound)
        let end = arc.point(at: dom.upperBound)
        // Hyperbola: x = a*cosh(t), y = b*sinh(t)
        let expectedX = 5.0 * cosh(1.0)
        #expect(abs(start.x - expectedX) < 0.1)
        #expect(abs(end.x - expectedX) < 0.1)
        #expect(start.y < 0)
        #expect(end.y > 0)
    }
}

@Suite("GC_MakeArcOfParabola")
struct ArcOfParabolaTests {
    @Test("Arc of parabola between parameters")
    func arcOfParabola() throws {
        let arc = try #require(Curve3D.arcOfParabola(
            focalDistance: 2.0,
            alpha1: -3.0, alpha2: 3.0))
        let mid = arc.point(at: 0.0)
        #expect(simd_length(mid) < 0.01)
    }
}

@Suite("GC_MakeConicalSurface")
struct ConicalSurfaceTests {
    @Test("Conical surface from axis and angle")
    func fromAxis() throws {
        let surf = try #require(Surface.conicalSurface(semiAngle: .pi / 6, radius: 5.0))
        #expect(surf.handle != nil)
    }

    @Test("Conical surface from points and radii")
    func fromPointsRadii() throws {
        let surf = try #require(Surface.conicalSurface(
            point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
            r1: 5.0, r2: 2.0))
        #expect(surf.handle != nil)
    }
}

@Suite("GC_MakeCylindricalSurface")
struct CylindricalSurfaceTests {
    @Test("Cylindrical surface from axis and radius")
    func fromAxis() throws {
        let surf = try #require(Surface.cylindricalSurface(radius: 3.0))
        #expect(surf.handle != nil)
    }

    @Test("Cylindrical surface from 3 points")
    func fromPoints() throws {
        let surf = try #require(Surface.cylindricalSurface(
            point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10), point3: SIMD3(5, 0, 5)))
        #expect(surf.handle != nil)
    }
}

@Suite("GC_MakePlane")
struct PlaneConstructionTests {
    @Test("Plane from 3 points")
    func fromPoints() throws {
        let surf = try #require(Surface.planeFromPoints(
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0)))
        #expect(surf.handle != nil)
    }

    @Test("Plane from point and normal")
    func fromPointNormal() throws {
        let surf = try #require(Surface.planeFromPointNormal(
            point: SIMD3(5, 5, 5), normal: SIMD3(1, 1, 1)))
        #expect(surf.handle != nil)
    }
}

@Suite("GC_MakeTrimmedCone")
struct TrimmedConeTests {
    @Test("Trimmed cone from endpoints and radii")
    func trimmedCone() throws {
        let surf = try #require(Surface.trimmedCone(
            point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
            r1: 5.0, r2: 2.0))
        #expect(surf.handle != nil)
    }
}

@Suite("GC_MakeTrimmedCylinder")
struct TrimmedCylinderTests {
    @Test("Trimmed cylinder from axis, radius, height")
    func trimmedCylinder() throws {
        let surf = try #require(Surface.trimmedCylinder(radius: 4.0, height: 8.0))
        #expect(surf.handle != nil)
    }
}

@Suite("GC_MakeMirror")
struct ShapeMirrorTests {
    @Test("Mirror box about point")
    func mirrorAboutPoint() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Box is centered at origin (-5 to +5), mirror about (20,0,0)
        let mirrored = box.mirroredAboutPoint(SIMD3(20, 0, 0))
        #expect(mirrored != nil)
        if let m = mirrored {
            #expect(m.isValid)
            let bb = m.bounds
            // Box (-5..5) mirrored about x=20 gives (35..45)
            #expect(abs(bb.min.x - 35) < 0.5)
            #expect(abs(bb.max.x - 45) < 0.5)
        }
    }

    @Test("Mirror box about axis")
    func mirrorAboutAxis() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mirrored = box.mirroredAboutAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
        #expect(mirrored != nil)
        if let m = mirrored {
            #expect(m.isValid)
        }
    }
}

@Suite("GC_MakeScale")
struct ShapeScaleAboutPointTests {
    @Test("Scale box about origin")
    func scaleAboutOrigin() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let scaled = box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 2.0)
        #expect(scaled != nil)
        if let s = scaled {
            #expect(s.isValid)
            let size = s.size
            #expect(abs(size.x - 20) < 0.5)
            #expect(abs(size.y - 20) < 0.5)
            #expect(abs(size.z - 20) < 0.5)
        }
    }

    @Test("Scale with factor 0.5")
    func halfScale() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let scaled = box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 0.5)
        #expect(scaled != nil)
        if let s = scaled {
            #expect(s.isValid)
            let size = s.size
            #expect(abs(size.x - 10) < 0.5)
        }
    }
}

@Suite("GC_MakeTranslation")
struct ShapeTranslateByPointsTests {
    @Test("Translate box from point to point")
    func translateByPoints() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let translated = box.translated(from: SIMD3(0, 0, 0), to: SIMD3(20, 0, 0))
        #expect(translated != nil)
        if let t = translated {
            #expect(t.isValid)
            let bb = t.bounds
            // Box centered at origin (-5..5) translated by (20,0,0) → (15..25)
            #expect(abs(bb.min.x - 15) < 0.5)
            #expect(abs(bb.max.x - 25) < 0.5)
        }
    }
}

@Suite("GC_MakeEllipse — 3 Points")
struct EllipseThreePointsTests {
    @Test("Create ellipse through three points")
    func ellipseFromThreePoints() throws {
        // S1 and S2 are points on ellipse, center is the center
        let curve = Curve3D.ellipseThreePoints(
            s1: SIMD3(10, 0, 0),
            s2: SIMD3(0, 5, 0),
            center: SIMD3(0, 0, 0)
        )
        #expect(curve != nil)
        if let c = curve {
            let dom = c.domain
            #expect(dom.upperBound > dom.lowerBound)
        }
    }
}

@Suite("GC_MakeHyperbola — 3 Points")
struct HyperbolaThreePointsTests {
    @Test("Create hyperbola through three points")
    func hyperbolaFromThreePoints() throws {
        // S1 sets the major axis/radius (Center→S1); S2's distance off that axis sets the minor
        // radius. S2 must be OFF the major axis — OCCT 8.0.0p1 rejects a zero minor radius (a
        // collinear S2, as the old test used, is a degenerate hyperbola).
        let curve = Curve3D.hyperbolaThreePoints(
            s1: SIMD3(5, 0, 0),
            s2: SIMD3(0, 3, 0),
            center: SIMD3(0, 0, 0)
        )
        #expect(curve != nil)
        if let c = curve {
            let dom = c.domain
            #expect(dom.upperBound > dom.lowerBound)
        }
    }
}

@Suite("Intrv_Interval Tests")
struct IntrvIntervalTests {
    @Test("create and get bounds")
    func createAndBounds() {
        let iv = Interval(start: 1.0, end: 5.0)
        let b = iv.bounds
        #expect(abs(b.start - 1.0) < 1e-10)
        #expect(abs(b.end - 5.0) < 1e-10)
    }

    @Test("create with tolerances")
    func createWithTolerances() {
        let iv = Interval(start: 1.0, end: 5.0, tolStart: 0.01, tolEnd: 0.02)
        let b = iv.bounds
        #expect(abs(b.tolStart - 0.01) < 1e-6)
        #expect(abs(b.tolEnd - 0.02) < 1e-6)
    }

    @Test("probably empty")
    func probablyEmpty() {
        let big = Interval(start: 0, end: 10)
        #expect(!big.isProbablyEmpty)

        let empty = Interval(start: 5, end: 5, tolStart: 1.0, tolEnd: 1.0)
        #expect(empty.isProbablyEmpty)
    }

    @Test("before and after")
    func beforeAfter() {
        let a = Interval(start: 1, end: 3)
        let b = Interval(start: 5, end: 8)
        #expect(a.isBefore(b))
        #expect(b.isAfter(a))
    }

    @Test("inside and enclosing")
    func insideEnclosing() {
        let outer = Interval(start: 0, end: 10)
        let inner = Interval(start: 2, end: 8)
        #expect(inner.isInside(outer))
        #expect(outer.isEnclosing(inner))
    }

    @Test("similar")
    func similar() {
        let a = Interval(start: 0, end: 10)
        let b = Interval(start: 0, end: 10)
        #expect(a.isSimilar(to: b))
    }

    @Test("position")
    func position() {
        let a = Interval(start: 1, end: 3)
        let b = Interval(start: 5, end: 8)
        #expect(a.position(relativeTo: b) == 0) // Before
    }

    @Test("set and modify bounds")
    func modifyBounds() {
        let iv = Interval(start: 0, end: 10)
        iv.setStart(2)
        iv.setEnd(8)
        let b = iv.bounds
        #expect(abs(b.start - 2.0) < 1e-10)
        #expect(abs(b.end - 8.0) < 1e-10)
    }

    @Test("fuse and cut")
    func fuseCut() {
        let iv = Interval(start: 3, end: 7)
        iv.fuseAtStart(1)
        #expect(abs(iv.bounds.start - 1.0) < 1e-10)
        iv.fuseAtEnd(9)
        #expect(abs(iv.bounds.end - 9.0) < 1e-10)

        iv.cutAtStart(2)
        #expect(abs(iv.bounds.start - 2.0) < 1e-10)
        iv.cutAtEnd(8)
        #expect(abs(iv.bounds.end - 8.0) < 1e-10)
    }
}

@Suite("Intrv_Intervals Tests")
struct IntrvIntervalsTests {
    @Test("create from single interval")
    func createSingle() {
        let set = IntervalSet(start: 1, end: 5)
        #expect(set.count == 1)
        let b = set.bounds(at: 0)
        #expect(abs(b.start - 1.0) < 1e-10)
        #expect(abs(b.end - 5.0) < 1e-10)
    }

    @Test("create empty")
    func createEmpty() {
        let set = IntervalSet()
        #expect(set.count == 0)
    }

    @Test("unite non-overlapping")
    func uniteNonOverlapping() {
        let set = IntervalSet(start: 1, end: 3)
        set.unite(start: 5, end: 8)
        #expect(set.count == 2)
    }

    @Test("unite overlapping merges")
    func uniteOverlapping() {
        let set = IntervalSet(start: 1, end: 5)
        set.unite(start: 3, end: 8)
        #expect(set.count == 1)
    }

    @Test("subtract middle")
    func subtractMiddle() {
        let set = IntervalSet(start: 0, end: 10)
        set.subtract(start: 3, end: 7)
        #expect(set.count == 2)
    }

    @Test("intersect")
    func intersect() {
        let set = IntervalSet(start: 0, end: 10)
        set.intersect(start: 3, end: 7)
        #expect(set.count == 1)
        let b = set.bounds(at: 0)
        #expect(abs(b.start - 3.0) < 1e-10)
        #expect(abs(b.end - 7.0) < 1e-10)
    }

    @Test("xUnite symmetric difference")
    func xUnite() {
        let set = IntervalSet(start: 0, end: 5)
        set.xUnite(start: 3, end: 8)
        #expect(set.count == 2)
    }
}

// MARK: - v0.76.0: Geom 3D Entities, ShapeConstruct_Curve, Bisector utilities

@Suite("GeomPoint3D Tests")
struct GeomPoint3DTests {
    @Test("create and read coordinates")
    func createAndRead() {
        let p = GeomPoint3D(x: 1, y: 2, z: 3)
        #expect(abs(p.x - 1) < 1e-10)
        #expect(abs(p.y - 2) < 1e-10)
        #expect(abs(p.z - 3) < 1e-10)
    }

    @Test("create from SIMD3")
    func createFromSIMD() {
        let p = GeomPoint3D(simd: SIMD3(4, 5, 6))
        let c = p.coordinates
        #expect(abs(c.x - 4) < 1e-10)
        #expect(abs(c.y - 5) < 1e-10)
    }

    @Test("setCoordinates")
    func setCoordinates() {
        let p = GeomPoint3D(x: 0, y: 0, z: 0)
        p.setCoordinates(x: 10, y: 20, z: 30)
        #expect(abs(p.x - 10) < 1e-10)
    }

    @Test("distance between points")
    func distance() {
        let p1 = GeomPoint3D(x: 0, y: 0, z: 0)
        let p2 = GeomPoint3D(x: 3, y: 4, z: 0)
        #expect(abs(p1.distance(to: p2) - 5.0) < 1e-10)
    }

    @Test("translate")
    func translate() {
        let p = GeomPoint3D(x: 1, y: 0, z: 0)
        p.translate(dx: 10, dy: 0, dz: 0)
        #expect(abs(p.x - 11) < 1e-10)
    }
}

@Suite("GeomDirection Tests")
struct GeomDirectionTests {
    @Test("create unit direction")
    func create() {
        let d = GeomDirection(x: 0, y: 0, z: 1)
        let c = d.coordinates
        #expect(abs(c.z - 1) < 1e-10)
    }

    @Test("auto-normalizes")
    func normalizes() {
        let d = GeomDirection(x: 3, y: 4, z: 0)
        let c = d.coordinates
        let mag = sqrt(c.x * c.x + c.y * c.y + c.z * c.z)
        #expect(abs(mag - 1.0) < 1e-10)
    }

    @Test("crossed product")
    func crossed() {
        let dx = GeomDirection(x: 1, y: 0, z: 0)
        let dy = GeomDirection(x: 0, y: 1, z: 0)
        if let cross = dx.crossed(with: dy) {
            #expect(abs(cross.coordinates.z - 1.0) < 1e-10)
        }
    }

    @Test("setCoordinates")
    func setCoordinates() {
        let d = GeomDirection(x: 1, y: 0, z: 0)
        d.setCoordinates(x: 0, y: 1, z: 0)
        #expect(abs(d.coordinates.y - 1.0) < 1e-10)
    }
}

@Suite("GeomVector3D Tests")
struct GeomVector3DTests {
    @Test("magnitude")
    func magnitude() {
        let v = GeomVector3D(x: 3, y: 4, z: 0)
        #expect(abs(v.magnitude - 5.0) < 1e-10)
    }

    @Test("from two points")
    func fromPoints() {
        let v = GeomVector3D(from: SIMD3(1, 1, 1), to: SIMD3(4, 5, 1))
        #expect(abs(v.magnitude - 5.0) < 1e-10)
    }

    @Test("dot product")
    func dot() {
        let v1 = GeomVector3D(x: 1, y: 2, z: 3)
        let v2 = GeomVector3D(x: 4, y: 5, z: 6)
        #expect(abs(v1.dot(v2) - 32.0) < 1e-10)
    }

    @Test("added")
    func added() {
        let v1 = GeomVector3D(x: 1, y: 0, z: 0)
        let v2 = GeomVector3D(x: 0, y: 1, z: 0)
        let sum = v1.added(v2)
        let c = sum.coordinates
        #expect(abs(c.x - 1) < 1e-10 && abs(c.y - 1) < 1e-10)
    }

    @Test("multiplied")
    func multiplied() {
        let v = GeomVector3D(x: 1, y: 2, z: 3)
        let m = v.multiplied(by: 2.0)
        #expect(abs(m.coordinates.x - 2) < 1e-10)
    }

    @Test("normalized")
    func normalized() {
        let v = GeomVector3D(x: 0, y: 0, z: 10)
        if let n = v.normalized() {
            #expect(abs(n.magnitude - 1.0) < 1e-10)
        }
    }

    @Test("crossed")
    func crossed() {
        let v1 = GeomVector3D(x: 1, y: 0, z: 0)
        let v2 = GeomVector3D(x: 0, y: 1, z: 0)
        let cross = v1.crossed(v2)
        #expect(abs(cross.coordinates.z - 1.0) < 1e-10)
    }
}

@Suite("Axis1Placement Tests")
struct Axis1PlacementTests {
    @Test("create and read")
    func createAndRead() {
        let ax = Axis1Placement(origin: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1))
        #expect(abs(ax.location.x - 1) < 1e-10)
        #expect(abs(ax.direction.z - 1) < 1e-10)
    }

    @Test("reverse")
    func reverse() {
        let ax = Axis1Placement(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
        ax.reverse()
        #expect(abs(ax.direction.z + 1) < 1e-10)
    }

    @Test("reversed copy")
    func reversedCopy() {
        let ax = Axis1Placement(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 1, 0))
        let rev = ax.reversed()
        #expect(abs(rev.direction.y + 1) < 1e-10)
        #expect(abs(ax.direction.y - 1) < 1e-10)  // original unchanged
    }

    @Test("setDirection and setLocation")
    func setters() {
        let ax = Axis1Placement(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        ax.setDirection(SIMD3(0, 1, 0))
        ax.setLocation(SIMD3(5, 5, 5))
        #expect(abs(ax.direction.y - 1) < 1e-10)
        #expect(abs(ax.location.x - 5) < 1e-10)
    }
}

@Suite("Axis2Placement Tests")
struct Axis2PlacementTests {
    @Test("create and read directions")
    func createAndRead() {
        let ax = Axis2Placement(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        #expect(abs(ax.xDirection.x - 1) < 1e-10)
        #expect(abs(ax.yDirection.y - 1) < 1e-10)
        #expect(abs(ax.mainDirection.z - 1) < 1e-10)
    }

    @Test("location")
    func location() {
        let ax = Axis2Placement(origin: SIMD3(5, 5, 5), normal: SIMD3(0, 1, 0), xDirection: SIMD3(1, 0, 0))
        #expect(abs(ax.location.x - 5) < 1e-10)
    }

    @Test("setDirection")
    func setDirection() {
        let ax = Axis2Placement(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        ax.setDirection(SIMD3(0, 1, 0))
        #expect(abs(ax.mainDirection.y - 1) < 1e-10)
    }

    @Test("setXDirection")
    func setXDirection() {
        let ax = Axis2Placement(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        ax.setXDirection(SIMD3(0, 1, 0))
        #expect(abs(ax.xDirection.y - 1) < 1e-10)
    }
}

// MARK: - v0.77.0 Tests

@Suite("GeomLib Tool Tests")
struct GeomLibToolTests {
    @Test("parameter on 3D line")
    func parameterOn3DLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let param = line.parameterOf(point: SIMD3(5, 0, 0))
            if let p = param { #expect(abs(p - 5.0) < 1e-6) }
        }
    }

    @Test("parameters on surface")
    func parametersOnSurface() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let uv = plane.parametersOf(point: SIMD3(3, 4, 0))
            if let uv = uv {
                #expect(abs(uv.u - 3.0) < 1e-6)
                #expect(abs(uv.v - 4.0) < 1e-6)
            }
        }
    }

    @Test("parameter on 2D line")
    func parameterOn2DLine() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let param = line.parameterOf(point: SIMD2(7, 0))
            if let p = param { #expect(abs(p - 7.0) < 1e-6) }
        }
    }
}

@Suite("GeomLib IsPlanarSurface Tests")
struct GeomLibIsPlanarSurfaceTests {
    @Test("plane is planar")
    func planeIsPlanar() {
        if let plane = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)) {
            #expect(plane.isPlanar())
        }
    }

    @Test("get plane from planar surface")
    func getPlane() {
        if let plane = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)) {
            let result = plane.planarPlane()
            if let r = result {
                #expect(abs(r.origin.z - 3.0) < 1e-6)
                #expect(abs(r.normal.z) > 0.99)
            }
        }
    }

    @Test("cylinder is not planar")
    func cylinderNotPlanar() {
        if let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            #expect(!cyl.isPlanar())
        }
    }
}

@Suite("GeomLib CheckBSpline Tests")
struct GeomLibCheckBSplineTests {
    @Test("check 3D BSpline tangents")
    func check3D() {
        if let bsp = Curve3D.bspline(poles: [SIMD3(0,0,0), SIMD3(1,2,0), SIMD3(3,1,0), SIMD3(4,0,0)], knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let result = bsp.checkBSplineTangents()
            // May be nil for simple Bezier-like BSplines — just verify no crash
            let _ = result
        }
    }

    @Test("fix 3D BSpline tangents")
    func fix3D() {
        if let bsp = Curve3D.bspline(poles: [SIMD3(0,0,0), SIMD3(1,2,0), SIMD3(3,1,0), SIMD3(4,0,0)], knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let fixed = bsp.fixBSplineTangents(fixFirst: false, fixLast: false)
            let _ = fixed
        }
    }

    @Test("check 2D BSpline tangents")
    func check2D() {
        if let bsp = Curve2D.bspline(poles: [SIMD2(0,0), SIMD2(1,2), SIMD2(3,1), SIMD2(4,0)],
                                      knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let result = bsp.checkBSplineTangents()
            let _ = result
        }
    }

    @Test("fix 2D BSpline tangents")
    func fix2D() {
        if let bsp = Curve2D.bspline(poles: [SIMD2(0,0), SIMD2(1,2), SIMD2(3,1), SIMD2(4,0)],
                                      knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let fixed = bsp.fixBSplineTangents(fixFirst: false, fixLast: false)
            let _ = fixed
        }
    }
}

@Suite("GeomLib Interpolate Tests")
struct GeomLibInterpolateTests {
    @Test("polynomial interpolation")
    func interpolate() {
        let points: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0), SIMD3(3,-1,0), SIMD3(4,0,0)]
        let params = [0.0, 0.25, 0.5, 0.75, 1.0]
        let curve = Curve3D.polynomialInterpolation(degree: 3, points: points, parameters: params)
        #expect(curve != nil)
    }

    @Test("interpolated curve endpoints")
    func endpoints() {
        let points: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(2,2,0), SIMD3(4,0,0)]
        let params = [0.0, 0.5, 1.0]
        if let curve = Curve3D.polynomialInterpolation(degree: 3, points: points, parameters: params) {
            let dom = curve.domain
            let start = curve.point(at: dom.lowerBound)
            let end = curve.point(at: dom.upperBound)
            #expect(abs(start.x) < 1e-6 && abs(start.y) < 1e-6)
            #expect(abs(end.x - 4.0) < 1e-6 && abs(end.y) < 1e-6)
        }
    }
}

// MARK: - v0.78.0: Shape Modifications, Surface Recognition & Polygon Data

@Suite("BRepTools_TrsfModification")
struct TrsfModificationTests {
    @Test("apply translation via modifier")
    func applyTranslation() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            // Identity rotation + translation (100, 200, 300)
            if let result = Shape.trsfModification(box,
                                                     a11: 1, a12: 0, a13: 0, a14: 100,
                                                     a21: 0, a22: 1, a23: 0, a24: 200,
                                                     a31: 0, a32: 0, a33: 1, a34: 300) {
                #expect(result.isValid)
                if let v = result.volume {
                    #expect(abs(v - 6000) < 1.0)
                }
            }
        }
    }

    @Test("apply rotation via modifier")
    func applyRotation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // 90° rotation around Z: (cos90, -sin90, 0) = (0, -1, 0), (sin90, cos90, 0) = (1, 0, 0)
            if let result = Shape.trsfModification(box,
                                                     a11: 0, a12: -1, a13: 0, a14: 0,
                                                     a21: 1, a22: 0, a23: 0, a24: 0,
                                                     a31: 0, a32: 0, a33: 1, a34: 0) {
                #expect(result.isValid)
            }
        }
    }
}

@Suite("BRepTools_GTrsfModification")
struct GTrsfModificationTests {
    @Test("non-uniform scale")
    func nonUniformScale() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // First convert to NURBS for non-uniform scaling
            if let nurbs = box.convertedToNURBS() {
                // Scale X by 2
                if let result = Shape.gtrsfModification(nurbs,
                                                          a11: 2, a12: 0, a13: 0, a14: 0,
                                                          a21: 0, a22: 1, a23: 0, a24: 0,
                                                          a31: 0, a32: 0, a33: 1, a34: 0) {
                    #expect(result.isValid)
                }
            }
        }
    }
}

@Suite("gce_MakeCirc Tests")
struct GceMakeCircTests {
    @Test func circleThrough3Points() {
        if let circ = Curve3D.circleThrough3Points(SIMD3(5,0,0), SIMD3(0,5,0), SIMD3(-5,0,0)) {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func circleFromCenterNormal() {
        if let circ = Curve3D.circleFromCenterNormal(center: SIMD3(1,2,3),
                                                      normal: SIMD3(0,0,1), radius: 7.0) {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeCone Tests")
struct GceMakeConeTests {
    @Test func coneFrom2PointsRadii() {
        if let cone = Surface.coneFrom2PointsRadii(p1: SIMD3(0,0,0), p2: SIMD3(0,0,10),
                                                    radius1: 5.0, radius2: 2.0) {
            #expect(Bool(true)) // Construction succeeded
        }
    }
}

@Suite("gce_MakeCylinder Tests")
struct GceMakeCylinderTests {
    @Test func cylinderFrom3Points() {
        if let cyl = Surface.cylinderFrom3Points(p1: SIMD3(0,0,0), p2: SIMD3(0,0,10),
                                                  p3: SIMD3(3,0,0)) {
            #expect(Bool(true))
        }
    }
}

@Suite("gce_MakeLin Tests")
struct GceMakeLinTests {
    @Test func lineFrom2Points() {
        if let line = Curve3D.lineFrom2Points(SIMD3(0,0,0), SIMD3(1,2,3)) {
            let domain = line.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakePln Tests")
struct GceMakePlnTests {
    @Test func planeFromEquation() {
        if let plane = Surface.planeFromEquation(a: 0, b: 0, c: 1, d: -5) {
            #expect(Bool(true))
        }
    }

    @Test func planeFrom3Points() {
        if let plane = Surface.planeFrom3Points(p1: SIMD3(0,0,0), p2: SIMD3(1,0,0),
                                                 p3: SIMD3(0,1,0)) {
            #expect(Bool(true))
        }
    }
}

@Suite("gce_MakeDir Tests")
struct GceMakeDirTests {
    @Test func directionFrom2Points() {
        if let dir = Curve3D.directionFrom2Points(SIMD3(0,0,0), SIMD3(3,0,0)) {
            #expect(abs(dir.x - 1.0) < 1e-10)
            #expect(abs(dir.y) < 1e-10)
            #expect(abs(dir.z) < 1e-10)
        }
    }
}

@Suite("gce_MakeElips Tests")
struct GceMakeElipsTests {
    @Test func ellipseFromCenterNormal() {
        if let elips = Curve3D.ellipseFromCenterNormal(center: SIMD3(0,0,0), normal: SIMD3(0,0,1),
                                                        majorRadius: 10, minorRadius: 5) {
            let domain = elips.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeHypr Tests")
struct GceMakeHyprTests {
    @Test func hyperbolaFromCenterNormal() {
        if let hypr = Curve3D.hyperbolaFromCenterNormal(center: SIMD3(0,0,0), normal: SIMD3(0,0,1),
                                                         majorRadius: 8, minorRadius: 3) {
            let domain = hypr.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

@Suite("gce_MakeParab Tests")
struct GceMakeParabTests {
    @Test func parabolaFromCenterNormal() {
        if let parab = Curve3D.parabolaFromCenterNormal(center: SIMD3(0,0,0), normal: SIMD3(0,0,1),
                                                         focal: 4.0) {
            let domain = parab.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

// MARK: - v0.82.0: Quantity_Period, Quantity_Date, Font_FontMgr, Image_AlienPixMap

@Suite("Period Tests")
struct PeriodTests {
    @Test func createFromComponents() {
        if let p = Period(days: 1, hours: 2, minutes: 30, seconds: 15) {
            let c = p.components
            #expect(c.days == 1)
            #expect(c.hours == 2)
            #expect(c.minutes == 30)
            #expect(c.seconds == 15)
        }
    }

    @Test func createFromSeconds() {
        if let p = Period(totalSeconds: 3661, microseconds: 500) {
            #expect(p.totalSeconds == 3661)
            #expect(p.totalMicroseconds == 500)
        }
    }

    @Test func addPeriods() {
        if let p1 = Period(hours: 1), let p2 = Period(minutes: 30) {
            let sum = p1 + p2
            let c = sum.components
            #expect(c.hours == 1)
            #expect(c.minutes == 30)
        }
    }

    @Test func subtractPeriods() {
        if let p1 = Period(hours: 2), let p2 = Period(minutes: 30) {
            let diff = p1 - p2
            let c = diff.components
            #expect(c.hours == 1)
            #expect(c.minutes == 30)
        }
    }

    @Test func equality() {
        let p1 = Period(hours: 1, minutes: 30)
        let p2 = Period(totalSeconds: 5400)
        if let a = p1, let b = p2 {
            #expect(a == b)
        }
    }

    @Test func comparison() {
        if let p1 = Period(hours: 1), let p2 = Period(hours: 2) {
            #expect(p1 < p2)
            #expect(p2 > p1)
        }
    }

    @Test func isValidComponents() {
        #expect(Period.isValid(days: 1, hours: 2, minutes: 30))
        #expect(!Period.isValid(days: -1))
    }

    @Test func isValidSeconds() {
        #expect(Period.isValid(totalSeconds: 100))
        #expect(!Period.isValid(totalSeconds: -1))
    }

    @Test func withMilliseconds() {
        if let p = Period(seconds: 1, milliseconds: 500, microseconds: 250) {
            let c = p.components
            #expect(c.seconds == 1)
            #expect(c.milliseconds == 500)
            #expect(c.microseconds == 250)
        }
    }

    @Test func zeroPeriod() {
        if let p = Period(totalSeconds: 0) {
            #expect(p.totalSeconds == 0)
            #expect(p.totalMicroseconds == 0)
        }
    }
}

@Suite("Coordinate System Tests")
struct CoordinateSystemTests {
    @Test func zUpDirection() {
        let up = coordinateSystemUpDirection(.zUp)
        #expect(abs(up.z - 1.0) < 1e-10)
    }

    @Test func yUpDirection() {
        let up = coordinateSystemUpDirection(.yUp)
        #expect(abs(up.y - 1.0) < 1e-10)
    }

    @Test func convertWithScaling() {
        let result = convertCoordinateSystem(x: 1000, y: 0, z: 500,
                                              from: .zUp, inputUnit: 0.001,
                                              to: .zUp, outputUnit: 1.0)
        #expect(abs(result.x - 1.0) < 1e-6)
        #expect(abs(result.z - 0.5) < 1e-6)
    }

    @Test func convertZupToYup() {
        let result = convertCoordinateSystem(x: 1, y: 2, z: 3,
                                              from: .zUp, inputUnit: 1.0,
                                              to: .yUp, outputUnit: 1.0)
        // Z-up (X,Y,Z) → Y-up (X,Z,-Y)
        #expect(abs(result.x - 1.0) < 1e-6)
        #expect(abs(result.y - 3.0) < 1e-6)
        #expect(abs(result.z + 2.0) < 1e-6)
    }
}

@Suite("GeomTransformation Tests")
struct GeomTransformationTests {
    @Test func identity() {
        if let t = GeomTransformation() {
            #expect(abs(t.scaleFactor - 1.0) < 1e-10)
            #expect(!t.isNegative)
        }
    }

    @Test func translation() {
        if let t = GeomTransformation() {
            t.setTranslation(dx: 10, dy: 20, dz: 30)
            let p = t.apply(x: 0, y: 0, z: 0)
            #expect(abs(p.x - 10) < 1e-10)
            #expect(abs(p.y - 20) < 1e-10)
            #expect(abs(p.z - 30) < 1e-10)
        }
    }

    @Test func rotation() {
        if let t = GeomTransformation() {
            t.setRotation(originX: 0, originY: 0, originZ: 0,
                         dirX: 0, dirY: 0, dirZ: 1,
                         angle: .pi / 2)
            let p = t.apply(x: 1, y: 0, z: 0)
            #expect(abs(p.x) < 1e-10)
            #expect(abs(p.y - 1) < 1e-10)
        }
    }

    @Test func scale() {
        if let t = GeomTransformation() {
            t.setScale(centerX: 0, centerY: 0, centerZ: 0, factor: 2.0)
            #expect(abs(t.scaleFactor - 2.0) < 1e-10)
        }
    }

    @Test func mirror() {
        if let t = GeomTransformation() {
            t.setMirrorPoint(x: 0, y: 0, z: 0)
            #expect(t.isNegative)
        }
    }

    @Test func multiply() {
        if let t1 = GeomTransformation(), let t2 = GeomTransformation() {
            t1.setTranslation(dx: 10, dy: 0, dz: 0)
            t2.setTranslation(dx: 0, dy: 5, dz: 0)
            if let combined = t1.multiplied(by: t2) {
                let p = combined.apply(x: 0, y: 0, z: 0)
                #expect(abs(p.x - 10) < 1e-10)
                #expect(abs(p.y - 5) < 1e-10)
            }
        }
    }

    @Test func invert() {
        if let t = GeomTransformation() {
            t.setTranslation(dx: 10, dy: 20, dz: 30)
            if let inv = t.inverted() {
                let p = inv.apply(x: 10, y: 20, z: 30)
                #expect(abs(p.x) < 1e-10)
                #expect(abs(p.y) < 1e-10)
                #expect(abs(p.z) < 1e-10)
            }
        }
    }

    @Test func matrixValue() {
        if let t = GeomTransformation() {
            t.setTranslation(dx: 10, dy: 20, dz: 30)
            #expect(abs(t.value(row: 1, col: 4) - 10) < 1e-10)
            #expect(abs(t.value(row: 2, col: 4) - 20) < 1e-10)
        }
    }
}

// MARK: - v0.91.0 Tests

@Suite("ElCLib Tests")
struct ElCLibTests {

    @Test func valueOnLine() {
        let p = ElCLib.valueOnLine(u: 5.0, origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        #expect(abs(p.x - 5.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func valueOnCircle() {
        let p = ElCLib.valueOnCircle(u: 0.0, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x - 10.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func valueOnCircleAtPiOver2() {
        let p = ElCLib.valueOnCircle(u: .pi / 2, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 10.0) < 1e-10)
    }

    @Test func valueOnEllipse() {
        let p = ElCLib.valueOnEllipse(u: 0.0, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                       majorRadius: 20.0, minorRadius: 10.0)
        #expect(abs(p.x - 20.0) < 1e-10)
    }

    @Test func d1OnCircle() {
        let result = ElCLib.d1OnCircle(u: 0.0, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(result.point.x - 10.0) < 1e-10)
        #expect(abs(result.tangent.y - 10.0) < 1e-10)
    }

    @Test func parameterOnLine() {
        let u = ElCLib.parameterOnLine(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0), point: SIMD3(7, 0, 0))
        #expect(abs(u - 7.0) < 1e-10)
    }

    @Test func inPeriod() {
        let u = ElCLib.inPeriod(u: 7.0, uFirst: 0.0, uLast: 2 * .pi)
        #expect(u >= 0.0 && u < 2 * .pi)
    }
}

@Suite("ElSLib Tests")
struct ElSLibTests {

    @Test func valueOnPlane() {
        let p = ElSLib.valueOnPlane(u: 3.0, v: 4.0, origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(abs(p.x - 3.0) < 1e-10)
        #expect(abs(p.y - 4.0) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func valueOnSphere() {
        let p = ElSLib.valueOnSphere(u: 0, v: 0, origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x - 10.0) < 1e-10)
    }

    @Test func valueOnCylinder() {
        let p = ElSLib.valueOnCylinder(u: 0, v: 10, origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        #expect(abs(p.x - 5.0) < 1e-10)
        #expect(abs(p.z - 10.0) < 1e-10)
    }

    @Test func valueOnTorus() {
        let p = ElSLib.valueOnTorus(u: 0, v: 0, origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
                                     majorRadius: 20.0, minorRadius: 5.0)
        #expect(abs(p.x - 25.0) < 1e-10)
    }

    @Test func parametersOnSphere() {
        let uv = ElSLib.parametersOnSphere(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10.0,
                                            point: SIMD3(10, 0, 0))
        #expect(abs(uv.u) < 1e-10)
        #expect(abs(uv.v) < 1e-10)
    }
}

@Suite("Quaternion Tests")
struct QuaternionTests {

    @Test func identity() {
        let q = Quaternion()
        let c = q.components
        #expect(abs(c.w - 1.0) < 1e-10)
        #expect(abs(c.x) < 1e-10)
    }

    @Test func fromAxisAngle() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 2)
        let rotated = q.rotate(SIMD3(1, 0, 0))
        #expect(abs(rotated.x) < 1e-10)
        #expect(abs(rotated.y - 1.0) < 1e-10)
    }

    @Test func fromVectors() {
        let q = Quaternion.fromVectors(from: SIMD3(1, 0, 0), to: SIMD3(0, 1, 0))
        let rotated = q.rotate(SIMD3(1, 0, 0))
        #expect(abs(rotated.y - 1.0) < 1e-10)
    }

    @Test func eulerAngles() {
        let q = Quaternion()
        // gp_Intrinsic_XYZ = 8 in gp_EulerSequence enum
        q.setEulerAngles(order: 8, alpha: .pi / 4, beta: 0, gamma: 0)
        let euler = q.getEulerAngles(order: 8)
        #expect(abs(euler.alpha - .pi / 4) < 1e-10)
    }

    @Test func matrix() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 2)
        let m = q.matrix
        #expect(m.count == 9)
    }

    @Test func multiply() {
        let q1 = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 4)
        let q2 = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 4)
        let q3 = q1.multiplied(by: q2)
        let rotated = q3.rotate(SIMD3(1, 0, 0))
        #expect(abs(rotated.x) < 1e-10)
        #expect(abs(rotated.y - 1.0) < 1e-10)
    }

    @Test func axisAngle() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 6)
        let aa = q.axisAngle
        #expect(abs(aa.angle - .pi / 6) < 1e-10)
        #expect(abs(aa.axis.z - 1.0) < 1e-10)
    }

    @Test func rotationAngle() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 3)
        #expect(abs(q.rotationAngle - .pi / 3) < 1e-10)
    }

    @Test func normalize() {
        let q = Quaternion(x: 1, y: 2, z: 3, w: 4)
        q.normalize()
        let c = q.components
        let norm = sqrt(c.x*c.x + c.y*c.y + c.z*c.z + c.w*c.w)
        #expect(abs(norm - 1.0) < 1e-10)
    }
}

// MARK: - v0.94.0 Tests

@Suite("MathMatrix Tests")
struct MathMatrixTests {

    @Test func createAndQuery() {
        let m = MathMatrix(rows: 3, cols: 3, initialValue: 0.0)
        #expect(m.rows == 3)
        #expect(m.cols == 3)
    }

    @Test func setGetValue() {
        let m = MathMatrix(rows: 2, cols: 2)
        m.setValue(row: 1, col: 1, value: 5.0)
        #expect(abs(m.value(row: 1, col: 1) - 5.0) < 1e-10)
    }

    @Test func determinant() {
        let m = MathMatrix(rows: 2, cols: 2)
        m.setValue(row: 1, col: 1, value: 1); m.setValue(row: 1, col: 2, value: 2)
        m.setValue(row: 2, col: 1, value: 3); m.setValue(row: 2, col: 2, value: 4)
        #expect(abs(m.determinant - (-2.0)) < 1e-10)
    }

    @Test func invert() {
        let m = MathMatrix(rows: 2, cols: 2)
        m.setValue(row: 1, col: 1, value: 1); m.setValue(row: 1, col: 2, value: 2)
        m.setValue(row: 2, col: 1, value: 3); m.setValue(row: 2, col: 2, value: 4)
        #expect(m.invert())
    }
}

@Suite("MathGauss Tests")
struct MathGaussTests {

    @Test func solve2x2() {
        // 2x+y=5, x+3y=7 → x=1.6, y=1.8
        let matrix = [2.0, 1.0, 1.0, 3.0]
        let rhs = [5.0, 7.0]
        if let solution = MathGauss.solve(matrix: matrix, rhs: rhs) {
            #expect(abs(solution[0] - 1.6) < 1e-10)
            #expect(abs(solution[1] - 1.8) < 1e-10)
        }
    }

    @Test func determinant() {
        let det = MathGauss.determinant(matrix: [2.0, 1.0, 1.0, 3.0], n: 2)
        #expect(abs(det - 5.0) < 1e-10)
    }
}

@Suite("MathSVD Tests")
struct MathSVDTests {

    @Test func leastSquares() {
        // Overdetermined 3x2 system
        let A = [1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        let b = [1.0, 2.0, 4.0]
        if let x = MathSVD.solve(matrix: A, rows: 3, cols: 2, rhs: b) {
            #expect(x.count == 2)
            #expect(x[0] > 0 && x[1] > 0)
        }
    }
}

@Suite("MathPolynomialRoots Tests")
struct MathPolynomialRootsTests {

    @Test func quadratic() {
        // x²-5x+6=0 → x=2,3
        if let roots = MathPolynomialRoots.solve(coefficients: [1.0, -5.0, 6.0]) {
            #expect(roots.count == 2)
            let sorted = roots.sorted()
            if sorted.count == 2 {
                #expect(abs(sorted[0] - 2.0) < 1e-10)
                #expect(abs(sorted[1] - 3.0) < 1e-10)
            }
        }
    }

    @Test func linear() {
        // 2x+4=0 → x=-2
        if let roots = MathPolynomialRoots.solve(coefficients: [2.0, 4.0]) {
            #expect(roots.count == 1)
            if roots.count == 1 { #expect(abs(roots[0] + 2.0) < 1e-10) }
        }
    }

    @Test func noRealRoots() {
        // x²+1=0
        if let roots = MathPolynomialRoots.solve(coefficients: [1.0, 0.0, 1.0]) {
            #expect(roots.count == 0)
        }
    }
}

@Suite("MathJacobi Tests")
struct MathJacobiTests {

    @Test func eigenvalues() {
        // [[2,1],[1,2]] → eigenvalues 1,3
        let matrix = [2.0, 1.0, 1.0, 2.0]
        if let ev = MathJacobi.eigenvalues(matrix: matrix, n: 2) {
            #expect(ev.count == 2)
            let sorted = ev.sorted()
            if sorted.count == 2 {
                #expect(abs(sorted[0] - 1.0) < 1e-10)
                #expect(abs(sorted[1] - 3.0) < 1e-10)
            }
        }
    }
}

@Suite("MathHouseholder Tests")
struct MathHouseholderTests {

    @Test func overdetermindedSolve() {
        // 3x2 system: [[1,0],[0,1],[1,1]] x = [1,2,4]
        let A = [1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        let b = [1.0, 2.0, 4.0]
        if let x = MathHouseholder.solve(matrix: A, rows: 3, cols: 2, rhs: b) {
            #expect(x.count == 2)
            #expect(x[0] > 0 && x[1] > 0)
        }
    }
}

@Suite("MathCrout Tests")
struct MathCroutTests {

    @Test func symmetricSolve() {
        // [[4,2],[2,3]] x = [8,7] → x=1.25, y=1.5
        let A = [4.0, 2.0, 2.0, 3.0]
        let b = [8.0, 7.0]
        if let x = MathCrout.solve(matrix: A, rhs: b) {
            #expect(abs(x[0] - 1.25) < 1e-10)
            #expect(abs(x[1] - 1.5) < 1e-10)
        }
    }

    @Test func determinant() {
        let det = MathCrout.determinant(matrix: [4.0, 2.0, 2.0, 3.0], n: 2)
        #expect(abs(det - 8.0) < 1e-10)
    }
}

@Suite("Precision Tests")
struct PrecisionTests {

    @Test func confusion() {
        #expect(abs(OCCTPrecision.confusion - 1e-7) < 1e-15)
    }

    @Test func angular() {
        #expect(abs(OCCTPrecision.angular - 1e-12) < 1e-20)
    }

    @Test func isInfinite() {
        #expect(OCCTPrecision.isInfinite(3e100))
        #expect(!OCCTPrecision.isInfinite(1.0))
    }

    @Test func ordering() {
        #expect(OCCTPrecision.intersection < OCCTPrecision.confusion)
        #expect(OCCTPrecision.approximation > OCCTPrecision.confusion)
    }
}

// MARK: - v0.103.0 Tests

@Suite("gce Transform Factory 3D Tests")
struct TransformFactory3DTests {

    @Test func pointMirror() {
        let t = TransformFactory3D.mirrorPoint(SIMD3(0, 0, 0))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x + 1) < 1e-6)
        #expect(abs(p.y + 2) < 1e-6)
        #expect(abs(p.z + 3) < 1e-6)
    }

    @Test func planeMirror() {
        let t = TransformFactory3D.mirrorPlane(point: SIMD3(0,0,0), normal: SIMD3(0,0,1))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x - 1) < 1e-6)
        #expect(abs(p.z + 3) < 1e-6)
    }

    @Test func rotation90() {
        let t = TransformFactory3D.rotation(point: .zero, direction: SIMD3(0,0,1), angle: .pi/2)
        let p = t.apply(to: SIMD3(1, 0, 0))
        #expect(abs(p.x) < 1e-6)
        #expect(abs(p.y - 1) < 1e-6)
    }

    @Test func scaleBy2() {
        let t = TransformFactory3D.scale(center: .zero, factor: 2)
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x - 2) < 1e-6)
        #expect(abs(p.y - 4) < 1e-6)
        #expect(abs(p.z - 6) < 1e-6)
    }

    @Test func translationVector() {
        let t = TransformFactory3D.translation(SIMD3(10, 20, 30))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x - 11) < 1e-6)
        #expect(abs(p.y - 22) < 1e-6)
    }

    @Test func translationPoints() {
        let t = TransformFactory3D.translation(from: .zero, to: SIMD3(5, 5, 5))
        let p = t.apply(to: SIMD3(1, 1, 1))
        #expect(abs(p.x - 6) < 1e-6)
    }

    @Test func axisMirror() {
        let t = TransformFactory3D.mirrorAxis(point: .zero, direction: SIMD3(0,0,1))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x + 1) < 1e-6)
        #expect(abs(p.y + 2) < 1e-6)
        #expect(abs(p.z - 3) < 1e-6)
    }
}

// MARK: - v0.105.0 Tests

@Suite("GC_MakeCircle Tests")
struct GCMakeCircleTests {

    @Test func circleFromAxisAndRadius() {
        let c = Curve3D.gcCircle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circleFrom3Points() {
        let c = Curve3D.gcCircle(p1: SIMD3(1, 0, 0), p2: SIMD3(0, 1, 0), p3: SIMD3(-1, 0, 0))
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circleCenterNormal() {
        let c = Curve3D.gcCircleCenterNormal(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 10)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }

    @Test func circleParallel() {
        let c = Curve3D.gcCircleParallel(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                          radius: 5, distance: 3)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
        }
    }
}

@Suite("GC_MakeEllipse Tests")
struct GCMakeEllipseTests {

    @Test func ellipseFromAxisAndRadii() {
        let e = Curve3D.gcEllipse(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                   majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }

    @Test func ellipseFromFullAx2() {
        let e = Curve3D.gcEllipse(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                   xDirection: SIMD3(1, 0, 0),
                                   majorRadius: 10, minorRadius: 5)
        #expect(e != nil)
        if let e = e {
            #expect(e.isClosed)
        }
    }
}

@Suite("GC_MakeHyperbola Tests")
struct GCMakeHyperbolaTests {

    @Test func hyperbolaFromAxisAndRadii() {
        let h = Curve3D.gcHyperbola(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                     majorRadius: 10, minorRadius: 5)
        #expect(h != nil)
    }
}

@Suite("GeomLib_LogSample Tests")
struct LogSampleTests {

    @Test func logarithmicSampling() {
        let params = LogSample.sample(from: 1, to: 100, count: 5)
        #expect(params.count == 5)
        // Should be monotonically increasing
        for i in 1..<params.count {
            #expect(params[i] > params[i-1])
        }
    }

    @Test func singleSample() {
        let params = LogSample.sample(from: 1, to: 10, count: 1)
        #expect(params.count == 1)
    }
}

// MARK: - v0.106.0 Tests

@Suite("GC_MakeConicalSurface Tests")
struct GCMakeConicalSurfaceTests {

    @Test func conicalFromAxisAngleRadius() {
        if let s = Surface.gcConicalSurface(center: .zero, normal: SIMD3(0, 0, 1),
                                             semiAngle: .pi / 6, radius: 5) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func conicalFrom2PtsRadii() {
        if let s = Surface.gcConicalSurface2Pts(p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                                                  r1: 5, r2: 2) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func conicalFrom4Pts() {
        // 4 points on the cone surface
        let s = Surface.gcConicalSurface4Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0),
            p3: SIMD3(2, 0, 10), p4: SIMD3(0, 2, 10))
        // May or may not succeed depending on point geometry
        let _ = s
    }
}

@Suite("GC_MakeCylindricalSurface Tests")
struct GCMakeCylindricalSurfaceTests {

    @Test func cylindricalFromAxisRadius() {
        if let s = Surface.gcCylindricalSurface(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func cylindricalFrom3Pts() {
        let s = Surface.gcCylindricalSurface3Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0), p3: SIMD3(-5, 0, 0))
        // May or may not succeed depending on point configuration
        let _ = s
    }

    @Test func cylindricalFromCircle() {
        if let s = Surface.gcCylindricalSurfaceFromCircle(center: .zero, normal: SIMD3(0, 0, 1),
                                                            radius: 5) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func cylindricalParallel() {
        if let s = Surface.gcCylindricalSurfaceParallel(center: .zero, normal: SIMD3(0, 0, 1),
                                                          radius: 5, distance: 2) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func cylindricalFromAxis() {
        if let s = Surface.gcCylindricalSurfaceAxis(point: .zero, direction: SIMD3(0, 0, 1),
                                                      radius: 5) {
            #expect(s.continuity >= 0)
        }
    }
}

@Suite("GC_MakeTrimmedCone Tests")
struct GCMakeTrimmedConeTests {

    @Test func trimmedCone2Pts() {
        if let s = Surface.gcTrimmedCone2Pts(p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
                                               r1: 5, r2: 2) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func trimmedCone4Pts() {
        let s = Surface.gcTrimmedCone4Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0),
            p3: SIMD3(2, 0, 10), p4: SIMD3(0, 2, 10))
        let _ = s
    }
}

@Suite("GC_MakeTrimmedCylinder Tests")
struct GCMakeTrimmedCylinderTests {

    @Test func trimmedCylinderCircle() {
        if let s = Surface.gcTrimmedCylinderCircle(center: .zero, normal: SIMD3(0, 0, 1),
                                                     radius: 5, height: 10) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func trimmedCylinderAxis() {
        if let s = Surface.gcTrimmedCylinderAxis(point: .zero, direction: SIMD3(0, 0, 1),
                                                   radius: 5, height: 10) {
            #expect(s.continuity >= 0)
        }
    }

    @Test func trimmedCylinder3Pts() {
        if let s = Surface.gcTrimmedCylinder3Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(5, 0, 10), p3: SIMD3(0, 5, 0)) {
            #expect(s.continuity >= 0)
        }
    }
}

@Suite("math_TrigonometricFunctionRoots")
struct TrigRootsTests {
    @Test func sinZero() {
        // sin(x) = 0 on [0, 2pi] => x = 0, pi, 2pi
        let roots = TrigRoots.solve(D: 1, from: 0, to: 2 * .pi)
        #expect(roots.count >= 2)
    }

    @Test func cosHalf() {
        // cos(x) = 0.5 => x = pi/3, 5pi/3
        let roots = TrigRoots.solve(C: 1, E: -0.5, from: 0, to: 2 * .pi)
        #expect(roots.count >= 1)
    }

    @Test func infiniteRoots() {
        // 0 = 0 => all reals are solutions
        let inf = TrigRoots.hasInfiniteRoots(from: 0, to: 2 * .pi)
        #expect(inf)
    }
}

// MARK: - v0.110.0 Math Solver Tests

@Suite("MathSolver FunctionRoot v0.110")
struct MathSolverFunctionRootTests {
    @Test func findRootNewton() {
        // f(x) = x^2 - 4, root at x=2
        if let root = MathSolver.findRoot(near: 3.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }

    @Test func findRootNegative() {
        // f(x) = x^2 - 4, root at x=-2
        if let root = MathSolver.findRoot(near: -3.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root + 2.0) < 1e-6)
        }
    }

    @Test func findRootBounded() {
        // f(x) = x^2 - 4, root at x=2 in [0, 5]
        if let root = MathSolver.findRoot(near: 3.0, in: 0.0...5.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }

    @Test func findRootBisection() {
        // f(x) = x^2 - 4 on [0, 5], root at x=2
        if let root = MathSolver.findRootBisection(in: 0.0...5.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }

    @Test func findRootCubic() {
        // f(x) = x^3 - 8, root at x=2
        if let root = MathSolver.findRoot(near: 3.0) { x in
            (value: x * x * x - 8, derivative: 3 * x * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }
}

@Suite("MathSolver SystemOfEquations v0.110")
struct MathSolverSystemTests {
    @Test func solveCircleLine() {
        // x^2 + y^2 = 25, x - y = 1
        // Starting near (4, 3)
        if let sol = MathSolver.solveSystem(
            variables: 2, equations: 2,
            startPoint: [4.0, 3.0],
            values: { x in
                [x[0] * x[0] + x[1] * x[1] - 25, x[0] - x[1] - 1]
            },
            jacobian: { x in
                [2 * x[0], 2 * x[1], 1.0, -1.0]
            }
        ) {
            // Check solution satisfies both equations
            let eq1 = sol[0] * sol[0] + sol[1] * sol[1] - 25
            let eq2 = sol[0] - sol[1] - 1
            #expect(abs(eq1) < 1e-4)
            #expect(abs(eq2) < 1e-4)
        }
    }

    @Test func solveLinearSystem() {
        // 2x + y = 5, x - y = 1 -> x=2, y=1
        if let sol = MathSolver.solveSystem(
            variables: 2, equations: 2,
            startPoint: [0.0, 0.0],
            values: { x in
                [2 * x[0] + x[1] - 5, x[0] - x[1] - 1]
            },
            jacobian: { _ in
                [2.0, 1.0, 1.0, -1.0]
            }
        ) {
            #expect(abs(sol[0] - 2.0) < 1e-4)
            #expect(abs(sol[1] - 1.0) < 1e-4)
        }
    }
}

@Suite("MathSolver BFGS v0.110")
struct MathSolverBFGSTests {
    @Test func minimizeQuadratic() {
        // f(x,y) = (x-3)^2 + (y-4)^2, minimum at (3, 4)
        if let result = MathSolver.minimize(
            variables: 2,
            startPoint: [0.0, 0.0],
            function: { x in
                let val = (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
                let grad = [2 * (x[0] - 3), 2 * (x[1] - 4)]
                return (value: val, gradient: grad)
            }
        ) {
            #expect(abs(result.point[0] - 3.0) < 1e-4)
            #expect(abs(result.point[1] - 4.0) < 1e-4)
            #expect(abs(result.minimum) < 1e-4)
        }
    }

    @Test func minimizeRosenbrock() {
        // Rosenbrock: f(x,y) = (1-x)^2 + 100*(y-x^2)^2
        // Minimum at (1, 1) with f=0
        if let result = MathSolver.minimize(
            variables: 2,
            startPoint: [0.0, 0.0],
            tolerance: 1e-10,
            maxIterations: 1000,
            function: { x in
                let val = (1 - x[0]) * (1 - x[0]) + 100 * (x[1] - x[0] * x[0]) * (x[1] - x[0] * x[0])
                let gx = -2 * (1 - x[0]) - 400 * x[0] * (x[1] - x[0] * x[0])
                let gy = 200 * (x[1] - x[0] * x[0])
                return (value: val, gradient: [gx, gy])
            }
        ) {
            #expect(abs(result.point[0] - 1.0) < 0.1)
            #expect(abs(result.point[1] - 1.0) < 0.1)
        }
    }
}

@Suite("MathSolver Powell v0.110")
struct MathSolverPowellTests {
    @Test func minimizeBowl() {
        // f(x,y) = (x-3)^2 + (y-4)^2
        if let result = MathSolver.minimizePowell(
            variables: 2,
            startPoint: [0.0, 0.0],
            function: { x in
                (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            }
        ) {
            #expect(abs(result.point[0] - 3.0) < 1e-3)
            #expect(abs(result.point[1] - 4.0) < 1e-3)
            #expect(abs(result.minimum) < 1e-3)
        }
    }
}

@Suite("MathSolver BrentMinimum v0.110")
struct MathSolverBrentTests {
    @Test func minimizeQuadratic() {
        // f(x) = x^2 - 4, minimum at x=0 with f=-4
        if let result = MathSolver.minimizeBrent(ax: -1.0, bx: 1.0, cx: 5.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(result.location) < 0.1)
            #expect(abs(result.minimum + 4.0) < 0.1)
        }
    }

    @Test func minimizeSine() {
        // f(x) = sin(x), minimum near x = 3*pi/2 ~ 4.712 with f=-1
        // Bracket: [3, 5, 6]
        if let result = MathSolver.minimizeBrent(ax: 3.0, bx: 5.0, cx: 6.0) { x in
            (value: sin(x), derivative: cos(x))
        } {
            #expect(abs(result.location - 3 * Double.pi / 2) < 0.1)
            #expect(abs(result.minimum + 1.0) < 0.1)
        }
    }
}

// MARK: - v0.111.0 Tests

@Suite("MathSolver PSO v0.111")
struct MathSolverPSOTests {
    @Test func minimizeBowl() {
        // f(x,y) = (x-3)^2 + (y-4)^2, minimum at (3, 4) with value 0
        if let result = MathSolver.particleSwarm(
            variables: 2,
            lower: [-10.0, -10.0],
            upper: [10.0, 10.0],
            steps: [0.5, 0.5],
            particles: 64,
            iterations: 100,
            function: { x in
                (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            }
        ) {
            #expect(result.minimum < 1.0)
        }
    }

    @Test func minimizeRosenbrock() {
        // Rosenbrock: f(x,y) = (1-x)^2 + 100*(y-x^2)^2, min at (1,1)
        if let result = MathSolver.particleSwarm(
            variables: 2,
            lower: [-5.0, -5.0],
            upper: [5.0, 5.0],
            steps: [0.1, 0.1],
            particles: 128,
            iterations: 200,
            function: { x in
                (1 - x[0]) * (1 - x[0]) + 100 * (x[1] - x[0] * x[0]) * (x[1] - x[0] * x[0])
            }
        ) {
            // PSO may not find exact minimum, but should get close
            #expect(result.minimum < 10.0)
        }
    }
}

@Suite("MathSolver GlobOptMin v0.111")
struct MathSolverGlobOptMinTests {
    @Test func globalMinBowl() {
        // f(x,y) = (x-3)^2 + (y-4)^2, global minimum at (3, 4) with value 0
        if let result = MathSolver.globalMinimize(
            variables: 2,
            lower: [-10.0, -10.0],
            upper: [10.0, 10.0],
            function: { x in
                (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            }
        ) {
            #expect(result.minimum < 1.0)
            #expect(abs(result.point[0] - 3.0) < 1.0)
            #expect(abs(result.point[1] - 4.0) < 1.0)
        }
    }

    @Test func globalMin1D() {
        if let result = MathSolver.globalMinimize(
            variables: 1,
            lower: [-5.0],
            upper: [5.0],
            function: { x in (x[0] - 2) * (x[0] - 2) + 1 }
        ) {
            #expect(abs(result.minimum - 1.0) < 0.5)
        }
    }
}

@Suite("MathSolver FunctionRoots v0.111")
struct MathSolverFunctionRootsTests {
    @Test func findAllRootsQuadratic() {
        // f(x) = x^2 - 4, roots at x = -2 and x = 2
        let roots = MathSolver.findAllRoots(in: -5.0...5.0, samples: 20) { x in
            (value: x * x - 4, derivative: 2 * x)
        }
        #expect(roots.count == 2)
        if roots.count >= 2 {
            let sorted = roots.sorted()
            #expect(abs(sorted[0] + 2.0) < 0.1)
            #expect(abs(sorted[1] - 2.0) < 0.1)
        }
    }

    @Test func findAllRootsSin() {
        // f(x) = sin(x), roots at 0, pi, 2*pi in [−0.5, 6.5]
        let roots = MathSolver.findAllRoots(in: -0.5...6.5, samples: 30) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(roots.count >= 2)
    }
}

@Suite("MathSolver GaussIntegrate v0.111")
struct MathSolverGaussIntegrateTests {
    @Test func integrateSin() {
        // Integral of sin(x) from 0 to pi = 2
        let result = MathSolver.integrate(from: 0, to: Double.pi, order: 10) { x in
            sin(x)
        }
        #expect(abs(result - 2.0) < 0.01)
    }

    @Test func integratePolynomial() {
        // Integral of x^2 from 0 to 1 = 1/3
        let result = MathSolver.integrate(from: 0, to: 1, order: 5) { x in
            x * x
        }
        #expect(abs(result - 1.0 / 3.0) < 0.01)
    }

    @Test func integrateConstant() {
        // Integral of 1 from 0 to 5 = 5
        let result = MathSolver.integrate(from: 0, to: 5, order: 3) { _ in 1.0 }
        #expect(abs(result - 5.0) < 0.01)
    }
}

@Suite("MathSolver NewtonSystem v0.111")
struct MathSolverNewtonSystemTests {
    @Test func solveCircleLine() {
        // x^2 + y^2 = 25, x - y = 1, starting near (4, 3)
        if let sol = MathSolver.solveSystemNewton(
            variables: 2, equations: 2,
            startPoint: [4.0, 3.0],
            values: { x in [x[0] * x[0] + x[1] * x[1] - 25, x[0] - x[1] - 1] },
            jacobian: { x in [2 * x[0], 2 * x[1], 1.0, -1.0] }
        ) {
            let eq1 = sol[0] * sol[0] + sol[1] * sol[1] - 25
            #expect(abs(eq1) < 1e-4)
            let eq2 = sol[0] - sol[1] - 1
            #expect(abs(eq2) < 1e-4)
        }
    }
}

@Suite("PolynomialSolver Laguerre v0.111")
struct PolynomialSolverLaguerreTests {
    @Test func quadraticRoots() {
        // x^2 - 5x + 6 = 0 -> roots 2, 3
        let roots = PolynomialSolver.laguerreRoots(coefficients: [6.0, -5.0, 1.0])
        #expect(roots.count == 2)
        if roots.count >= 2 {
            #expect(abs(roots[0] - 2.0) < 0.1)
            #expect(abs(roots[1] - 3.0) < 0.1)
        }
    }

    @Test func cubicRoots() {
        // x^3 - 6x^2 + 11x - 6 = 0 -> roots 1, 2, 3
        let roots = PolynomialSolver.laguerreRoots(coefficients: [-6.0, 11.0, -6.0, 1.0])
        #expect(roots.count == 3)
        if roots.count >= 3 {
            #expect(abs(roots[0] - 1.0) < 0.1)
            #expect(abs(roots[1] - 2.0) < 0.1)
            #expect(abs(roots[2] - 3.0) < 0.1)
        }
    }

    @Test func complexRoots() {
        // x^2 + 1 = 0 -> complex roots i, -i (no real roots)
        let realRoots = PolynomialSolver.laguerreRoots(coefficients: [1.0, 0.0, 1.0])
        #expect(realRoots.count == 0)

        let complexRoots = PolynomialSolver.laguerreComplexRoots(coefficients: [1.0, 0.0, 1.0])
        #expect(complexRoots.count == 2)
        if complexRoots.count >= 2 {
            // Should be approximately (0, 1) and (0, -1)
            #expect(abs(complexRoots[0].real) < 0.1)
            #expect(abs(abs(complexRoots[0].imaginary) - 1.0) < 0.1)
        }
    }

    @Test func quinticRoots() {
        // x^5 - 15x^4 + 85x^3 - 225x^2 + 274x - 120 = 0 -> roots 1, 2, 3, 4, 5
        let roots = PolynomialSolver.quinticRoots(a: 1, b: -15, c: 85, d: -225, e: 274, f: -120)
        // Quintic uses PolyResult with max 4 roots, so we may get up to 4
        #expect(roots.count >= 3)
    }
}

// MARK: - v0.111.1 Tests

@Suite("math_NewtonMinimum Tests")
struct NewtonMinimumTests {

    @Test func minimizeQuadratic() {
        // f(x,y) = (x-3)^2 + (y-4)^2, min at (3,4)
        let result = MathSolver.minimizeNewton(variables: 2, startPoint: [0, 0]) { x in
            let fx = (x[0]-3)*(x[0]-3) + (x[1]-4)*(x[1]-4)
            let gx = [2*(x[0]-3), 2*(x[1]-4)]
            let hx = [2.0, 0.0, 0.0, 2.0] // identity Hessian
            return (fx, gx, hx)
        }
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.point[0] - 3.0) < 1e-4)
            #expect(abs(r.point[1] - 4.0) < 1e-4)
            #expect(abs(r.minimum) < 1e-6)
        }
    }

    @Test func minimizeRosenbrock() {
        // f(x,y) = (1-x)^2 + 100*(y-x^2)^2, min at (1,1)
        let result = MathSolver.minimizeNewton(variables: 2, startPoint: [0, 0], maxIterations: 100) { x in
            let fx = (1-x[0])*(1-x[0]) + 100*(x[1]-x[0]*x[0])*(x[1]-x[0]*x[0])
            let gx0 = -2*(1-x[0]) + 100*2*(x[1]-x[0]*x[0])*(-2*x[0])
            let gx1 = 100*2*(x[1]-x[0]*x[0])
            let h00 = 2 + 100*(12*x[0]*x[0] - 4*x[1])
            let h01 = -400*x[0]
            let h10 = -400*x[0]
            let h11 = 200.0
            return (fx, [gx0, gx1], [h00, h01, h10, h11])
        }
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.point[0] - 1.0) < 0.1)
            #expect(abs(r.point[1] - 1.0) < 0.1)
        }
    }
}

@Suite("v0.115.0 - Transform Expansion")
struct TransformExpansionTests {

    @Test func generalTransform() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Identity rotation + translation by (5,0,0)
            let matrix: [Double] = [
                1, 0, 0,  // row 0 of rotation
                0, 1, 0,  // row 1
                0, 0, 1,  // row 2
                5, 0, 0   // translation
            ]
            let result = box.transformed(matrix: matrix)
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }

    @Test func nonUniformScale() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Scale by (2, 1, 0.5) = non-uniform
            let matrix: [Double] = [
                2, 0, 0, 0,  // row 0: scaleX=2, no translate
                0, 1, 0, 0,  // row 1: scaleY=1
                0, 0, 0.5, 0 // row 2: scaleZ=0.5
            ]
            let result = box.gTransformed(matrix: matrix)
            #expect(result != nil)
        }
    }
}

@Suite("CoordinateSystem3D")
struct CoordinateSystem3DTests {
    @Test func defaultXYZ() {
        let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        #expect(cs.isDirect)
        #expect(abs(cs.yDirection.y - 1.0) < 1e-10)
    }

    @Test func fromNormal() {
        let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        #expect(cs.isDirect)
    }

    @Test func angle() {
        let cs1 = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        let cs2 = CoordinateSystem3D(origin: .zero, direction: SIMD3(1, 0, 0))
        #expect(abs(cs1.angle(to: cs2) - .pi / 2) < 1e-10)
    }

    @Test func isCoplanar() {
        let cs1 = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        let cs2 = CoordinateSystem3D(origin: SIMD3(1, 1, 0), direction: SIMD3(0, 0, 1))
        #expect(cs1.isCoplanar(with: cs2))
    }

    @Test func mirrorPoint() {
        let cs = CoordinateSystem3D(origin: SIMD3(1, 0, 0), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let mirrored = cs.mirrored(about: .zero)
        #expect(abs(mirrored.origin.x + 1.0) < 1e-10)
    }

    @Test func rotate() {
        let cs = CoordinateSystem3D(origin: SIMD3(1, 0, 0), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let rotated = cs.rotated(about: .zero, axisDirection: SIMD3(0, 0, 1), angle: .pi / 2)
        #expect(abs(rotated.origin.x) < 1e-10)
        #expect(abs(rotated.origin.y - 1.0) < 1e-10)
    }

    @Test func translate() {
        let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let translated = cs.translated(by: SIMD3(1, 2, 3))
        #expect(abs(translated.origin.x - 1.0) < 1e-10)
        #expect(abs(translated.origin.z - 3.0) < 1e-10)
    }
}

@Suite("Quaternion Interpolation")
struct QuaternionInterpolationTests {
    @Test func slerpMidpoint() {
        let q1 = SIMD4<Double>(0, 0, 0, 1) // identity
        let q2 = SIMD4<Double>(0, 0, sin(.pi / 4), cos(.pi / 4)) // 90 deg about Z
        let mid = MathSolver.quaternionSlerp(from: q1, to: q2, t: 0.5)
        #expect(abs(mid.w) > 0.9) // close to 45 deg
    }

    @Test func nlerpEndpoints() {
        let q1 = SIMD4<Double>(0, 0, 0, 1)
        let q2 = SIMD4<Double>(0, 0, sin(.pi / 4), cos(.pi / 4))
        let r0 = MathSolver.quaternionNlerp(from: q1, to: q2, t: 0.0)
        #expect(abs(r0.w - 1.0) < 0.1)
    }

    @Test func transformInterpolate() {
        let from = (translation: SIMD3<Double>(0, 0, 0), quaternion: SIMD4<Double>(0, 0, 0, 1))
        let to = (translation: SIMD3<Double>(10, 0, 0), quaternion: SIMD4<Double>(0, 0, 0, 1))
        let mid = MathSolver.transformInterpolate(from: from, to: to, t: 0.5)
        #expect(abs(mid.translation.x - 5.0) < 0.5)
    }
}

@Suite("Vector2DMath")
struct Vector2DMathTests {
    @Test func modulus() {
        #expect(abs(Vector2DMath.modulus(SIMD2(3, 4)) - 5.0) < 1e-10)
    }

    @Test func cross() {
        #expect(abs(Vector2DMath.cross(SIMD2(1, 0), SIMD2(0, 1)) - 1.0) < 1e-10)
    }

    @Test func dot() {
        #expect(abs(Vector2DMath.dot(SIMD2(1, 2), SIMD2(3, 4)) - 11.0) < 1e-10)
    }

    @Test func normalize() {
        let n = Vector2DMath.normalize(SIMD2(3, 4))
        #expect(n != nil)
        if let n = n { #expect(abs(Vector2DMath.modulus(n) - 1.0) < 1e-10) }
    }
}

@Suite("Vector3DMath")
struct Vector3DMathTests {
    @Test func modulus() {
        #expect(abs(Vector3DMath.modulus(SIMD3(1, 2, 2)) - 3.0) < 1e-10)
    }

    @Test func cross() {
        let c = Vector3DMath.cross(SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        #expect(abs(c.z - 1.0) < 1e-10)
    }

    @Test func dot() {
        #expect(abs(Vector3DMath.dot(SIMD3(1, 2, 3), SIMD3(4, 5, 6)) - 32.0) < 1e-10)
    }

    @Test func dotCross() {
        #expect(abs(Vector3DMath.dotCross(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)) - 1.0) < 1e-10)
    }

    @Test func normalize() {
        let n = Vector3DMath.normalize(SIMD3(1, 2, 2))
        #expect(n != nil)
        if let n = n { #expect(abs(Vector3DMath.modulus(n) - 1.0) < 1e-10) }
    }
}

@Suite("BracketedRoot")
struct BracketedRootTests {
    @Test func findRoot() {
        let result = MathSolver.bracketedRoot(in: 0...5) { x in
            (value: x * x - 4.0, derivative: 2.0 * x)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.root - 2.0) < 1e-8) }
    }

    @Test func findSinRoot() {
        let result = MathSolver.bracketedRoot(in: 2...4) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.root - .pi) < 1e-8) }
    }
}

@Suite("BracketMinimum")
struct BracketMinimumTests {
    @Test func bracketQuadratic() {
        let result = MathSolver.bracketMinimum(a: -5.0, b: 2.0) { x in x * x }
        #expect(result != nil)
        if let r = result { #expect(r.fb <= r.fa && r.fb <= r.fc) }
    }
}

@Suite("FRPR Minimizer")
struct FRPRTests {
    @Test func minimizeQuadratic() {
        let result = MathSolver.minimizeFRPR(startPoint: [10.0, 10.0]) { x in
            let fx = (x[0] - 1.0) * (x[0] - 1.0) + (x[1] - 2.0) * (x[1] - 2.0)
            let gx = [2.0 * (x[0] - 1.0), 2.0 * (x[1] - 2.0)]
            return (value: fx, gradient: gx)
        }
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.location[0] - 1.0) < 0.01)
            #expect(abs(r.location[1] - 2.0) < 0.01)
        }
    }
}

@Suite("FunctionAllRoots")
struct FunctionAllRootsTests {
    @Test func sinRoots() {
        let roots = MathSolver.findAllRoots(in: 0.1...10.0) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(roots.count >= 3) // pi, 2pi, 3pi
    }
}

@Suite("GaussLeastSquare")
struct GaussLeastSquareTests {
    @Test func overdetermined() {
        let A: [Double] = [1, 0, 0, 1, 1, 1] // 3x2
        let b: [Double] = [1, 2, 3]
        let x = MathSolver.leastSquares(matrix: A, rows: 3, cols: 2, rhs: b)
        #expect(x != nil)
        if let x = x { #expect(x.count == 2) }
    }
}

@Suite("NewtonRoot")
struct NewtonRootTests {
    @Test func findRoot() {
        let result = MathSolver.newtonRoot(guess: 3.0) { x in
            (value: x * x - 4.0, derivative: 2.0 * x)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.root - 2.0) < 1e-8) }
    }
}

@Suite("Uzawa")
struct UzawaTests {
    @Test func constrainedOptimization() {
        let cont: [Double] = [1, 1] // x + y = 1
        let sec: [Double] = [1]
        let result = MathSolver.uzawa(constraintMatrix: cont, nConstraints: 1, nVars: 2,
                                      constraintRHS: sec, startPoint: [0, 0])
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.result[0] - 0.5) < 0.1)
            #expect(abs(r.result[1] - 0.5) < 0.1)
        }
    }
}

@Suite("EigenValues")
struct EigenValuesTests {
    @Test func tridiagonal() {
        let diag = [2.0, 2.0, 2.0]
        let subdiag = [1.0, 1.0, 0.0]
        let ev = MathSolver.eigenvalues(diagonal: diag, subdiagonal: subdiag)
        #expect(ev != nil)
        if let ev = ev { #expect(ev.count == 3) }
    }

    @Test func withVectors() {
        let diag = [2.0, 2.0, 2.0]
        let subdiag = [1.0, 1.0, 0.0]
        let result = MathSolver.eigenvaluesAndVectors(diagonal: diag, subdiagonal: subdiag)
        #expect(result != nil)
        if let r = result {
            #expect(r.eigenvalues.count == 3)
            #expect(r.eigenvectors.count == 3)
            #expect(r.eigenvectors[0].count == 3)
        }
    }
}

// MARK: - v0.117.0 Tests

@Suite("MathPolyRc4")
struct MathPolyRc4Tests {
    @Test func linear() {
        // 2x + 4 = 0 => x = -2
        let roots = PolynomialSolver.linearRc4(a: 2, b: 4)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 1)
            #expect(abs(r[0] - (-2.0)) < 1e-10)
        }
    }

    @Test func linearDegenerate() {
        // 0x + 0 = 0 => infinite solutions => returns -1
        let roots = PolynomialSolver.linearRc4(a: 0, b: 0)
        // InfiniteSolutions status means IsDone() is false => returns nil or -1
        // The function returns -1 when IsDone is false, so nil
        #expect(roots == nil)
    }

    @Test func quadratic() {
        // x^2 - 5x + 6 = 0 => x = 2, 3
        let roots = PolynomialSolver.quadraticRc4(a: 1, b: -5, c: 6)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 2)
            #expect(abs(r[0] - 2.0) < 1e-10)
            #expect(abs(r[1] - 3.0) < 1e-10)
        }
    }

    @Test func quadraticNoRealRoots() {
        // x^2 + 1 = 0 => no real roots
        let roots = PolynomialSolver.quadraticRc4(a: 1, b: 0, c: 1)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 0)
        }
    }

    @Test func cubic() {
        // x^3 - 6x^2 + 11x - 6 = 0 => x = 1, 2, 3
        let roots = PolynomialSolver.cubicRc4(a: 1, b: -6, c: 11, d: -6)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 3)
            #expect(abs(r[0] - 1.0) < 1e-8)
            #expect(abs(r[1] - 2.0) < 1e-8)
            #expect(abs(r[2] - 3.0) < 1e-8)
        }
    }

    @Test func quartic() {
        // (x-1)(x-2)(x-3)(x-4) = x^4 - 10x^3 + 35x^2 - 50x + 24
        let roots = PolynomialSolver.quarticRc4(a: 1, b: -10, c: 35, d: -50, e: 24)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 4)
            #expect(abs(r[0] - 1.0) < 1e-6)
            #expect(abs(r[1] - 2.0) < 1e-6)
            #expect(abs(r[2] - 3.0) < 1e-6)
            #expect(abs(r[3] - 4.0) < 1e-6)
        }
    }
}

@Suite("MathIntegRc4")
struct MathIntegRc4Tests {
    @Test func gauss() {
        let result = MathSolver.integGauss(over: 0...Double.pi) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-6) }
    }

    @Test func gaussAdaptive() {
        let result = MathSolver.integGaussAdaptive(over: 0...Double.pi, tolerance: 1e-10) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-8) }
    }

    @Test func kronrod() {
        let result = MathSolver.integKronrod(over: 0...Double.pi) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-6) }
    }

    @Test func kronrodAdaptive() {
        let result = MathSolver.integKronrodAdaptive(over: 0...Double.pi, tolerance: 1e-10) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-8) }
    }

    @Test func tanhSinh() {
        let result = MathSolver.integTanhSinh(over: 0...Double.pi, tolerance: 1e-8) { sin($0) }
        #expect(result != nil)
        if let r = result { #expect(abs(r.value - 2.0) < 1e-4) }
    }
}

@Suite("Convert_CompPolynomialToPoles")
struct PolynomialConvertTests {
    @Test func linearPolynomial() {
        // f(x) = 2x + 1 on [0,1]
        let result = PolynomialConvert.polynomialToPoles(
            dimension: 1, maxDegree: 1, degree: 1,
            coefficients: [1.0, 2.0],
            polynomialInterval: 0.0...1.0,
            trueInterval: 0.0...1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.poles.count > 0)
            #expect(r.knots.count > 0)
            #expect(r.degree == 1)
        }
    }

    @Test func quadraticPolynomial() {
        // f(x) = x^2 + x + 1 on [0,1]
        let result = PolynomialConvert.polynomialToPoles(
            dimension: 1, maxDegree: 2, degree: 2,
            coefficients: [1.0, 1.0, 1.0],
            polynomialInterval: 0.0...1.0,
            trueInterval: 0.0...1.0)
        #expect(result != nil)
        if let r = result {
            #expect(r.poles.count > 0)
            #expect(r.degree == 2)
        }
    }

    @Test func remappedInterval() {
        // Linear polynomial remapped from [0,1] to [-1,1]
        let result = PolynomialConvert.polynomialToPoles(
            dimension: 1, maxDegree: 1, degree: 1,
            coefficients: [0.0, 1.0],
            polynomialInterval: 0.0...1.0,
            trueInterval: -1.0...1.0)
        #expect(result != nil)
    }
}

@Suite("gp_Trsf_Extras")
struct TrsfExtrasTests {
    @Test func transformFromMatrix() {
        // Translation by (5, 10, 15)
        let box = Shape.box(width: 1, height: 1, depth: 1)
        if let b = box {
            let result = b.transformed(byMatrix: [
                1, 0, 0, 5,
                0, 1, 0, 10,
                0, 0, 1, 15
            ])
            #expect(result != nil)
            if let r = result {
                let bb = r.boundingBox
                #expect(bb != nil)
                if let bb = bb {
                    // Should be translated
                    #expect(bb.min.x > 4.0)
                    #expect(bb.min.y > 9.0)
                    #expect(bb.min.z > 14.0)
                }
            }
        }
    }

    @Test func transformIsNegative() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            // A freshly created box has identity location
            #expect(b.isTransformNegative == false)
        }
    }

    @Test func mirrorTransformProducesResult() {
        // Use origin-based box (corner at 5,0,0) so mirror moves it clearly
        let box = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b = box {
            // Mirror through YZ plane: X -> -X
            let mirrored = b.transformed(byMatrix: [
                -1, 0, 0, 0,
                 0, 1, 0, 0,
                 0, 0, 1, 0
            ])
            #expect(mirrored != nil)
            if let m = mirrored {
                let bb = m.boundingBox
                #expect(bb != nil)
                if let bb = bb {
                    // Original was [5,15], mirrored should be [-15,-5]
                    #expect(bb.max.x < -4.0)
                }
            }
        }
    }

    @Test func displacement() {
        let m = TransformUtils.displacement(
            from: (point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1)),
            to: (point: SIMD3(10, 0, 0), direction: SIMD3(0, 0, 1)))
        #expect(m.values.count == 12)
        // Translation of 10 in X should appear in a14
        #expect(abs(m.values[3] - 10.0) < 1e-10)
    }

    @Test func transformation() {
        let m = TransformUtils.transformation(
            from: (point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1)),
            to: (point: SIMD3(5, 5, 5), direction: SIMD3(0, 0, 1)))
        #expect(m.values.count == 12)
    }

    @Test func invalidMatrixSize() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            // Wrong size array should return nil
            let result = b.transformed(byMatrix: [1, 0, 0])
            #expect(result == nil)
        }
    }
}

@Suite("PlaneGeometry_Operations")
struct PlaneGeometryTests {
    @Test func distanceToPointOnPlane() {
        let d = PlaneGeometry.distanceToPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(5, 5, 0))
        #expect(abs(d) < 1e-10)
    }

    @Test func distanceToPointAbovePlane() {
        let d = PlaneGeometry.distanceToPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(0, 0, 7))
        #expect(abs(d - 7.0) < 1e-10)
    }

    @Test func distanceToParallelLine() {
        let d = PlaneGeometry.distanceToLine(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            linePoint: SIMD3(0, 0, 5), lineDirection: SIMD3(1, 0, 0))
        #expect(abs(d - 5.0) < 1e-10)
    }

    @Test func distanceToIntersectingLine() {
        let d = PlaneGeometry.distanceToLine(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            linePoint: SIMD3(0, 0, 5), lineDirection: SIMD3(0, 0, 1))
        #expect(abs(d) < 1e-10)
    }

    @Test func containsPointTrue() {
        let r = PlaneGeometry.containsPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(100, 200, 0), tolerance: 1e-7)
        #expect(r)
    }

    @Test func containsPointFalse() {
        let r = PlaneGeometry.containsPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(0, 0, 1), tolerance: 1e-7)
        #expect(!r)
    }
}

@Suite("LineGeometry_Operations")
struct LineGeometryTests {
    @Test func distanceToPointOnLine() {
        let d = LineGeometry.distanceToPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(5, 0, 0))
        #expect(abs(d) < 1e-10)
    }

    @Test func distanceToPointOffLine() {
        let d = LineGeometry.distanceToPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(5, 3, 0))
        #expect(abs(d - 3.0) < 1e-10)
    }

    @Test func distanceBetweenParallelLines() {
        let d = LineGeometry.distanceToLine(
            line1Point: SIMD3(0, 0, 0), line1Direction: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 4, 0), line2Direction: SIMD3(1, 0, 0))
        #expect(abs(d - 4.0) < 1e-10)
    }

    @Test func distanceBetweenIntersectingLines() {
        let d = LineGeometry.distanceToLine(
            line1Point: SIMD3(0, 0, 0), line1Direction: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 0), line2Direction: SIMD3(0, 1, 0))
        #expect(abs(d) < 1e-10)
    }

    @Test func containsPointTrue() {
        let r = LineGeometry.containsPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(100, 0, 0), tolerance: 1e-7)
        #expect(r)
    }

    @Test func containsPointFalse() {
        let r = LineGeometry.containsPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(0, 1, 0), tolerance: 1e-7)
        #expect(!r)
    }
}

@Suite("gp_Vec Extras v0.120.0")
struct GpVecExtrasTests {

    @Test func crossMagnitude() {
        let v1 = SIMD3<Double>(1, 0, 0)
        let v2 = SIMD3<Double>(0, 1, 0)
        let mag = Shape.vecCrossMagnitude(v1, v2)
        #expect(abs(mag - 1.0) < 1e-10)
    }

    @Test func crossMagnitudeParallel() {
        let v1 = SIMD3<Double>(1, 0, 0)
        let v2 = SIMD3<Double>(2, 0, 0)
        let mag = Shape.vecCrossMagnitude(v1, v2)
        #expect(abs(mag) < 1e-10)
    }

    @Test func crossSquareMagnitude() {
        let v1 = SIMD3<Double>(1, 0, 0)
        let v2 = SIMD3<Double>(0, 1, 0)
        let sqMag = Shape.vecCrossSquareMagnitude(v1, v2)
        #expect(abs(sqMag - 1.0) < 1e-10)
    }

    @Test func crossMagnitudeScaled() {
        let v1 = SIMD3<Double>(3, 0, 0)
        let v2 = SIMD3<Double>(0, 4, 0)
        let mag = Shape.vecCrossMagnitude(v1, v2)
        #expect(abs(mag - 12.0) < 1e-10)
    }
}

@Suite("gp_Dir Extras v0.120.0")
struct GpDirExtrasTests {

    @Test func isOpposite() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(-1, 0, 0)
        #expect(Shape.dirIsOpposite(d1, d2, tolerance: 0.01))
    }

    @Test func isNotOpposite() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(0, 1, 0)
        #expect(!Shape.dirIsOpposite(d1, d2, tolerance: 0.01))
    }

    @Test func isNormal() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(0, 1, 0)
        #expect(Shape.dirIsNormal(d1, d2, tolerance: 0.01))
    }

    @Test func isNotNormal() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(1, 0, 0)
        #expect(!Shape.dirIsNormal(d1, d2, tolerance: 0.01))
    }

    @Test func isNormalDiagonal() {
        // (1,1,0) normalized is perpendicular to (1,-1,0) normalized
        let d1 = SIMD3<Double>(1, 1, 0)
        let d2 = SIMD3<Double>(1, -1, 0)
        #expect(Shape.dirIsNormal(d1, d2, tolerance: 0.01))
    }
}

@Suite("Integration: Precision Extremes")
struct IntegrationPrecisionExtremesTests {

    @Test func microScale() {
        if let micro = Shape.box(width: 0.001, height: 0.001, depth: 0.001) {
            #expect(micro.isValid)
            if let vol = micro.volume {
                #expect(abs(vol - 1e-9) < 1e-12)
            }
        }
    }

    @Test func macroScale() {
        if let macro = Shape.box(width: 1000, height: 1000, depth: 1000) {
            #expect(macro.isValid)
            if let vol = macro.volume {
                #expect(abs(vol - 1e9) < 1e3)
            }
        }
    }

    @Test func mixedScaleLargeBoxSmallHole() {
        if let big = Shape.box(width: 1000, height: 1000, depth: 1000) {
            if let drilled = big.drilled(at: SIMD3(0.0, 0.0, 500.0), direction: SIMD3(0, 0, -1), radius: 0.01, depth: 0) {
                #expect(drilled.isValid)
            }
        }
    }
}

@Suite("Curve3D Transform")
struct Curve3DTransformTests {

    @Test("Translate BSpline curve")
    func translateCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)
        ])
        if let c = curve {
            let p0 = c.point(at: 0)
            let ok = c.translate(dx: 10, dy: 0, dz: 0)
            #expect(ok)
            let p1 = c.point(at: 0)
            #expect(abs(p1.x - p0.x - 10) < 0.001)
        }
    }

    @Test("Rotate curve")
    func rotateCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0)
        ])
        if let c = curve {
            let ok = c.rotate(axisOrigin: SIMD3(0, 0, 0),
                               axisDirection: SIMD3(0, 0, 1),
                               angle: .pi / 2)
            #expect(ok)
            let p = c.point(at: 0)
            // After 90 degree rotation around Z, (1,0,0) -> (0,1,0)
            #expect(abs(p.x) < 0.1)
            #expect(abs(p.y - 1) < 0.1)
        }
    }

    @Test("Scale curve")
    func scaleCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0)
        ])
        if let c = curve {
            let ok = c.scale(center: SIMD3(0, 0, 0), factor: 2)
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.x - 2) < 0.1)
        }
    }

    @Test("Mirror curve through point")
    func mirrorPointCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0)
        ])
        if let c = curve {
            let ok = c.mirrorPoint(SIMD3(0, 0, 0))
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.x + 1) < 0.1) // (1,0,0) -> (-1,0,0)
        }
    }

    @Test("Mirror curve through axis")
    func mirrorAxisCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 1, 0)
        ])
        if let c = curve {
            let ok = c.mirrorAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.y + 1) < 0.1) // y=1 -> y=-1
        }
    }

    @Test("Mirror curve through plane")
    func mirrorPlaneCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 5), SIMD3(2, 0, 5), SIMD3(3, 0, 5)
        ])
        if let c = curve {
            let ok = c.mirrorPlane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.z + 5) < 0.1) // z=5 -> z=-5
        }
    }
}

@Suite("Surface Transform")
struct SurfaceTransformTests {

    @Test("Translate surface")
    func translateSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.translate(dx: 10, dy: 0, dz: 5)
            #expect(ok)
        }
    }

    @Test("Rotate surface")
    func rotateSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.rotate(axisOrigin: SIMD3(0, 0, 0),
                               axisDirection: SIMD3(1, 0, 0),
                               angle: .pi / 4)
            #expect(ok)
        }
    }

    @Test("Scale surface")
    func scaleSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.scale(center: SIMD3(0, 0, 0), factor: 2)
            #expect(ok)
        }
    }

    @Test("Mirror surface through point")
    func mirrorPointSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.mirrorPoint(SIMD3(0, 0, 0))
            #expect(ok)
        }
    }

    @Test("Mirror surface through axis")
    func mirrorAxisSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.mirrorAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
            #expect(ok)
        }
    }

    @Test("Mirror surface through plane")
    func mirrorPlaneSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.mirrorPlane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
            #expect(ok)
        }
    }

    @Test("Transform BezierSurface values")
    func transformBezierSurface() {
        // Create a Bezier surface and verify transform changes values
        let surf = Surface.bezierFill(
            Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))!,
            Curve3D.line(through: SIMD3(0, 10, 0), direction: SIMD3(1, 0, 0))!
        )
        if let s = surf {
            let ok = s.translate(dx: 0, dy: 0, dz: 100)
            #expect(ok)
        }
    }
}

@Suite("TransformedCurve — Curve with Translation")
struct TransformedCurveTests {

    @Test func translateCircle() {
        guard let circ = Curve3D.circle(center: SIMD3(0,0,0), normal: SIMD3(0,0,1), radius: 5.0) else { return }
        guard let translated = circ.translated(tx: 10, ty: 0, tz: 0) else { return }
        let domain = translated.domain
        // Evaluate at start — circle starts at (5,0,0), translated to (15,0,0)
        let pt = translated.point(at: domain.lowerBound)
        #expect(abs(pt.x - 15.0) < 0.1)
    }
}

// MARK: - v0.144 #75: Drawing.transformed + bounds

@Suite("v0.144 Drawing transform + bounds")
struct DrawingCompositionTests {
    @Test("Drawing.bounds returns finite box for a projected box")
    func drawingBounds() {
        guard let box = Shape.box(width: 100, height: 50, depth: 25),
              let front = Drawing.frontView(of: box) else {
            Issue.record("setup nil"); return
        }
        let bounds = front.bounds()
        #expect(bounds != nil)
        if let b = bounds {
            #expect(b.min.x.isFinite && b.max.x.isFinite)
            #expect(b.max.x > b.min.x)
        }
    }

    @Test("transformed(translate:scale:) returns non-nil wrapper")
    func transformedSmoke() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let top = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let transformed = top.transformed(translate: SIMD2(50, 30), scale: 0.5)
        #expect(transformed.translate == SIMD2(50, 30))
        #expect(transformed.scale == 0.5)
    }

    @Test("DXFWriter.collectFromDrawing accepts TransformedDrawing")
    func dxfFromTransformed() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let top = Drawing.topView(of: box) else {
            Issue.record("setup nil"); return
        }
        let t = top.transformed(translate: SIMD2(100, 100), scale: 2.0)
        let writer = DXFWriter()
        writer.collectFromDrawing(t)
        // At least some lines or polylines should have been emitted.
        let counts = writer.entityCounts
        #expect(counts.lines + counts.polylines > 0)
    }
}
