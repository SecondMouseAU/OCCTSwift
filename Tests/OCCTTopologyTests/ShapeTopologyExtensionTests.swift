import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape Topology Extension Tests")
struct ShapeTopologyExtensionTests {

    @Test func shapeOrientation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let orient = box.orientation
            #expect(orient == .forward)
        }
    }

    @Test func shapeReversed() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let rev = box.reversed {
                #expect(rev.orientation == .reversed)
            }
        }
    }

    @Test func shapeComplemented() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let comp = box.complemented {
                #expect(comp.orientation == .reversed)
            }
        }
    }

    @Test func shapeComposed() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let comp = box.composed(with: .reversed) {
                #expect(comp.orientation == .reversed)
            }
        }
    }

    @Test func shapeFlags() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.isFree
            let _ = box.isModified
            let _ = box.isChecked
            let _ = box.isOrientable
            #expect(!box.isInfinite)
            #expect(!box.isNull)
        }
    }

    @Test func shapeConvex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.isConvex
        }
    }

    @Test func shapePartnerAndEqual() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A shape is a partner with itself
            #expect(box.isPartner(with: box))
            #expect(box.isEqual(to: box))
        }
    }

    @Test func shapeNbChildren() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let n = box.nbChildren
            #expect(n > 0)
        }
    }

    @Test func shapeHashCode() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let h = box.hashCode
            #expect(h != 0)
        }
    }

    @Test func shapeSetOrientation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.setOrientation(.reversed)
            #expect(box.orientation == .reversed)
            box.setOrientation(.forward)
            #expect(box.orientation == .forward)
        }
    }
}
