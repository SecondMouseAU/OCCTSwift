// Ground truth for #492: what GeomConvert_CurveToAnaCurve / GeomConvert_SurfToAnaSurf
// actually return, against the pinned OCCT 8.0.0p1 kernel.
//
// Questions:
//  1. Can ConvertToAnalytical ever hand back the SAME handle it was given?
//     (the `result == surface->surface` guard in OCCTSurfaceToAnalytical assumes it can)
//  2. What comes back for an already-analytical input?
//  3. What comes back for an unconvertible input — null, or the input?
//  4. Gap()/newFirst/newLast on each path.

#include <Geom_Plane.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CurveToAnaCurve.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <gp_Pnt.hxx>
#include <gp_Ax3.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>
#include <cmath>

static const char* yn(bool b) { return b ? "YES" : "no"; }

static void probeSurface(const char* label, const Handle(Geom_Surface)& s, double tol) {
    printf("--- surface: %s\n", label);
    if (s.IsNull()) { printf("    input is null, skipped\n"); return; }
    try {
        GeomConvert_SurfToAnaSurf conv(s);
        Handle(Geom_Surface) r = conv.ConvertToAnalytical(tol);
        printf("    result null?           %s\n", yn(r.IsNull()));
        if (!r.IsNull()) {
            printf("    same handle as input?  %s\n", yn(r == s));
            printf("    result type            %s\n", r->DynamicType()->Name());
            printf("    gap                    %.6g\n", conv.Gap());
        } else {
            printf("    gap                    %.6g\n", conv.Gap());
        }
        printf("    IsCanonical(input)     %s\n", yn(GeomConvert_SurfToAnaSurf::IsCanonical(s)));
    } catch (const Standard_Failure& e) {
        printf("    THREW: %s\n", e.GetMessageString() ? e.GetMessageString() : "(no message)");
    } catch (...) {
        printf("    THREW: (unknown)\n");
    }
}

static void probeSurfaceBounded(const char* label, const Handle(Geom_Surface)& s, double tol,
                                double uMin, double uMax, double vMin, double vMax) {
    printf("--- surface (bounded): %s  uv=[%.3g,%.3g]x[%.3g,%.3g]\n", label, uMin, uMax, vMin, vMax);
    if (s.IsNull()) { printf("    input is null, skipped\n"); return; }
    try {
        GeomConvert_SurfToAnaSurf conv(s);
        Handle(Geom_Surface) r = conv.ConvertToAnalytical(tol, uMin, uMax, vMin, vMax);
        printf("    result null?           %s\n", yn(r.IsNull()));
        if (!r.IsNull()) {
            printf("    same handle as input?  %s\n", yn(r == s));
            printf("    result type            %s\n", r->DynamicType()->Name());
        }
        printf("    gap                    %.6g\n", conv.Gap());
    } catch (const Standard_Failure& e) {
        printf("    THREW: %s\n", e.GetMessageString() ? e.GetMessageString() : "(no message)");
    } catch (...) {
        printf("    THREW: (unknown)\n");
    }
}

static void probeCurve(const char* label, const Handle(Geom_Curve)& c, double tol,
                       bool subRange) {
    printf("--- curve: %s%s\n", label, subRange ? "  (sub-range: middle half)" : "  (full range)");
    if (c.IsNull()) { printf("    input is null, skipped\n"); return; }
    double f = c->FirstParameter(), l = c->LastParameter();
    if (subRange) { double d = (l - f) * 0.25; f += d; l -= d; }
    try {
        GeomConvert_CurveToAnaCurve conv(c);
        Handle(Geom_Curve) r;
        double nf = -12345, nl = -12345;
        bool ok = conv.ConvertToAnalytical(tol, r, f, l, nf, nl);
        printf("    ok                     %s\n", yn(ok));
        printf("    result null?           %s\n", yn(r.IsNull()));
        if (!r.IsNull()) {
            printf("    same handle as input?  %s\n", yn(r == c));
            printf("    result type            %s\n", r->DynamicType()->Name());
        }
        printf("    in  F/L                %.6g / %.6g\n", f, l);
        printf("    out newF/newL          %.6g / %.6g\n", nf, nl);
        printf("    gap                    %.6g\n", conv.Gap());
    } catch (const Standard_Failure& e) {
        printf("    THREW: %s\n", e.GetMessageString() ? e.GetMessageString() : "(no message)");
    } catch (...) {
        printf("    THREW: (unknown)\n");
    }
}

