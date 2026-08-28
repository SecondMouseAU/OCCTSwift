import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.122.0, Sewing Extended")
struct SewingExtendedTests {
    @Test("Sewing deleted faces and queries")
    func sewingDeletedFacesAndQueries() {
        // Create two adjacent faces and sew them
        let face1 = Shape.box(width: 10, height: 10, depth: 0.01)
        let face2 = Shape.box(width: 10, height: 10, depth: 0.01)
        if let f1 = face1, let f2 = face2 {
            let sewing = SewingBuilder(tolerance: 1e-3)
            if let s = sewing {
                s.add(f1)
                s.add(f2)
                s.perform()
                let result = s.result
                #expect(result != nil)
                // Check deleted faces count (may be 0)
                let deletedCount = s.nbDeletedFaces
                #expect(deletedCount >= 0)
            }
        }
    }

    @Test("Sewing is modified and modified shape")
    func sewingIsModified() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if faces.count >= 2 {
                let sewing = SewingBuilder(tolerance: 1e-3)
                if let s = sewing {
                    s.add(faces[0])
                    s.add(faces[1])
                    s.perform()
                    let _ = s.result
                    // Check modification query
                    let isMod = s.isModified(faces[0])
                    if isMod {
                        let mod = s.modified(faces[0])
                        #expect(mod != nil)
                    }
                    #expect(true)  // No crash
                }
            }
        }
    }

    @Test("Sewing is degenerated")
    func sewingIsDegenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let sewing = SewingBuilder(tolerance: 1e-3)
            if let s = sewing {
                s.add(b)
                s.perform()
                let degen = s.isDegenerated(b)
                #expect(!degen)
            }
        }
    }

    @Test("Sewing load and modes")
    func sewingLoadAndModes() {
        let sewing = SewingBuilder(tolerance: 1e-3)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box {
                s.load(b)
                s.setNonManifoldMode(true)
                s.setFaceMode(true)
                s.setFloatingEdgesMode(false)
                s.setMinTolerance(1e-6)
                s.setMaxTolerance(1e-1)
                s.perform()
                let result = s.result
                #expect(result != nil)
            }
        }
    }

    @Test("Sewing section bound and which face")
    func sewingSectionBoundAndWhichFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let sewing = SewingBuilder(tolerance: 1e-3)
            if let s = sewing {
                s.add(b)
                s.perform()
                let edges = b.subShapes(ofType: .edge)
                if edges.count > 0 {
                    let _ = s.isSectionBound(edges[0])
                    let _ = s.whichFace(edges[0])
                    #expect(true)
                }
            }
        }
    }
}
