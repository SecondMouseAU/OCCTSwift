// Reachability probe for issue #1155: does BRepFilletAPI_MakeFillet/MakeChamfer's
// solid reconstruction (TopOpeBRepBuild_HBuilder -> TopOpeBRepBuild_Builder) ever
// take the "KPart" fast path that reaches GMergeSolids/GFillFaceSFS (the GridSS/ffsfs
// family of file-scope GLOBAL_* statics)? If FindIsKPart()/KPreturn()/GMergeSolids()/
// GFillFaceSFS() never print, that code family is unreached by this scenario.
#include <cstdio>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopExp.hxx>

static void filletAllEdges(const TopoDS_Shape& s, double radius, const char* label) {
    fprintf(stderr, "=== filletAllEdges(%s) ===\n", label);
    BRepFilletAPI_MakeFillet mk(s);
    int n = 0;
    for (TopExp_Explorer exp(s, TopAbs_EDGE); exp.More(); exp.Next()) {
        mk.Add(radius, TopoDS::Edge(exp.Current()));
        ++n;
    }
    fprintf(stderr, "    (%d edges added)\n", n);
    mk.Build();
    fprintf(stderr, "    IsDone=%d\n", mk.IsDone());
    if (mk.IsDone()) {
        GProp_GProps props;
        BRepGProp::VolumeProperties(mk.Shape(), props);
        fprintf(stderr, "    volume=%f\n", props.Mass());
    }
}

static void chamferAllEdges(const TopoDS_Shape& s, double d, const char* label) {
    fprintf(stderr, "=== chamferAllEdges(%s) ===\n", label);
    (void)d;
    BRepFilletAPI_MakeChamfer mk(s);
    int n = 0;
    for (TopExp_Explorer exp(s, TopAbs_EDGE); exp.More(); exp.Next()) {
        mk.Add(TopoDS::Edge(exp.Current()));
        ++n;
    }
    fprintf(stderr, "    (%d edges added)\n", n);
    mk.Build();
    fprintf(stderr, "    IsDone=%d\n", mk.IsDone());
}

int main() {
    // 1. Plain box, all 12 edges filleted -- classic "round every edge" op, corners
    //    where 3 fillets converge (ChFi3d_Builder_CnCrn.cxx territory).
    TopoDS_Shape box = BRepPrimAPI_MakeBox(20, 20, 20).Shape();
    filletAllEdges(box, 2.0, "box-all-edges");

    // 2. Box union sphere (matches the existing #341/#298 gate scenario geometry,
    //    known to create curved/planar SameDomain-adjacent regions), a handful of
    //    edges filleted.
    TopoDS_Shape box2 = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
    TopoDS_Shape sph = BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape();
    BRepAlgoAPI_Fuse fuse(box2, sph);
    fuse.Build();
    if (fuse.IsDone()) {
        filletAllEdges(fuse.Shape(), 0.5, "box-fuse-sphere-all-edges");
    }

    // 3. Two boxes fused sharing an entire coincident face (the classic KPart
    //    "iskole"/"disjoint by tangent face" configuration), then fillet all edges
    //    of the result.
    TopoDS_Shape boxA = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    TopoDS_Shape boxB = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape();
    BRepAlgoAPI_Fuse fuse2(boxA, boxB);
    fuse2.Build();
    if (fuse2.IsDone()) {
        filletAllEdges(fuse2.Shape(), 1.0, "coincident-face-fuse-all-edges");
    }

    // 4. Chamfer, same box.
    chamferAllEdges(box, 1.0, "box-all-edges-chamfer");

    // 5. Cylinder fillet (curved SameDomain-prone geometry).
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 20).Shape();
    filletAllEdges(cyl, 1.0, "cylinder-all-edges");

    fprintf(stderr, "=== harness done ===\n");
    return 0;
}
