// Epic #766 (#1978), evidence correction pass for OCCTCurveTests: the kernel side of the 11
// records whose bridge_output and kernel_output carried different types, in the same keys the
// corrected records use, plus the kernel-absence check behind the one N/A record whose bridge
// function is a stub (OCCTBRepGraphSetEdgeRegularity).
//
// Each line is `EVID <record> key=value ...`. Inputs are the ones the Swift tests use:
//   38 Approx_SameParameter, Geom_Line / Geom2d_Line / Geom_Plane through the origin, tol 1e-6
//   39 Geom_BSplineCurve poles (0,0,0) (3,5,0) (7,5,0) (10,0,0), knots {0,1} mult {4,4}, degree 3
//   40 Geom_BezierCurve poles (0,0,0) (1,2,0) (2,0,0), non-rational
//   41 Geom_BezierCurve poles (0,0,0) (3,5,0) (7,5,0) (10,0,0), SetWeight(2, 2.0)
//   42/43 BiTgte_CurveOnEdge on edges of the centred 10 box (Shape.box centres it)
//   44 BRepAdaptor_Curve2d(edge[0], face[0]) on the centred 10 x 20 x 30 box
//   45..48 GeomAPI_PointsToBSpline(24-point helix, 3, 8, C2, tol3D): what OCCTBSplineApproxInterp
//          forwards; the bridge setters have no kernel counterpart, so the kernel side is the
//          same call repeated with only the arguments the bridge forwards.
#include <Approx_SameParameter.hxx>
#include <BRepAdaptor_Curve2d.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BiTgte_CurveOnEdge.hxx>
#include <GC_MakePlane.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <NCollection_Array1.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <algorithm>
#include <cmath>
#include <cstdio>

static Handle(Geom_BSplineCurve) helixFit(double tol)
{
  TColgp_Array1OfPnt a(1, 24);
  for (int i = 0; i < 24; i++)
  {
    double t = i / 23.0 * 2.0 * M_PI;
    a(i + 1) = gp_Pnt(std::cos(t), std::sin(t), 0.1 * t);
  }
  return GeomAPI_PointsToBSpline(a, 3, 8, GeomAbs_C2, tol).Curve();
}

static double maxDev(const Handle(Geom_BSplineCurve)& a, const Handle(Geom_BSplineCurve)& b)
{
  double m = 0;
  for (int i = 0; i <= 32; i++)
  {
    double ua = a->FirstParameter() + (a->LastParameter() - a->FirstParameter()) * i / 32.0;
    double ub = b->FirstParameter() + (b->LastParameter() - b->FirstParameter()) * i / 32.0;
    m = std::max(m, a->Value(ua).Distance(b->Value(ub)));
  }
  return m;
}

