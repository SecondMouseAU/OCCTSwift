import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Intersection Tests")
struct SurfaceIntersectionTests {

    @Test("Intersect two perpendicular planar faces gives line")
    func intersectPerpendicularPlanes() {
        // Create two boxes that share an edge
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!

        let faces1 = box1.faces()
        let faces2 = box2.faces()
        #expect(faces1.count >= 2)
        #expect(faces2.count >= 2)

        // Find two faces with perpendicular normals
        var face1: Face?
        var face2: Face?
        for f1 in faces1 {
            guard let n1 = f1.normal else { continue }
            for f2 in faces2 {
                guard let n2 = f2.normal else { continue }
                let dot = abs(n1.x * n2.x + n1.y * n2.y + n1.z * n2.z)
                if dot < 0.01 {  // perpendicular
                    face1 = f1
                    face2 = f2
                    break
                }
            }
            if face1 != nil { break }
        }
        #expect(face1 != nil)
        #expect(face2 != nil)

        if let f1 = face1, let f2 = face2 {
            let result = f1.intersection(with: f2)
            // Perpendicular planes of the same box should intersect along an edge
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }

    @Test("Intersect cylinder with plane gives curve")
    func intersectCylinderWithPlane() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        let cylFaces = cyl.faces()
        let boxFaces = box.faces()

        // Find the cylindrical face
        var cylFace: Face?
        for face in cylFaces {
            if face.surfaceType == .cylinder {
                cylFace = face
                break
            }
        }

        // Find a planar face that would intersect the cylinder
        var planeFace: Face?
        for face in boxFaces {
            if face.surfaceType == .plane {
                planeFace = face
                break
            }
        }

        #expect(cylFace != nil)
        #expect(planeFace != nil)

        if let cf = cylFace, let pf = planeFace {
            let result = cf.intersection(with: pf)
            // The plane should cut through the cylinder
            if let r = result {
                #expect(r.isValid)
            }
        }
    }
}
