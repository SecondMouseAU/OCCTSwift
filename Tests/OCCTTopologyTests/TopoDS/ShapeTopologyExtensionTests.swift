import Foundation
import OCCTBridge
import Testing

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

    @Test func shapeConvex() throws {
        // The Convex flag is a stored hint, false on anything the kernel builds.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(!box.isConvex)

        // It has no setter, so the positive reading comes through the BREP text: the last
        // digit of a shape's flag line is Convex.
        // The record text is the one OCCT 8.0.1's BREP writer produces (verified on kernel.6); a
        // format change leaves `edited == brep`, which the next expectation reports.
        let face = try #require(Shape.faceFromPlane(uBounds: 0...10, vBounds: 0...10))
        #expect(!face.isConvex)
        let brep = try #require(face.toBREPString())
        let edited = brep.replacingOccurrences(
            of: "Fa\n0  1e-07 1 0\n\n1101000", with: "Fa\n0  1e-07 1 0\n\n1101001")
        #expect(edited != brep)
        let flagged = try #require(Shape.fromBREPString(edited))
        #expect(flagged.isConvex)
    }

    @Test func shapePartnerAndEqual() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A shape is a partner with itself
            #expect(box.isPartner(with: box))
            #expect(box.isEqual(to: box))
        }
    }

    @Test func shapeNbChildren() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // solid -> its shell; shell -> six faces; face -> its wire; wire -> four edges;
        // edge -> two vertices; vertex -> none.
        #expect(box.nbChildren == 1)
        let shell = try #require(box.subShapes(ofType: .shell).first)
        #expect(shell.nbChildren == 6)
        let face = try #require(box.subShapes(ofType: .face).first)
        #expect(face.nbChildren == 1)
        let wire = try #require(box.subShapes(ofType: .wire).first)
        #expect(wire.nbChildren == 4)
        let edge = try #require(box.subShapes(ofType: .edge).first)
        #expect(edge.nbChildren == 2)
        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        #expect(vertex.nbChildren == 0)
        // A compound of two solids has two.
        let sphere = try #require(Shape.sphere(radius: 5))
        let compound = try #require(Shape.compound([box, sphere]))
        #expect(compound.nbChildren == 2)
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
