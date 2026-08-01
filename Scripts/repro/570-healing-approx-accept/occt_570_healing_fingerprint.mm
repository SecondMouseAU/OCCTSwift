// OCCTSwift#570 — the healing paths that accept an approximation on MaxError() <= tol.
//
// #522 fixed AdvApp2Var_ApproxF2var::mma2ce1_ writing the U Jacobi maxima into the V workspace slot,
// which made every patch's interior truncation error evaluate to exactly zero. Three kernel healing
// sites make an accept/reject decision on that number:
//
//   ShapeConstruct::ConvertSurfaceToBSpline    accepts on anApprox.MaxError() <= Tol3d && IsDone()
//   ShapeCustom_BSplineRestriction::ConvertSurface   accepts on anApprox.MaxError() <= myTol3d
//   ShapeCustom_ConvertToBSpline::NewSurface   calls the first, forcing GeomAbs_C0 for offset surfaces
//
// This harness fingerprints the *result* of each reachable bridge entry point across a fixture set
// that includes offset surfaces (the only way to exercise the forced-C0 branch), so the same binary
// run against a stock and a 0019 kernel gives a real before/after. See this directory's README.md.

#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepTools.hxx>
#include <BRepTools_Modifier.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <Precision.hxx>
#include <ShapeConstruct.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Elips.hxx>

#include <cmath>
#include <cstdio>
#include <ctime>
#include <string>
#include <vector>

// ---------------------------------------------------------------------------------------------
// Fingerprint of one surface: enough of its shape to notice any change, plus how far it sits from
// the surface it was meant to reproduce.
// ---------------------------------------------------------------------------------------------

static std::string typeName(const Handle(Geom_Surface) & s)
{
    if (s.IsNull()) return "NULL";
    std::string n = s->DynamicType()->Name();
    if (n.rfind("Geom_", 0) == 0) n = n.substr(5);
    return n;
}

// Unwrap trimming/offset shells so the BSpline underneath can be described.
static Handle(Geom_BSplineSurface) innerBSpline(Handle(Geom_Surface) s)
{
    for (int guard = 0; guard < 8 && !s.IsNull(); guard++)
    {
        Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(s);
        if (!bs.IsNull()) return bs;
        Handle(Geom_RectangularTrimmedSurface) rts = Handle(Geom_RectangularTrimmedSurface)::DownCast(s);
        if (!rts.IsNull()) { s = rts->BasisSurface(); continue; }
        Handle(Geom_OffsetSurface) os = Handle(Geom_OffsetSurface)::DownCast(s);
        if (!os.IsNull()) { s = os->BasisSurface(); continue; }
        break;
    }
    return Handle(Geom_BSplineSurface)();
}

// Max distance between two surfaces over an NxN grid of the requested domain. Returns -1 if either
// surface refuses to evaluate anywhere on it (an offset surface at a degenerate pole, typically).
static double deviation(const Handle(Geom_Surface) & a, const Handle(Geom_Surface) & b,
                        double u0, double u1, double v0, double v1, int n = 24)
{
    if (a.IsNull() || b.IsNull()) return -1;
    double worst = -1;
    for (int i = 0; i <= n; i++)
    {
        for (int j = 0; j <= n; j++)
        {
            double u = u0 + (u1 - u0) * i / (double)n;
            double v = v0 + (v1 - v0) * j / (double)n;
            try
            {
                double d = a->Value(u, v).Distance(b->Value(u, v));
                if (d > worst) worst = d;
            }
            catch (Standard_Failure const&) { }
        }
    }
    return worst;
}

