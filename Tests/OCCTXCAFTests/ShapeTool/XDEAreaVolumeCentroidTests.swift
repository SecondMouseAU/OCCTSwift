import Foundation
import Testing

@testable import OCCTSwift

@Suite("XDE Area Volume Centroid")
struct XDEAreaVolumeCentroidTests {
    @Test("Set and get area")
    func area() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let node = try #require(doc.rootNodes.first)
        node.setArea(2200.0)
        let area = try #require(node.area)
        #expect(abs(area - 2200.0) < 1e-5)
    }

    @Test("Set and get volume")
    func volume() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let node = try #require(doc.rootNodes.first)
        node.setVolume(6000.0)
        let vol = try #require(node.volume)
        #expect(abs(vol - 6000.0) < 1e-5)
    }

    @Test("Set and get centroid")
    func centroid() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        doc.addShape(box)
        let node = try #require(doc.rootNodes.first)
        node.setCentroid(x: 5, y: 10, z: 15)
        let c = try #require(node.centroid)
        #expect(abs(c.x - 5.0) < 1e-5)
        #expect(abs(c.y - 10.0) < 1e-5)
        #expect(abs(c.z - 15.0) < 1e-5)
    }
}
