import Testing

@testable import OCCTSwift

@Suite("v0.137 Shape.revolutionAxes")
struct ShapeRevolutionAxesTests {
    @Test("Cylinder yields exactly one axis")
    func cylinderOneAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cylinder nil")
            return
        }
        let axes = cyl.revolutionAxes()
        #expect(axes.count == 1)
        if let a = axes.first {
            #expect(a.kind == ShapeAxis.Kind.cylinder)
            #expect(abs(a.direction.z - 1.0) < 1e-6 || abs(a.direction.z + 1.0) < 1e-6)
        }
    }

    @Test("Box yields no revolution axes")
    func boxNoAxes() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        #expect(box.revolutionAxes().isEmpty)
    }

    @Test("Torus yields one deduplicated axis")
    func torusDedupedAxis() {
        guard let torus = Shape.torus(majorRadius: 20, minorRadius: 5) else {
            Issue.record("torus nil")
            return
        }
        let axes = torus.revolutionAxes()
        #expect(axes.count >= 1)
        #expect(axes.contains { $0.kind == .torus })
    }

    @Test("Coaxial cylinder + torus collapse to one axis")
    func coaxialDedup() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let torus = Shape.torus(majorRadius: 10, minorRadius: 2),
            let combined = cyl.union(torus)
        else {
            Issue.record("union nil")
            return
        }
        // Proves the union actually kept both bodies rather than silently returning just one
        // operand (#764): the cylinder (r=5) and the torus (major 10, minor 2, tube spans
        // radius 8..12) never overlap, so a real union's volume is exactly their sum. Without
        // this, a union that quietly dropped the torus would leave `combined` with the
        // cylinder's own single axis, and axes.count below would still read 1, passing without
        // ever exercising dedup.
        if let cylVol = cyl.volume, let torusVol = torus.volume,
            let combinedVol = combined.volume
        {
            #expect(abs(combinedVol - (cylVol + torusVol)) < 1e-3)
        }
        let axes = combined.revolutionAxes()
        // Both share the Z axis at the origin → dedup to 1.
        #expect(axes.count == 1)
    }

    // #726/#763: extentMin/extentMax/hasExtent were hardcoded 0/0/false on every call, so
    // `extent` was `nil` for every axis regardless of input. Fixed by measuring the face's own
    // bounding box along the axis direction. A cylindrical face's true Z-extent (in whichever
    // sign OCCT hands back `Axis().Direction()`, not fixed -- see `cylinderOneAxis` above, which
    // itself accepts either sign) is exactly its bounding box's, since no curvature bulges past
    // the two flat end circles along the axis. The SPAN (upperBound - lowerBound) is
    // sign-independent and is what's asserted; `Shape.cylinder`'s own height is the ground truth.
    @Test("Cylinder's revolution axis reports a real, non-nil extent matching its height")
    func cylinderRevolutionAxisHasExtent() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else {
            Issue.record("cylinder nil")
            return
        }
        let axes = cyl.revolutionAxes()
        #expect(axes.count == 1)
        guard let a = axes.first, let extent = a.extent else {
            Issue.record("expected a non-nil extent on the cylinder's revolution axis")
            return
        }
        #expect(abs((extent.upperBound - extent.lowerBound) - 20) < 1e-6)
    }

    // #1576: `OCCTShapeRevolutionAxes` writes only `min(collected.size(), maxAxes)` entries into
    // the caller's buffer but used to `return (int32_t)collected.size()` -- the full, UNCAPPED
    // count -- rather than the capped count it actually wrote. `revolutionAxes()`'s own buffer
    // is a fixed 256-element Swift array, so a shape with more than 256 distinct (post-dedup)
    // axes made the bridge report a count exceeding what was written, and the `map` below
    // indexing `buffer[256..<count]` trapped (Swift arrays are bounds-checked). 300 cylinders,
    // each offset far enough along X that `axesCoincide`'s cross-product-with-the-axis-direction
    // check can never collapse two of them (their separation is perpendicular to the shared Z
    // axis direction, so it's never "the same line"), forces exactly 300 distinct axes: enough to
    // overrun the real 256-element buffer through the real public API, no shipped constant
    // changed to get there.
    @Test("More than 256 distinct revolution axes: reported count never exceeds the buffer capacity")
    func manyDistinctAxesCountNeverExceedsBufferCapacity() {
        let n = 300
        var cylinders: [Shape] = []
        cylinders.reserveCapacity(n)
        for i in 0..<n {
            guard
                let cyl = Shape.cylinder(
                    at: SIMD3(Double(i) * 10, 0, 0),
                    direction: SIMD3(0, 0, 1),
                    radius: 1,
                    height: 1
                )
            else {
                Issue.record("cylinder \(i) nil")
                return
            }
            cylinders.append(cyl)
        }
        guard let combined = Shape.compound(cylinders) else {
            Issue.record("compound nil")
            return
        }
        let axes = combined.revolutionAxes()
        // Pre-fix this would have trapped constructing `axes` at all (fatal error: Index out of
        // range), before ever reaching an #expect; reaching this line at all is part of the proof.
        #expect(axes.count <= 256)
        // All 300 axes are genuinely distinct, so the capped count should be exactly the buffer
        // size, confirming the raw (uncapped) count really did exceed it.
        #expect(axes.count == 256)
        #expect(axes.allSatisfy { $0.kind == .cylinder })
    }
}
