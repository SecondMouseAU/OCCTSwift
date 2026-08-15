// Link-only stubs for symbols OCCTBridge_Modeling.mm references (from OTHER, un-compiled bridge
// translation units) but that occt_916_section_builder_stale.mm never actually calls. Needed only
// to satisfy the linker when compiling this one real, unmodified bridge file standalone against
// the xcframework, without pulling in the rest of Sources/OCCTBridge/src/*.mm.
#include "OCCTBridge.h"
#include "OCCTBridge_Internal.h"
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <vector>

void OCCTShapeRelease(OCCTShapeRef shape) { delete (OCCTShape*)shape; }

void occtEnsureSignals() {}

bool occtHasSelfIntersectingWire(const TopoDS_Shape&) { abort(); }

TopoDS_Shape occtUnifySameDomainInput(const TopoDS_Shape&, BRepBuilderAPI_Copy&) { abort(); }

TopoDS_Shape occtUnifySameDomainMapped(const TopoDS_Shape&, BRepBuilderAPI_Copy&) { abort(); }

std::vector<TopoDS_Shell> occtBodyBoundingShells(const TopoDS_Shape&) { abort(); }

TopoDS_Shape occtSolidBodiesToShape(const std::vector<TopoDS_Shape>&) { abort(); }

BRepOffsetAPI_MakeFilling occtFillingMakeBuilder(int32_t, int32_t, int32_t, int32_t, double) {
    abort();
}

bool occtFillingAddConstraint(BRepOffsetAPI_MakeFilling&, const TopoDS_Edge&, const TopoDS_Face&,
                               OCCTFillingSupport, GeomAbs_Shape, bool) {
    abort();
}