int main() {
    const double tol = 1e-4;

    printf("========== SURFACES ==========\n");

    Handle(Geom_Plane) plane = new Geom_Plane(gp_Ax3(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)));
    probeSurface("Geom_Plane (already analytical)", plane, tol);

    Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    probeSurface("Geom_CylindricalSurface (already analytical)", cyl, tol);

    Handle(Geom_SphericalSurface) sph =
        new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
    probeSurface("Geom_SphericalSurface (already analytical)", sph, tol);

    // BSpline that IS a plane
    {
        TColgp_Array2OfPnt pts(1, 4, 1, 4);
        for (int i = 1; i <= 4; ++i)
            for (int j = 1; j <= 4; ++j)
                pts.SetValue(i, j, gp_Pnt(i * 2.0, j * 2.0, 0.0));
        GeomAPI_PointsToBSplineSurface maker(pts);
        probeSurface("BSpline over a flat grid (convertible -> plane)", maker.Surface(), tol);
    }

    // BSpline that is NOT analytical (a saddle / freeform bump)
    Handle(Geom_BSplineSurface) freeform;
    {
        TColgp_Array2OfPnt pts(1, 5, 1, 5);
        for (int i = 1; i <= 5; ++i)
            for (int j = 1; j <= 5; ++j) {
                double x = i * 2.0, y = j * 2.0;
                pts.SetValue(i, j, gp_Pnt(x, y, sin(x * 0.7) * cos(y * 1.3) * 4.0));
            }
        GeomAPI_PointsToBSplineSurface maker(pts);
        freeform = maker.Surface();
        probeSurface("BSpline freeform bumpy (NOT convertible)", freeform, tol);
    }

    // Trimmed / offset wrappers around an analytical surface
    probeSurface("RectangularTrimmed(plane)",
                 new Geom_RectangularTrimmedSurface(Handle(Geom_Surface)(plane), -10.0, 10.0, -10.0, 10.0, true, true), tol);
    probeSurface("RectangularTrimmed(cylinder)",
                 new Geom_RectangularTrimmedSurface(Handle(Geom_Surface)(cyl), 0.0, M_PI, -5.0, 5.0, true, true), tol);
    probeSurface("Offset(plane, 2.0)", new Geom_OffsetSurface(plane, 2.0), tol);

    printf("\n========== SURFACES (bounded overload) ==========\n");
    probeSurfaceBounded("Geom_Plane (already analytical)", plane, tol, -10, 10, -10, 10);
    probeSurfaceBounded("BSpline freeform bumpy", freeform, tol, 0, 1, 0, 1);
    {
        TColgp_Array2OfPnt pts(1, 4, 1, 4);
        for (int i = 1; i <= 4; ++i)
            for (int j = 1; j <= 4; ++j)
                pts.SetValue(i, j, gp_Pnt(i * 2.0, j * 2.0, 0.0));
        GeomAPI_PointsToBSplineSurface maker(pts);
        Handle(Geom_Surface) flat = maker.Surface();
        double u1, u2, v1, v2; flat->Bounds(u1, u2, v1, v2);
        probeSurfaceBounded("BSpline flat, full bounds", flat, tol, u1, u2, v1, v2);
        probeSurfaceBounded("BSpline flat, middle half", flat, tol,
                            u1 + (u2 - u1) * 0.25, u2 - (u2 - u1) * 0.25,
                            v1 + (v2 - v1) * 0.25, v2 - (v2 - v1) * 0.25);
        probeSurfaceBounded("BSpline flat, INVERTED uv (uMin>uMax)", flat, tol, u2, u1, v2, v1);
    }

    printf("\n========== CURVES ==========\n");

    Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 1, 0));
    probeCurve("Geom_Line (already analytical, infinite range)", line, tol, false);
    probeCurve("TrimmedCurve(line, 0..10)", new Geom_TrimmedCurve(line, 0, 10), tol, false);
    probeCurve("TrimmedCurve(line, 0..10)", new Geom_TrimmedCurve(line, 0, 10), tol, true);

    Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0);
    probeCurve("Geom_Circle (already analytical)", circ, tol, false);
    probeCurve("Geom_Circle (already analytical)", circ, tol, true);

    // BSpline that IS a circle
    {
        Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(circ);
        probeCurve("BSpline over a circle (convertible)", bs, tol, false);
        probeCurve("BSpline over a circle (convertible)", bs, tol, true);
    }

    // BSpline that IS a line
    {
        TColgp_Array1OfPnt pts(1, 5);
        for (int i = 1; i <= 5; ++i) pts.SetValue(i, gp_Pnt(i * 1.0, i * 2.0, i * 3.0));
        GeomAPI_PointsToBSpline maker(pts);
        probeCurve("BSpline over collinear points (convertible -> line)", maker.Curve(), tol, false);
    }

    // Freeform BSpline: not analytical
    {
        TColgp_Array1OfPnt pts(1, 6);
        pts.SetValue(1, gp_Pnt(0, 0, 0));
        pts.SetValue(2, gp_Pnt(1, 3, 0));
        pts.SetValue(3, gp_Pnt(2, -2, 1));
        pts.SetValue(4, gp_Pnt(4, 5, -3));
        pts.SetValue(5, gp_Pnt(6, 0, 2));
        pts.SetValue(6, gp_Pnt(8, 4, 0));
        GeomAPI_PointsToBSpline maker(pts);
        probeCurve("BSpline freeform wiggle (NOT convertible)", maker.Curve(), tol, false);
    }

    printf("\n========== DONE ==========\n");
    return 0;
}
