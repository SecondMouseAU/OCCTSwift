import Foundation
import Testing

@testable import OCCTSwift

/// #3200 on the #2881 model (#3209): the vertex-snap window answers nil or a valid shape.
///
/// It never answers a done-but-`BRepCheck`-invalid one. Lives here, beside `Issue2881FilletObstacleTests`,
/// because the model is a `Fixtures/` file of this target and the wasm runner preopens only each
/// target's own `Fixtures` directory. The Apple-and-wasm-neutral cases are in
/// `Tests/OCCTModelingTests/Blends/Issue3200FilletResultValidityTests.swift`.
@Suite("Fillet of the #2881 model is BRepCheck-valid or nil (#3200)")
struct Issue3200FilletModelValidityTests {

    /// Whatever came back must be valid.
    private func expectNilOrValid(_ result: Shape?, _ context: String) {
        if let result {
            #expect(result.isValid, "\(context): returned a BRepCheck-invalid shape")
        }
    }

    private func model() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/occt1568-fillet-obstacle-model.brep")
        return try Shape.loadBREP(from: url)
    }

    /// Edge 13 in DRAW's 1-based numbering is index 12 here.
    @Test("The vertex-snap window of the #2881 model no longer answers an invalid shape")
    func vertexSnapWindow() throws {
        let m = try model()
        let e = m.edges()[12]
        // Below, inside and above the window: only the first and last may answer a shape.
        for r in [1.4983, 1.4984, 1.4985, 1.49853, 1.500000002, 1.5001, 1.501, 1.5018] {
            expectNilOrValid(m.filleted(edges: [e], radius: r), "model edge 13 r=\(r)")
        }
        // Pinned while #3209 is parked: a done-but-invalid window answers nil.
        #expect(m.filleted(edges: [e], radius: 1.4984) == nil)
        #expect(m.filleted(edges: [e], radius: 1.5001) == nil)
    }

    @Test("Radii outside the window keep their valid result")
    func outsideTheWindow() throws {
        let m = try model()
        let e = m.edges()[12]
        for (r, faces) in [(1.4, 29), (1.4982, 29), (1.52, 25)] {
            let result = try #require(m.filleted(edges: [e], radius: r), "r=\(r)")
            #expect(result.isValid)
            #expect(result.faces().count == faces, "r=\(r)")
        }
    }
}
