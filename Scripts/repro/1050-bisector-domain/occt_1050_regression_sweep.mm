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
//   lost     the shipped window found a crossing and the fix does not     (must be 0)
//   moved    both found one and they differ by more than a tolerance      (must be 0)
//   gained   the fix found one the shipped window dropped                 (the point of the fix)
//   bogus    a gained crossing that is not actually a crossing            (must be 0)
//
// A non-zero `lost` or `moved` would mean the fix is not a strict widening, which is the one thing
// the hand-picked fixtures cannot rule out.
//
// `bogus` is the other half, and a first draft of this probe claimed to rule out "inventing one"
// while only counting the three classes above, which does not check a single gained crossing. Every
// gained crossing is now validated on its own terms: equidistant from both point pairs to a
// relative tolerance, and at non-negative parameter on both half-lines. Counting a disagreement is
// not the same as checking the answer, and the count alone cannot tell a recovered crossing from a
// fabricated one.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1050-bisector-domain/occt_1050_regression_sweep.mm -o /tmp/occt_1050_sweep
//   /tmp/occt_1050_sweep
//
// PROVING THE `bogus` CHECK FIRES. A validator nobody has watched fail is worth nothing, so the
// nudge that breaks every gained crossing is a committed switch rather than a local edit somebody
// has to reconstruct from a README:
//
//   OCCT_1050_NUDGE_GAINED=1 /tmp/occt_1050_sweep
//
// It displaces each gained crossing by 1e-3 * scale before validating, which must drive `bogus`
// above zero and the exit code to 1.

#include <Bisector_Bisec.hxx>
#include <Bisector_Inter.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>

#include <cmath>
#include <cstdlib>
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

// Is `h` actually a crossing of the two bisector half-lines of `p`? Checked on its own terms, with
// no reference to what either body computed: equidistance from each pair, and non-negative
// parameter on each kept ray, whose origin and direction are read off the built curves.
// `worstRel` accumulates the largest relative equidistance error seen.
bool validate(const Inputs& p, const Hit& h, double& worstRel)
{
  const double d1a = std::hypot(h.x - p.ax, h.y - p.ay);
  const double d1b = std::hypot(h.x - p.bx, h.y - p.by);
  const double d2c = std::hypot(h.x - p.cx, h.y - p.cy);
  const double d2d = std::hypot(h.x - p.dx, h.y - p.dy);

  const double r1 = std::fabs(d1a - d1b) / std::max(1e-300, std::max(d1a, d1b));
  const double r2 = std::fabs(d2c - d2d) / std::max(1e-300, std::max(d2c, d2d));
  worstRel        = std::max(worstRel, std::max(r1, r2));
  if (r1 > 1e-9 || r2 > 1e-9)
    return false;

  Bisector_Bisec b1, b2;
  if (!buildBisectors(p, b1, b2))
    return false;
  const gp_Pnt2d o1 = b1.Value()->Value(0), e1 = b1.Value()->Value(1);
  const gp_Pnt2d o2 = b2.Value()->Value(0), e2 = b2.Value()->Value(1);
  const double   t1 = (h.x - o1.X()) * (e1.X() - o1.X()) + (h.y - o1.Y()) * (e1.Y() - o1.Y());
  const double   t2 = (h.x - o2.X()) * (e2.X() - o2.X()) + (h.y - o2.Y()) * (e2.Y() - o2.Y());
  // A crossing exactly at a midpoint is parameter 0, so the bound is a small negative slack
  // scaled to the coordinates rather than a bare >= 0.
  const double slack = -1e-6 * std::max(1.0, std::max(std::fabs(t1), std::fabs(t2)));
  return t1 >= slack && t2 >= slack;
}

} // namespace

int main()
{
  // Fixed seed: this is meant to be re-runnable to the same numbers, not a different sample each
  // time somebody checks the claim.
  std::mt19937_64 rng(20260821);

  const bool nudgeGained = std::getenv("OCCT_1050_NUDGE_GAINED") != nullptr;
  if (nudgeGained)
    printf("OCCT_1050_NUDGE_GAINED set: every gained crossing is displaced before validation, so\n"
           "`bogus` must be non-zero and the exit code 1. This is the check proving itself.\n\n");

  printf("no-regression sweep, shipped [-100, 100] against the curve's own range\n\n");
  printf("  %-10s %-8s %-8s %-8s %-8s %-7s %-7s %-7s %-12s\n",
         "scale",
         "cases",
         "both",
         "neither",
         "gained",
         "lost",
         "moved",
         "bogus",
         "worst equid.");

  const double SCALES[] = {1e-3, 1.0, 1e3, 1e6};
  int    totalLost = 0, totalMoved = 0, totalGained = 0, totalCases = 0, totalBogus = 0;
  int    totalBoth = 0;
  double worstOverall = 0;

  for (double scale : SCALES)
  {
    std::uniform_real_distribution<double> u(-scale, scale);
    const int                              N = 4000;
    int    both = 0, neither = 0, gained = 0, lost = 0, moved = 0, bogus = 0;
    double worstRel = 0;

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
        if (nudgeGained)
          f.x += 1e-3 * std::max(1.0, scale); // see OCCT_1050_NUDGE_GAINED above
        if (!validate(p, f, worstRel))
        {
          ++bogus;
          printf("    BOGUS at scale %g: (%.17g, %.17g) from A(%.17g,%.17g) B(%.17g,%.17g) "
                 "C(%.17g,%.17g) D(%.17g,%.17g)\n",
                 scale, f.x, f.y, p.ax, p.ay, p.bx, p.by, p.cx, p.cy, p.dx, p.dy);
        }
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

    printf("  %-10.0e %-8d %-8d %-8d %-8d %-7d %-7d %-7d %-12.3g\n",
           scale, N, both, neither, gained, lost, moved, bogus, worstRel);
    totalCases += N;
    totalLost += lost;
    totalMoved += moved;
    totalGained += gained;
    totalBogus += bogus;
    totalBoth += both;
    worstOverall = std::max(worstOverall, worstRel);
  }

  printf("\n  %d cases across 4 scales: %d gained, %d lost, %d moved, %d bogus\n",
         totalCases, totalGained, totalLost, totalMoved, totalBogus);
  // `lost` and `moved` can only fire where the SHIPPED body found a crossing, so their denominator
  // is not the case count. Printed rather than left to a README footnote, because the headline
  // above reads as though all four figures rest on the same 16000 and they do not.
  printf("  gained and bogus are over all %d; lost and moved can only fire where the shipped body\n"
         "  found a crossing, which is %d of them\n",
         totalCases, totalBoth + totalLost);
  printf("  worst relative equidistance error over every gained crossing: %.3g\n", worstOverall);
  printf("\n  lost, moved and bogus must all be 0. gained is the fix doing its job: every one is a\n");
  printf("  crossing the shipped window discarded and returned as an empty array, and each has been\n");
  printf("  checked to be equidistant from both pairs and on the live side of both rays.\n");
  return (totalLost == 0 && totalMoved == 0 && totalBogus == 0) ? 0 : 1;
}