int main()
{
  {
    Handle(Geom_Line)   l3 = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    Handle(Geom2d_Line) l2 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom_Plane)  pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
    Approx_SameParameter sp(l3, l2, pl, 1e-6);
    printf("EVID 38 done=%d is_same_parameter=%d (TolReached %.6g, not asserted)\n", sp.IsDone(),
           sp.IsSameParameter(), sp.TolReached());
  }
  {
    NCollection_Array1<gp_Pnt> p(1, 4);
    p(1) = gp_Pnt(0, 0, 0); p(2) = gp_Pnt(3, 5, 0); p(3) = gp_Pnt(7, 5, 0); p(4) = gp_Pnt(10, 0, 0);
    NCollection_Array1<double> k(1, 2);
    k(1) = 0; k(2) = 1;
    NCollection_Array1<int> m(1, 2);
    m(1) = 4; m(2) = 4;
    Handle(Geom_BSplineCurve) c = new Geom_BSplineCurve(p, k, m, 3);
    int succeeded = 1;
    try
    {
      c->SetOrigin(1);
    }
    catch (Standard_Failure& f)
    {
      succeeded = 0;
      printf("  (SetOrigin(1) threw: %s)\n", f.what());
    }
    printf("EVID 39 periodic=%d succeeded=%d\n", c->IsPeriodic(), succeeded);
  }
  {
    NCollection_Array1<gp_Pnt> p(1, 3);
    p(1) = gp_Pnt(0, 0, 0); p(2) = gp_Pnt(1, 2, 0); p(3) = gp_Pnt(2, 0, 0);
    Handle(Geom_BezierCurve) c = new Geom_BezierCurve(p);
    printf("EVID 40 rational=%d weights_present=%d\n", c->IsRational(), c->Weights() != nullptr);
  }
  {
    NCollection_Array1<gp_Pnt> p(1, 4);
    p(1) = gp_Pnt(0, 0, 0); p(2) = gp_Pnt(3, 5, 0); p(3) = gp_Pnt(7, 5, 0); p(4) = gp_Pnt(10, 0, 0);
    Handle(Geom_BezierCurve) c = new Geom_BezierCurve(p);
    c->SetWeight(2, 2.0);
    const NCollection_Array1<double>* w = c->Weights();
    printf("EVID 41 rational=%d weights=", c->IsRational());
    for (int i = w->Lower(); i <= w->Upper(); i++)
      printf("%s%g", i == w->Lower() ? "" : ",", (*w)(i));
    printf("\n");
  }
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape em;
    TopExp::MapShapes(box, TopAbs_EDGE, em);
    BiTgte_CurveOnEdge adj(TopoDS::Edge(em(1)), TopoDS::Edge(em(2)));
    double             f = adj.FirstParameter(), l = adj.LastParameter(), mid = (f + l) / 2;
    gp_Pnt             p;
    adj.D0(mid, p);
    printf("EVID 42 domain=[%g, %g] mid=%g point_at_mid=(%g, %g, %g)\n", f, l, mid, p.X(), p.Y(), p.Z());
    BiTgte_CurveOnEdge same(TopoDS::Edge(em(1)), TopoDS::Edge(em(1)));
    gp_Pnt             q;
    same.D0(5.0, q);
    printf("EVID 43 domain=[%g, %g] point_at_5=(%g, %g, %g)\n", same.FirstParameter(), same.LastParameter(),
           q.X(), q.Y(), q.Z());
  }
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    TopTools_IndexedMapOfShape em, fm;
    TopExp::MapShapes(box, TopAbs_EDGE, em);
    TopExp::MapShapes(box, TopAbs_FACE, fm);
    BRepAdaptor_Curve2d pc(TopoDS::Edge(em(1)), TopoDS::Face(fm(1)));
    printf("EVID 44 first=%g last=%g\n", pc.FirstParameter(), pc.LastParameter());
  }
  {
    // 45: tuning setters, 46: interpolatePoint, 47: performOptimal, 48: tolerance setters. In every
    // case the bridge forwards only (points, 3, 8, C2, tol3D); tol3D defaults to 1e-3.
    Handle(Geom_BSplineCurve) plain = helixFit(1e-3), again = helixFit(1e-3);
    printf("EVID 45 max_deviation=%.17g\n", maxDev(plain, again));
    printf("EVID 46 max_deviation=%.17g\n", maxDev(plain, again));
    Handle(Geom_BSplineCurve) o1 = helixFit(1e-3), o2 = helixFit(1e-3);
    printf("EVID 47 max_deviation=%.17g\n", std::max(maxDev(plain, o1), maxDev(o1, o2)));
    // 48: both setter orders leave tol3D = min(...) = 1e-8, so both reach the same kernel call.
    Handle(Geom_BSplineCurve) t1 = helixFit(1e-8), t2 = helixFit(1e-8), t3 = helixFit(1e-8);
    printf("EVID 48 max_deviation=%.17g\n", std::max(maxDev(t1, t2), maxDev(t1, t3)));
    // Control: the tolerance the bridge does forward genuinely moves the fit.
    printf("control tol3D 1e-1 vs 1e-8 max_deviation=%.17g\n", maxDev(helixFit(1e-1), helixFit(1e-8)));
  }
  // Record 57: BRepGraph_LayerRegularity in the pinned kernel headers.
#if __has_include(<BRepGraph_LayerRegularity.hxx>)
  printf("EVID 57 BRepGraph_LayerRegularity.hxx present=1\n");
#else
  printf("EVID 57 BRepGraph_LayerRegularity.hxx present=0\n");
#endif
  return 0;
}
