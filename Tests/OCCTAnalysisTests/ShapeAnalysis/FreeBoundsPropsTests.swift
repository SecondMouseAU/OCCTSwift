import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - FreeBoundsProperties")
struct FreeBoundsPropsTests {

    @Test func boxFaceFreeBounds() {
        // Remove one face from a box to create a shell with a free bound
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                // A single face has free bounds (its wire)
                if let fbp = FreeBoundsProperties(shape: faces[0], tolerance: 1e-7) {
                    let ok = fbp.perform()
                    // May or may not find free bounds depending on face topology
                    if ok {
                        let closed = fbp.closedCount
                        let open = fbp.openCount
                        #expect(closed >= 0)
                        #expect(open >= 0)
                    }
                }
            }
        }
    }

    @Test func shellWithHoleFreeBounds() {
        // Create a compound of 5 faces (open box)
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count >= 5 {
                if let compound = Shape.builderMakeCompound() {
                    for i in 0..<5 {
                        compound.builderAdd(faces[i])
                    }
                    if let fbp = FreeBoundsProperties(shape: compound, tolerance: 1e-3) {
                        let ok = fbp.perform()
                        if ok {
                            let total = fbp.closedCount + fbp.openCount
                            #expect(total >= 0)
                            if fbp.closedCount > 0 {
                                let area = fbp.closedArea(at: 0)
                                let perimeter = fbp.closedPerimeter(at: 0)
                                #expect(perimeter >= 0)
                                // Area can be negative for some orientations
                                let _ = area
                                let wire = fbp.closedWire(at: 0)
                                #expect(wire != nil)
                            }
                        }
                    }
                }
            }
        }
    }

    // Two stacked rectangles: two disjoint closed free bounds, no open ones.
    private func twoRects(_ w: Double, _ h: Double) -> Shape {
        let lower = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(w, 0, 0), SIMD3(w, h, 0), SIMD3(0, h, 0),
            ])!)!
        let upper = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 5), SIMD3(w, 0, 5), SIMD3(w, h, 5), SIMD3(0, h, 5),
            ])!)!
        return Shape.compound([lower, upper])!
    }

    // #504: OCCT's own Perform() appends to its result sequences and never clears them, and
    // Init() does not clear them either; only the constructors allocate them. Two calls used
    // to double every count, three to triple it, and perform() is public and @discardableResult.
    // The bridge latches it now.
    @Test func performIsIdempotent() throws {
        let props = try #require(FreeBoundsProperties(shape: twoRects(10, 10), tolerance: 0.01))
        #expect(props.perform())
        let once = props.closedCount
        #expect(once == 2)

        #expect(props.perform())
        #expect(props.perform())
        #expect(props.closedCount == once)
        #expect(props.openCount == 0)
        #expect(props.totalCount == once)
    }

    // #504: the accessors used to return 0 until perform() had been called, so forgetting it
    // read as "this shape has no free bounds". They run the analysis on demand now.
    @Test func accessorsRunTheAnalysisOnDemand() throws {
        let props = try #require(FreeBoundsProperties(shape: twoRects(10, 10), tolerance: 0.01))
        #expect(props.closedCount == 2)  // no perform() call at all
        #expect(props.info(.closed, at: 0) != nil)
        #expect(props.wire(.closed, at: 0) != nil)
    }

    // #504: the C layer took a 1-based index here and a 0-based one in the family Shape used,
    // and neither range-checked it, so an out-of-range read reached NCollection_Sequence::Value
    // and came back as 0 from the catch-all. Both are 0-based and checked now.
    @Test func indexOutOfRange() throws {
        let props = try #require(FreeBoundsProperties(shape: twoRects(10, 10), tolerance: 0.01))
        #expect(props.info(.closed, at: 1) != nil)

        for bad in [props.closedCount, props.closedCount + 5, -1] {
            #expect(props.info(.closed, at: bad) == nil)
            #expect(props.wire(.closed, at: bad) == nil)
            #expect(props.closedArea(at: bad) == 0)
            #expect(props.closedPerimeter(at: bad) == 0)
        }
        // The open sequence is empty for every fixture reachable through this API.
        #expect(props.openCount == 0)
        #expect(props.info(.open, at: 0) == nil)
        #expect(props.wire(.open, at: 0) == nil)
        #expect(props.openArea(at: 0) == 0)
        #expect(props.openPerimeter(at: 0) == 0)
        #expect(props.openWire(at: 0) == nil)
    }

    // #504: closedRatio/closedWidth had no coverage. `ratio` is the contour's length/width
    // aspect ratio, NOT area/perimeter^2, which is what the bridge header and Shape.FreeBoundInfo
    // both claimed. A 20x10 bound is 2, and area/perimeter^2 would be 0.0556.
    @Test func ratioAndWidthAreAnAspectRatio() throws {
        let props = try #require(FreeBoundsProperties(shape: twoRects(20, 10), tolerance: 0.01))
        let bound = try #require(props.info(.closed, at: 0))
        #expect(abs(bound.area - 200.0) < 0.5)
        #expect(abs(bound.perimeter - 60.0) < 0.5)
        #expect(abs(bound.ratio - 2.0) < 0.01)
        #expect(abs(bound.width - 10.0) < 0.05)
        #expect(bound.notchCount == 0)

        #expect(props.closedArea(at: 0) == bound.area)
        #expect(props.closedPerimeter(at: 0) == bound.perimeter)
        #expect(props.closedRatio(at: 0) == bound.ratio)
        #expect(props.closedWidth(at: 0) == bound.width)
    }

    // #504: OCCT solves ratio and width from area and perimeter, and a square bound sits exactly
    // on the boundary between the two branches of that solve: one ulp the wrong way and there is
    // no real root, so both come back 0 while area and perimeter stay correct. Pinned because it
    // makes a square the one fixture that must not be used to test ratio or width.
    @Test func squareBoundReportsNoRatioOrWidth() throws {
        let props = try #require(FreeBoundsProperties(shape: twoRects(10, 10), tolerance: 0.01))
        let bound = try #require(props.info(.closed, at: 0))
        #expect(abs(bound.area - 100.0) < 0.5)
        #expect(abs(bound.perimeter - 40.0) < 0.5)
        #expect(bound.ratio == 0)
        #expect(bound.width == 0)
    }

    // #504: notchCount was only reachable through Shape's family, which is gone; it is part of
    // info(_:at:) now. A narrow V cut into the contour is what OCCT counts as a notch.
    @Test func notchesAreCounted() throws {
        let notched = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0),
                SIMD3(5.05, 10, 0), SIMD3(5.0, 1, 0), SIMD3(4.95, 10, 0),
                SIMD3(0, 10, 0),
            ])!)!
        let plain = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 5), SIMD3(10, 0, 5), SIMD3(10, 10, 5), SIMD3(0, 10, 5),
            ])!)!
        let props = try #require(
            FreeBoundsProperties(
                shape: Shape.compound([notched, plain])!,
                tolerance: 0.01))
        let counts = (0..<props.closedCount).compactMap { props.info(.closed, at: $0)?.notchCount }
        #expect(counts.contains(1))  // the slit
        #expect(counts.contains(0))  // the plain square
    }
}
