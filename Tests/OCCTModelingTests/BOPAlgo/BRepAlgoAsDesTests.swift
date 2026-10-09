import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAlgo_AsDes v0.112")
struct BRepAlgoAsDesTests {

    @Test func createAndQuery() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                ad.add(parent: faces[0], child: edges[0])
                #expect(ad.hasDescendant(faces[0]))
                #expect(ad.descendantCount(faces[0]) == 1)
            }
        }
    }

    @Test func noDescendant() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                #expect(!ad.hasDescendant(faces[0]))
                #expect(ad.descendantCount(faces[0]) == 0)
            }
        }
    }

    @Test func multipleChildren() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count >= 3 {
                ad.add(parent: faces[0], child: edges[0])
                ad.add(parent: faces[0], child: edges[1])
                ad.add(parent: faces[0], child: edges[2])
                #expect(ad.descendantCount(faces[0]) == 3)
            }
        }
    }

    @Test func separateParents() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count >= 2 && edges.count >= 2 {
                ad.add(parent: faces[0], child: edges[0])
                ad.add(parent: faces[1], child: edges[1])
                #expect(ad.hasDescendant(faces[0]))
                #expect(ad.hasDescendant(faces[1]))
                #expect(ad.descendantCount(faces[0]) == 1)
                #expect(ad.descendantCount(faces[1]) == 1)
            }
        }
    }

    @Test func emptyTracker() {
        let ad = AsDesTracker()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(!ad.hasDescendant(box))
        }
    }
}