// One line describing what came out, stable enough to diff two kernels.
static void printSurface(const char* tag, const Handle(Geom_Surface) & result,
                         const Handle(Geom_Surface) & source,
                         double u0, double u1, double v0, double v1)
{
    printf("    %-14s type=%-28s", tag, typeName(result).c_str());
    if (result.IsNull()) { printf("\n"); return; }

    Handle(Geom_BSplineSurface) bs = innerBSpline(result);
    if (bs.IsNull())
        printf(" deg=--x--  poles=--x--  knots=--x-- ");
    else
        printf(" deg=%dx%d  poles=%dx%d  knots=%dx%d ", bs->UDegree(), bs->VDegree(), bs->NbUPoles(),
               bs->NbVPoles(), bs->NbUKnots(), bs->NbVKnots());

    double dev = deviation(result, source, u0, u1, v0, v1);
    if (dev < 0)
        printf(" dev=n/a\n");
    else
        printf(" dev=%.6g\n", dev);
}

// ---------------------------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------------------------

struct Fixture
{
    std::string          label;
    Handle(Geom_Surface) surface; // what the face is built on
    double               u0, u1, v0, v1;
};

static Handle(Geom_BSplineSurface) bicubicBSpline()
{
    // Genuinely cubic in both directions: a pole count is not a degree (#522's fixture trap).
    NCollection_Array2<gp_Pnt> poles(1, 4, 1, 4);
    for (int i = 1; i <= 4; i++)
        for (int j = 1; j <= 4; j++)
            poles.SetValue(i, j, gp_Pnt(i * 3.0, j * 3.0, (double)((i * j) % 5)));
    Handle(Geom_BezierSurface) bez = new Geom_BezierSurface(poles);
    // Bezier -> BSpline so it can carry an offset (Geom_OffsetSurface wants a real basis).
    NCollection_Array1<double> uk(1, 2), vk(1, 2);
    NCollection_Array1<int>    um(1, 2), vm(1, 2);
    uk(1) = vk(1) = 0.0;
    uk(2) = vk(2) = 1.0;
    um(1) = um(2) = vm(1) = vm(2) = 4;
    return new Geom_BSplineSurface(poles, uk, vk, um, vm, 3, 3);
}

static std::vector<Fixture> fixtures()
{
    gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    std::vector<Fixture> f;

    // --- offset surfaces: the only way into ShapeCustom_ConvertToBSpline's forced-C0 branch -----
    // Full sphere: the V-boundary isos degenerate to its poles, which is exactly where #522's
    // NDMINU floor collapses.
    f.push_back({"offset(sphere r=10, +2) full",
                 new Geom_OffsetSurface(new Geom_SphericalSurface(ax3, 10.0), 2.0),
                 0.0, 2 * M_PI, -M_PI / 2, M_PI / 2});
    // Same sphere trimmed off its poles: #522 showed this does not collapse.
    f.push_back({"offset(sphere r=10, +2) V[-1,1]",
                 new Geom_OffsetSurface(
                     new Geom_RectangularTrimmedSurface(new Geom_SphericalSurface(ax3, 10.0), 0.0,
                                                        2 * M_PI, -1.0, 1.0),
                     2.0),
                 0.0, 2 * M_PI, -1.0, 1.0});
    f.push_back({"offset(cylinder r=5, +1)",
                 new Geom_OffsetSurface(
                     new Geom_RectangularTrimmedSurface(new Geom_CylindricalSurface(ax3, 5.0), 0.0,
                                                        2 * M_PI, -10.0, 10.0),
                     1.0),
                 0.0, 2 * M_PI, -10.0, 10.0});
    f.push_back({"offset(torus 20/5, +1)",
                 new Geom_OffsetSurface(new Geom_ToroidalSurface(ax3, 20.0, 5.0), 1.0),
                 0.0, 2 * M_PI, 0.0, 2 * M_PI});
    f.push_back({"offset(cone, +1)",
                 new Geom_OffsetSurface(
                     new Geom_RectangularTrimmedSurface(new Geom_ConicalSurface(ax3, 0.4, 3.0), 0.0,
                                                        2 * M_PI, 0.0, 12.0),
                     1.0),
                 0.0, 2 * M_PI, 0.0, 12.0});
    f.push_back({"offset(bicubic bspline, +1)", new Geom_OffsetSurface(bicubicBSpline(), 1.0), 0.0,
                 1.0, 0.0, 1.0});
    f.push_back({"offset(revolved ellipse, +1)",
                 new Geom_OffsetSurface(
                     new Geom_SurfaceOfRevolution(
                         new Geom_Ellipse(gp_Elips(gp_Ax2(gp_Pnt(20, 0, 0), gp_Dir(0, 1, 0)), 6.0, 2.0)),
                         gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))),
                     1.0),
                 0.0, 2 * M_PI, 0.0, 2 * M_PI});

    // --- non-offset surfaces that still reach the approximation loop -----------------------------
    f.push_back({"revolved ellipse",
                 new Geom_SurfaceOfRevolution(
                     new Geom_Ellipse(gp_Elips(gp_Ax2(gp_Pnt(20, 0, 0), gp_Dir(0, 1, 0)), 6.0, 2.0)),
                     gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))),
                 0.0, 2 * M_PI, 0.0, 2 * M_PI});
    f.push_back({"bicubic bspline", bicubicBSpline(), 0.0, 1.0, 0.0, 1.0});
    // Elementary surfaces short-circuit ConvertSurfaceToBSpline entirely (GeomConvert exact
    // conversion, no approximation) — carried as the control.
    f.push_back({"sphere r=10 (elementary)",
                 new Geom_RectangularTrimmedSurface(new Geom_SphericalSurface(ax3, 10.0), 0.0,
                                                    2 * M_PI, -M_PI / 2, M_PI / 2),
                 0.0, 2 * M_PI, -M_PI / 2, M_PI / 2});

    return f;
}

