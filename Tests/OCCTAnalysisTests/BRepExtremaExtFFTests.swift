import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema ExtFF Tests")
struct BRepExtremaExtFFTests {
    /// The #2249 fixture: two axis-aligned 5-cubes with a 7.5 gap between them.
    ///
    /// `Shape.box(width:height:depth:)` centres its box and `Shape.box(origin:...)` takes a corner,
    /// so the measured bounding boxes are [-2.5, 2.5]^3 and [10, 15] x [0, 5] x [0, 5]. Every one of
    /// the 36 face pairs is either parallel or has no classified extremum, which is why the suite
    /// needs a second fixture to reach the witnessed branch at all.
    private func twoCubes() throws -> (Shape, Shape) {
        let box1 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let box2 = try #require(
            Shape.box(origin: SIMD3(10, 0, 0), width: 5, height: 5, depth: 5))
        return (box1, box2)
    }

    @Test("Face-face distance between separated boxes")
    func faceFaceDistance() throws {
        let (box1, box2) = try twoCubes()
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
        #expect(foundResult, "no face pair of two separated boxes answered at all")
    }

    /// #2249: for parallel faces the kernel computes no witness point, so the API reports none.
    ///
    /// `BRepExtrema_ExtFF::Perform` appends one square distance and leaves `myPointsOnS1/S2` empty
    /// on its `IsParallel()` branch (`BRepExtrema_ExtFF.cxx:83-86`), so `NbExt()` is 1 while
    /// `ParameterOnFace1(1, ...)` throws `Standard_OutOfRange`. The bridge used to let its
    /// function-level `catch (...)` return the half-written struct, and the four witness fields
    /// arrived in Swift as zeros that read as measurements.
    @Test("Parallel faces report isParallel and no witness points (#2249)")
    func parallelFacesReportNoWitnessPoints() throws {
        let (box1, box2) = try twoCubes()
        var parallelPairs = 0
        for i in 0..<6 {
            for j in 0..<6 {
                guard let r = box1.faceFaceExtrema(faceIndex1: i, other: box2, faceIndex2: j),
                    r.isParallel
                else { continue }
                parallelPairs += 1
                #expect(r.pointOnFace1 == nil, "pair (\(i), \(j)) fabricated a point on face 1")
                #expect(r.pointOnFace2 == nil, "pair (\(i), \(j)) fabricated a point on face 2")
                #expect(r.face1UV == nil, "pair (\(i), \(j)) fabricated a UV on face 1")
                #expect(r.face2UV == nil, "pair (\(i), \(j)) fabricated a UV on face 2")
                // The distance is real on this branch: the kernel appended it before giving up on
                // the points, and DRAW's offset dimension reads exactly this value.
                #expect(r.distance > 0.0, "pair (\(i), \(j)) reported a zero distance")
                #expect(r.solutionCount == 1)
            }
        }
        // 12 of the 36 pairs are parallel: 2 x caps against 2 x caps, and likewise in y and z.
        #expect(parallelPairs == 12, "found \(parallelPairs) parallel pairs, expected 12")
    }

    /// The facing x caps, x = 2.5 and x = 10, whose 7.5 offset is also the two solids' own gap.
    @Test("A parallel pair reports the plane offset as its distance (#2249)")
    func parallelPairReportsThePlaneOffset() throws {
        let (box1, box2) = try twoCubes()
        let r = try #require(box1.faceFaceExtrema(faceIndex1: 1, other: box2, faceIndex2: 0))
        #expect(r.isParallel)
        #expect(abs(r.distance - 7.5) < 1e-9, "distance was \(r.distance)")
        #expect(r.pointOnFace1 == nil)
        let shapeGap = try #require(box1.minDistance(to: box2))
        #expect(abs(r.distance - shapeGap) < 1e-6, "the facing caps are what the solids' gap is")
    }

    /// The documented caveat, pinned so nobody "corrects" the doc comment (#2249).
    ///
    /// On the parallel branch `BRepExtrema_ExtFF` has not reached `BRepClass_FaceClassifier`, so the
    /// distance is between the two underlying surfaces and not between the trimmed faces. Pair
    /// (2, 2) is a y cap of each box: those two planes, y = 2.5 and y = 0, are 2.5 apart, while the
    /// faces lying in them are 7.5 apart in x and do not overlap there at all. `minDistance(to:)`,
    /// which goes through `BRepExtrema_DistShapeShape`, is what answers for the solids.
    @Test("The parallel distance is the surface offset, not the face gap (#2249)")
    func parallelDistanceIsTheSurfaceOffset() throws {
        let (box1, box2) = try twoCubes()
        let r = try #require(box1.faceFaceExtrema(faceIndex1: 2, other: box2, faceIndex2: 2))
        #expect(r.isParallel)
        #expect(abs(r.distance - 2.5) < 1e-9, "distance was \(r.distance)")
        let shapeGap = try #require(box1.minDistance(to: box2))
        #expect(abs(shapeGap - 7.5) < 1e-6, "shape gap was \(shapeGap)")
        #expect(r.distance < shapeGap, "the caveat has stopped being true")
    }

    /// The other branch, so the witnessed path is exercised rather than assumed (#2249).
    ///
    /// A sphere face against a planar box cap is not parallel, so `BRepExtrema_ExtFF` classifies
    /// its extrema and fills both points. Box1's x = 2.5 cap against a radius-2 sphere centred at
    /// x = 12: the nearest sphere point is x = 10, so the distance is 7.5 and the two witness
    /// points are (2.5, 0, 0) and (10, 0, 0).
    @Test("Non-parallel faces carry witness points that match the distance (#2249)")
    func nonParallelFacesCarryWitnessPoints() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let sphere = try #require(Shape.sphere(radius: 2)?.translated(by: SIMD3(12, 0, 0)))

        var witnessed = 0
        for i in 0..<6 {
            guard let r = box.faceFaceExtrema(faceIndex1: i, other: sphere, faceIndex2: 0) else {
                continue
            }
            #expect(!r.isParallel, "a sphere face cannot be parallel to a plane")
            guard let p1 = r.pointOnFace1, let p2 = r.pointOnFace2 else {
                Issue.record("face \(i) against the sphere reported no witness points")
                continue
            }
            #expect(r.face1UV != nil)
            #expect(r.face2UV != nil)
            // The two points are what the distance measures, so they have to agree with it.
            #expect(
                abs(simd_distance(p1, p2) - r.distance) < 1e-6,
                "face \(i): |p1 - p2| = \(simd_distance(p1, p2)) but distance = \(r.distance)")
            witnessed += 1
        }
        #expect(witnessed == 6, "only \(witnessed) of the 6 box faces answered")
    }

    /// The nearest pair, with both numbers checked against hand arithmetic (#2249).
    @Test("The closest box cap to the sphere measures 7.5 at (2.5, 0, 0) (#2249)")
    func nearestWitnessPointsAreWhereTheGeometrySaysTheyAre() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let sphere = try #require(Shape.sphere(radius: 2)?.translated(by: SIMD3(12, 0, 0)))

        let all = (0..<6).compactMap {
            box.faceFaceExtrema(faceIndex1: $0, other: sphere, faceIndex2: 0)
        }
        let r = try #require(all.min { $0.distance < $1.distance })
        #expect(abs(r.distance - 7.5) < 1e-6, "distance was \(r.distance)")
        if let p1 = r.pointOnFace1 {
            #expect(abs(p1.x - 2.5) < 1e-4, "point on the cap was \(p1)")
            #expect(abs(p1.y) < 1e-4)
            #expect(abs(p1.z) < 1e-4)
        } else {
            Issue.record("the nearest pair reported no point on face 1")
        }
        if let p2 = r.pointOnFace2 {
            #expect(abs(p2.x - 10.0) < 1e-4, "point on the sphere was \(p2)")
        } else {
            Issue.record("the nearest pair reported no point on face 2")
        }
    }
}
