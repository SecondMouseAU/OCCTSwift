// #556 ground truth, full sweep: for every distinct OCCT entry point the 60 guarded bridge
// functions pass a geometry Handle into, does a null handle raise a catchable Standard_Failure
// (which the bridge's existing catch(...) already absorbs) or an uncatchable OS signal?
// Each probe runs in a forked child.
#include <BRepAlgoAPI_Section.hxx>
#include <BRepLib_MakeEdge2d.hxx>
#include <BRep_Tool.hxx>
#include <Bisector_BisecAna.hxx>
#include <Draft_FaceInfo.hxx>
#include <ExtremaPC_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GeomAPI_ExtremaSurfaceSurface.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomFill_Gordon.hxx>
#include <Geom_BoundedCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <Geom2d_BoundedCurve.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Approx_SameParameter.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <GeomFill_NSections.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <GeomLib_Tool.hxx>
#include <GeomTools_Curve2dSet.hxx>
#include <GeomTools_CurveSet.hxx>
#include <GeomTools_SurfaceSet.hxx>
#include <LocalAnalysis_CurveContinuity.hxx>
#include <LocalAnalysis_SurfaceContinuity.hxx>
#include <ShapeUpgrade_ConvertCurve2dToBezier.hxx>
#include <ShapeUpgrade_SplitCurve2dContinuity.hxx>
#include <ShapeUpgrade_SplitCurve3dContinuity.hxx>
#include <ShapeUpgrade_SplitSurfaceAngle.hxx>
#include <ShapeUpgrade_SplitSurfaceArea.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <ShapeConstruct_Curve.hxx>
#include <ShapeConstruct_ProjectCurveOnSurface.hxx>
#include <ShapeCustom_Curve.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <ShapeCustom_Surface.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Sequence.hxx>
#include <Standard_Failure.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <sstream>
#include <cstdio>
#include <cstring>
#include <functional>
#include <sys/wait.h>
#include <unistd.h>

static int uncatchable = 0, catchable = 0, benign = 0;

static void probe(const char* bridgeFn, const char* call, const std::function<void()>& body) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        try { body(); }
        catch (Standard_Failure const&) { _exit(3); }
        catch (...) { _exit(4); }
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    const char* verdict;
    bool crash = false;
    if (WIFSIGNALED(st)) { verdict = "SIGNAL (uncatchable)"; crash = true; }
    else if (WEXITSTATUS(st) == 3) { verdict = "Standard_Failure"; catchable++; }
    else if (WEXITSTATUS(st) == 4) { verdict = "other exception"; catchable++; }
    else { verdict = "returned"; benign++; }
    if (crash) uncatchable++;
    printf("  %-22s %-42s %s\n", bridgeFn, call, verdict);
}

