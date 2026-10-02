import Foundation
import Testing

@testable import OCCTSwift

/// #3003: an arc-join offset returned its faces in an order set by allocation addresses.
///
/// `BRepOffset_MakeOffset::BuildOffsetByArc` registered the offset faces as roots by walking a
/// `DataMap` hashed on `TShape` pointers, so two identical calls gave the same solid with its faces
/// in a different order, and `BRepGProp` summed the volume in that order, so the last digits moved
/// (4e-16 to 9e-16 on three lines of two #766 probes). Carried kernel patch `0047` walks the
/// entries in the order they were bound.
///
/// `Scripts/repro/3003-offset-roots-hash-order/` holds the measurement. Against the pinned
/// `v4.0.0-kernel.3` asset, 32 builds in one process with a different amount of heap held before
/// each gave 32 face orders; with `0047` they give one.
@Suite("Issue 3003: arc-join offsets do not depend on allocation addresses")
struct Issue3003OffsetOrderTests {

    /// Where each face of `shape` is, in the order the shape holds them.
    ///
    /// The 26 faces of a rounded cube offset have 26 different boxes, so two builds that agree on
    /// this list agree on the order, and a permutation shows up at the first index it differs.
    private func faceBoxes(_ shape: Shape) throws -> [String] {
        try shape.faces().map { face in
            let box = try #require(
                Shape.fromFace(face)?.boundingBox, "face \(face.index) has no bounding box")
            func r(_ v: Double) -> String { String(format: "%.6f", (v * 1e6).rounded() / 1e6 + 0.0) }
            return "\(r(box.min.x)),\(r(box.min.y)),\(r(box.min.z))..\(r(box.max.x)),\(r(box.max.y)),\(r(box.max.z))"
        }
    }

    /// Gated on `OCCTSWIFT_LOCAL=1`, the way `StressBuilderLifecycleTests`' `0027` test is: the fix
    /// is carried patch `0047`, which the pinned asset does not carry, and `ci.yml`'s
    /// `build-and-test` resolves that asset. `kernel-integration.yml` builds the patches from source
    /// with `OCCTSWIFT_LOCAL=1`, which is where this runs. A skipped test and a passing one both
    /// report green, so the per-test line in the log is the only signal: read `started`, not
    /// `skipped`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func arcJoinFaceOrderAndVolumeDoNotDependOnTheHeap() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))

        // The fixture has to be the thing the defect is about: an arc join, whose result holds six
        // planes, twelve edge rounds and eight corner spheres. An intersection join returns six
        // faces and is reproducible whatever the heap does, so a call that quietly became one
        // would pass this test and mean nothing.
        let first = try #require(box.offset(by: 1.0, joinType: .arc))
        let reference = try faceBoxes(first)
        #expect(reference.count == 26, "an arc-join offset of a box has 26 faces")
        #expect(Set(reference).count == reference.count, "the 26 faces must be told apart")
        let referenceVolume = try #require(first.volume)

        // A NEW box for every build, and a different amount of heap held before it, so each build's
        // input gets other addresses. The map the builder walked was keyed on the INPUT's shapes, so
        // offsetting one box again and again in one process gives the same order every time, which
        // is why the first version of this test passed against the unpatched kernel. Without the
        // heap held, the allocator also reuses addresses in a short cycle and a handful of builds
        // can agree by luck.
        var held: [[UInt8]] = []
        var movedFaces: [Int] = []
        var movedVolumes: [Int] = []
        for run in 1..<32 {
            held.append([UInt8](repeating: 0, count: 16 + 16 * run))
            let fresh = try #require(Shape.box(width: 10, height: 10, depth: 10), "build \(run)")
            let offset = try #require(fresh.offset(by: 1.0, joinType: .arc), "build \(run)")
            if try faceBoxes(offset) != reference { movedFaces.append(run) }
            if try #require(offset.volume).bitPattern != referenceVolume.bitPattern {
                movedVolumes.append(run)
            }
        }
        #expect(
            movedFaces.isEmpty,
            "the faces came back in another order in builds \(movedFaces) of 31")
        #expect(
            movedVolumes.isEmpty,
            "the volume differed from build 0's in its last digits in builds \(movedVolumes) of 31")
    }
}
