// #1979 kernel parity for GeomToolsCurve2dSetTests, IntAna2dTests, IntToolsFClass2dTests,
// InterpolationExpansion2DTests and Issue1020Extrema2dBoundsTests: the same OCCT calls, with the
// same inputs, that OCCTGeomToolsCurve2dSetWrite/Read, OCCTIntAna2d*, OCCTIntToolsFClass2dIsHole,
// OCCTCurve2DInterpolateWithTangents / OCCTCurve2DInterpolate and OCCTExtremaExtPElC2dLin make.
#include <GeomTools_Curve2dSet.hxx>
#include <GCE2d_MakeLine.hxx>
#include <gce_MakeCirc2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <IntAna2d_Conic.hxx>
#include <IntTools_FClass2d.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Geom_Plane.hxx>
#include <TopoDS.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <Extrema_ExtPElC2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Circ2d.hxx>
#include <sstream>
#include <cstdio>

static void pts(const char* tag, IntAna2d_AnaIntersection& in)
{
  printf("%s: done=%d n=%d", tag, in.IsDone(), in.NbPoints());
  for (int i = 1; i <= in.NbPoints(); i++)
    printf(" (%.12g, %.12g)", in.Point(i).Value().X(), in.Point(i).Value().Y());
  printf("\n");
}

int main()
{
  {
    GeomTools_Curve2dSet cs;
    Handle(Geom2d_Line)   l = GCE2d_MakeLine(gp_Pnt2d(0, 0), gp_Pnt2d(1, 0)).Value();
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gce_MakeCirc2d(gp_Pnt2d(0, 0), 3.0).Value());
    printf("Curve2dSet Add line=%d circle=%d line-again=%d\n", cs.Add(l), cs.Add(c), cs.Add(l));
    std::ostringstream os;
    cs.Write(os);
    std::istringstream   is(os.str());
    GeomTools_Curve2dSet rd;
    rd.Read(is);
    printf("  round trip: curve2d(3) null=%d circle radius=%.12g\n", rd.Curve2d(3).IsNull(),
           Handle(Geom2d_Circle)::DownCast(rd.Curve2d(2))->Radius());
  }
  {
    IntAna2d_AnaIntersection a(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 1)), gp_Lin2d(gp_Pnt2d(10, 0), gp_Dir2d(-1, 1)));
    pts("lin-lin", a);
    IntAna2d_AnaIntersection b(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)),
                               IntAna2d_Conic(gp_Circ2d(gp_Ax2d(gp_Pnt2d(5, 3), gp_Dir2d(1, 0)), 5)));
    pts("lin-circ", b);
    IntAna2d_AnaIntersection c(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5),
                               gp_Circ2d(gp_Ax2d(gp_Pnt2d(7, 0), gp_Dir2d(1, 0)), 5));
    pts("circ-circ", c);
  }
  {
    Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    TopoDS_Face        f  = BRepBuilderAPI_MakeFace(pl, 0, 10, 0, 10, 1e-7);
    IntTools_FClass2d  fc(f, 1e-7);
    printf("plane face [0,10]^2 IsHole=%d\n", fc.IsHole());
  }
  {
    Handle(TColgp_HArray1OfPnt2d) p = new TColgp_HArray1OfPnt2d(1, 3);
    p->SetValue(1, gp_Pnt2d(0, 0));
    p->SetValue(2, gp_Pnt2d(5, 5));
    p->SetValue(3, gp_Pnt2d(10, 0));
    Geom2dAPI_Interpolate in(p, false, 1e-6);
    in.Load(gp_Vec2d(1, 1), gp_Vec2d(1, -1));
    in.Perform();
    printf("tangent interpolation: poles=%d value(2)=(%.12g, %.12g)\n", in.Curve()->NbPoles(), in.Curve()->Value(2).X(),
           in.Curve()->Value(2).Y());
    Handle(TColgp_HArray1OfPnt2d) q = new TColgp_HArray1OfPnt2d(1, 4);
    q->SetValue(1, gp_Pnt2d(0, 0));
    q->SetValue(2, gp_Pnt2d(10, 0));
    q->SetValue(3, gp_Pnt2d(10, 10));
    q->SetValue(4, gp_Pnt2d(0, 10));
    Geom2dAPI_Interpolate pin(q, true, 1e-6);
    pin.Perform();
    printf("periodic square: periodic=%d domain=[%.12g, %.12g] value(20)=(%.12g, %.12g)\n", pin.Curve()->IsPeriodic(),
           pin.Curve()->FirstParameter(), pin.Curve()->LastParameter(), pin.Curve()->Value(20).X(),
           pin.Curve()->Value(20).Y());
  }
  for (double x : {2e10, 4.0})
  {
    Extrema_ExtPElC2d e(gp_Pnt2d(x, 3), gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 1e-9, RealFirst(), RealLast());
    printf("ExtPElC2d (%g, 3) to x-axis: n=%d param=%.12g sqdist=%.12g\n", x, e.NbExt(), e.Point(1).Parameter(),
           e.SquareDistance(1));
  }
  return 0;
}
