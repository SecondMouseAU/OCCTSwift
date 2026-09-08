// Probe for #1633: ExtremaPC_Curve::Perform vs PerformWithEndpoints across the curve
// kinds ExtremaPC_Curve dispatches over.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1633-extremapc-endpoints/probe.mm -o /tmp/occt_probe_1633
//   /tmp/occt_probe_1633

#include <ExtremaPC.hxx>
#include <ExtremaPC_Curve.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>
#include <string>

static void report(const std::string& label, const occ::handle<Geom_Curve>& c, const gp_Pnt& q)
{
  printf("--- %s, query (%g, %g, %g)\n", label.c_str(), q.X(), q.Y(), q.Z());
  ExtremaPC_Curve ext(c);
  if (!ext.IsInitialized())
  {
    printf("    NOT INITIALIZED\n");
    return;
  }
  {
    const ExtremaPC::Result& r = ext.Perform(q, 1e-9);
    printf("    Perform             IsDone=%d NbExt=%d", (int)r.IsDone(), (int)r.NbExt());
    if (r.IsDone() && r.NbExt() > 0)
      printf(" min=%.6f", std::sqrt(r.MinSquareDistance()));
    printf("\n");
    for (int i = 0; i < r.NbExt(); ++i)
      printf("        [%d] u=%.6f d=%.6f p=(%.4f, %.4f, %.4f)\n",
             i, r[i].Parameter, std::sqrt(r[i].SquareDistance),
             r[i].Point.X(), r[i].Point.Y(), r[i].Point.Z());
  }
  {
    const ExtremaPC::Result& r = ext.PerformWithEndpoints(q, 1e-9);
    printf("    WithEndpoints       IsDone=%d NbExt=%d", (int)r.IsDone(), (int)r.NbExt());
    if (r.IsDone() && r.NbExt() > 0)
      printf(" min=%.6f", std::sqrt(r.MinSquareDistance()));
    printf("\n");
    for (int i = 0; i < r.NbExt(); ++i)
      printf("        [%d] u=%.6f d=%.6f p=(%.4f, %.4f, %.4f)\n",
             i, r[i].Parameter, std::sqrt(r[i].SquareDistance),
             r[i].Point.X(), r[i].Point.Y(), r[i].Point.Z());
  }
}

static void reportBounded(const std::string&            label,
                          const occ::handle<Geom_Curve>& c,
                          double                        uMin,
                          double                        uMax,
                          const gp_Pnt&                 q)
{
  printf("--- %s, bounds [%g, %g], query (%g, %g, %g)\n",
         label.c_str(), uMin, uMax, q.X(), q.Y(), q.Z());
  ExtremaPC_Curve ext(c, uMin, uMax);
  if (!ext.IsInitialized())
  {
    printf("    NOT INITIALIZED\n");
    return;
  }
  {
    const ExtremaPC::Result& r = ext.Perform(q, 1e-9);
    printf("    Perform             IsDone=%d NbExt=%d", (int)r.IsDone(), (int)r.NbExt());
    if (r.IsDone() && r.NbExt() > 0)
      printf(" min=%.6f", std::sqrt(r.MinSquareDistance()));
    printf("\n");
  }
  {
    const ExtremaPC::Result& r = ext.PerformWithEndpoints(q, 1e-9);
    printf("    WithEndpoints       IsDone=%d NbExt=%d", (int)r.IsDone(), (int)r.NbExt());
    if (r.IsDone() && r.NbExt() > 0)
      printf(" min=%.6f", std::sqrt(r.MinSquareDistance()));
    printf("\n");
    for (int i = 0; i < r.NbExt(); ++i)
      printf("        [%d] u=%.6f d=%.6f p=(%.4f, %.4f, %.4f)\n",
             i, r[i].Parameter, std::sqrt(r[i].SquareDistance),
             r[i].Point.X(), r[i].Point.Y(), r[i].Point.Z());
  }
}

