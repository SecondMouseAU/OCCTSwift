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

    printf("\n%d uncatchable signal(s), %d catchable exception(s), %d returned normally.\n",
           uncatchable, catchable, benign);
    printf("Only the uncatchable ones were reachable crashes before the #556 guards; the rest were\n"
           "already absorbed by each function's own catch (...).\n");
    return 0;
}
