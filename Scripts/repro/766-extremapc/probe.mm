// #766 kernel parity for Tests/OCCTAnalysisTests/ExtremaPCTests.swift (suites "ExtremaPC, Point
// to Curve Distance" and "Issue 1633: point-curve extrema include the domain's ends").
// Same OCCT calls as occtExtremaPCCurveImpl (OCCTBridge_Curve3D_Curves.mm) and
// OCCTExtremaPCMinDistance: ExtremaPC_Curve(curve) or ExtremaPC_Curve(curve, uMin, uMax),
// PerformWithEndpoints(p, 1e-9); the bridge reports sqrt(SquareDistance) per extremum and
// sqrt(MinSquareDistance()) for the minimum. Curves are built as the Curve3D factories build them.
#include <ExtremaPC.hxx>
#include <ExtremaPC_Curve.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomEval_CircularHelixCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cmath>
#include <cstdio>

static void all(const char* name, const ExtremaPC_Curve& ext, gp_Pnt q)
{
  if (!ext.IsInitialized())
  {
    printf("%s: NOT INITIALIZED\n", name);
    return;
  }
  const auto& r = ext.PerformWithEndpoints(q, 1e-9);
  printf("%s: query (%g, %g, %g) IsDone=%d NbExt=%d", name, q.X(), q.Y(), q.Z(),
         r.IsDone() ? 1 : 0, r.IsDone() ? (int)r.NbExt() : -1);
  if (r.IsDone() && r.NbExt() > 0)
    printf(" min distance=%.17g", std::sqrt(r.MinSquareDistance()));
  printf("\n");
  for (int i = 0; r.IsDone() && i < (int)r.NbExt(); ++i)
    printf("  [%d] u=%.17g distance=%.17g point=(%.17g, %.17g, %.17g)\n", i, r[i].Parameter,
           std::sqrt(r[i].SquareDistance), r[i].Point.X(), r[i].Point.Y(), r[i].Point.Z());
}

int main()
{
  Handle(Geom_Circle) c5  = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Handle(Geom_Circle) c10 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
  Handle(Geom_Line)   ln  = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom_TrimmedCurve) seg = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();

  // ExtremaPC, Point to Curve Distance
  all("pointToCircle", ExtremaPC_Curve(c5), gp_Pnt(10, 0, 0));
  all("pointToLine (bounded 0..100)", ExtremaPC_Curve(ln, 0, 100), gp_Pnt(5, 3, 0));
  all("minimumDistanceConvenience", ExtremaPC_Curve(c5), gp_Pnt(10, 0, 0));
  all("pointToCircleOppositeStart", ExtremaPC_Curve(c10), gp_Pnt(-10, 0, 0));
  Handle(Geom_Curve) helix =
    new GeomEval_CircularHelixCurve(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10);
  all("pointToHelix", ExtremaPC_Curve(helix), gp_Pnt(0, 0, 0));

  // Issue 1633
  all("segmentQueriedPastItsEnd", ExtremaPC_Curve(seg), gp_Pnt(20, 0, 0));
  all("segmentQueriedPastItsStart", ExtremaPC_Curve(seg), gp_Pnt(-4, 3, 0));
  all("interiorFootStillWinsAndIsStillReported", ExtremaPC_Curve(seg), gp_Pnt(5, 3, 0));
  Handle(Geom_TrimmedCurve) arc =
    GC_MakeArcOfCircle(gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(-5, 0, 0)).Value();
  all("arcEndBeatsTheInteriorMaximum", ExtremaPC_Curve(arc), gp_Pnt(0, -6, 0));
  all("fullCircleIsUnchanged", ExtremaPC_Curve(c5), gp_Pnt(0, 10, 0));
  all("unboundedLineIsUnchanged", ExtremaPC_Curve(ln), gp_Pnt(20, 3, 0));
  all("boundedOverloadReportsItsOwnBounds [0,10]", ExtremaPC_Curve(ln, 0, 10), gp_Pnt(20, 0, 0));
  all("boundedOverloadReportsItsOwnBounds [0,4]", ExtremaPC_Curve(ln, 0, 4), gp_Pnt(20, 0, 0));

  TColgp_Array1OfPnt poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(3, 4, 0);
  poles(3) = gp_Pnt(7, 4, 0);
  poles(4) = gp_Pnt(10, 0, 0);
  Handle(Geom_BezierCurve) bez = new Geom_BezierCurve(poles);
  all("bezierQueriedPastItsEnd", ExtremaPC_Curve(bez), gp_Pnt(30, 0, 0));

  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 4);
  for (int i = 1; i <= 4; ++i)
    pts->SetValue(i, poles(i));
  GeomAPI_Interpolate interp(pts, false, 1e-6);
  interp.Perform();
  all("bsplineQueriedPastItsEnd", ExtremaPC_Curve(interp.Curve()), gp_Pnt(30, 0, 0));

  const gp_Pnt qs[] = {gp_Pnt(20, 0, 0), gp_Pnt(-4, 3, 0), gp_Pnt(5, 3, 0), gp_Pnt(0, 0, 0),
                       gp_Pnt(10, 7, 2)};
  for (const gp_Pnt& q : qs)
    all("minimumDistanceAgreesWithTheExtremaArray", ExtremaPC_Curve(seg), q);
  return 0;
}
