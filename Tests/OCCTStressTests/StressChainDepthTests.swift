// StressChainDepthTests.swift
// Category 3: Long boolean chains, feature chains, transform chains, wire construction.

import Foundation
import OCCTSwift
import Testing

// #2983: every link of every chain below is required. The chains used to bind each link with
// `if let ... { shape = result }`, which skips a link the kernel (or the bridge) refuses and goes on
// to assert on the shorter chain; only the final figure said whether every link ran, and for the
// chains whose figure barely moves per link that is a small signal. On the pinned kernel every link
// of every chain here succeeds (measured, 0 refusals in 50 + 100 + 50 + 50 + 30 booleans, 1000 + 1000
// + 100 + 100 transforms and 4 + 5 + 10 + 10 features), so a refusal is now a failure that names its
// link. `tenSuccessiveFillets` is the one chain whose second link is refused by the kernel, and it
// still says so.

/// A sphere of `radius` centred at (`x`, `y`, 0), required.
private func sphereAt(radius: Double, x: Double, y: Double) throws -> Shape {
    let sphere = try #require(Shape.sphere(radius: radius), "sphere r=\(radius)")
    return try #require(sphere.translated(by: SIMD3(x, y, 0)), "translate sphere to (\(x), \(y))")
}

/// The (x, y) centres of `shape`'s cylindrical faces, sorted by x then y. A full cylinder's box is
/// centred on its axis, so the middle of the face's bounds is the axis' position.
private func cylinderCentres(of shape: Shape) throws -> [SIMD2<Double>] {
    var centres: [SIMD2<Double>] = []
    for face in shape.faces() where face.surfaceType == .cylinder {
        let b = try #require(face.bounds, "cylindrical face with no bounds")
        centres.append(SIMD2((b.min.x + b.max.x) / 2, (b.min.y + b.max.y) / 2))
    }
    return centres.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
}

// MARK: - Boolean Chains

@Suite("Stress: Boolean Chains")
struct StressBooleanChainTests {

