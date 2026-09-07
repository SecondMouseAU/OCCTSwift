import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `Shape.splitDrafts` had no test anywhere in the tree (#1393). It has two now, one per kernel,
/// because the operation's answer differs between them and neither answer should go unmeasured.
///
/// `LocOpe_SplitDrafts::Perform` only accepts a planar face (its `NewPlane()` helper intersects
/// the neutral plane with the face's own plane), and for a planar face it then pipes along the
/// intersection line of two planes. Both the pipe's path and its section are therefore infinite
/// `Geom_Line`s, and `GeomFill_Pipe` converts each through `GeomConvert::CurveToBSplineCurve`,
/// which raises `Standard_DomainError("No such curve")` on an infinite curve by documented design.
/// So every valid call reached the same throw. Measured, not inferred:
/// `Scripts/repro/1393-splitdrafts/`.
///
/// `Scripts/patches/0034` trims both lines to the shape's own extent in `LocOpe_SplitDrafts`
/// before handing them to the pipe, which is where the defect was: `CurveToBSplineCurve` already
/// converts a *trimmed* line, and always has. The patch is not in `Package.swift`'s pinned kernel
/// asset, so `ci.yml`'s `build-and-test` still sees the refusal while `kernel-integration.yml`,
/// which builds `Scripts/patches/` from source and sets `OCCTSWIFT_LOCAL=1`, sees the split. The
/// two tests below are gated on exactly that, so a repin that changes the answer makes one of them
/// fail loudly rather than leaving either kernel untested.
@Suite("Issue #1393, LocOpe_SplitDrafts coverage")
struct Issue1393SplitDraftsTests {

    /// The one request both tests make: a 10 mm box, its top face, a wire along x = 0 on that
    /// face, and the neutral plane x = 0, which is the plane whose intersection with the face is
    /// the line the wire lies along. A neutral plane coincident with the face's own plane makes
    /// the kernel's `NewPlane()` helper bail before doing anything.
    private static let draftAngle = 10.0 * .pi / 180.0

    private func draftedBox() throws -> (box: Shape, result: Shape?) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // The top face of the box, found by its own geometry rather than by a pinned index.
        let faces = box.faces()
        let topIndex = try #require(
            faces.firstIndex(where: {
                guard $0.isPlanar, let b = $0.bounds else { return false }
                // Shape.box is centred on the origin, so the top face sits at z = +5.
                return abs(b.min.z - 5.0) < 1e-6 && abs(b.max.z - 5.0) < 1e-6
            }))
        let wire = try #require(Wire.line(from: SIMD3(0, -5, 5), to: SIMD3(0, 5, 5)))
        let result = box.splitDrafts(
            faceIndex: topIndex, wire: wire,
            direction: SIMD3(1, 0, 0),
            planeOrigin: SIMD3(0, 0, 0),
            planeNormal: SIMD3(1, 0, 0),
            angle: Self.draftAngle)
        return (box, result)
    }

    // The pinned kernel has no 0034, so the throw is still there and the bridge's catch turns it
    // into nil. Asserting that keeps ci.yml's build-and-test measuring something real rather than
    // skipping, and it fails the moment a repin carries the patch, which is the signal to delete
    // this test and leave only the behavioural one below.
    @Test(
        "splitDrafts refuses on the pinned kernel, which has no 0034",
        .enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] != "1"))
    func planarRequestIsRefusedOnPinnedKernel() throws {
        let (_, result) = try draftedBox()
        #expect(result == nil, "LocOpe_SplitDrafts cannot complete on the pinned kernel")
    }

    // The behavioural half, run by kernel-integration.yml against a kernel built from
    // Scripts/patches/. It asserts the split HAPPENED, not that it stopped throwing: the box gains
    // exactly one face, exactly one face is tilted off the axes, and the volume grows by the
    // wedge the draft adds. Measured against the patched kernel via the override-link technique
    // (Scripts/repro/1393-splitdrafts/README.md): 6 faces -> 7, volume 1000 -> 1022.04.
    @Test(
        "splitDrafts drafts the face on a kernel carrying 0034",
        .enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func planarRequestDraftsTheFace() throws {
        let (box, maybeResult) = try draftedBox()
        let result = try #require(maybeResult, "LocOpe_SplitDrafts should complete with 0034")

        let before = box.faces().count
        let after = result.faces().count
        #expect(before == 6)
        #expect(after == before + 1, "the top face should be split in two")

        // Exactly one face is drafted: its normal is off every axis, by the draft angle.
        let tilted = result.faces().compactMap { face -> SIMD3<Double>? in
            guard let n = face.normal else { return nil }
            let onAxis =
                abs(abs(n.x) - 1) < 1e-6 || abs(abs(n.y) - 1) < 1e-6 || abs(abs(n.z) - 1) < 1e-6
            return onAxis ? nil : n
        }
        #expect(tilted.count == 1, "one drafted face, got \(tilted.count)")
        if let n = tilted.first {
            // The drafted plane is the top face rotated about x = 0 by the draft angle, so its
            // normal makes exactly that angle with +z.
            let fromVertical = acos(min(1.0, abs(n.z)))
            #expect(abs(fromVertical - Self.draftAngle) < 1e-6, "drafted by \(fromVertical) rad")
        }

        // The draft tips half the top face (5 mm of run, 10 mm wide) up by the angle, so the
        // solid gains that wedge: 0.5 * 5 * 5*tan(10 deg) * 10.
        let wedge = 0.5 * 5.0 * (5.0 * tan(Self.draftAngle)) * 10.0
        let v0 = try #require(box.volume)
        let v1 = try #require(result.volume)
        #expect(abs(v0 - 1000.0) < 1e-6)
        #expect(abs(v1 - (1000.0 + wedge)) < 1e-4, "volume \(v1), expected \(1000.0 + wedge)")
    }
}
