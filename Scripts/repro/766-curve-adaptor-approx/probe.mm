// Epic #766 (#1978), kernel parity for Adaptor3dIsoCurveTests.swift,
// ApproxCurvilinearParameterTests.swift and ApproxSameParameterTests.swift.
// Same inputs as the Swift tests, straight to OCCT, mirroring the bridge:
//   OCCTAdaptor3dIsoCurveEval  -> Adaptor3d_IsoCurve on BRep_Tool::Surface, range clamped to 1e6
//   OCCTAdaptor3dIsoCurveEdge  -> Geom_Surface::UIso/VIso + BRepBuilderAPI_MakeEdge(c, p1, p2)
//   OCCTApproxCurvilinearParameter -> Approx_CurvilinearParameter(BRepAdaptor_Curve, tol, C1, 8, 50)
//   OCCTApproxSameParameter    -> Approx_SameParameter(c3d, c2d, surf, 1e-6)
#include <Adaptor3d_IsoCurve.hxx>
#include <Approx_CurvilinearParameter.hxx>
#include <Approx_SameParameter.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakePlane.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Surface.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void isoEval(const TopoDS_Face& face, int isoType, double param, int n)
{
  Handle(Geom_Surface)        s  = BRep_Tool::Surface(face);
  Handle(GeomAdaptor_Surface) sa = new GeomAdaptor_Surface(s);
  Adaptor3d_IsoCurve          iso(sa, isoType == 0 ? GeomAbs_IsoU : GeomAbs_IsoV, param);
  double                      f = iso.FirstParameter(), l = iso.LastParameter();
  printf("  iso range raw [%.17g, %.17g]\n", f, l);
  if (f < -1e6)
    f = -1e6;
  if (l > 1e6)
    l = 1e6;
  for (int i = 0; i < n; i++)
  {
    double t = f + (l - f) * i / (n > 1 ? n - 1 : 1);
    gp_Pnt p;
    iso.D0(t, p);
    printf("  pt[%d] t=%.17g (%.17g, %.17g, %.17g)\n", i, t, p.X(), p.Y(), p.Z());
  }
}

static void isoEdge(const TopoDS_Face& face, int isoType, double param, double p1, double p2)
{
  Handle(Geom_Surface) s = BRep_Tool::Surface(face);
  Handle(Geom_Curve)   c = isoType == 0 ? s->UIso(param) : s->VIso(param);
  BRepBuilderAPI_MakeEdge me(c, p1, p2);
  printf("  done=%d\n", me.IsDone());
  if (!me.IsDone())
    return;
  BRepAdaptor_Curve a(me.Edge());
  gp_Pnt            a0 = a.Value(a.FirstParameter()), a1 = a.Value(a.LastParameter());
  printf("  type=%d range=[%.17g, %.17g] length=%.17g\n", (int)a.GetType(), a.FirstParameter(),
         a.LastParameter(), GCPnts_AbscissaPoint::Length(a));
  printf("  start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n", a0.X(), a0.Y(), a0.Z(),
         a1.X(), a1.Y(), a1.Z());
}

int main()
{
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(10, 20).Shape();
  TopoDS_Face  lateral;
  int          k = 0;
  for (TopExp_Explorer ex(cyl, TopAbs_FACE); ex.More(); ex.Next(), k++)
  {
    BRepAdaptor_Surface sa(TopoDS::Face(ex.Current()));
    printf("cylinder face %d: adaptor type %d\n", k, (int)sa.GetType());
    if (sa.GetType() == GeomAbs_Cylinder && lateral.IsNull())
      lateral = TopoDS::Face(ex.Current());
  }

  printf("uIsoOnCylinder: lateral face, u=0, count=5\n");
  isoEval(lateral, 0, 0.0, 5);
  printf("vIsoOnCylinder: lateral face, v=10, count=10\n");
  isoEval(lateral, 1, 10.0, 10);
  printf("uIsoCurveEdge: lateral face, u=0, v in [0, 10]\n");
  isoEdge(lateral, 0, 0.0, 0.0, 10.0);
  printf("vIsoCurveEdge: lateral face, v=10, u in [0, pi]\n");
  isoEdge(lateral, 1, 10.0, 0.0, M_PI);

  // Curvilinear parameter: every edge of the r=10 h=5 cylinder, first one Approx accepts.
  TopoDS_Shape cyl5 = BRepPrimAPI_MakeCylinder(10, 5).Shape();
  k                 = 0;
  for (TopExp_Explorer ex(cyl5, TopAbs_EDGE); ex.More(); ex.Next(), k++)
  {
    TopoDS_Edge               e  = TopoDS::Edge(ex.Current());
    Handle(BRepAdaptor_Curve) ad = new BRepAdaptor_Curve(e);
    printf("curvilinearCircle: edge %d type=%d range=[%.17g, %.17g] length=%.17g\n", k,
           (int)ad->GetType(), ad->FirstParameter(), ad->LastParameter(),
           GCPnts_AbscissaPoint::Length(*ad));
    try
    {
      Approx_CurvilinearParameter ap(ad, 1e-3, GeomAbs_C1, 8, 50);
      printf("  done=%d hasResult=%d maxError3d=%.6g\n", ap.IsDone(), ap.HasResult(),
             ap.IsDone() ? ap.MaxError3d() : -1.0);
      if (ap.IsDone() && ap.HasResult())
      {
        Handle(Geom_BSplineCurve) bs = ap.Curve3d();
        printf("  bspline range=[%.17g, %.17g] degree=%d poles=%d\n", bs->FirstParameter(),
               bs->LastParameter(), bs->Degree(), bs->NbPoles());
        BRepAdaptor_Curve r(BRepBuilderAPI_MakeEdge(bs).Edge());
        printf("  result edge type=%d length=%.17g\n", (int)r.GetType(),
               GCPnts_AbscissaPoint::Length(r));
        // arc length from the start to the parameter halfway through the range
        double half = (bs->FirstParameter() + bs->LastParameter()) / 2;
        printf("  length [first, mid-parameter]=%.17g\n",
               GCPnts_AbscissaPoint::Length(r, r.FirstParameter(), half));
      }
    }
    catch (Standard_Failure& f)
    {
      printf("  threw %s\n", f.GetMessageString());
    }
  }

  printf("sameParamLinePlane\n");
  Handle(Geom_Line)   l3 = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom2d_Line) l2 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Handle(Geom_Plane)  pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  Approx_SameParameter sp(l3, l2, pl, 1e-6);
  printf("  done=%d isSame=%d tolReached=%.17g\n", sp.IsDone(), sp.IsSameParameter(),
         sp.TolReached());
  // A 2D line running the other way along the same trace: not same-parameter.
  Handle(Geom2d_Line)  l2r = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(-1, 0));
  Approx_SameParameter sr(l3, l2r, pl, 1e-6);
  printf("  reversed 2D line: done=%d isSame=%d tolReached=%.17g\n", sr.IsDone(),
         sr.IsSameParameter(), sr.TolReached());
  return 0;
}