    @Test func fiftySubtractions() throws {
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 100))
        for i in 0..<50 {
            let angle = Double(i) * (2.0 * .pi / 50.0)
            let cutter = try sphereAt(radius: 3, x: 30.0 * cos(angle), y: 30.0 * sin(angle))
            shape = try #require(shape.subtracting(cutter), "cut \(i)")
            // The first cut is on its own: a sphere of r = 3 is 4/3 pi 27 = 113.0973355. Every
            // later one overlaps its neighbours (3.77 apart, 6 across), so only the first has a
            // closed form.
            if i == 0 {
                #expect(abs((shape.volume ?? 0) - (1e6 - 4.0 / 3.0 * .pi * 27)) < 1e-6)
            }
        }
        #expect(shape.isValid)
        // Epic #766: "smaller than before" held for any single successful cut. The kernel's
        // volume after all fifty is 995373.8819 (Scripts/repro/766-stress-chain-depth/).
        #expect(abs((shape.volume ?? 0) - 995373.8819) < 1e-3)
    }

    @Test func hundredSubtractions() throws {
        var shape = try #require(Shape.box(width: 200, height: 200, depth: 200))
        for i in 0..<100 {
            let angle = Double(i) * (2.0 * .pi / 100.0)
            let cutter = try sphereAt(radius: 2, x: 60.0 * cos(angle), y: 60.0 * sin(angle))
            shape = try #require(shape.subtracting(cutter), "cut \(i)")
            // Check validity every 25 ops
            if (i + 1) % 25 == 0 { #expect(shape.isValid, "invalid after cut \(i)") }
            // The neighbouring spheres are 3.77 apart and 4 across, so the first cut alone has a
            // closed form: 4/3 pi 8 = 33.5103216.
            if i == 0 {
                #expect(abs((shape.volume ?? 0) - (8e6 - 4.0 / 3.0 * .pi * 8)) < 1e-6)
            }
        }
        // Epic #766: pinned to the kernel's volume after all hundred cuts.
        #expect(abs((shape.volume ?? 0) - 7996665.368) < 1e-2)
    }

    @Test func fiftyUnions() throws {
        var shape = try #require(Shape.box(width: 5, height: 5, depth: 5))
        for i in 0..<50 {
            let box = try #require(
                Shape.box(origin: SIMD3(Double(i) * 5, 0, 0), width: 5, height: 5, depth: 5),
                "box \(i)")
            shape = try #require(shape.union(box), "union \(i)")
        }
        #expect(shape.isValid)
        // Epic #766: "positive" held for the starting box alone, so fifty failed unions passed.
        // Closed form: the starting box is centred on the origin, [-2.5, 2.5]^3, and
        // `box(origin:)` takes the minimum corner, so box i is [5i, 5i + 5] x [0, 5] x [0, 5]. The
        // fifty are disjoint from one another, and only box 0 meets the starting box, in
        // [0, 2.5]^3 = 15.625. So 51 boxes of 125, less that one overlap: 6375 - 15.625 = 6359.375.
        #expect(abs((shape.volume ?? 0) - (51 * 125 - 15.625)) < 1e-6)
        // One solid, not fifty-one touching ones: the fuse merged the abutting faces.
        #expect(shape.solidCount == 1)
    }

    @Test func fiftyIntersections() throws {
        // Start large, progressively intersect with slightly smaller boxes
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 100))
        for i in 0..<50 {
            let size = 100.0 - Double(i) * 0.5
            let box = try #require(Shape.box(width: size, height: size, depth: size), "box \(i)")
            shape = try #require(shape.intersection(box), "intersection \(i)")
            // Boxes are centred, so each common is the smaller of the two cubes.
            if i == 1 || i == 49 {
                #expect(abs((shape.volume ?? 0) - size * size * size) < 1e-4, "after \(i)")
            }
        }
        #expect(shape.isValid)
        // Epic #766: the last common is with the 75.5-wide box, so the result is that box.
        #expect(abs((shape.volume ?? 0) - 75.5 * 75.5 * 75.5) < 1e-4)
    }

    @Test func mixedBooleans() throws {
        var shape = try #require(Shape.box(width: 50, height: 50, depth: 50))
        for i in 0..<30 {
            let small = try #require(
                Shape.box(
                    origin: SIMD3(Double(i % 5) * 8, Double(i / 5) * 8, 0),
                    width: 6, height: 6, depth: 6),
                "small box \(i)")
            let combined: Shape?
            switch i % 3 {
            case 0: combined = shape.union(small)
            case 1: combined = shape.subtracting(small)
            default: combined = shape.intersection(small)
            }
            shape = try #require(combined, "boolean \(i) (kind \(i % 3))")
            // Epic #766: validity alone passed for thirty no-op booleans, and so did the final
            // "ends empty" figure, which any chain that loses its shape reaches. So the volume
            // after every link is pinned. The 50-cube is centred on the origin and the small
            // boxes start at their minimum corner, so:
            //   0 union at (0,0)     inside the cube          125000
            //   1 subtract at (8,0)  inside the cube          125000 - 216
            //   2 intersect at (16,0) inside, clear of the cut  216
            //   3 union at (24,0)    abuts nothing, disjoint    432
            //   4 subtract at (32,0) disjoint from both         432
            //   5 intersect at (0,8) meets neither              empty
            // and from there the chain repeats: a union puts a 216 box back, a subtract misses it,
            // and the intersect at the next cell misses it, leaving nothing again. An empty
            // result has no volume (reported as nil, not 0) and no faces.
            let expected: Double?
            switch i {
            case 0: expected = 125_000
            case 1: expected = 125_000 - 216
            case 2: expected = 216
            case 3, 4: expected = 432
            default: expected = i % 3 == 2 ? nil : 216
            }
            if let expected {
                #expect(abs((shape.volume ?? 0) - expected) < 1e-6, "volume after \(i)")
            } else {
                #expect(shape.volume == nil, "volume after \(i)")
                #expect(shape.subShapeCount(ofType: .face) == 0, "faces after \(i)")
            }
        }
        #expect(shape.isValid)
    }
}

// MARK: - Feature Chains

@Suite("Stress: Feature Chains")
struct StressFeatureChainTests {

