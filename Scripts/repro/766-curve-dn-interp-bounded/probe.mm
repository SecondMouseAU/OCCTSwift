// Epic #766 (#1978), kernel parity for CurveDNTests.swift, CurveInterpolationTests.swift and
// CurveIsBoundedTests.swift. Same inputs as the tests: Geom_Curve/Geom2d_Curve/Geom_Surface::DN,
// GeomAPI_Interpolate into a one-edge wire read back through BRepAdaptor_CompCurve (as
// OCCTWireInterpolate, OCCTWireGetLength, OCCTWireGetPointAt and OCCTWireGetCurveInfo do), and
// Geom_BoundedCurve / Geom2d_BoundedCurve down-casts.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BoundedCurve.hxx>
#include <Geom2d_BoundedCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_SphericalSurface.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>
#include <vector>

static void wire(const char* name, const std::vector<gp_Pnt>& p, bool closed, bool tan, gp_Vec t0 = gp_Vec(), gp_Vec t1 = gp_Vec())
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)p.size());
  for (size_t i = 0; i < p.size(); i++)
    a->SetValue((int)i + 1, p[i]);
  GeomAPI_Interpolate ip(a, closed, 1e-6);
  if (tan)
    ip.Load(t0, t1);
  ip.Perform();
  TopoDS_Wire           w = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(ip.Curve()));
  BRepAdaptor_CompCurve c(w);
  double                f = c.FirstParameter(), l = c.LastParameter();
  gp_Pnt                m = c.Value(f + 0.5 * (l - f));
  printf("%s: closed=%d length=%.17g value(0.5)=(%.17g, %.17g, %.17g)\n", name, c.IsClosed(),
         GCPnts_AbscissaPoint::Length(c), m.X(), m.Y(), m.Z());
}

int main()
{
  Handle(Geom_Line) l = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  gp_Vec            d1 = l->DN(0, 1), d2 = l->DN(0, 2);
  printf("line DN(0,1)=(%g, %g, %g) DN(0,2)=(%g, %g, %g)\n", d1.X(), d1.Y(), d1.Z(), d2.X(), d2.Y(), d2.Z());
  Handle(Geom2d_Line) l2 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
  gp_Vec2d            e1 = l2->DN(0, 1);
  printf("2D line (1,1) DN(0,1)=(%.17g, %.17g)\n", e1.X(), e1.Y());
  Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  gp_Vec du = s->DN(0, M_PI / 4, 1, 0);
  printf("sphere r=5 DN(0, pi/4, 1, 0)=(%.17g, %.17g, %.17g)\n", du.X(), du.Y(), du.Z());

  wire("2 points (0,0,0) (10,10,0)", {gp_Pnt(0, 0, 0), gp_Pnt(10, 10, 0)}, false, false);
  wire("5 points zigzag", {gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, 0, 0), gp_Pnt(30, 5, 0), gp_Pnt(40, 0, 0)}, false, false);
  wire("closed 4 points r=10", {gp_Pnt(10, 0, 0), gp_Pnt(0, 10, 0), gp_Pnt(-10, 0, 0), gp_Pnt(0, -10, 0)}, true, false);
  wire("2 points with tangents (1,1,0) (1,-1,0)", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)}, false, true, gp_Vec(1, 1, 0), gp_Vec(1, -1, 0));
  wire("5 points 3D", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 5), gp_Pnt(20, 0, 10), gp_Pnt(30, 0, 5), gp_Pnt(40, 0, 0)}, false, false);

  TColgp_Array1OfPnt fp(1, 3);
  fp(1) = gp_Pnt(0, 0, 0);
  fp(2) = gp_Pnt(1, 1, 0);
  fp(3) = gp_Pnt(2, 0, 0);
  Handle(Geom_Curve) fit = GeomAPI_PointsToBSpline(fp, 3, 8, GeomAbs_C2, 1e-3).Curve();
  printf("bounded: Geom_Line=%d fitted BSpline=%d\n", !Handle(Geom_BoundedCurve)::DownCast(Handle(Geom_Curve)(l)).IsNull(),
         !Handle(Geom_BoundedCurve)::DownCast(fit).IsNull());
  TColgp_Array1OfPnt2d fp2(1, 3);
  fp2(1) = gp_Pnt2d(0, 0);
  fp2(2) = gp_Pnt2d(1, 1);
  fp2(3) = gp_Pnt2d(2, 0);
  Handle(Geom2d_Curve) fit2 = Geom2dAPI_PointsToBSpline(fp2).Curve();
  printf("bounded 2D: Geom2d_Line=%d fitted BSpline=%d\n",
         !Handle(Geom2d_BoundedCurve)::DownCast(Handle(Geom2d_Curve)(l2)).IsNull(),
         !Handle(Geom2d_BoundedCurve)::DownCast(fit2).IsNull());
  return 0;
}
