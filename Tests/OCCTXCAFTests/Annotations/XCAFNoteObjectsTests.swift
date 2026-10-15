import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFNoteObjects_NoteObject Tests")
struct XCAFNoteObjectsTests {
    @Test func create() throws {
        let obj = try #require(NoteObject())
        // A new note object holds nothing: no plane, point, text point or presentation.
        #expect(!obj.hasPlane)
        #expect(!obj.hasPoint)
        #expect(!obj.hasPointText)
        #expect(obj.planeOrigin == (0, 0, 0))
        #expect(obj.point == (0, 0, 0))
        #expect(obj.presentation == nil)
    }

    @Test func initiallyEmpty() throws {
        let obj = try #require(NoteObject())
        #expect(!obj.hasPlane)
        #expect(!obj.hasPoint)
        #expect(!obj.hasPointText)
    }

    @Test func setPlane() {
        if let obj = NoteObject() {
            obj.setPlane(
                originX: 1, originY: 2, originZ: 3,
                normalX: 0, normalY: 0, normalZ: 1)
            #expect(obj.hasPlane)
            let origin = obj.planeOrigin
            #expect(abs(origin.x - 1.0) < 1e-6)
        }
    }

    @Test func setPoint() {
        if let obj = NoteObject() {
            obj.setPoint(x: 10, y: 20, z: 30)
            #expect(obj.hasPoint)
            let pt = obj.point
            #expect(abs(pt.x - 10) < 1e-6)
        }
    }

    @Test func setPresentation() throws {
        let obj = try #require(NoteObject())
        #expect(obj.presentation == nil)
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1))
        obj.setPresentation(box)

        // What comes back is the box that went in: a unit solid centred on the origin.
        let presentation = try #require(obj.presentation)
        #expect(presentation.shapeType == .solid)
        #expect(abs((presentation.volume ?? 0) - 1) < 1e-9)
        let bounds = try #require(presentation.bounds)
        #expect(vectorDistance(bounds.min, SIMD3(-0.5, -0.5, -0.5)) < 1e-5)
        #expect(vectorDistance(bounds.max, SIMD3(0.5, 0.5, 0.5)) < 1e-5)
    }

    @Test func reset() {
        if let obj = NoteObject() {
            obj.setPlane(
                originX: 1, originY: 2, originZ: 3,
                normalX: 0, normalY: 0, normalZ: 1)
            obj.setPoint(x: 10, y: 20, z: 30)
            obj.reset()
            #expect(!obj.hasPlane)
            #expect(!obj.hasPoint)
        }
    }
}