    @Test func filletDrillChamferChain() throws {
        var shape = try #require(Shape.box(width: 40, height: 40, depth: 20))
        // Fillet. Each link is required (see the note at the top of the file), and pinned as it
        // goes: a link that returned its input would leave the later figures where they were.
        shape = try #require(shape.filleted(radius: 1.0), "fillet")
        #expect(shape.isValid)
        #expect(shape.subShapeCount(ofType: .face) == 26, "6 faces + 12 edge fillets + 8 corners")
        // Closed form: the twelve edges are 4 x (38 + 38 + 18) = 376 long between the corners and
        // each removes (1 - pi/4) r^2 per unit length; each of the eight corners removes
        // (1 - pi/6) r^3 more. 32000 - 80.6903 - 3.8112 = 31915.4985.
        let edgeLoss: Double = 376.0 * (1.0 - Double.pi / 4.0)
        let cornerLoss: Double = 8.0 * (1.0 - Double.pi / 6.0)
        var expectedVolume: Double = 32000.0 - edgeLoss - cornerLoss
        #expect(abs((shape.volume ?? 0) - expectedVolume) < 1e-6)
        // Drill 4 holes
        let positions: [SIMD3<Double>] = [
            SIMD3(-10, -10, 10), SIMD3(10, -10, 10),
            SIMD3(-10, 10, 10), SIMD3(10, 10, 10),
        ]
        for (n, pos) in positions.enumerated() {
            shape = try #require(
                shape.drilled(at: pos, direction: SIMD3(0, 0, -1), radius: 2, depth: 0),
                "drill \(n)")
            // A through-hole of r = 2 in the 20-deep plate takes 80 pi, well clear of the fillets.
            expectedVolume -= 80 * .pi
            #expect(abs((shape.volume ?? 0) - expectedVolume) < 1e-6, "volume after drill \(n)")
        }
        #expect(shape.isValid)
        // Chamfer
        shape = try #require(shape.chamfered(distance: 0.3), "chamfer")
        #expect(shape.isValid)
        #expect(
            shape.subShapeCount(ofType: .face) == 38,
            "measured 26 fillet faces + 4 hole walls + 8 chamfer faces")
        // Shell. #2830: this link never ran, and "may fail on complex geometry" was the wrong
        // reason. `shelled(thickness:)` is `MakeThickSolidBySimple`, whose domain is a non-closed
        // shell or face, so it refuses this closed chain result for the same reason it refuses a
        // plain box (#2739). The refusal is pinned rather than skipped, because an `if let` that
        // never binds leaves the chain one link shorter than the test claims, with nothing saying
        // so.
        //
        // `shelled(thickness:openFaces:)` is what hollows a closed solid, and it is deliberately
        // not the link here: on this chain result it returns a shape whose `isValid` is false and
        // whose `volume` is nil, measured, so it would trade a dead link for a failing one. That
        // non-nil-but-invalid result is filed as #2846, since it is a bridge and docs question. The
        // chain therefore ends at the chamfer, which is what its name already says. The trailing
        // `#expect(shape.isValid)` that used to sit here is gone: `shape` is untouched by the
        // refused shell, so it re-asserted the chamfer already asserted three lines up.
        #expect(shape.shelled(thickness: -1.0) == nil)
        // Epic #766: four validity checks passed for a chain in which every step could have
        // failed, because each link sits behind its own `if let`. The volume says they ran: the
        // 40 x 40 x 20 box is 32000, the r = 1 fillet on all twelve edges takes about 86, the four
        // r = 2 through-holes take 320 pi = 1005.31, and the 0.3 chamfer takes the remainder.
        #expect(abs((shape.volume ?? 0) - 30905.43876) < 1e-3)
    }

    @Test func tenSuccessiveFillets() throws {
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 100))
        var succeeded = 0
        for i in 0..<10 {
            let radius = 0.5 + Double(i) * 0.1
            if let f = shape.filleted(radius: radius) {
                shape = f
                #expect(shape.isValid)
                succeeded += 1
            } else {
                break  // Fillet failed, expected for complex shapes
            }
        }
        // Epic #766: a first fillet that failed broke out before any expectation ran. In the
        // kernel the first fillet (r = 0.5) succeeds and the second, on the filleted box, does not.
        #expect(succeeded == 1)
        #expect(abs((shape.volume ?? 0) - 999935.7869) < 1e-3)
    }

    @Test func tenDrillsGrid() throws {
        var shape = try #require(Shape.box(width: 100, height: 100, depth: 10))
        for row in 0..<5 {
            for col in 0..<2 {
                let x = -30.0 + Double(row) * 15.0
                let y = -10.0 + Double(col) * 20.0
                shape = try #require(
                    shape.drilled(
                        at: SIMD3(x, y, 10), direction: SIMD3(0, 0, -1), radius: 2, depth: 0),
                    "drill (\(row), \(col))")
            }
        }
        #expect(shape.isValid)
        // Epic #766: ten through-holes of radius 2 in a 10-thick plate: 1e5 - 10·π·4·10.
        #expect(abs((shape.volume ?? 0) - (1e5 - 400 * .pi)) < 1e-3)
        // Each hole adds one cylindrical face to the box's six.
        #expect(shape.subShapeCount(ofType: .face) == 16)
        // Where the holes are. The volume is the same wherever a hole sits inside the plate, and
        // so is the face count, so neither can see a drill that swapped x and y or ignored the
        // row spacing; the cylinder axes can: rows at x = -30, -15, 0, 15, 30, columns at
        // y = -10, 10.
        var expected: [SIMD2<Double>] = []
        for row in 0..<5 {
            for col in 0..<2 {
                expected.append(SIMD2(-30.0 + Double(row) * 15.0, -10.0 + Double(col) * 20.0))
            }
        }
        let centres = try cylinderCentres(of: shape)
        #expect(centres.count == 10)
        for (found, want) in zip(centres, expected) {
            #expect(abs(found.x - want.x) < 1e-5 && abs(found.y - want.y) < 1e-5, "hole at \(want)")
        }
    }

    @Test func deepFeatureChain() throws {
        var shape = try #require(Shape.box(width: 50, height: 50, depth: 30))
        // Fillet → drill → fillet → drill → ... 10 cycles. All twenty links are required, which
        // is what the old `stepCount == 20` counted (measured: every one succeeds in the kernel).
        for i in 0..<10 {
            shape = try #require(shape.filleted(radius: 0.3), "fillet \(i)")
            let x = -15.0 + Double(i) * 3.0
            shape = try #require(
                shape.drilled(at: SIMD3(x, 0, 15), direction: SIMD3(0, 0, -1), radius: 1, depth: 0),
                "drill \(i)")
        }
        #expect(shape.isValid)
        #expect(abs((shape.volume ?? 0) - 74045.18424) < 1e-3)
    }
}

