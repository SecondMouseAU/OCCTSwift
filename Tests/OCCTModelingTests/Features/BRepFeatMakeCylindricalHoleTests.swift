import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFeat_MakeCylindricalHole Tests")
struct BRepFeatMakeCylindricalHoleTests {
    @Test("through hole")
    func throughHole() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let result = b.cylindricalHole(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3)
            if let r = result {
                let newFaces = r.subShapes(ofType: .face)
                let origFaces = b.subShapes(ofType: .face)
                #expect(newFaces.count > origFaces.count)
            }
        }
    }

    @Test("blind hole")
    func blindHole() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let result = b.cylindricalHoleBlind(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3, depth: 10)
            if let r = result {
                let newFaces = r.subShapes(ofType: .face)
                let origFaces = b.subShapes(ofType: .face)
                #expect(newFaces.count > origFaces.count)
            }
        }
    }

    @Test("thru next hole")
    func thruNextHole() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let result = b.cylindricalHoleThruNext(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3)
            if let r = result {
                let newFaces = r.subShapes(ofType: .face)
                let origFaces = b.subShapes(ofType: .face)
                #expect(newFaces.count > origFaces.count)
            }
        }
    }

    @Test("hole status check")
    func statusCheck() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            let status = b.cylindricalHoleStatus(
                axisOrigin: SIMD3(10, 10, 0),
                axisDirection: SIMD3(0, 0, 1),
                radius: 3)
            #expect(status == .noError)
        }
    }
}
