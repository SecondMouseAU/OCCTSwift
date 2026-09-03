import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.73.0: TKHlr Tests

@Suite("HLR Extended Edge Categories Tests")
struct HLRExtendedEdgeCategoryTests {
    @Test("exact HLR visible sharp edges on box")
    func exactVisibleSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrEdges(direction: SIMD3(1, 1, 1), category: .visibleSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("exact HLR hidden sharp edges on box")
    func exactHiddenSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrEdges(direction: SIMD3(1, 1, 1), category: .hiddenSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("exact HLR cylinder outlines")
    func cylinderOutlines() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let outlines = c.hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleOutline)
            if let o = outlines {
                #expect(o.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("poly HLR visible sharp edges on box")
    func polyVisibleSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrPolyEdges(direction: SIMD3(1, 1, 1), category: .visibleSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("poly HLR hidden sharp edges on box")
    func polyHiddenSharp() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrPolyEdges(direction: SIMD3(1, 1, 1), category: .hiddenSharp)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("compound of edges generic API")
    func compoundOfEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.hlrCompoundOfEdges(
                direction: SIMD3(1, 1, 1),
                edgeType: .sharp, visible: true, in3d: true)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    // MARK: - #1500: visibleIso/hiddenIso/isoLine used to always return nil

    // `algo->Add(shape, nbIso)`'s `nbIso` used to be omitted entirely (defaulting to 0 in OCCT),
    // which gates isoline computation off for every shape, so `.visibleIso`/`.hiddenIso` (via
    // `hlrEdges`) and `.isoLine` (via `hlrCompoundOfEdges`) always returned `nil`, contradicting
    // the bridge's own "exact HLR only" docs, which implied they worked for exact HLR. Fixture is
    // the issue's own repro: a cylinder viewed from the side, where isoparametric lines run the
    // length of the visible/hidden halves of the curved surface.

    @Test("exact HLR visible iso lines on cylinder viewed from side (#1500)")
    func cylinderVisibleIso() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let edges = c.hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleIso)
            #expect(edges != nil)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("exact HLR hidden iso lines on cylinder viewed from side (#1500)")
    func cylinderHiddenIso() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let edges = c.hlrEdges(direction: SIMD3(1, 0, 0), category: .hiddenIso)
            #expect(edges != nil)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("compound of edges isoLine type on cylinder viewed from side (#1500)")
    func cylinderCompoundOfEdgesIsoLine() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let edges = c.hlrCompoundOfEdges(
                direction: SIMD3(1, 0, 0),
                edgeType: .isoLine, visible: true, in3d: true)
            #expect(edges != nil)
            if let e = edges {
                #expect(e.subShapes(ofType: .edge).count > 0)
            }
        }
    }

    @Test("nbIso: 0 still disables isoline computation, matching OCCT's own default (#1500)")
    func nbIsoZeroStillReturnsNil() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let edges = c.hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleIso, nbIso: 0)
            #expect(edges == nil)
        }
    }
}
