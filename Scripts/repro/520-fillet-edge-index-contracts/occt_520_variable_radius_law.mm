// OCCTSwift#520 ground truth, part 1: which SetRadius overload OCCTShapeFilletVariable actually
// calls.
//
// The bridge writes, once per profile point:
//
//     double param = first + params[i] * (last - first);   // a curve parameter
//     fillet.SetRadius(radii[i], param, 1);                // "1 is the contour index"
//
// BRepFilletAPI_MakeFillet has no (Real, Real, Integer) overload. The viable candidate is
// SetRadius(const double Radius, const int IC, const int IinC), so `param` is silently truncated
// to an int and used as the *contour* index, and `1` is the edge-within-contour index. This probe
// measures what that does, against a call that passes the profile the way OCCT documents it
// (a TColgp_Array1OfPnt2d of (relative parameter, radius) pairs).
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
#include <TColgp_Array1OfPnt2d.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>

static TopoDS_Shape box(double side) { return BRepPrimAPI_MakeBox(side, side, side).Shape(); }

static TopoDS_Edge firstEdge(const TopoDS_Shape& s) {
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(s, TopAbs_EDGE, edgeMap);
    return TopoDS::Edge(edgeMap(1));  // bridge edgeIndex 0
}

static void result(const char* label, BRepFilletAPI_MakeFillet& fillet) {
    printf("%-46s", label);
    try {
        fillet.Build();
        printf(" IsDone=%d", (int)fillet.IsDone());
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
    } catch (Standard_Failure& f) {
        printf(" THREW: %s\n", f.GetMessageString());
    }
}

// Exactly what OCCTShapeFilletVariable does today.
static void asBridgeDoesIt(const char* label, double side,
                           const double* params, const double* radii, int count) {
    TopoDS_Shape s = box(side);
    TopoDS_Edge e = firstEdge(s);
    BRepFilletAPI_MakeFillet fillet(s);
    fillet.Add(e);

    double first, last;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(e, first, last);
    printf("  edge parameter range [%g, %g], NbContours=%d\n", first, last, fillet.NbContours());
    for (int i = 0; i < count; i++) {
        double param = first + params[i] * (last - first);
        printf("    SetRadius(%g, %g -> IC=%d, IinC=1)\n", radii[i], param, (int)param);
        fillet.SetRadius(radii[i], param, 1);
    }
    result(label, fillet);
}

// The same profile, passed the way BRepFilletAPI_MakeFillet documents it.
static void asOCCTDocumentsIt(const char* label, double side,
                              const double* params, const double* radii, int count) {
    TopoDS_Shape s = box(side);
    BRepFilletAPI_MakeFillet fillet(s);
    fillet.Add(firstEdge(s));

    TColgp_Array1OfPnt2d UandR(1, count);
    for (int i = 0; i < count; i++) UandR.SetValue(i + 1, gp_Pnt2d(params[i], radii[i]));
    fillet.SetRadius(UandR, 1, 1);
    result(label, fillet);
}

static void constantRadius(const char* label, double side, double radius) {
    TopoDS_Shape s = box(side);
    BRepFilletAPI_MakeFillet fillet(s);
    fillet.Add(radius, firstEdge(s));
    result(label, fillet);
}

int main() {
    // Unbuffered: one of these cases crashes, and a buffered stdout loses everything printed
    // before it.
    setvbuf(stdout, NULL, _IONBF, 0);

    // Case 1: the two-point profile from Shape.filletedVariable's own doc comment and test.
    {
        const double params[] = {0.0, 1.0};
        const double radii[]  = {1.0, 3.0};
        printf("=== profile [(0.0, 1.0), (1.0, 3.0)] on a 20mm box, edge 0 ===\n");
        asBridgeDoesIt("  bridge: SetRadius(r, param, 1)", 20.0, params, radii, 2);
        asOCCTDocumentsIt("  OCCT:   SetRadius(UandR, 1, 1)", 20.0, params, radii, 2);
        constantRadius("  reference: constant 1.0", 20.0, 1.0);
        constantRadius("  reference: constant 3.0", 20.0, 3.0);
    }

    // Case 2: three points, so the two-point shortcut inside OCCT's UandR overload is not taken.
    {
        const double params[] = {0.0, 0.5, 1.0};
        const double radii[]  = {1.0, 4.0, 1.0};
        printf("\n=== profile [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)] on a 30mm box, edge 0 ===\n");
        asBridgeDoesIt("  bridge: SetRadius(r, param, 1)", 30.0, params, radii, 3);
        asOCCTDocumentsIt("  OCCT:   SetRadius(UandR, 1, 1)", 30.0, params, radii, 3);
        constantRadius("  reference: constant 1.0", 30.0, 1.0);
        constantRadius("  reference: constant 4.0", 30.0, 4.0);
    }

    // Case 3: which of the bridge's two truncated contour indices, if either, is the one that
    // takes effect. ChFi3d_FilBuilder::SetRadius guards only `IC <= NbElements()`, so IC=0 passes
    // that check and reaches Value(0) on a 1-based sequence, while a large IC is dropped silently.
    printf("\n=== the two truncated contour indices in isolation (20mm box, 1 contour) ===\n");
    for (int ic : {0, 1, 20}) {
        TopoDS_Shape s = box(20.0);
        BRepFilletAPI_MakeFillet fillet(s);
        fillet.Add(firstEdge(s));
        char label[80];
        snprintf(label, sizeof(label), "  SetRadius(2.0, IC=%d, IinC=1)", ic);
        try {
            fillet.SetRadius(2.0, ic, 1);
        } catch (Standard_Failure& f) {
            printf("%-46s SetRadius THREW: %s\n", label, f.GetMessageString());
            continue;
        }
        result(label, fillet);
    }
    return 0;
}