// MARK: - Transform Chains

@Suite("Stress: Transform Chains")
struct StressTransformChainTests {

    @Test func thousandTranslations() throws {
        var shape = standardBox()
        for i in 0..<1000 {
            shape = try #require(shape.translated(by: SIMD3(0.001, 0, 0)), "translation \(i)")
        }
        #expect(shape.isValid)
        // Epic #766: `b.max.x > 0.5` held after a single successful translation, and the `bounds!`
        // it read was a force unwrap. 1000 x 0.001 moves the box 1 along X, from [-5, 5] to
        // [-4, 6], and Y and Z do not move.
        let b = try #require(shape.bounds)
        #expect(abs(b.max.x - 6) < 1e-6)
        #expect(abs(b.min.x - -4) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
        #expect(abs(b.min.y - -5) < 1e-6)
        #expect(abs(b.max.z - 5) < 1e-6)
        #expect(abs(b.min.z - -5) < 1e-6)
    }

    @Test func thousandRotations() throws {
        var shape = standardBox()
        let angleStep = (2.0 * .pi) / 1000.0
        for i in 0..<1000 {
            shape = try #require(shape.rotated(axis: SIMD3(0, 0, 1), angle: angleStep), "turn \(i)")
            // The control a full turn cannot give: a box that was never rotated has the same
            // bounds as one turned all the way round. An eighth of the way (125 steps, 45 degrees)
            // the box is on its diagonal, so its x and y extents are 5 sqrt(2) = 7.0711 and not 5.
            // The box bounds carry the kernel's 1e-7 enlargement.
            if i == 124 {
                let mid = try #require(shape.bounds)
                #expect(abs(mid.max.x - 5 * 2.0.squareRoot()) < 1e-6)
                #expect(abs(mid.min.y - -5 * 2.0.squareRoot()) < 1e-6)
                #expect(abs(mid.max.y - 5 * 2.0.squareRoot()) < 1e-6)
                #expect(abs(mid.min.x - -5 * 2.0.squareRoot()) < 1e-6)
            }
        }
        #expect(shape.isValid)
        // After the full turn the box is back where it started and axis-aligned, volume 1000 to
        // rounding (measured 999.9999999999875).
        #expect(abs((shape.volume ?? 0) - 1000.0) < 1e-6)
        // Epic #766: the volume is the same at every angle, so it could not see a wrong one. The
        // bounds can: after a full turn the box is axis-aligned again, corners at +/- 5.
        let b = try #require(shape.bounds)
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
        #expect(abs(b.min.x - -5) < 1e-6)
        #expect(abs(b.min.y - -5) < 1e-6)
        // A turn about Z leaves Z alone.
        #expect(abs(b.max.z - 5) < 1e-6)
        #expect(abs(b.min.z - -5) < 1e-6)
    }

