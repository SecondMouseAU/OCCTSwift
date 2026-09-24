// Epic #766 (#1978), kernel parity for CurveJoinTests.swift, CurveLengthTests.swift,
// CurvePlanarityTests.swift and CurveSplitConcatTests.swift. Same inputs as the tests, straight to
// the calls the bridge makes: GeomConvert_CompCurveToBSplineCurve, GCPnts_AbscissaPoint,
// GeomAPI_ProjectPointOnCurve, ShapeAnalysis_Curve::IsPlanar and
// GeomConvert::C0BSplineToArrayOfC1BSplineCurve (and the 2D equivalents).
#include <GC_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cstdio>
#include <vector>

static Handle(Geom_BSplineCurve) fit(std::vector<gp_Pnt> p)
{
  TColgp_Array1OfPnt a(1, (int)p.size());
  for (size_t i = 0; i < p.size(); i++)
    a((int)i + 1) = p[i];
  return GeomAPI_PointsToBSpline(a, 3, 8, GeomAbs_C2, 1e-3).Curve();
}

static void join(const char* name, std::vector<std::pair<gp_Pnt, gp_Pnt>> s)
{
  GeomConvert_CompCurveToBSplineCurve j(GC_MakeSegment(s[0].first, s[0].second).Value());
  for (size_t i = 1; i < s.size(); i++)
    j.Add(GC_MakeSegment(s[i].first, s[i].second).Value(), 1e-6);
  Handle(Geom_BSplineCurve) r = j.BSplineCurve();
  printf("%s: start=(%g, %g, %g) end=(%g, %g, %g) domain=[%.17g, %.17g]\n", name, r->StartPoint().X(),
         r->StartPoint().Y(), r->StartPoint().Z(), r->EndPoint().X(), r->EndPoint().Y(),
         r->EndPoint().Z(), r->FirstParameter(), r->LastParameter());
}

int main()
{
  join("join 2", {{gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(2, 1, 0)}});
  join("join 3", {{gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(2, 1, 0)}, {gp_Pnt(2, 1, 0), gp_Pnt(3, 1, 1)}});
  join("join 1", {{gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0)}});

  Handle(TColgp_HArray1OfPnt) p = new TColgp_HArray1OfPnt(1, 2);
  p->SetValue(1, gp_Pnt(0, 0, 0));
  p->SetValue(2, gp_Pnt(10, 0, 0));
  GeomAPI_Interpolate ip(p, false, 1e-6);
  ip.Load(gp_Vec(1, 0, 0), gp_Vec(1, 0, 0));
  ip.Perform();
  GeomAdaptor_Curve ia(ip.Curve());
  printf("3D interpolant with tangents (1,0,0): length=%.17g\n", GCPnts_AbscissaPoint::Length(ia));
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  printf("projection of (5,3,0) on X axis: parameter=%.17g\n",
         GeomAPI_ProjectPointOnCurve(gp_Pnt(5, 3, 0), line).LowerDistanceParameter());
  Handle(TColgp_HArray1OfPnt2d) p2 = new TColgp_HArray1OfPnt2d(1, 3);
  p2->SetValue(1, gp_Pnt2d(0, 0));
  p2->SetValue(2, gp_Pnt2d(5, 5));
  p2->SetValue(3, gp_Pnt2d(10, 0));
  Geom2dAPI_Interpolate ip2(p2, false, 1e-6);
  ip2.Load(gp_Vec2d(1, 1), gp_Vec2d(1, -1));
  ip2.Perform();
  Geom2dAdaptor_Curve ia2(ip2.Curve());
  printf("2D interpolant with tangents: length=%.17g\n", GCPnts_AbscissaPoint::Length(ia2));

  ShapeAnalysis_Curve sac;
  gp_XYZ              n;
  bool pc = sac.IsPlanar(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), n, 0);
  printf("circle IsPlanar=%d normal=(%g, %g, %g)\n", pc, n.X(), n.Y(), n.Z());
  gp_XYZ n2;
  bool ps = sac.IsPlanar(GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0)).Value(), n2, 0);
  printf("segment IsPlanar=%d normal=(%g, %g, %g)\n", ps, n2.X(), n2.Y(), n2.Z());

  auto f1 = fit({gp_Pnt(0, 0, 0), gp_Pnt(5, 5, 0), gp_Pnt(10, 0, 0)});
  Handle(NCollection_HArray1<Handle(Geom_BSplineCurve)>) arr;
  GeomConvert::C0BSplineToArrayOfC1BSplineCurve(f1, arr, 1e-6);
  printf("split fit (0,0)(5,5)(10,0): %d pieces\n", arr->Length());
  auto f2 = fit({gp_Pnt(10, 0, 0), gp_Pnt(15, -5, 0), gp_Pnt(20, 0, 0)});
  GeomConvert_CompCurveToBSplineCurve cc(f1);
  bool                                ok = cc.Add(f2, 1e-6);
  Handle(Geom_BSplineCurve)           r  = cc.BSplineCurve();
  printf("concatenate two fits: add=%d start=(%g, %g, %g) end=(%g, %g, %g)\n", ok, r->StartPoint().X(),
         r->StartPoint().Y(), r->StartPoint().Z(), r->EndPoint().X(), r->EndPoint().Y(), r->EndPoint().Z());
  TColgp_Array1OfPnt2d q(1, 3);
  q(1) = gp_Pnt2d(0, 0);
  q(2) = gp_Pnt2d(5, 5);
  q(3) = gp_Pnt2d(10, 0);
  Handle(Geom2d_BSplineCurve) g2 = Geom2dAPI_PointsToBSpline(q).Curve();
  Handle(NCollection_HArray1<Handle(Geom2d_BSplineCurve)>) arr2;
  Geom2dConvert::C0BSplineToArrayOfC1BSplineCurve(g2, arr2, 1e-6);
  printf("split 2D fit: %d pieces\n", arr2->Length());
  return 0;
}
