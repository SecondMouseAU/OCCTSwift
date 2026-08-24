import Foundation
import Testing

@testable import OCCTSwift

/// #994: `OCCTBridge_Topology.mm`'s `trsfFromMatrix12` / `matrix12FromTrsf` and
/// `OCCTBridge_BRepGraph.mm`'s `locationFromMatrix` each converted the same twelve doubles into
/// the same `gp_Trsf`, in two files. All three are now
/// `occtTrsfFromMatrix12Interleaved` / `occtMatrix12InterleavedFromTrsf` /
/// `occtLocationFromMatrix12Interleaved` in `OCCTBridge_Internal.h`.
///
/// `located(matrix:)`, `locationMatrix` and `setLocation(matrix:)` had no test of their own: the
/// bridge could have read the twelve doubles in any order, or lost the translation entirely, and
/// nothing would have gone red. The BRepGraph half is not reachable from here at all, because the
/// location it writes into the graph has no read-side API and `BRepGraph.shape(nodeKind:)` does
/// not apply it; `Scripts/repro/994-matrix12-interleaved/` measures that half directly in C++.
@Suite("Shape location: one INTERLEAVED matrix conversion (#994)")
struct Issue994Matrix12 {

    /// Translate by (5, 6, 7), INTERLEAVED: three rows of `r r r t`.
    ///
    /// The same transform written GROUPED would be `[1,0,0, 0,1,0, 0,0,1, 5,6,7]`, and reading
    /// that array with this layout yields translation (0, 0, 7) rather than a refusal, which is
    /// why the shared helpers carry the layout in their names.
    private static let translate567: [Double] = [
        1, 0, 0, 5,
        0, 1, 0, 6,
        0, 0, 1, 7,
    ]

    /// A 30-degree rotation about Z with the same translation, so no two of the twelve slots hold
    /// the same number and a permuted read cannot pass by coincidence.
    private static let rotatedAndTranslated: [Double] = {
        let c = cos(Double.pi / 6)
        let s = sin(Double.pi / 6)
        return [
            c, -s, 0, 5,
            s, c, 0, 6,
            0, 0, 1, 7,
        ]
    }()

    private func box() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)
    }

    @Test("located(matrix:) moves the shape by the translation the INTERLEAVED layout names")
    func locatedAppliesTheTranslation() {
        guard let box = box(), let before = box.boundingBox else {
            Issue.record("box fixture should build and report a bounding box")
            return
        }
        guard let moved = box.located(matrix: Self.translate567), let after = moved.boundingBox
        else {
            Issue.record("located should succeed and report a bounding box")
            return
        }
        // The operation did something, and did exactly (5, 6, 7): reading the array GROUPED would
        // give (0, 0, 7), and dropping the translation would give (0, 0, 0).
        #expect(abs((after.min.x - before.min.x) - 5) < 1e-6)
        #expect(abs((after.min.y - before.min.y) - 6) < 1e-6)
        #expect(abs((after.min.z - before.min.z) - 7) < 1e-6)
        #expect(abs((after.max.x - before.max.x) - 5) < 1e-6)
        #expect(abs((after.max.y - before.max.y) - 6) < 1e-6)
        #expect(abs((after.max.z - before.max.z) - 7) < 1e-6)
    }

    @Test("locationMatrix reads back exactly what located(matrix:) was given")
    func locationMatrixRoundTripsTranslation() {
        guard let moved = box()?.located(matrix: Self.translate567) else {
            Issue.record("located should succeed")
            return
        }
        let back = moved.locationMatrix
        #expect(back.count == 12)
        guard back.count == 12 else { return }
        for i in 0..<12 {
            #expect(abs(back[i] - Self.translate567[i]) < 1e-12)
        }
    }

    @Test("locationMatrix round-trips a rotation whose twelve slots are all distinct")
    func locationMatrixRoundTripsRotation() {
        guard let moved = box()?.located(matrix: Self.rotatedAndTranslated) else {
            Issue.record("located should succeed on a rotation")
            return
        }
        let back = moved.locationMatrix
        guard back.count == 12 else {
            Issue.record("locationMatrix should be twelve doubles")
            return
        }
        for i in 0..<12 {
            #expect(abs(back[i] - Self.rotatedAndTranslated[i]) < 1e-12)
        }
    }

    @Test("setLocation(matrix:) in place agrees with located(matrix:)")
    func setLocationAgreesWithLocated() {
        guard let a = box(), let b = box() else {
            Issue.record("two box fixtures should build")
            return
        }
        guard let viaLocated = a.located(matrix: Self.rotatedAndTranslated) else {
            Issue.record("located should succeed")
            return
        }
        b.setLocation(matrix: Self.rotatedAndTranslated)
        let fromLocated = viaLocated.locationMatrix
        let fromSet = b.locationMatrix
        guard fromLocated.count == 12, fromSet.count == 12 else {
            Issue.record("both should report twelve doubles")
            return
        }
        for i in 0..<12 {
            #expect(abs(fromLocated[i] - fromSet[i]) < 1e-12)
        }
        if let x = viaLocated.boundingBox, let y = b.boundingBox {
            #expect(abs(x.min.x - y.min.x) < 1e-9)
            #expect(abs(x.max.z - y.max.z) < 1e-9)
        } else {
            Issue.record("both located shapes should report a bounding box")
        }
    }

    @Test("An unplaced shape reports the identity matrix, not zeros")
    func identityForAnUnplacedShape() {
        guard let box = box() else {
            Issue.record("box fixture should build")
            return
        }
        let m = box.locationMatrix
        guard m.count == 12 else {
            Issue.record("locationMatrix should be twelve doubles")
            return
        }
        let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]
        for i in 0..<12 {
            #expect(abs(m[i] - identity[i]) < 1e-12)
        }
    }
}
