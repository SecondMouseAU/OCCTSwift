import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFNoteObjects_NoteObject Tests")
struct XCAFNoteObjectsTests {
    @Test func create() {
        let obj = NoteObject()
        #expect(obj != nil)
    }

    @Test func initiallyEmpty() {
        if let obj = NoteObject() {
            #expect(!obj.hasPlane)
            #expect(!obj.hasPoint)
            #expect(!obj.hasPointText)
        }
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

    @Test func setPresentation() {
        if let obj = NoteObject() {
            if let box = Shape.box(width: 1, height: 1, depth: 1) {
                obj.setPresentation(box)
                #expect(obj.presentation != nil)
            }
        }
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
