// OCCTSwift#520 ground truth, part 2: what BRepFilletAPI_MakeFillet::Build() does when a contour
// added by the radius-law overload Add(edge) never receives a radius, and what the documented
// UandR overload does with parameters and radii the bridge never checks.
//
// Part 1 (occt_520_variable_radius_law.mm) ends in a SIGSEGV, so each case here runs in its own
// process: pass the case name as argv[1]. `run.sh` runs them all and reports each exit status.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <cstring>

static TopoDS_Shape box(double side) { return BRepPrimAPI_MakeBox(side, side, side).Shape(); }

static TopoDS_Edge firstEdge(const TopoDS_Shape& s) {
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(s, TopAbs_EDGE, edgeMap);
    return TopoDS::Edge(edgeMap(1));
}

static void result(BRepFilletAPI_MakeFillet& fillet) {
    try {
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
    } catch (Standard_Failure& f) {
        printf("  THREW: %s\n", f.GetMessageString());
    }
}

// Add(edge) with a UandR profile, the overload OCCTShapeFilletEvolving uses.
static void withProfile(int count, const double* params, const double* radii) {
    TopoDS_Shape s = box(20.0);
    BRepFilletAPI_MakeFillet fillet(s);
    fillet.Add(firstEdge(s));
    TColgp_Array1OfPnt2d UandR(1, count);
    for (int i = 0; i < count; i++) UandR.SetValue(i + 1, gp_Pnt2d(params[i], radii[i]));
    try {
        fillet.SetRadius(UandR, 1, 1);
    } catch (Standard_Failure& f) {
        printf("  SetRadius THREW: %s\n", f.GetMessageString());
        return;
    }
    result(fillet);
}

int main(int argc, const char** argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    const char* which = argc > 1 ? argv[1] : "";
    printf("[%s]\n", which);

    // --- the contour that never gets a radius ---

    // Add(edge) and nothing else. This is what OCCTShapeFilletEvolving produces for an edge whose
    // radiusPoints array is empty (pointCounts[i] == 0 takes neither of its two branches).
    if (!strcmp(which, "no-radius")) {
        TopoDS_Shape s = box(20.0);
        BRepFilletAPI_MakeFillet fillet(s);
        fillet.Add(firstEdge(s));
        printf("  NbContours=%d, no SetRadius call at all\n", fillet.NbContours());
        result(fillet);
    }

    // Every SetRadius dropped because the truncated contour index exceeded NbElements(). This is
    // what OCCTShapeFilletVariable produces for any edge whose curve parameter range does not
    // start at 0 (the box edges all start at 0, which is why its tests pass).
    if (!strcmp(which, "radius-dropped")) {
        TopoDS_Shape s = box(20.0);
        BRepFilletAPI_MakeFillet fillet(s);
        fillet.Add(firstEdge(s));
        printf("  NbContours=%d, SetRadius(2.0, IC=20, IinC=1) is dropped by IC <= NbElements()\n",
               fillet.NbContours());
        fillet.SetRadius(2.0, 20, 1);
        result(fillet);
    }

    // --- the UandR profile the bridge never validates ---

    // A non-positive radius in the profile.
    if (!strcmp(which, "zero-radius")) {
        const double params[] = {0.0, 1.0};
        const double radii[]  = {1.0, 0.0};
        withProfile(2, params, radii);
    }
    if (!strcmp(which, "negative-radius")) {
        const double params[] = {0.0, 1.0};
        const double radii[]  = {1.0, -3.0};
        withProfile(2, params, radii);
    }
    if (!strcmp(which, "all-radii-zero")) {
        const double params[] = {0.0, 0.5, 1.0};
        const double radii[]  = {0.0, 0.0, 0.0};
        withProfile(3, params, radii);
    }

    // Parameters outside the [0,1] both OCCT's header and Shape.filletedVariable's doc comment
    // promise. OCCT renormalises with Ucur = (Ucur - Uf) / (Ul - Uf) for 3+ points, and ignores
    // X entirely for 1 or 2 points, so these are the cases that say how much [0,1] is worth.
    if (!strcmp(which, "params-out-of-range-2pt")) {
        const double params[] = {99.0, -3.0};   // X ignored: the 2-point shortcut reads Y only
        const double radii[]  = {1.0, 3.0};
        withProfile(2, params, radii);
    }
    if (!strcmp(which, "params-out-of-range-3pt")) {
        const double params[] = {-5.0, 0.0, 7.0};   // renormalised to 0, 0.4166.., 1
        const double radii[]  = {1.0, 4.0, 1.0};
        withProfile(3, params, radii);
    }
    if (!strcmp(which, "params-equivalent-3pt")) {
        const double params[] = {0.0, 0.416666666666667, 1.0};   // the renormalised equivalent
        const double radii[]  = {1.0, 4.0, 1.0};
        withProfile(3, params, radii);
    }
    // All three parameters equal: Ul - Uf == 0, so the renormalisation divides by zero.
    if (!strcmp(which, "params-degenerate-3pt")) {
        const double params[] = {0.5, 0.5, 0.5};
        const double radii[]  = {1.0, 4.0, 1.0};
        withProfile(3, params, radii);
    }
    // Descending parameters: Ul - Uf < 0, so the renormalisation flips the profile.
    if (!strcmp(which, "params-descending-3pt")) {
        const double params[] = {1.0, 0.5, 0.0};
        const double radii[]  = {1.0, 4.0, 2.0};
        withProfile(3, params, radii);
    }
    // A single point: the X is ignored and the radius is constant.
    if (!strcmp(which, "single-point")) {
        const double params[] = {0.5};
        const double radii[]  = {2.0};
        withProfile(1, params, radii);
    }
    return 0;
}
