// OCCTSwift#489 ground truth: what BRepFilletAPI_MakeFillet::Add(r, edge) does for r == 0
// and r < 0, uniform and mixed with a valid radius. See README.md in this directory.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>

static void report(const char* label, double r0, double r1, bool twoEdges) {
    printf("--- %s (r0=%g%s) ---\n", label, r0, twoEdges ? ", r1 varies" : "");
    try {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(box, TopAbs_EDGE, edgeMap);
        BRepFilletAPI_MakeFillet fillet(box);
        fillet.Add(r0, TopoDS::Edge(edgeMap(1)));
        if (twoEdges) fillet.Add(r1, TopoDS::Edge(edgeMap(2)));
        fillet.Build();
        printf("  Build ok, IsDone=%d\n", (int)fillet.IsDone());
        if (fillet.IsDone()) {
            TopoDS_Shape res = fillet.Shape();
            printf("  IsNull=%d\n", (int)res.IsNull());
            if (!res.IsNull()) {
                GProp_GProps props;
                BRepGProp::VolumeProperties(res, props);
                BRepCheck_Analyzer an(res);
                printf("  volume=%.6f valid=%d\n", props.Mass(), (int)an.IsValid());
            }
        } else {
            printf("  NbFaultyContours=%d\n", fillet.NbFaultyContours());
        }
    } catch (Standard_Failure& f) {
        printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
    } catch (...) {
        printf("  THREW unknown\n");
    }
}

int main() {
    report("baseline positive", 2.0, 0, false);
    report("zero radius", 0.0, 0, false);
    report("negative radius", -5.0, 0, false);
    report("mixed valid+zero", 2.0, 0.0, true);
    report("mixed valid+negative", 2.0, -5.0, true);
    printf("done\n");
    return 0;
}