static TopoDS_Face faceOf(const Fixture& f)
{
    BRepBuilderAPI_MakeFace mk(f.surface, f.u0, f.u1, f.v0, f.v1, Precision::Confusion());
    if (!mk.IsDone()) return TopoDS_Face();
    return mk.Face();
}

static Handle(Geom_Surface) firstFaceSurface(const TopoDS_Shape& s)
{
    for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    {
        TopLoc_Location l;
        return BRep_Tool::Surface(TopoDS::Face(e.Current()), l);
    }
    return Handle(Geom_Surface)();
}

// ---------------------------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------------------------

static const char* contName(GeomAbs_Shape s)
{
    switch (s)
    {
        case GeomAbs_C0: return "C0";
        case GeomAbs_C1: return "C1";
        case GeomAbs_C2: return "C2";
        default: return "??";
    }
}

int main()
{
    printf("Precision::Approximation() = %g   Precision::Confusion() = %g\n\n",
           Precision::Approximation(), Precision::Confusion());

    std::vector<Fixture> all = fixtures();

    // -----------------------------------------------------------------------------------------
    // 1. ShapeConstruct::ConvertSurfaceToBSpline directly, at the continuity each healing path
    //    actually asks for. This is the decision site; everything below inherits it.
    // -----------------------------------------------------------------------------------------
    printf("=========================================================================\n");
    printf(" 1. ShapeConstruct::ConvertSurfaceToBSpline (tol=Precision::Approximation(),\n");
    printf("    MaxSegments=10000, MaxDegree=15 — exactly what ShapeCustom_ConvertToBSpline passes)\n");
    printf("=========================================================================\n");
    for (const Fixture& f : all)
    {
        printf("  %s   domain U[%g %g] V[%g %g]\n", f.label.c_str(), f.u0, f.u1, f.v0, f.v1);
        for (GeomAbs_Shape cnt : {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2})
        {
            Handle(Geom_BSplineSurface) res;
            try
            {
                res = ShapeConstruct::ConvertSurfaceToBSpline(f.surface, f.u0, f.u1, f.v0, f.v1,
                                                             Precision::Approximation(), cnt, 10000,
                                                             15);
            }
            catch (Standard_Failure const& e)
            {
                printf("    req=%-3s      THREW %s\n", contName(cnt), e.GetMessageString());
                continue;
            }
            char tag[16];
            snprintf(tag, sizeof(tag), "req=%s", contName(cnt));
            printSurface(tag, res, f.surface, f.u0, f.u1, f.v0, f.v1);
        }
        printf("\n");
    }

    // -----------------------------------------------------------------------------------------
    // 2. What GeomConvert_ApproxSurface itself reports for the same request — the number the
    //    accept/reject test is made against.
    // -----------------------------------------------------------------------------------------
    printf("=========================================================================\n");
    printf(" 2. The accepted number: GeomConvert_ApproxSurface(surf, Tol3d/2, cnt, cnt, 15, 15,\n");
    printf("    10000, 0).MaxError() vs the real deviation, and whether MaxError() <= Tol3d holds\n");
    printf("=========================================================================\n");
    const double tol3d = Precision::Approximation();
    for (const Fixture& f : all)
    {
        printf("  %s\n", f.label.c_str());
        for (GeomAbs_Shape cnt : {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2})
        {
            Handle(Geom_Surface) trimmed =
                new Geom_RectangularTrimmedSurface(f.surface, f.u0, f.u1, f.v0, f.v1);
            try
            {
                GeomConvert_ApproxSurface a(trimmed, tol3d / 2, cnt, cnt, 15, 15, 10000, 0);
                Handle(Geom_BSplineSurface) bs = a.Surface();
                double dev = deviation(bs, f.surface, f.u0, f.u1, f.v0, f.v1);
                printf("    req=%-3s isDone=%d maxError=%-13.6g accepted=%-3s ", contName(cnt),
                       (int)a.IsDone(), a.MaxError(),
                       (a.MaxError() <= tol3d && a.IsDone()) ? "YES" : "no");
                if (bs.IsNull())
                    printf("surface=NULL\n");
                else
                    printf("deg=%dx%d poles=%dx%d dev=%.6g\n", bs->UDegree(), bs->VDegree(),
                           bs->NbUPoles(), bs->NbVPoles(), dev);
            }
            catch (Standard_Failure const& e)
            {
                printf("    req=%-3s THREW %s\n", contName(cnt), e.GetMessageString());
            }
        }
        printf("\n");
    }

    // -----------------------------------------------------------------------------------------
    // 3. ShapeCustom::ConvertToBSpline — the bridge's OCCTShapeConvertToBSpline /
    //    OCCTShapeCustomConvertToBSpline / OCCTShapeConvertToBSplineAdvanced.
    //    offset=true takes the forced-GeomAbs_C0 branch; offset=false converts the basis instead.
    // -----------------------------------------------------------------------------------------
    printf("=========================================================================\n");
    printf(" 3. ShapeCustom::ConvertToBSpline(shape, extr, revol, offset, plane)\n");
    printf("=========================================================================\n");
    for (const Fixture& f : all)
    {
        TopoDS_Face face = faceOf(f);
        if (face.IsNull()) { printf("  %s   FACE BUILD FAILED\n\n", f.label.c_str()); continue; }
        printf("  %s\n", f.label.c_str());
        for (bool offsetMode : {true, false})
        {
            TopoDS_Shape out;
            try
            {
                out = ShapeCustom::ConvertToBSpline(face, true, true, offsetMode, false);
            }
            catch (Standard_Failure const& e)
            {
                printf("    offset=%-5s  THREW %s\n", offsetMode ? "true" : "false",
                       e.GetMessageString());
                continue;
            }
            char tag[24];
            snprintf(tag, sizeof(tag), "offset=%s", offsetMode ? "true" : "false");
            printSurface(tag, firstFaceSurface(out), f.surface, f.u0, f.u1, f.v0, f.v1);
        }
        printf("\n");
    }

    // -----------------------------------------------------------------------------------------
    // 4. ShapeCustom::BSplineRestriction — the bridge's OCCTShapeBSplineRestriction (hardcoded C1),
    //    OCCTShapeCustomBSplineRestriction and OCCTShapeBSplineRestrictionAdvanced (caller's).
    // -----------------------------------------------------------------------------------------
    printf("=========================================================================\n");
    printf(" 4. ShapeCustom::BSplineRestriction(shape, tol3d=0.01, tol2d=0.01, maxDeg=9,\n");
    printf("    maxSeg=10000, cont3d, cont2d, degreePriority=true, rational=true)\n");
    printf("=========================================================================\n");
    for (const Fixture& f : all)
    {
        TopoDS_Face face = faceOf(f);
        if (face.IsNull()) { printf("  %s   FACE BUILD FAILED\n\n", f.label.c_str()); continue; }
        printf("  %s\n", f.label.c_str());
        for (GeomAbs_Shape cnt : {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2})
        {
            TopoDS_Shape out;
            try
            {
                Handle(ShapeCustom_RestrictionParameters) params =
                    new ShapeCustom_RestrictionParameters();
                out = ShapeCustom::BSplineRestriction(face, 0.01, 0.01, 9, 10000, cnt, cnt, true,
                                                      true, params);
            }
            catch (Standard_Failure const& e)
            {
                printf("    cont=%-3s      THREW %s\n", contName(cnt), e.GetMessageString());
                continue;
            }
            char tag[16];
            snprintf(tag, sizeof(tag), "cont=%s", contName(cnt));
            printSurface(tag, firstFaceSurface(out), f.surface, f.u0, f.u1, f.v0, f.v1);
        }
        printf("\n");
    }

    // -----------------------------------------------------------------------------------------
    // 5. The 1999 workaround. ShapeCustom_ConvertToBSpline::NewSurface forces GeomAbs_C0 for any
    //    offset surface ("pdn 30.06.99 because of hang-up in GeomConvert_ApproxSurface") instead of
    //    passing surf->Continuity(). Time the request it suppresses, so retiring it is a
    //    measurement rather than an assumption.
    // -----------------------------------------------------------------------------------------
    printf("=========================================================================\n");
    printf(" 5. What the 1999 forced-C0 workaround suppresses: ConvertSurfaceToBSpline at\n");
    printf("    surf->Continuity() instead of GeomAbs_C0, wall-clock timed\n");
    printf("=========================================================================\n");
    for (const Fixture& f : all)
    {
        Handle(Geom_OffsetSurface) os = Handle(Geom_OffsetSurface)::DownCast(f.surface);
        if (os.IsNull()) continue; // the workaround only fires for offset surfaces
        GeomAbs_Shape own = f.surface->Continuity();
        const char*   ownName = own == GeomAbs_CN ? "CN"
                                : own == GeomAbs_C3 ? "C3"
                                                    : contName(own);
        printf("  %-32s Continuity()=%s\n", f.label.c_str(), ownName);
        for (int which = 0; which < 2; which++)
        {
            GeomAbs_Shape req = which == 0 ? GeomAbs_C0 : own;
            clock_t                     t0 = clock();
            Handle(Geom_BSplineSurface) res;
            const char*                 err = nullptr;
            try
            {
                res = ShapeConstruct::ConvertSurfaceToBSpline(f.surface, f.u0, f.u1, f.v0, f.v1,
                                                             Precision::Approximation(), req, 10000,
                                                             15);
            }
            catch (Standard_Failure const& e) { err = e.GetMessageString(); }
            double secs = (double)(clock() - t0) / CLOCKS_PER_SEC;
            printf("    %-22s %7.3fs  ", which == 0 ? "forced C0 (today)" : "own continuity", secs);
            if (err) { printf("THREW %s\n", err); continue; }
            if (res.IsNull()) { printf("NULL\n"); continue; }
            double dev = deviation(res, f.surface, f.u0, f.u1, f.v0, f.v1);
            printf("deg=%dx%d poles=%dx%d dev=%.6g\n", res->UDegree(), res->VDegree(),
                   res->NbUPoles(), res->NbVPoles(), dev);
        }
        printf("\n");
    }

    printf("done\n");
    return 0;
}
