//  BRepGraphUnavailable.swift
//
//  What a build against a kernel without the BRepGraph package sees of `BRepGraph`. OCCT 8.1
//  withdrew the package (OCCT#1628, deferred with no date; see OCCT discussion 1656), so the
//  upstream `IR` kernel has no BRepGraph.hxx, the bridge half of the feature is compiled out
//  (`OCCTBridge_BRepGraph.mm`), and the Swift half in `BRepGraph.swift` and `BRepGraph+Attributes.swift`
//  is excluded from the target by Package.swift, as is this file when the kernel does provide the
//  package. The resolution members of the construction types are behind OCCTSWIFT_HAS_BREPGRAPH.
//
//  The type stays so that `BRepGraph.NodeKind` and `BRepGraph.NodeRef` (BRepGraphNodeRef.swift) keep
//  a home, and the one way to obtain a graph is marked unavailable with the reason, so the compiler
//  says why instead of "cannot find".

/// A topology graph over a shape.
///
/// Unavailable in this build. OCCT 8.1 withdrew the `BRepGraph` package (OCCT#1628, deferred with no date), so a build
/// against the upstream `IR` kernel cannot make one. The 8.0.x kernels still provide it and a
/// build against one of them (a local `Libraries/OCCT.xcframework` whose headers include
/// `BRepGraph.hxx`) turns the real implementation back on.
public final class BRepGraph: @unchecked Sendable {

    /// Build a topology graph from a shape.
    ///
    /// Unavailable in this build.
    @available(
        *, unavailable,
        message:
            "BRepGraph was withdrawn upstream in OCCT 8.1 (OCCT#1628), deferred with no date; see OCCT discussion 1656. It is unavailable against the upstream IR kernel."
    )
    public init?(shape: Shape, parallel: Bool = false) {
        fatalError("unavailable")
    }
}
