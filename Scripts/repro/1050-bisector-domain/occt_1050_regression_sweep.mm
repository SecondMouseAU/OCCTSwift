// #1050, third probe: the no-regression sweep.
//
// The other two probes are ten hand-picked fixtures. Hand-picked fixtures can show that the fix
// finds something the shipped window dropped; they cannot show that it never LOSES one, never MOVES
// one, and never invents one, because those are claims about the whole input space and ten points
// are not a sample of it.
//
// This runs the shipped [-100, 100] body and the fixed curve's-own-range body over randomised
// four-point configurations at four scales, and classifies every disagreement:
//
//   lost    the shipped window found a crossing and the fix does not      (must be 0)
//   moved   both found one and they differ by more than a tolerance       (must be 0)
//   gained  the fix found one the shipped window dropped                  (the point of the fix)
//
// A non-zero `lost` or `moved` would mean the fix is not a strict widening, which is the one thing
// the hand-picked fixtures cannot rule out.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1050-bisector-domain/occt_1050_regression_sweep.mm -o /tmp/occt_1050_sweep
//   /tmp/occt_1050_sweep

#include <Bisector_Bisec.hxx>
#include <Bisector_Inter.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>

#include <cmath>
#include <cstdio>
#include <random>

namespace
{

struct Inputs
{
  double ax, ay, bx, by, cx, cy, dx, dy;
};

struct Hit
{
  bool   found = false;
  double x = 0, y = 0, u1 = 0;
};

bool buildBisectors(const Inputs& p, Bisector_Bisec& b1, Bisector_Bisec& b2)
{
  Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(p.ax, p.ay));
  Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(p.bx, p.by));
  gp_Vec2d                      perpAB(-(p.by - p.ay), p.bx - p.ax);
  gp_Vec2d                      v1 = perpAB;
  v1.Normalize();
  gp_Vec2d v2 = perpAB.Reversed();
  v2.Normalize();
  b1.Perform(pA, pB, gp_Pnt2d((p.ax + p.bx) / 2, (p.ay + p.by) / 2), v1, v2, 1.0, 1e-6);
  if (b1.Value().IsNull())
    return false;

  Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(p.cx, p.cy));
  Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(p.dx, p.dy));
  gp_Vec2d                      perpCD(-(p.dy - p.cy), p.dx - p.cx);
  gp_Vec2d                      v3 = perpCD;
  v3.Normalize();
  gp_Vec2d v4 = perpCD.Reversed();
  v4.Normalize();
  b2.Perform(pC, pD, gp_Pnt2d((p.cx + p.dx) / 2, (p.cy + p.dy) / 2), v3, v4, 1.0, 1e-6);
  return !b2.Value().IsNull();
}

// `shipped` selects the pre-#1050 [-100, 100] window; otherwise the curve's own parameter range.
Hit run(const Inputs& p, bool shipped)
{
  Hit h;
  try
  {
    Bisector_Bisec b1, b2;
    if (!buildBisectors(p, b1, b2))
      return h;
    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    double                             f1, l1, f2, l2;
    if (shipped)
    {
      f1 = f2 = -100.0;
      l1 = l2 = 100.0;
    }
    else
    {
      f1 = c1->FirstParameter();
      l1 = c1->LastParameter();
      f2 = c2->FirstParameter();
      l2 = c2->LastParameter();
    }
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(f1)), f1, 1e-6, gp_Pnt2d(c1->Value(l1)), l1, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(f2)), f2, 1e-6, gp_Pnt2d(c2->Value(l2)), l2, 1e-6);
    Bisector_Inter  inter;
    inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
    if (!inter.IsDone() || inter.NbPoints() == 0)
      return h;
    h.found = true;
    h.x     = inter.Point(1).Value().X();
    h.y     = inter.Point(1).Value().Y();
    h.u1    = inter.Point(1).ParamOnFirst();
  }
  catch (...)
  {
    // Both columns take the same throw for the same input, so a refusal is not a disagreement.
  }
  return h;
}

} // namespace

int main()
{
  // Fixed seed: this is meant to be re-runnable to the same numbers, not a different sample each
  // time somebody checks the claim.
  std::mt19937_64 rng(20260821);

  printf("no-regression sweep, shipped [-100, 100] against the curve's own range\n\n");
  printf("  %-10s %-9s %-9s %-9s %-9s %-9s %-14s\n",
         "scale",
         "cases",
         "both",
         "neither",
         "gained",
         "lost",
         "moved");

  const double SCALES[] = {1e-3, 1.0, 1e3, 1e6};
  int          totalLost = 0, totalMoved = 0, totalGained = 0, totalCases = 0;

  for (double scale : SCALES)
  {
    std::uniform_real_distribution<double> u(-scale, scale);
    const int                              N = 4000;
    int both = 0, neither = 0, gained = 0, lost = 0, moved = 0;

    for (int i = 0; i < N; ++i)
    {
      Inputs p{u(rng), u(rng), u(rng), u(rng), u(rng), u(rng), u(rng), u(rng)};
      Hit    s = run(p, true);
      Hit    f = run(p, false);

      if (!s.found && !f.found)
      {
        ++neither;
      }
      else if (!s.found && f.found)
      {
        ++gained;
      }
      else if (s.found && !f.found)
      {
        ++lost;
        printf("    LOST at scale %g: A(%.17g,%.17g) B(%.17g,%.17g) C(%.17g,%.17g) D(%.17g,%.17g)\n",
               scale, p.ax, p.ay, p.bx, p.by, p.cx, p.cy, p.dx, p.dy);
      }
      else
      {
        ++both;
        // Both found one. They must be the same point: the fix widens the search, it does not
        // change what the search computes. Scale the tolerance, since coordinates do.
        const double tol = 1e-9 * std::max(1.0, scale);
        if (std::fabs(s.x - f.x) > tol || std::fabs(s.y - f.y) > tol)
        {
          ++moved;
          printf("    MOVED at scale %g: shipped (%.17g, %.17g) fix (%.17g, %.17g)\n",
                 scale, s.x, s.y, f.x, f.y);
        }
      }
    }

    printf("  %-10.0e %-9d %-9d %-9d %-9d %-9d %-14d\n",
           scale, N, both, neither, gained, lost, moved);
    totalCases += N;
    totalLost += lost;
    totalMoved += moved;
    totalGained += gained;
  }

  printf("\n  %d cases across 4 scales: %d gained, %d lost, %d moved\n",
         totalCases, totalGained, totalLost, totalMoved);
  printf("\n  lost and moved must both be 0. gained is the fix doing its job: every one of those is\n");
  printf("  a crossing the shipped window discarded and returned as an empty array.\n");
  return (totalLost == 0 && totalMoved == 0) ? 0 : 1;
}
