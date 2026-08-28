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
}
