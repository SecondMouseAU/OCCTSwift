import Foundation
import Testing

@testable import OCCTSwift

@Suite("XDE Area Volume Centroid")
struct XDEAreaVolumeCentroidTests {
    @Test("Set and get area")
    func area() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setArea(2200.0)
                if let area = node.area {
                    #expect(abs(area - 2200.0) < 1e-5)
                }
            }
        }
    }

    @Test("Set and get volume")
    func volume() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setVolume(6000.0)
                if let vol = node.volume {
                    #expect(abs(vol - 6000.0) < 1e-5)
                }
            }
        }
    }

    @Test("Set and get centroid")
    func centroid() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.setCentroid(x: 5, y: 10, z: 15)
                if let c = node.centroid {
                    #expect(abs(c.x - 5.0) < 1e-5)
                    #expect(abs(c.y - 10.0) < 1e-5)
                    #expect(abs(c.z - 15.0) < 1e-5)
                }
            }
        }
    }
}
