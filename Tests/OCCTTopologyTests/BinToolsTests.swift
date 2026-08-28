import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BinTools Shape I/O Tests")
struct BinToolsTests {
    @Test func writeAndReadBinaryData() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            if let data = box.toBinaryData() {
                #expect(data.count > 10)
                if let readShape = Shape.fromBinaryData(data) {
                    #expect(readShape.isValid)
                }
            }
        }
    }

    @Test func writeAndReadBinaryFile() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                "test_v85_bin.brep")
            let ok = box.writeBinary(to: url)
            #expect(ok)
            if let readShape = Shape.loadBinary(from: url) {
                #expect(readShape.isValid)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func sphereRoundtrip() {
        if let sphere = Shape.sphere(radius: 5) {
            if let data = sphere.toBinaryData() {
                if let readShape = Shape.fromBinaryData(data) {
                    #expect(readShape.isValid)
                }
            }
        }
    }
}