    @Test func hundredScales() throws {
        var shape = standardBox()
        // Scale up then back down. Up by 1.01 and back by 1/1.01 fifty times each is the identity,
        // so a chain that did nothing ends where this one does. The half-way figure is the part a
        // no-op cannot reach: fifty scalings by 1.01 take the half-side to 5 * 1.01^50 and the
        // volume to 1000 * 1.01^150.
        for i in 0..<50 {
            shape = try #require(shape.scaled(by: 1.01), "scale up \(i)")
        }
        let upBounds = try #require(shape.bounds)
        #expect(abs(upBounds.max.x - 5 * pow(1.01, 50)) < 1e-5)
        #expect(abs((shape.volume ?? 0) - 1000 * pow(1.01, 150)) < 1e-6 * pow(1.01, 150) * 1000)
        for i in 0..<50 {
            shape = try #require(shape.scaled(by: 1.0 / 1.01), "scale down \(i)")
        }
        #expect(shape.isValid)
        // Epic #766: a 10 percent band around 1000 passed for a chain in which the fifty scalings
        // up and the fifty back down had both done nothing, and it also passed if one direction
        // had run and the other had not been far off. Back at the start, the box is the box
        // again: volume 1000, corners at +/- 5.
        #expect(abs((shape.volume ?? 0) - 1000) < 1e-6)
        let b = try #require(shape.bounds)
        // 1e-6 and not 1e-9: a hundred `gp_Trsf` scalings accumulate rounding in the corner
        // coordinates that the volume, being a product of three of them, happens to cancel.
        // Measured on the pinned kernel, 1e-9 is below that floor and 1e-6 is well above it.
        #expect(abs(b.max.x - 5) < 1e-6)
        #expect(abs(b.min.x - -5) < 1e-6)
        #expect(abs(b.max.y - 5) < 1e-6)
        #expect(abs(b.min.y - -5) < 1e-6)
        #expect(abs(b.max.z - 5) < 1e-6)
        #expect(abs(b.min.z - -5) < 1e-6)
    }

    @Test func mixedTransforms() throws {
        var shape = standardBox()
        // The same hundred links followed on paper: the box's centre c, its turn angle and its
        // scale. `translated` adds to c, `rotated` about Z through the origin turns c and the box,
        // `scaled` scales about the origin so it scales c and the box.
        var centre = SIMD2<Double>(0, 0)
        var angle = 0.0
        var scale = 1.0
        for i in 0..<100 {
            switch i % 3 {
            case 0:
                shape = try #require(shape.translated(by: SIMD3(0.01, 0, 0)), "translate \(i)")
                centre.x += 0.01
            case 1:
                shape = try #require(
                    shape.rotated(axis: SIMD3(0, 0, 1), angle: 0.01), "rotate \(i)")
                let (c, s) = (cos(0.01), sin(0.01))
                centre = SIMD2(c * centre.x - s * centre.y, s * centre.x + c * centre.y)
                angle += 0.01
            default:
                shape = try #require(shape.scaled(by: 1.001), "scale \(i)")
                centre *= 1.001
                scale *= 1.001
            }
        }
        #expect(shape.isValid)
        // Epic #766: 33 scalings by 1.001 (rotation and translation keep the volume), so
        // 1000 · 1.001^99 = 1104.01168603.
        #expect(abs((shape.volume ?? 0) - 1104.01168603) < 1e-6)
        // Rotation and translation keep the volume, so the figure above cannot see them. The
        // bounds can: an axis-aligned box of half-side 5 * scale turned by `angle` spans
        // 5 * scale * (|cos| + |sin|) each side of its centre in x and y, and 5 * scale in z.
        // The box bounds carry the kernel's 1e-7 enlargement.
        let half = 5 * scale * (abs(cos(angle)) + abs(sin(angle)))
        let b = try #require(shape.bounds)
        #expect(abs(b.max.x - (centre.x + half)) < 1e-5)
        #expect(abs(b.min.x - (centre.x - half)) < 1e-5)
        #expect(abs(b.max.y - (centre.y + half)) < 1e-5)
        #expect(abs(b.min.y - (centre.y - half)) < 1e-5)
        #expect(abs(b.max.z - 5 * scale) < 1e-5)
        #expect(abs(b.min.z - -5 * scale) < 1e-5)
    }
}

