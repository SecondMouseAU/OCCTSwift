// #1050, fourth probe: the two limits the reference doc asserted without measuring.
//
// Both claims were written into docs/reference/Shape-Recognition.md by this issue's own fix and
// both were wrong. An independent pre-PR review raised them; this is the measurement that settled
// them, and it is committed because the corrected sentences are now load-bearing documentation.
//
//   PART 1  "a crossing is found HOWEVER FAR from the midpoints it falls" is false. The bisector is
//           trimmed to [0, Precision::Infinite()], which is 2e100, so the search really does end,
//           and past it the caller gets the same silent empty array #1050 is about, with the
//           threshold moved from 100 to 2e100 rather than removed.
//
//   PART 2  The first cause of an empty result was documented as "the pair is too close to have a
//           direction", citing a separation of 1e-300 and implying gp_Vec2d::Normalize() refuses.
//           Measured, refusal starts at a separation of about 1e-10 and comes from
//           GccAna_NoSolution inside Bisector_Bisec::Perform. Normalize() itself does not refuse
//           until about 1e-162, where sep*sep underflows to zero, which is 152 orders of magnitude
//           later and is not the mechanism a caller meets.
//
//           A draft of that correction said Normalize() copes "all the way down to 1e-300", off by
//           138 orders of magnitude, because this probe's own grid jumped 1e-160 to 1e-300 and
//           never bracketed the transition. Correcting a wrong figure with an unbracketed grid is
//           the same mistake wearing a measurement, so the grid now steps through it.
//
// PART 1 also records a fixture mistake worth keeping. Its first version held the second pair's
// half-width at a fixed 5 while walking u out to 1e150. At u = 1e50 that half-width is below the
// ulp of -1e50, so the pair collapsed to a single point and the probe measured its own degeneracy,
// reporting a Standard_ConstructionError at 1e50 that had nothing to do with the domain. Both the
// pair separation and the half-width now scale with u.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1050-bisector-domain/occt_1050_limits.mm -o /tmp/occt_1050_limits
//   /tmp/occt_1050_limits
#include <Bisector_Bisec.hxx>
#include <Bisector_Inter.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <cmath>
#include <cstdio>
#include <string>

struct R { int pts; double x, y; bool threw; std::string what; };

static R go(double ax, double ay, double bx, double by, double cx, double cy, double dx, double dy)
{
  R r{0, 0, 0, false, ""};
  try
  {
    Bisector_Bisec b1, b2;
    Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
    Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
    gp_Vec2d perpAB(-(by - ay), bx - ax);
    gp_Vec2d v1 = perpAB; v1.Normalize();
    gp_Vec2d v2 = perpAB.Reversed(); v2.Normalize();
    b1.Perform(pA, pB, gp_Pnt2d((ax + bx) / 2, (ay + by) / 2), v1, v2, 1.0, 1e-6);
    Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(cx, cy));
    Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(dx, dy));
    gp_Vec2d perpCD(-(dy - cy), dx - cx);
    gp_Vec2d v3 = perpCD; v3.Normalize();
    gp_Vec2d v4 = perpCD.Reversed(); v4.Normalize();
    b2.Perform(pC, pD, gp_Pnt2d((cx + dx) / 2, (cy + dy) / 2), v3, v4, 1.0, 1e-6);
    if (b1.Value().IsNull() || b2.Value().IsNull()) { r.what = "null bisector"; return r; }
    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    double f1 = c1->FirstParameter(), l1 = c1->LastParameter();
    double f2 = c2->FirstParameter(), l2 = c2->LastParameter();
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(f1)), f1, 1e-6, gp_Pnt2d(c1->Value(l1)), l1, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(f2)), f2, 1e-6, gp_Pnt2d(c2->Value(l2)), l2, 1e-6);
    Bisector_Inter inter;
    inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
    if (!inter.IsDone()) { r.what = "not done"; return r; }
    r.pts = inter.NbPoints();
    if (r.pts) { r.x = inter.Point(1).Value().X(); r.y = inter.Point(1).Value().Y(); }
  }
  catch (Standard_Failure const& f) { r.threw = true; r.what = f.ExceptionType(); }
  catch (...) { r.threw = true; r.what = "unknown"; }
  return r;
}

int main()
{
  printf("PART 1  is a crossing found HOWEVER FAR? LastParameter() is 2e100, so it is not.\n\n");
  printf("  %-14s %-12s %-40s\n", "target u", "past 2e100?", "result");
  const double US[] = {1e6, 1e50, 1e99, 5e99, 1e100, 2e100, 5e100, 1e101, 1e150};
  for (double u : US)
  {
    // Bisector 1 of A(0,0) B(0,h) runs -x from (0,h/2). Both the pair separation and the second
    // pair's half-width SCALE with u: at u = 1e50 a fixed half-width of 5 is below the ulp of
    // -1e50, so the second pair collapses to one point and the refusal measures the fixture rather
    // than the bound. That is the first version of this probe, and it is why this one scales.
    const double h = u * 1e-2;
    const double w = u * 1e-2;
    R r = go(0, 0, 0, h, -u - w, 0, -u + w, 0);
    char res[80];
    if (r.threw) snprintf(res, sizeof(res), "THREW %s", r.what.c_str());
    else if (r.pts == 0) snprintf(res, sizeof(res), "no intersection %s", r.what.c_str());
    else snprintf(res, sizeof(res), "(%.6g, %.6g)", r.x, r.y);
    printf("  %-14.3g %-12s %-40s  want y=%.3g\n", u, u > 2e100 ? "yes" : "no", res, u * 1e-2 / 2);
  }

  printf("\n\nPART 2  where does a near-coincident FIRST pair start being refused, and by what?\n\n");
  printf("  The doc says \"too close to have a direction\" with 1e-300 as the example. Bracketed:\n\n");
  printf("  %-14s %-44s %-24s\n", "|b - a|", "result", "closed-form crossing y");
  // The grid has to BRACKET both transitions, not straddle them. A draft jumped 1e-160 to 1e-300
  // and so never saw where Normalize() actually starts refusing, which was then published as
  // "copes all the way down to 1e-300". It does not: sep*sep underflows to zero around 1e-162.
  const double SEPS[] = {1e0,    1e-6,   1e-8,   1e-9,   1e-10,  1e-11,  1e-20, 1e-100,
                         1e-154, 1e-160, 1e-161, 1e-162, 1e-163, 1e-200, 1e-300};
  for (double sep : SEPS)
  {
    R r = go(0, 0, 0, sep, -55, 0, -45, 0);
    char res[80];
    if (r.threw) snprintf(res, sizeof(res), "THREW %s", r.what.c_str());
    else if (r.pts == 0) snprintf(res, sizeof(res), "no intersection %s", r.what.c_str());
    else snprintf(res, sizeof(res), "(%.10g, %.6g)", r.x, r.y);
    printf("  %-14.3g %-44s %-24.6g\n", sep, res, sep / 2);
  }

  printf("\n  Does gp_Vec2d::Normalize() itself refuse at these separations?\n");
  for (double sep : SEPS)
  {
    bool threw = false;
    try { gp_Vec2d v(-sep, 0.0); v.Normalize(); } catch (...) { threw = true; }
    printf("    Normalize(perp of |b-a| = %-10.3g) %s\n", sep, threw ? "THREW" : "ok");
  }
  return 0;
}