int main()
{
  // 1. Trimmed line segment [0, 10] along +X.
  occ::handle<Geom_Line> line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  occ::handle<Geom_TrimmedCurve> seg = new Geom_TrimmedCurve(line, 0.0, 10.0);
  report("trimmed line [0,10] +X (issue's own case)", seg, gp_Pnt(20, 0, 0));
  report("trimmed line [0,10] +X, foot inside", seg, gp_Pnt(5, 3, 0));
  report("trimmed line [0,10] +X, past the START", seg, gp_Pnt(-4, 3, 0));

  // 2. Untrimmed (infinite) line.
  report("untrimmed line +X", line, gp_Pnt(20, 3, 0));

  // 3. Full circle, radius 5, centre origin, XY plane.
  occ::handle<Geom_Circle> circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  report("full circle r=5", circ, gp_Pnt(0, 10, 0));

  // 4. Trimmed circle arc [0, pi].
  occ::handle<Geom_TrimmedCurve> arc = new Geom_TrimmedCurve(circ, 0.0, M_PI);
  report("circle arc [0,pi] r=5", arc, gp_Pnt(0, -6, 0));

  // 5. Trimmed ellipse arc.
  occ::handle<Geom_Ellipse> ell = new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 8, 3);
  occ::handle<Geom_TrimmedCurve> ellArc = new Geom_TrimmedCurve(ell, 0.0, M_PI / 2);
  report("ellipse arc [0,pi/2] 8x3", ellArc, gp_Pnt(20, 0, 0));

  // 6. Trimmed parabola.
  occ::handle<Geom_Parabola> par = new Geom_Parabola(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2.0);
  occ::handle<Geom_TrimmedCurve> parArc = new Geom_TrimmedCurve(par, 0.0, 5.0);
  report("parabola arc [0,5] focal=2", parArc, gp_Pnt(40, 40, 0));

  // 7. Trimmed hyperbola.
  occ::handle<Geom_Hyperbola> hyp =
    new Geom_Hyperbola(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0, 3.0);
  occ::handle<Geom_TrimmedCurve> hypArc = new Geom_TrimmedCurve(hyp, 0.0, 1.0);
  report("hyperbola arc [0,1] 4x3", hypArc, gp_Pnt(40, 0, 0));

  // 8. Bezier from four poles.
  TColgp_Array1OfPnt poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(3, 4, 0);
  poles(3) = gp_Pnt(7, 4, 0);
  poles(4) = gp_Pnt(10, 0, 0);
  occ::handle<Geom_BezierCurve> bez = new Geom_BezierCurve(poles);
  report("bezier 4 poles [0,1]", bez, gp_Pnt(30, 0, 0));

  // 9. B-spline through the same points.
  TColgp_Array1OfPnt pts(1, 4);
  pts(1) = gp_Pnt(0, 0, 0);
  pts(2) = gp_Pnt(3, 4, 0);
  pts(3) = gp_Pnt(7, 4, 0);
  pts(4) = gp_Pnt(10, 0, 0);
  GeomAPI_PointsToBSpline fit(pts, 3, 8, GeomAbs_C2, 1e-4);
  occ::handle<Geom_BSplineCurve> bs = fit.Curve();
  report("bspline through 4 pts", bs, gp_Pnt(30, 0, 0));

  // 10. Offset curve on the trimmed segment.
  occ::handle<Geom_OffsetCurve> off = new Geom_OffsetCurve(seg, 2.0, gp_Dir(0, 0, 1));
  report("offset of trimmed line [0,10], offset 2", off, gp_Pnt(20, 0, 0));

  // 11. Bounded constructor over an untrimmed line.
  reportBounded("untrimmed line +X, 3-arg ctor", line, 0.0, 10.0, gp_Pnt(20, 0, 0));

  // 12. Bounded constructor over a trimmed segment, sub-range.
  reportBounded("trimmed line [0,10], sub-range", seg, 0.0, 4.0, gp_Pnt(20, 0, 0));

  // 13. Bounded constructor over a full circle, half range.
  reportBounded("full circle r=5, half range", circ, 0.0, M_PI, gp_Pnt(0, -6, 0));

  return 0;
}