// MARK: - Wire Construction

@Suite("Stress: Wire Construction Chains")
struct StressWireConstructionTests {

    @Test func hundredEdgeWire() {
        let builder = WireBuilder()
        let box = Shape.box(width: 100, height: 100, depth: 100)!
        let edges = box.subShapes(ofType: .edge)
        // Add many edges (some may be duplicates, that's fine)
        for i in 0..<min(100, edges.count * 10) {
            builder.addEdge(edges[i % edges.count])
        }
        // Epic #766: both were discarded. BRepBuilderAPI_MakeWire ends done, with each of the 12
        // edges in the wire once however often it was added.
        #expect(builder.isDone)
        #expect(builder.wire?.subShapeCount(ofType: .edge) == 12)
    }

    @Test func largePolygonWire() throws {
        // 100-sided polygon
        var points: [SIMD3<Double>] = []
        for i in 0..<100 {
            let angle = Double(i) * 2.0 * .pi / 100.0
            points.append(SIMD3(10.0 * cos(angle), 10.0 * sin(angle), 0))
        }
        // Epic #766: a nil wire or length used to pass. The perimeter of the regular 100-gon of
        // radius 10 is 200·10·sin(π/100).
        let w = try #require(Wire.polygon3D(points, closed: true))
        #expect(abs((w.length ?? 0) - 2000 * sin(.pi / 100)) < 1e-9)
    }

    @Test func manyPointInterpolation() throws {
        // Interpolate through 50 points
        var points: [SIMD3<Double>] = []
        for i in 0..<50 {
            let t = Double(i) / 49.0
            points.append(SIMD3(t * 20, sin(t * 4 * .pi) * 3, 0))
        }
        // Epic #766: a nil curve skipped the whole body, and `pt.x.isFinite` is true of every
        // double a wrong curve could return. An interpolating curve passes through its data, so
        // its ends are the first and last point, it stays in the z = 0 plane the data lies in,
        // and its 100 samples stay inside the data's own x span.
        let curve = try #require(Curve3D.interpolate(points: points))
        let domain = curve.domain
        let first = curve.point(at: domain.lowerBound)
        let last = curve.point(at: domain.upperBound)
        #expect(abs(first.x - 0) < 1e-9)
        #expect(abs(first.y - 0) < 1e-9)
        #expect(abs(last.x - 20) < 1e-9)
        #expect(abs(last.y - sin(4 * .pi) * 3) < 1e-9)
        var maxAbsZ = 0.0
        var xOutOfSpan = 0
        for j in 0...100 {
            let u = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(j) / 100.0
            let pt = curve.point(at: u)
            maxAbsZ = max(maxAbsZ, abs(pt.z))
            if pt.x < -1e-9 || pt.x > 20 + 1e-9 { xOutOfSpan += 1 }
        }
        #expect(maxAbsZ < 1e-9)
        #expect(xOutOfSpan == 0)
    }
}

// MARK: - Document Assembly Chains

@Suite("Stress: Document Assembly Chains")
struct StressDocumentAssemblyTests {

