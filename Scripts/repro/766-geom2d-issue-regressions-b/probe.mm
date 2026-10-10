// #1979 kernel parity for the Issue562..Issue999 Geom2d regression suites: the OCCT calls their
// bridge functions make, on the tests' own fixtures. Knot splitting, nearest-point projection,
// continuity, circle conversion, curve-curve extrema and self-intersection, gp_Ax2's basis,
// Convert parameterisations, IntTools_FClass2d, and Bisector_BisecPC trimming.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Bisector_BisecPC.hxx>
#include <Convert_CircleToBSplineCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAPI_ExtremaCurveCurve.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom_Plane.hxx>
#include <IntTools_FClass2d.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ2d.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static Handle(Geom2d_BSplineCurve) kinked(int degree, int interior)
{
  std::vector<double> k{0};
  std::vector<int>    m{degree + 1};
  for (int i = 1; i <= interior; i++)
  {
    k.push_back(i);
    m.push_back(degree);
  }
  k.push_back(interior + 1);
  m.push_back(degree + 1);
  int sum = 0;
  for (int v : m)
    sum += v;
  int                  n = sum - degree - 1;
  TColgp_Array1OfPnt2d p(1, n);
  for (int i = 0; i < n; i++)
    p.SetValue(i + 1, gp_Pnt2d(i, i % 3));
  TColStd_Array1OfReal    K(1, (int)k.size());
  TColStd_Array1OfInteger M(1, (int)m.size());
  for (size_t i = 0; i < k.size(); i++)
  {
    K.SetValue((int)i + 1, k[i]);
    M.SetValue((int)i + 1, m[i]);
  }
  return new Geom2d_BSplineCurve(p, K, M, degree);
}

static void project(const char* tag, const Handle(Geom2d_Curve)& c, gp_Pnt2d q)
{
  // What the #615 fix measures: the nearest of the interior extrema and the two end points.
  Geom2dAPI_ProjectPointOnCurve pr(q, c, c->FirstParameter(), c->LastParameter());
  double best = 1e300, bu = 0;
  for (int i = 1; i <= pr.NbPoints(); i++)
    if (pr.Distance(i) < best)
    {
      best = pr.Distance(i);
      bu   = pr.Parameter(i);
    }
  for (double u : {c->FirstParameter(), c->LastParameter()})
    if (!Precision::IsInfinite(u) && c->Value(u).Distance(q) < best)
    {
      best = c->Value(u).Distance(q);
      bu   = u;
    }
  printf("%s: interior extrema=%d nearest u=%.12g distance=%.15g\n", tag, pr.NbPoints(), bu, best);
}

