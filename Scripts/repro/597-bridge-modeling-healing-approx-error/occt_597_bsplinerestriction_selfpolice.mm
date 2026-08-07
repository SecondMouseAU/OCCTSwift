// Confirms empirically (not just by reading ConvertSurface's source) that ShapeCustom_
// BSplineRestriction self-polices: when it cannot reach myTol3d even at maxDeg/maxSeg caps, it
// declines that face (keeps the ORIGINAL surface) rather than accepting an out-of-tolerance fit.
// Forces the real GeomConvert_ApproxSurface branch (not the exact-conversion shortcuts) with a
// high-degree/many-knot BSpline surface, an impossibly tight tolerance, and tiny maxDeg/maxSeg
// caps that cannot possibly reach it.
#include <ShapeCustom_BSplineRestriction.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TopoDS_Face.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <TopLoc_Location.hxx>
#include <cstdio>
#include <cmath>

int main() {
    // A wavy, high-degree (7), many-knot (10 spans) BSpline surface -- forces the general
    // approximation branch (ConvertSurface's "if (aSurf->IsKind(STANDARD_TYPE(Geom_BSplineSurface)))"
    // branch at line 742 falls through because UDeg/VDeg (7) and NbSeg (100) exceed tiny caps).
    int nu = 17, nv = 17; // 17 poles, degree 7 => 10 interior knots => many spans
    TColgp_Array2OfPnt poles(1, nu, 1, nv);
    for (int i = 1; i <= nu; i++)
        for (int j = 1; j <= nv; j++)
            poles.SetValue(i, j, gp_Pnt(i * 2.0, j * 2.0,
                                          5.0 * std::sin(i * 0.9) * std::cos(j * 0.85)));
    int degree = 7;
    int nKnots = nu - degree; // interior + 2 end knots simplified via uniform clamped construction
    TColStd_Array1OfReal uknots(1, nu - degree + 1), vknots(1, nv - degree + 1);
    for (int i = 1; i <= uknots.Length(); i++) uknots.SetValue(i, double(i - 1) / (uknots.Length() - 1));
    for (int i = 1; i <= vknots.Length(); i++) vknots.SetValue(i, double(i - 1) / (vknots.Length() - 1));
    TColStd_Array1OfInteger umults(1, uknots.Length()), vmults(1, vknots.Length());
    umults.SetValue(1, degree + 1); umults.SetValue(uknots.Length(), degree + 1);
    for (int i = 2; i < uknots.Length(); i++) umults.SetValue(i, 1);
    vmults.SetValue(1, degree + 1); vmults.SetValue(vknots.Length(), degree + 1);
    for (int i = 2; i < vknots.Length(); i++) vmults.SetValue(i, 1);

    Handle(Geom_BSplineSurface) wavy = new Geom_BSplineSurface(poles, uknots, vknots, umults, vmults, degree, degree);
    TopoDS_Face face = BRepBuilderAPI_MakeFace(wavy, 1e-6);

    // Impossibly tight tolerance (1e-14) with tiny caps (maxDeg=3, maxSeg=2) that cannot possibly
    // fit this wavy degree-7 surface -- forces ConvertSurface's escalation loop to exhaust and
    // give up (source: ShapeCustom_BSplineRestriction.cxx return false at line 980/995).
    Handle(ShapeCustom_BSplineRestriction) mod = new ShapeCustom_BSplineRestriction(
        true, false, false, 1e-14, 1e-15, GeomAbs_C1, GeomAbs_C1, 3, 2, false, false);
    BRepTools_Modifier modifier(face, mod);
    bool done = modifier.IsDone();
    double c3d = 0, c2d = 0;
    double surfErr = mod->MaxErrors(c3d, c2d);
    printf("isDone=%-5s reportedSurfaceErr=%-12g (sentinel if unconverted)\n",
           done ? "true" : "false", surfErr);

    if (done) {
        TopoDS_Shape result = modifier.ModifiedShape(face);
        TopoDS_Face resultFace;
        for (TopExp_Explorer exp(result, TopAbs_FACE); exp.More(); exp.Next()) { resultFace = TopoDS::Face(exp.Current()); break; }
        TopLoc_Location loc;
        Handle(Geom_Surface) resultSurf = BRep_Tool::Surface(resultFace, loc);
        bool stillBSpline = resultSurf == wavy; // same handle => untouched (declined), not re-approximated
        printf("result surface handle == original wavy BSpline handle: %s\n", stillBSpline ? "YES (declined, kept original -- self-policed)" : "NO (was replaced with a new, possibly out-of-tolerance, fit)");
        if (!stillBSpline) {
            Handle(Geom_BSplineSurface) newBS = Handle(Geom_BSplineSurface)::DownCast(resultSurf);
            if (!newBS.IsNull()) printf("new surface: degree %dx%d\n", newBS->UDegree(), newBS->VDegree());
        }
    }
    return 0;
}
