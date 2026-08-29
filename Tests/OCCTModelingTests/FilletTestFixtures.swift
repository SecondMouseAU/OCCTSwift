// FilletTestFixtures.swift
// Shared fixtures for fillet-related tests (Issue #612, #633, #639).
// No @Suite or @Test: only shared helpers.

import Foundation
import OCCTSwift

/// Shared fixtures for fillet tests using an open shell with known declined edges.
///
/// The shell is a 10mm box with one face dropped and the rest sewn back together.
/// Its free-boundary edges (4 of 12) are declined by `BRepFilletAPI_MakeFillet::Add`.
enum FilletTestFixtures {
    /// A 10mm box with one face dropped and the rest sewn back together: an open shell
    /// whose free boundary edges `BRepFilletAPI_MakeFillet::Add` declines.
    static func openShell() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let faces = box.faces().compactMap { Shape.fromFace($0) }
        guard faces.count == 6 else { return nil }
        return Shape.sew(shapes: Array(faces.dropFirst()))
    }

    /// Edge indices on the open shell that `BRepFilletAPI_MakeFillet::Add` declines.
    /// Measured by the Cluster B census on this exact fixture.
    static let declinedIndices = [6, 9, 10, 11]
}