int main() {
    Handle(Geom_Curve) nc;
    Handle(Geom2d_Curve) nc2;
    Handle(Geom_Surface) ns;

    printf("#556: null geometry Handle at every OCCT entry point the guarded bridge fns call\n");
    printf("(OCCT 8.0.0p1. 'Standard_Failure'/'returned' = the pre-fix catch(...) already coped.)\n\n");
    printf("  %-22s %-42s %s\n", "bridge function", "OCCT call", "result");
    printf("  %-22s %-42s %s\n", "----------------------", "------------------------------------------", "------");

    probe("Curve3DProjectPoint", "ShapeAnalysis_Curve::Project", [&] {
        ShapeAnalysis_Curve s; gp_Pnt p; double t;
        (void)s.Project(nc, gp_Pnt(0, 0, 0), 1e-7, p, t);
    });
    probe("Curve3DValidateRange", "ShapeAnalysis_Curve::ValidateRange", [&] {
        ShapeAnalysis_Curve s; double f = 0, l = 1; (void)s.ValidateRange(nc, f, l, 1e-7);
    });
    probe("...GetSamplePoints3D", "ShapeAnalysis_Curve::GetSamplePoints", [&] {
        ShapeAnalysis_Curve s; NCollection_Sequence<gp_Pnt> q;
        (void)s.GetSamplePoints(nc, 0, 1, q);
    });
    probe("Curve3DIsClosedWithPreci", "ShapeAnalysis_Curve::IsClosed", [&] {
        (void)ShapeAnalysis_Curve::IsClosed(nc, 1e-7);
    });
    probe("Curve3DIsPeriodicSA", "ShapeAnalysis_Curve::IsPeriodic", [&] {
        (void)ShapeAnalysis_Curve::IsPeriodic(nc);
    });
    probe("Curve3DConvertToPeriodic", "ShapeCustom_Curve ctor", [&] { ShapeCustom_Curve c(nc); (void)c; });
    probe("Curve3DSplitAt", "Handle(Geom_Curve)->FirstParameter", [&] {
        Handle(Geom_Curve) c = nc; (void)c->FirstParameter();
    });
    probe("GCPntsTangential...", "GeomAdaptor_Curve ctor", [&] { GeomAdaptor_Curve a(nc); (void)a; });
    probe("...ConvertToBSpline3D", "ShapeConstruct_Curve::ConvertToBSpline", [&] {
        ShapeConstruct_Curve s; (void)s.ConvertToBSpline(nc, 0, 1, 1e-7);
    });
    probe("...AdjustCurve3D", "ShapeConstruct_Curve::AdjustCurve", [&] {
        ShapeConstruct_Curve s; (void)s.AdjustCurve(nc, gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 1));
    });
    probe("Curve3DCreateOffset", "new Geom_OffsetCurve", [&] {
        Handle(Geom_OffsetCurve) o = new Geom_OffsetCurve(nc, 1.0, gp_Dir(0, 0, 1)); (void)o;
    });
    probe("Curve3DTrimmed", "new Geom_TrimmedCurve", [&] {
        Handle(Geom_TrimmedCurve) t = new Geom_TrimmedCurve(nc, 0, 1); (void)t;
    });
    probe("ConcatenateCurves3D", "Geom_BoundedCurve::DownCast then deref", [&] {
        Handle(Geom_BoundedCurve) b = Handle(Geom_BoundedCurve)::DownCast(nc);
        if (b.IsNull()) (void)nc->FirstParameter();
    });
    probe("...ParameterAtLength", "GCPnts_AbscissaPoint(adaptor)", [&] {
        GeomAdaptor_Curve a(nc); GCPnts_AbscissaPoint ap(a, 1.0, 0.0); (void)ap.IsDone();
    });
    probe("ExtremaPCCurve", "ExtremaPC_Curve ctor", [&] { ExtremaPC_Curve e(nc); (void)e; });

    printf("\n");
    probe("Curve2DConvertToLine", "ShapeCustom_Curve2d::ConvertToLine2d", [&] {
        double a = 0, b = 0, d = 0;
        (void)ShapeCustom_Curve2d::ConvertToLine2d(nc2, 0, 1, 1e-7, a, b, d);
    });
    probe("ApproxCurve2d / Gcc*", "Geom2dAdaptor_Curve ctor", [&] {
        Geom2dAdaptor_Curve a(nc2); (void)a;
    });
    probe("ExtremaExtCC2d", "Geom2dAdaptor_Curve(c, first, last)", [&] {
        Geom2dAdaptor_Curve a(nc2, 0, 1); (void)a;
    });
    probe("BisectorBisecAna...", "Bisector_BisecAna::Perform", [&] {
        Handle(Bisector_BisecAna) b = new Bisector_BisecAna();
        Handle(Geom2d_Point) p = new Geom2d_CartesianPoint(gp_Pnt2d(0, 0));
        b->Perform(nc2, p, gp_Pnt2d(0, 0), gp_Vec2d(1, 0), gp_Vec2d(0, 1), 1.0, 1e-7);
    });
    probe("Curve2DPointAt", "Geom2d_Curve->D0", [&] { gp_Pnt2d p; nc2->D0(0.5, p); });
    probe("...ConvertToBSpline2D", "ShapeConstruct_Curve::ConvertToBSpline(2d)", [&] {
        ShapeConstruct_Curve s; (void)s.ConvertToBSpline(nc2, 0, 1, 1e-7);
    });
    probe("...AdjustCurve2D", "ShapeConstruct_Curve::AdjustCurve2d", [&] {
        ShapeConstruct_Curve s; (void)s.AdjustCurve2d(nc2, gp_Pnt2d(0, 0), gp_Pnt2d(1, 1));
    });
    probe("ConcatenateCurves2D", "Geom2d_BoundedCurve::DownCast then deref", [&] {
        Handle(Geom2d_BoundedCurve) b = Handle(Geom2d_BoundedCurve)::DownCast(nc2);
        if (b.IsNull()) (void)nc2->FirstParameter();
    });
    probe("MakeEdge2dCurve", "BRepLib_MakeEdge2d ctor", [&] {
        BRepLib_MakeEdge2d m(nc2); (void)m.IsDone();
    });

    printf("\n");
    probe("SurfaceFillBSpline*", "GeomConvert::CurveToBSplineCurve", [&] {
        (void)GeomConvert::CurveToBSplineCurve(nc);
    });
    probe("SurfaceExtrema", "GeomAPI_ExtremaSurfaceSurface", [&] {
        GeomAPI_ExtremaSurfaceSurface e(ns, ns, 0, 1, 0, 1, 0, 1, 0, 1); (void)e.NbExtrema();
    });
    probe("SurfaceValueOfUV etc", "new ShapeAnalysis_Surface", [&] {
        Handle(ShapeAnalysis_Surface) s = new ShapeAnalysis_Surface(ns);
        (void)s->ValueOfUV(gp_Pnt(0, 0, 0), 1e-7);
    });
    probe("SurfaceConvertToPeriodic", "ShapeCustom_Surface::ConvertToPeriodic", [&] {
        ShapeCustom_Surface c(ns); (void)c.ConvertToPeriodic(Standard_False);
    });
    probe("SurfaceCreate*Trimmed", "new Geom_RectangularTrimmedSurface", [&] {
        Handle(Geom_RectangularTrimmedSurface) t = new Geom_RectangularTrimmedSurface(
            ns, 0.0, 1.0, 0.0, 1.0, Standard_True, Standard_True); (void)t;
    });
    probe("GeomFillGordon", "GeomFill_Gordon::Init + Perform", [&] {
        NCollection_Array1<occ::handle<Geom_Curve>> a(0, 1), b(0, 1);
        a.SetValue(0, nc); a.SetValue(1, nc); b.SetValue(0, nc); b.SetValue(1, nc);
        GeomFill_Gordon g; g.Init(a, b, 1e-7); g.Perform(); (void)g.IsDone();
    });

    printf("\n");
    probe("DraftFaceInfoFromSurface", "Draft_FaceInfo ctor", [&] {
        Draft_FaceInfo f(ns, false); (void)f;
    });
    probe("ShapeSectionWithSurface", "BRepAlgoAPI_Section(shape, surface)", [&] {
        TopoDS_Shape empty;
        BRepAlgoAPI_Section s(empty, ns); s.Build(); (void)s.IsDone();
    });
    probe("SectionBuilderInit1/2", "BRepAlgoAPI_Section::Init1", [&] {
        BRepAlgoAPI_Section s; s.Init1(ns);
    });
    probe("ProjectCurveOnSurface", "ShapeConstruct_ProjectCurveOnSurface", [&] {
        Handle(ShapeConstruct_ProjectCurveOnSurface) p = new ShapeConstruct_ProjectCurveOnSurface();
        p->Init(ns, 1e-7);
        Handle(Geom2d_Curve) out;
        (void)p->Perform(nc, 0, 1, out);
    });
    probe("BRepToolCurveOnPlane", "BRep_Tool::CurveOnPlane", [&] {
        TopoDS_Edge e; TopLoc_Location l; double f = 0, la = 0;
        (void)BRep_Tool::CurveOnPlane(e, ns, l, f, la);
    });

    // #618: the entry points the original sweep never saw. The walk that produced #556's census
    // matched only `param->field`, so every site reaching the handle through a cast or a local
    // alias was invisible, and so were the OCCT calls those sites make. Each probe below runs the
    // bridge function's real sequence, not just its first call, because the crash need not be on
    // the first one.
    printf("\n  --- #618: reached through a cast or a local alias, never measured by #556 ---\n");

    probe("LocalAnalysisCurveCont*", "LocalAnalysis_CurveContinuity ctor", [&] {
        LocalAnalysis_CurveContinuity cc(nc, 0.5, nc, 0.5, GeomAbs_C1);
        (void)cc.IsDone();
    });
    probe("LocalAnalysisSurfCont*", "LocalAnalysis_SurfaceContinuity ctor", [&] {
        LocalAnalysis_SurfaceContinuity sc(ns, 0.5, 0.5, ns, 0.5, 0.5, GeomAbs_C1);
        (void)sc.IsDone();
    });
    probe("GeomLibToolParameter3D", "GeomLib_Tool::Parameter(Geom_Curve)", [&] {
        double p = 0; (void)GeomLib_Tool::Parameter(nc, gp_Pnt(0, 0, 0), 1e-3, p);
    });
    probe("GeomLibToolParameter2D", "GeomLib_Tool::Parameter(Geom2d_Curve)", [&] {
        double p = 0; (void)GeomLib_Tool::Parameter(nc2, gp_Pnt2d(0, 0), 1e-3, p);
    });
    probe("GeomLibToolParams...Surf", "GeomLib_Tool::Parameters(Geom_Surface)", [&] {
        double u = 0, v = 0; (void)GeomLib_Tool::Parameters(ns, gp_Pnt(0, 0, 0), 1e-3, u, v);
    });
    probe("ApproxSameParameter", "Approx_SameParameter ctor", [&] {
        Approx_SameParameter a(nc, nc2, ns, 1e-3); (void)a.IsDone();
    });
    probe("SplitCurve3dContinuity", "ShapeUpgrade_SplitCurve3dContinuity Init+Perform", [&] {
        Handle(ShapeUpgrade_SplitCurve3dContinuity) s = new ShapeUpgrade_SplitCurve3dContinuity();
        s->Init(nc); s->SetCriterion(GeomAbs_C1); s->SetTolerance(1e-3); s->Perform(true);
        (void)s->GetCurves();
    });
    probe("SplitCurve2dContinuity", "ShapeUpgrade_SplitCurve2dContinuity Init+Perform", [&] {
        Handle(ShapeUpgrade_SplitCurve2dContinuity) s = new ShapeUpgrade_SplitCurve2dContinuity();
        s->Init(nc2); s->SetCriterion(GeomAbs_C1); s->SetTolerance(1e-3); s->Perform(true);
        (void)s->GetCurves();
    });
    probe("ConvertCurve2dToBezier", "ShapeUpgrade_ConvertCurve2dToBezier Init+Perform", [&] {
        Handle(ShapeUpgrade_ConvertCurve2dToBezier) c = new ShapeUpgrade_ConvertCurve2dToBezier();
        c->Init(nc2); c->Perform(true); (void)c->GetCurves();
    });
    probe("SplitSurfaceContinuity", "ShapeUpgrade_SplitSurfaceContinuity Init+Perform", [&] {
        Handle(ShapeUpgrade_SplitSurfaceContinuity) s = new ShapeUpgrade_SplitSurfaceContinuity();
        s->Init(ns); s->SetCriterion(GeomAbs_C1); s->SetTolerance(1e-3); s->Perform(true);
        (void)s->USplitValues();
    });
    probe("SplitSurfaceAngle", "ShapeUpgrade_SplitSurfaceAngle Init+Perform", [&] {
        Handle(ShapeUpgrade_SplitSurfaceAngle) s = new ShapeUpgrade_SplitSurfaceAngle(1.57);
        s->Init(ns); s->Perform(true); (void)s->USplitValues();
    });
    probe("SplitSurfaceArea", "ShapeUpgrade_SplitSurfaceArea Init+Perform", [&] {
        Handle(ShapeUpgrade_SplitSurfaceArea) s = new ShapeUpgrade_SplitSurfaceArea();
        s->SetNumbersUVSplits(2, 2); s->Init(ns); s->Perform(true); (void)s->USplitValues();
    });
    probe("Extrema* / ProjLib*", "GeomAdaptor_Surface ctor", [&] {
        Handle(GeomAdaptor_Surface) a = new GeomAdaptor_Surface(ns); (void)a;
    });
    probe("ExtremaExtCC etc", "GeomAdaptor_Curve(c, first, last)", [&] {
        Handle(GeomAdaptor_Curve) a = new GeomAdaptor_Curve(nc, 0, 1); (void)a;
    });
    probe("GeomToolsCurveSetWrite", "GeomTools_CurveSet::Add + Write", [&] {
        GeomTools_CurveSet cs; cs.Add(nc); std::ostringstream o; cs.Write(o);
    });
    probe("GeomToolsCurve2dSetWrite", "GeomTools_Curve2dSet::Add + Write", [&] {
        GeomTools_Curve2dSet cs; cs.Add(nc2); std::ostringstream o; cs.Write(o);
    });
    probe("GeomToolsSurfaceSetWrite", "GeomTools_SurfaceSet::Add + Write", [&] {
        GeomTools_SurfaceSet ss; ss.Add(ns); std::ostringstream o; ss.Write(o);
    });
    probe("GeomFillNSections", "GeomFill_NSections + ComputeSurface", [&] {
        NCollection_Sequence<occ::handle<Geom_Curve>> sec;
        NCollection_Sequence<double> par;
        sec.Append(nc); par.Append(0.0);
        sec.Append(nc); par.Append(1.0);
        Handle(GeomFill_NSections) n = new GeomFill_NSections(sec, par);
        n->ComputeSurface(); (void)n->BSplineSurface();
    });
    probe("GeomFillNSectionsInfo", "GeomFill_NSections + SectionShape", [&] {
        NCollection_Sequence<occ::handle<Geom_Curve>> sec;
        NCollection_Sequence<double> par;
        sec.Append(nc); par.Append(0.0);
        sec.Append(nc); par.Append(1.0);
        Handle(GeomFill_NSections) n = new GeomFill_NSections(sec, par);
        int a = 0, b = 0, c = 0; n->SectionShape(a, b, c);
    });
    probe("GeomLibIsPlanarSurface", "GeomLib_IsPlanarSurface ctor", [&] {
        GeomLib_IsPlanarSurface p(ns, 1e-7); (void)p.IsPlanar();
    });
    probe("GeomConvertIsCanonical", "GeomConvert_SurfToAnaSurf::IsCanonical", [&] {
        (void)GeomConvert_SurfToAnaSurf::IsCanonical(ns);
    });
    probe("Geom2dConvertApproxArcs", "Geom2dConvert_ApproxArcsSegments", [&] {
        Geom2dAdaptor_Curve a(nc2);
        Geom2dConvert_ApproxArcsSegments x(a, 1e-3, 1e-3); (void)x.GetResult();
    });

    printf("\n%d uncatchable signal(s), %d catchable exception(s), %d returned normally.\n",
           uncatchable, catchable, benign);
    printf("Only the uncatchable ones were reachable crashes before the #556 guards; the rest were\n"
           "already absorbed by each function's own catch (...).\n");
    return 0;
}