    // Epic #766: `guard let doc = Document.create() else { return }` passed when creation
    // failed, in all three tests. They now require the document.
    @Test func hundredShapesInDocument() throws {
        let doc = try #require(Document.create())
        var labels = Set<Int64>()
        for i in 0..<100 {
            let box = try #require(
                Shape.box(width: Double(i + 1), height: 10, depth: 10), "box \(i)")
            labels.insert(doc.addShape(box))
        }
        #expect(doc.shapeCount == 100)
        // A hundred distinct labels, not one label overwritten (measured: 0 through 99).
        #expect(labels.count == 100)
        #expect(!labels.contains { $0 < 0 })
    }

    @Test func deepAssemblyTree() throws {
        let doc = try #require(Document.create())
        // Build 5-level deep assembly
        let lastLabel = doc.addShape(standardBox())
        for _ in 0..<5 {
            let childBox = Shape.box(width: 5, height: 5, depth: 5)!
            let childLabel = doc.addShape(childBox)
            _ = childLabel
            _ = lastLabel
        }
        // Epic #766: the box plus five children, six free shapes (">= 5" passed with one missing).
        #expect(doc.shapeCount == 6)
    }

    @Test func manyColorAssignments() throws {
        let doc = try #require(Document.create())
        for i in 0..<50 {
            let r = Double(i) / 50.0
            _ = doc.colorToolAddColor(r: r, g: 0.5, b: 1.0 - r)
        }
        // Epic #766: fifty distinct colours, fifty entries.
        #expect(doc.colorToolColorCount == 50)
    }
}

// MARK: - Curve Evaluation Chains

@Suite("Stress: Curve Evaluation Depth")
struct StressCurveEvalDepthTests {

    // Epic #766: `pt.x.isFinite` is true of every double, so this measured that the evaluator
    // returned at all. `standardCurve3D()` is the r = 5 circle about Z through the origin, so
    // every one of the ten thousand points is exactly 5 from the origin and exactly on z = 0.
    // The errors are accumulated and asserted once: ten thousand `#expect` calls cost more than
    // the evaluation they wrap, and a maximum names the worst sample rather than the first.
    @Test func tenThousandPointEval() {
        let curve = standardCurve3D()
        let domain = curve.domain
        var maxRadiusError = 0.0
        var maxAbsZ = 0.0
        for i in 0..<10_000 {
            let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 9999.0
            let pt = curve.point(at: t)
            maxRadiusError = max(maxRadiusError, abs((pt.x * pt.x + pt.y * pt.y).squareRoot() - 5))
            maxAbsZ = max(maxAbsZ, abs(pt.z))
        }
        #expect(maxRadiusError < 1e-9)
        #expect(maxAbsZ < 1e-9)
    }

    // Epic #766: as above, `pt.x.isFinite` measured nothing. `standardBezierSurface()` has its
    // z poles at 2 on the four interior control points and 0 everywhere else, which is separable:
    // z(u, v) = 2 * A(u) * A(v) with A(t) = B1(t) + B2(t) = 3t(1 - t), so z = 18 u(1-u) v(1-v)
    // exactly. Its x and y poles are evenly spaced 0, 5, 10, 15, so x and y are linear in the
    // parameters over [0, 15].
    @Test func surfaceGridEval10x10() {
        let surf = standardBezierSurface()
        let dom = surf.domain
        var maxZError = 0.0
        var maxPlanError = 0.0
        for ui in 0..<100 {
            for vi in 0..<100 {
                let fu = Double(ui) / 99.0
                let fv = Double(vi) / 99.0
                let u = dom.uMin + (dom.uMax - dom.uMin) * fu
                let v = dom.vMin + (dom.vMax - dom.vMin) * fv
                let pt = surf.point(atU: u, v: v)
                maxZError = max(maxZError, abs(pt.z - 18 * fu * (1 - fu) * fv * (1 - fv)))
                maxPlanError = max(maxPlanError, abs(pt.x - 15 * fv), abs(pt.y - 15 * fu))
            }
        }
        #expect(maxZError < 1e-9)
        #expect(maxPlanError < 1e-9)
    }

    // Epic #766: `standardCurve2D()` is the r = 5 circle about the 2D origin, so every sample is
    // exactly 5 away from it. `pt.x.isFinite` was true of any answer at all.
    @Test func curve2DThousandPoints() {
        let curve = standardCurve2D()
        let domain = curve.domain
        var maxRadiusError = 0.0
        for i in 0..<1000 {
            let t = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(i) / 999.0
            let pt = curve.point(at: t)
            maxRadiusError = max(maxRadiusError, abs((pt.x * pt.x + pt.y * pt.y).squareRoot() - 5))
        }
        #expect(maxRadiusError < 1e-9)
    }
}
