// #1979 kernel parity for AHTBezierCurve2DTests, AnaFilletTests, ApproxArcsSegmentsTests,
// ApproxCurve2DTests and AxisPlacement2DTests: the same OCCT calls, with the same inputs, that
// the bridge functions those tests reach make.
#include <Geom2dEval_AHTBezierCurve.hxx>
#include <ChFi2d_AnaFilletAlgo.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopoDS_Vertex.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <Approx_Curve2d.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <gp_Pln.hxx>
#include <cstdio>
#include <cmath>

static double edgeLength(const TopoDS_Edge& e)
{
  BRepAdaptor_Curve c(e);
  return GCPnts_AbscissaPoint::Length(c);
}

static void vtx(const char* tag, const TopoDS_Edge& e)
{
  gp_Pnt a = BRep_Tool::Pnt(TopExp::FirstVertex(e, true));
  gp_Pnt b = BRep_Tool::Pnt(TopExp::LastVertex(e, true));
  printf("%s first=(%.12g, %.12g, %.12g) last=(%.12g, %.12g, %.12g) length=%.12g\n", tag, a.X(),
         a.Y(), a.Z(), b.X(), b.Y(), b.Z(), edgeLength(e));
}

static void dump(const char* tag, const NCollection_Sequence<Handle(Geom2d_Curve)>& r)
{
  printf("%s count=%d\n", tag, r.Length());
  for (int i = 1; i <= r.Length(); i++)
  {
    gp_Pnt2d a = r(i)->Value(r(i)->FirstParameter()), b = r(i)->Value(r(i)->LastParameter());
    printf("  [%d] %s (%.12g, %.12g)->(%.12g, %.12g)\n", i, r(i)->DynamicType()->Name(), a.X(),
           a.Y(), b.X(), b.Y());
  }
}

int main()
{
  // AHTBezierCurve2DTests.createAndEval (OCCTGeom2dEvalAHTBezierCurveCreate)
  {
    NCollection_Array1<gp_Pnt2d> pts(1, 5);
    for (int i = 0; i < 5; i++)
      pts(i + 1) = gp_Pnt2d(i, 0.5 * sin(double(i + 1)));
    Handle(Geom2dEval_AHTBezierCurve) c = new Geom2dEval_AHTBezierCurve(pts, 0, 1.0, 1.0);
    printf("AHT domain=[%.12g, %.12g]\n", c->FirstParameter(), c->LastParameter());
    for (double u : {c->FirstParameter(), 0.5 * (c->FirstParameter() + c->LastParameter()),
                     c->LastParameter()})
    {
      gp_Pnt2d p = c->Value(u);
      printf("AHT value(%.12g)=(%.12g, %.12g)\n", u, p.X(), p.Y());
    }
  }
  // AnaFilletTests.anaFillet (OCCTChFi2dAnaFillet)
  {
    TopoDS_Edge          e1 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge          e2 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0));
    gp_Pln               pl(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    ChFi2d_AnaFilletAlgo algo(e1, e2, pl);
    bool                 ok = algo.Perform(2.0);
    printf("AnaFillet perform=%d\n", ok);
    TopoDS_Edge       r1, r2;
    TopoDS_Edge       f = algo.Result(r1, r2);
    BRepAdaptor_Curve fc(f);
    printf("AnaFillet fillet type=%d (GeomAbs_Circle=%d)\n", (int)fc.GetType(), (int)GeomAbs_Circle);
    if (fc.GetType() == GeomAbs_Circle)
    {
      gp_Circ ci = fc.Circle();
      printf("AnaFillet fillet center=(%.12g, %.12g, %.12g) radius=%.12g\n", ci.Location().X(),
             ci.Location().Y(), ci.Location().Z(), ci.Radius());
    }
    vtx("AnaFillet fillet", f);
    vtx("AnaFillet edge1", r1);
    vtx("AnaFillet edge2", r2);
  }
  // ApproxArcsSegmentsTests (OCCTGeom2dConvertApproxArcsSegments)
  {
    Handle(Geom2d_Circle)       ci = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Handle(Geom2d_TrimmedCurve) tc = new Geom2d_TrimmedCurve(ci, 0, M_PI);
    Geom2dAdaptor_Curve         ad(tc);
    Geom2dConvert_ApproxArcsSegments ap(ad, 0.1, 0.1);
    dump("ApproxArcs circle", ap.GetResult());
    Handle(Geom2d_Line)              li = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_TrimmedCurve)      tl = new Geom2d_TrimmedCurve(li, 0, 10);
    Geom2dAdaptor_Curve              adl(tl);
    Geom2dConvert_ApproxArcsSegments apl(adl, 0.1, 0.1);
    dump("ApproxArcs line", apl.GetResult());
  }
  // ApproxCurve2DTests.approxCircle (OCCTApproxCurve2d)
  {
    Handle(Geom2d_Circle)     ci = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10);
    Handle(Adaptor2d_Curve2d) ad = new Geom2dAdaptor_Curve(ci, 0, 2 * M_PI);
    Approx_Curve2d            ap(ad, 0, 2 * M_PI, 1e-6, 1e-6, GeomAbs_C2, 8, 100);
    printf("ApproxCurve2d done=%d result=%d maxErr2dU=%.3g maxErr2dV=%.3g\n", ap.IsDone(),
           ap.HasResult(), ap.MaxError2dU(), ap.MaxError2dV());
    Handle(Geom2d_BSplineCurve) b = ap.Curve();
    printf("ApproxCurve2d domain=[%.12g, %.12g] degree=%d poles=%d\n", b->FirstParameter(),
           b->LastParameter(), b->Degree(), b->NbPoles());
    for (double u : {0.0, M_PI / 3, M_PI})
    {
      gp_Pnt2d p = b->Value(u);
      printf("ApproxCurve2d value(%.12g)=(%.12g, %.12g) radius=%.12g\n", u, p.X(), p.Y(),
             std::hypot(p.X(), p.Y()));
    }
  }
  // AxisPlacement2DTests (OCCTAxisPlacement2DCreate/Reversed/Angle)
  {
    Handle(Geom2d_AxisPlacement) a = new Geom2d_AxisPlacement(gp_Pnt2d(1, 2), gp_Dir2d(0, 1));
    printf("Axis create origin=(%.12g, %.12g) dir=(%.12g, %.12g)\n", a->Location().X(),
           a->Location().Y(), a->Direction().X(), a->Direction().Y());
    Handle(Geom2d_AxisPlacement) b = new Geom2d_AxisPlacement(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_AxisPlacement) r = Handle(Geom2d_AxisPlacement)::DownCast(b->Copy());
    r->Reverse();
    printf("Axis reversed origin=(%.12g, %.12g) dir=(%.12g, %.12g)\n", r->Location().X(),
           r->Location().Y(), r->Direction().X(), r->Direction().Y());
    Handle(Geom2d_AxisPlacement) c = new Geom2d_AxisPlacement(gp_Pnt2d(0, 0), gp_Dir2d(0, 1));
    printf("Axis angle=%.17g (pi/2=%.17g)\n", b->Angle(c), M_PI / 2);
  }
  return 0;
}
