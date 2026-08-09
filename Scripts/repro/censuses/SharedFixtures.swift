// Fixtures shared across cluster censuses (#694). `SharedFixture` was `Fixture`, private to Cluster
// A's own file, until Cluster B's census (#665) needed the same split-box compounds: #694's own
// reasoning for one `Censuses` target over one-target-per-cluster names this as the concrete win
// ("Cluster B's census wants the same split-box compounds Cluster A's uses. Today it would copy
// them."), not just a side effect of sharing a build target.
//
// Nothing here changes what Cluster A measures: this is the same code Cluster A's own `main.swift`
// carried, moved and renamed, not rewritten.

import Foundation
import OCCTSwift
import simd

enum SharedFixture {
    /// A single 10mm box, origin-centred (-5...5 on every axis). No sub-shape here is reachable
    /// from more than one PARENT SHAPE, but every edge is still reachable from two adjacent faces
    /// and every vertex from three edges within the one solid -- #502's own box measurement (24
    /// edge occurrences over 12 distinct, 48 vertex occurrences over 8 distinct).
    static func plainBox() -> Shape {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            fatalError("Shape.box failed")
        }
        return box
    }

    /// Two solids sharing one cut face, from one BRepAlgoAPI_Splitter run -- the exact
    /// construction Tests/OCCTTopologyTests/Issue614FaceOrientationTests.swift uses (measured
    /// there: 11 distinct faces, 12 face occurrences). `order` controls which half is compounded
    /// first, which is #642's whole claim: AAG answers differently depending on this order alone.
    static func splitBoxCompound(order: CompoundOrder) -> Shape {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
              let plate = Shape.face(from: Wire.rectangle(width: 60, height: 60)!),
              let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
              let knife = upright.translated(by: SIMD3(10, 0, 0)),
              let pieces = block.split(by: knife),
              pieces.count == 2
        else {
            fatalError("could not build the split-box fixture")
        }
        let ordered = order == .asSplit ? pieces : pieces.reversed()
        guard let compound = Shape.compound(Array(ordered)) else {
            fatalError("Shape.compound failed")
        }
        return compound
    }

    enum CompoundOrder: String { case asSplit = "order A (lower, upper)", reversed = "order B (upper, lower)" }

    /// A second two-solid split, cut HORIZONTALLY (z=4 through an origin-centred 10mm box) rather
    /// than down the middle. #642's own measurement ("upward+horizontal node set [2,8] vs [2]")
    /// needs the SHARED wall itself to be horizontal, which `splitBoxCompound` above is not: that
    /// fixture cuts with a VERTICAL plane, so its shared wall's normal is horizontal-axis (X), not
    /// vertical, and isHorizontal()/isUpward() never look at the duplicated face at all. Measuring
    /// only that fixture would silently miss #642's actual claim -- this is exactly the kind of gap
    /// a census is supposed to catch, not repeat.
    static func horizontalSplitBoxCompound(order: CompoundOrder) -> Shape {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
              let pieces = block.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
              pieces.count == 2
        else {
            fatalError("could not build the horizontal split-box fixture")
        }
        let ordered = order == .asSplit ? pieces : pieces.reversed()
        guard let compound = Shape.compound(Array(ordered)) else {
            fatalError("Shape.compound failed")
        }
        return compound
    }
}
