// OCCTSwift#489 ground truth, part 2: (a) what Build() does when no contour was added at all,
// (b) SetRadius with a non-positive radius (the radius-law path), (c) a NaN radius, and (d) the one
// case that escaped OCCTShapeBlendEdges' missing precondition: a bad radius whose edge index was
// out of range, so the bounds check dropped the pair and the batch built anyway.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Shape box() { return BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape(); }

static void result(BRepFilletAPI_MakeFillet& fillet) {
    fillet.Build();
    printf("  IsDone=%d", (int)fillet.IsDone());
    if (fillet.IsDone()) {
        TopoDS_Shape res = fillet.Shape();
        printf(" IsNull=%d", (int)res.IsNull());
        if (!res.IsNull()) {
            GProp_GProps props;
            BRepGProp::VolumeProperties(res, props);
            printf(" volume=%.6f valid=%d", props.Mass(), (int)BRepCheck_Analyzer(res).IsValid());
        }
    }
    printf("\n");
}

int main() {
    // (a) no contours added at all (every caller-supplied index out of range)
    printf("--- zero contours ---\n");
    try {
        TopoDS_Shape s = box();
        BRepFilletAPI_MakeFillet fillet(s);
        printf("  NbContours=%d\n", fillet.NbContours());
        result(fillet);
    } catch (Standard_Failure& f) { printf("  THREW: %s\n", f.GetMessageString()); }

    // (b) SetRadius with a non-positive radius (the FilletVariable / FilletEvolving path)
    for (double r : {0.0, -5.0}) {
        printf("--- SetRadius(%g, param, 1) ---\n", r);
        try {
            TopoDS_Shape s = box();
            TopTools_IndexedMapOfShape edgeMap;
            TopExp::MapShapes(s, TopAbs_EDGE, edgeMap);
            TopoDS_Edge e = TopoDS::Edge(edgeMap(1));
            BRepFilletAPI_MakeFillet fillet(s);
            fillet.Add(e);
            double first, last;
            Handle(Geom_Curve) c = BRep_Tool::Curve(e, first, last);
            fillet.SetRadius(r, first, 1);
            fillet.SetRadius(r, last, 1);
            result(fillet);
        } catch (Standard_Failure& f) { printf("  THREW: %s\n", f.GetMessageString()); }
    }

    // (c) NaN radius through Add()
    printf("--- Add(NaN, edge) ---\n");
    try {
        TopoDS_Shape s = box();
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(s, TopAbs_EDGE, edgeMap);
        BRepFilletAPI_MakeFillet fillet(s);
        fillet.Add(std::nan(""), TopoDS::Edge(edgeMap(1)));
        result(fillet);
    } catch (Standard_Failure& f) { printf("  THREW: %s\n", f.GetMessageString()); }

    // (d) one valid edge added, the invalid-radius entry skipped because its index was
    //     out of range, which today's OCCTShapeBlendEdges lets through.
    printf("--- valid edge only (bad-radius entry skipped by bounds check) ---\n");
    try {
        TopoDS_Shape s = box();
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(s, TopAbs_EDGE, edgeMap);
        BRepFilletAPI_MakeFillet fillet(s);
        fillet.Add(2.0, TopoDS::Edge(edgeMap(1)));
        result(fillet);
    } catch (Standard_Failure& f) { printf("  THREW: %s\n", f.GetMessageString()); }

    printf("done\n");
    return 0;
}
