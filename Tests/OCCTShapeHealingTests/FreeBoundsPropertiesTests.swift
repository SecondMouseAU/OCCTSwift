import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis FreeBoundsProperties Tests")
struct FreeBoundsPropertiesTests {
    @Test("Free bounds analysis on face compound")
    func freeBoundsOnFaces() throws {
        // Two separate faces form a compound with free bounds
        let compound = twoFaces()

        let analysis = compound.freeBoundsAnalysis(tolerance: 0.01)
        // #766: kernel (Scripts/repro/766-healing-freebounds-props): total=2 closed=2 open=0.
        #expect(analysis.totalCount == 2)
        #expect(analysis.closedCount == 2)
        #expect(analysis.openCount == 0)
    }

    // #766: this and the next test nested every assertion inside `if closedCount > 0` and
    // `if let`, so a bridge that found no bounds, or returned nil for index 0, passed both.
    @Test("Closed free bound info, area and perimeter")
    func closedBoundInfo() throws {
        let compound = twoFaces()
        let info = try #require(compound.closedFreeBoundInfo(tolerance: 0.01, index: 0))
        // Kernel: area=100 perimeter=40 ratio=0 width=0 notches=0 for each 10x10 bound.
        #expect(abs(info.area - 100.0) < 1e-9)
        #expect(abs(info.perimeter - 40.0) < 1e-9)
        #expect(info.notchCount == 0)
    }

    @Test("Free bound wire extraction")
    func freeBoundWire() throws {
        let compound = twoFaces()
        let wire = try #require(compound.closedFreeBoundWire(tolerance: 0.01, index: 0))
        #expect(wire.isValid)
        #expect(wire.edges().count == 4)
    }

    // Two stacked 10x10 faces: two disjoint closed free bounds, no open ones.
    private func twoFaces() -> Shape {
        let lower = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
            ])!)!
        let upper = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 5), SIMD3(10, 0, 5), SIMD3(10, 10, 5), SIMD3(0, 10, 5),
            ])!)!
        return Shape.compound([lower, upper])!
    }

    // #504: the four indexed accessors used to report "no such bound" by returning a zeroed
    // struct, which Shape.swift read as `perimeter > 0`. A bound whose perimeter really is 0
    // would have been indistinguishable, and the wire accessors had no signal at all beyond a
    // throw from inside OCCT. The index is now range-checked in the bridge.
    @Test("Free bound index out of range is nil, not a zeroed result")
    func freeBoundIndexOutOfRange() throws {
        let compound = twoFaces()
        let analysis = compound.freeBoundsAnalysis(tolerance: 0.01)
        #expect(analysis.closedCount == 2)
        #expect(analysis.totalCount == analysis.closedCount + analysis.openCount)

        #expect(compound.closedFreeBoundInfo(tolerance: 0.01, index: 1) != nil)
        #expect(compound.closedFreeBoundWire(tolerance: 0.01, index: 1) != nil)

        for bad in [analysis.closedCount, analysis.closedCount + 5, -1] {
            #expect(compound.closedFreeBoundInfo(tolerance: 0.01, index: bad) == nil)
            #expect(compound.closedFreeBoundWire(tolerance: 0.01, index: bad) == nil)
        }
    }

    // #504: the open side of this family had no coverage at all. The sewing-based free-edge
    // search closes essentially every contour it finds, so an open bound is not reachable
    // through this entry point. What is worth pinning is that asking for one is a clean nil.
    @Test("Open free bound accessors on a shape with no open bounds")
    func openFreeBoundsAbsent() throws {
        let compound = twoFaces()
        #expect(compound.freeBoundsAnalysis(tolerance: 0.01).openCount == 0)
        #expect(compound.openFreeBoundInfo(tolerance: 0.01, index: 0) == nil)
        #expect(compound.openFreeBoundWire(tolerance: 0.01, index: 0) == nil)
    }

    // #504: the search runs over the shape's direct children, so a bare face offers its wires,
    // not itself, and finds nothing. Every fixture in this suite is a compound for that reason.
    @Test("A lone face has no free bounds")
    func loneFaceHasNoFreeBounds() throws {
        let face = Shape.face(
            from: Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
            ])!)!
        let analysis = face.freeBoundsAnalysis(tolerance: 0.01)
        #expect(analysis.totalCount == 0)
        #expect(analysis.closedCount == 0)
        #expect(analysis.openCount == 0)
    }

    // #504: Shape's five methods and FreeBoundsProperties were two independent wrappings of one
    // OCCT class, with opposite index-base conventions in the C layer. They share one now, so
    // the same bound read either way has to come back identical.
    @Test("Shape and FreeBoundsProperties report the same bound")
    func shapeAndPropertiesAgree() throws {
        let compound = twoFaces()
        let props = try #require(FreeBoundsProperties(shape: compound, tolerance: 0.01))

        #expect(props.closedCount == compound.freeBoundsAnalysis(tolerance: 0.01).closedCount)

        for i in 0..<props.closedCount {
            let viaShape = try #require(compound.closedFreeBoundInfo(tolerance: 0.01, index: i))
            let viaProps = try #require(props.info(.closed, at: i))
            #expect(viaShape.area == viaProps.area)
            #expect(viaShape.perimeter == viaProps.perimeter)
            #expect(viaShape.ratio == viaProps.ratio)
            #expect(viaShape.width == viaProps.width)
            #expect(viaShape.notchCount == viaProps.notchCount)
        }
    }
}
