import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1513: `occtCPntsUniformDeflectionImpl` (`OCCTBridge_Curve3D_ArcLength.mm`, backing
/// `OCCTCPntsUniformDeflection`/`Range`) only guarded the wrapper pointer (`if (!shape) return
/// false;`), never `occtShapeIsPresent(shape)` -- so `TopoDS::Edge(shape->shape)` handed a
/// null-wrapping `OCCTShapeRef` a null `TopoDS_Shape`, and the immediately following
/// `BRepAdaptor_Curve bac(edge)` dereferenced it unconditionally: an uncatchable SIGSEGV, not a
/// catchable `Standard_Failure` the surrounding `catch (...)` could absorb. Every other sibling
/// in the same file (`OCCTGCPntsQuasiUniform`, `OCCTUniformAbscissaByCount`/`ByDistance` and
/// their `Range` variants) already called `occtShapeIsPresent` first.
///
/// `Shape.nullified` (public, deprecated-but-callable, see `Shape+Topology.swift`) is the issue's
/// own repro path: a real, non-null `OCCTShapeRef` wrapping a null `TopoDS_Shape`, exactly the
/// shape the pointer-only guard let through. Both `uniformDeflection` overloads share the one
/// bridge helper (#794), so one test per overload is one test per public entry point, not
/// redundant coverage of the same call.
///
/// The fix was carried in ALL SIX split-file copies of this `static` helper (#1380's shared-block
/// design duplicates it verbatim into every `OCCTBridge_Curve3D_*.mm` file; only `_ArcLength.mm`'s
/// copy is wired to the public C symbols these tests exercise, so this suite cannot directly probe
/// the other five, but `python3 Scripts/check-null-handle-guards.py` covers all six statically).
@Suite("Issue #1513: CPnts UniformDeflection null-shape guard")
struct Issue1513UniformDeflectionNullGuardTests {

    @Test("a nullified Shape returns nil, not a crash -- uniformDeflection(_:)")
    func nullifiedShapeUniformDeflectionReturnsNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        #expect(nulled.uniformDeflection(0.1) == nil)
    }

    @Test("a nullified Shape returns nil, not a crash -- uniformDeflection(_:range:)")
    func nullifiedShapeUniformDeflectionRangeReturnsNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        #expect(nulled.uniformDeflection(0.1, range: 0...1) == nil)
    }

    @Test("an ordinary edge is unaffected by the guard")
    func ordinaryEdgeUnaffected() throws {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 5))
        var found = false
        for edgeShape in cyl.subShapes(ofType: .edge) {
            if let result = edgeShape.uniformDeflection(0.1), result.points.count > 4 {
                #expect(result.parameters.count == result.points.count)
                found = true
                break
            }
        }
        #expect(found)
    }
}