int main()
{
  for (int splits : {302, 255, 256, 257})
  {
    Geom2dConvert_BSplineCurveKnotSplitting s(kinked(3, splits - 2), 1);
    printf("cubic, %d interior knots at multiplicity 3, split at C1: NbSplits=%d last=%d\n", splits - 2, s.NbSplits(),
           s.SplitValue(s.NbSplits()));
  }

  Handle(Geom2d_Circle)       c5  = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5));
  Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(c5, 0, M_PI);
  project("half circle from (0,-6)", arc, gp_Pnt2d(0, -6));
  project("half circle from (3,-4)", arc, gp_Pnt2d(3, -4));
  Handle(Geom2d_TrimmedCurve) seg = new Geom2d_TrimmedCurve(new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 3, 8);
  project("segment [3,8] from (100,0)", seg, gp_Pnt2d(100, 0));
  project("segment [3,8] from (0,0)", seg, gp_Pnt2d(0, 0));
  Geom2dAPI_ProjectPointOnCurve pre(gp_Pnt2d(0, -6), arc);
  printf("  pre-#615 (interior extrema only) from (0,-6): n=%d lower distance=%.12g at u=%.12g\n", pre.NbPoints(),
         pre.LowerDistance(), pre.LowerDistanceParameter());

  Handle(Geom2d_Circle) c20 = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(20, 0), gp_Dir2d(1, 0)), 5));
  Geom2dAPI_ExtremaCurveCurve ext(c5, c20, 0, 2 * M_PI, 0, 2 * M_PI);
  printf("ExtremaCurveCurve two r5 circles 20 apart: n=%d", ext.NbExtrema());
  for (int i = 1; i <= ext.NbExtrema(); i++)
    printf(" %.12g", ext.Distance(i));
  printf("\n");

  TColgp_Array1OfPnt2d bp(1, 4);
  bp.SetValue(1, gp_Pnt2d(0, 0));
  bp.SetValue(2, gp_Pnt2d(10, 10));
  bp.SetValue(3, gp_Pnt2d(-5, 10));
  bp.SetValue(4, gp_Pnt2d(5, 0));
  Geom2dAPI_InterCurveCurve self(new Geom2d_BezierCurve(bp), 1e-6);
  printf("looped Bezier self-intersections: n=%d", self.NbPoints());
  for (int i = 1; i <= self.NbPoints(); i++)
    printf(" (%.12g, %.12g)", self.Point(i).X(), self.Point(i).Y());
  printf("\n");
  Geom2dAPI_InterCurveCurve selfc(c5, 1e-6);
  printf("circle self-intersections: n=%d\n", selfc.NbPoints());

  const double d15 = 15.0 * M_PI / 180.0;
  gp_Ax2       ax(gp_Pnt(0, 0, 0), gp_Dir(sin(d15) * 0.6, sin(d15) * 0.8, cos(d15)));
  printf("gp_Ax2 basis for the 15-degree normal: X=(%.16g, %.16g, %.16g) Y=(%.16g, %.16g, %.16g)\n", ax.XDirection().X(),
         ax.XDirection().Y(), ax.XDirection().Z(), ax.YDirection().X(), ax.YDirection().Y(), ax.YDirection().Z());

  const char*                    names[] = {"TgtThetaOver2", "TgtThetaOver2_1", "TgtThetaOver2_2", "TgtThetaOver2_3",
                                            "TgtThetaOver2_4", "QuasiAngular", "RationalC1", "Polynomial"};
  Convert_ParameterisationType   types[] = {Convert_TgtThetaOver2, Convert_TgtThetaOver2_1, Convert_TgtThetaOver2_2,
                                            Convert_TgtThetaOver2_3, Convert_TgtThetaOver2_4, Convert_QuasiAngular,
                                            Convert_RationalC1, Convert_Polynomial};
  for (int i = 0; i < 8; i++)
  {
    try
    {
      Handle(Geom2d_BSplineCurve) b = Geom2dConvert::CurveToBSplineCurve(c5, types[i]);
      printf("CurveToBSplineCurve(circle r5, %s): degree=%d poles=%d\n", names[i], b->Degree(), b->NbPoles());
    }
    catch (Standard_Failure& e)
    {
      printf("CurveToBSplineCurve(circle r5, %s): throws %s\n", names[i], e.what());
    }
  }

  Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  TopoDS_Face        f  = BRepBuilderAPI_MakeFace(pl, 0, 10, 0, 10, 1e-7);
  for (double tol : {1e-6, 1e-7})
  {
    IntTools_FClass2d fc(f, tol);
    printf("IntTools_FClass2d tol %g: (-5e-7, 5)=%d (5,5)=%d (15,15)=%d  [IN=0 OUT=1 ON=2]\n", tol,
           (int)fc.Perform(gp_Pnt2d(-5e-7, 5)), (int)fc.Perform(gp_Pnt2d(5, 5)), (int)fc.Perform(gp_Pnt2d(15, 15)));
  }

  Handle(Geom2d_Line) xaxis = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  for (double md : {1.0, 10.0, 100.0, 500.0, 5000.0})
  {
    try
    {
      Bisector_BisecPC b;
      b.Perform(xaxis, gp_Pnt2d(0, 4), 1.0, md);
      printf("Bisector_BisecPC maxDistance %g: empty=%d span=%.12g\n", md, b.IsEmpty(),
             b.IsEmpty() ? 0.0 : b.LastParameter() - b.FirstParameter());
    }
    catch (Standard_Failure& e)
    {
      printf("Bisector_BisecPC maxDistance %g: throws %s\n", md, e.what());
    }
  }
  return 0;
}
