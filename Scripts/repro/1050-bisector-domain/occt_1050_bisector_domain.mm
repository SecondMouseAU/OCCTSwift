// #1050. OCCTBisectorInterPointPoint clamps both IntRes2d_Domain parameter ranges to a hardcoded
// [-100, 100]. This probe answers four questions the fix turns on, by measurement rather than
// by reading the call:
//
//   PART 1  What is a point-point bisector, and what parameter range does it actually carry?
//   PART 2  Is IntRes2d_Domain an input to the intersection or a filter on its output, and does
//           widening it to the representable range cost anything?
//   PART 3  Which candidate bound answers correctly on every fixture, including the degenerate
//           inputs (coincident points, parallel bisectors, a meeting point far outside the four
//           points' own extent).
//   PART 4  Why two of PART 3's rows are missed by every bound, unbounded ones included, which
//           turns out to be the ray Bisector_Bisec keeps rather than anything about the domain.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1050-bisector-domain/occt_1050_bisector_domain.mm -o /tmp/occt_1050_bisector
//   /tmp/occt_1050_bisector

#include <Bisector_Bisec.hxx>
#include <Bisector_Curve.hxx>
#include <Bisector_Inter.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>

#include <chrono>
#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

namespace
{

// Which parameter range to hand IntRes2d_Domain. Every variant runs the same body otherwise, so
// the only difference between two columns is the bound under test.
enum class Bound
{
  Shipped,        // the hardcoded +-100 in OCCTBridge_Geom2d.mm today
  Infinite,       // default-constructed IntRes2d_Domain(), HasFirstPoint() == false
  RealFirstLast,  // an explicitly bounded domain at RealFirst() / RealLast(), #1020's own remedy
  PrecisInfinite, // +- Precision::Infinite(), which is 2e100 and NOT RealLast()
  CurveOwnRange,  // the bisector curve's own FirstParameter() / LastParameter()
  InputSpan,      // 2 * (largest pairwise separation of the four input points) + 1
};

const Bound BOUNDS[] = {Bound::Shipped,
                        Bound::Infinite,
                        Bound::RealFirstLast,
                        Bound::PrecisInfinite,
                        Bound::CurveOwnRange,
                        Bound::InputSpan};
const int NBOUNDS = 6;

const char* boundName(Bound b)
{
  switch (b)
  {
    case Bound::Shipped:
      return "shipped +-100";
    case Bound::Infinite:
      return "infinite domain";
    case Bound::RealFirstLast:
      return "RealFirst/RealLast";
    case Bound::PrecisInfinite:
      return "+-Precision::Infinite";
    case Bound::CurveOwnRange:
      return "curve own range";
    case Bound::InputSpan:
      return "2 * input span + 1";
  }
  return "?";
}

struct Hit
{
  double x, y, paramOnFirst;
};

struct Outcome
{
  std::vector<Hit> hits;
  bool             threw = false;
  std::string      what;
};

struct Inputs
{
  double ax, ay, bx, by, cx, cy, dx, dy;
};

// Builds the two bisectors exactly as the bridge does today.
bool buildBisectors(const Inputs& p, Bisector_Bisec& b1, Bisector_Bisec& b2)
{
  Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(p.ax, p.ay));
  Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(p.bx, p.by));
  gp_Pnt2d                      midAB((p.ax + p.bx) / 2, (p.ay + p.by) / 2);
  gp_Vec2d                      vAB(p.bx - p.ax, p.by - p.ay);
  gp_Vec2d                      perpAB(-vAB.Y(), vAB.X());
  gp_Vec2d                      v1 = perpAB;
  v1.Normalize();
  gp_Vec2d v2 = perpAB.Reversed();
  v2.Normalize();
  b1.Perform(pA, pB, midAB, v1, v2, 1.0, 1e-6);
  if (b1.Value().IsNull())
    return false;

  Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(p.cx, p.cy));
  Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(p.dx, p.dy));
  gp_Pnt2d                      midCD((p.cx + p.dx) / 2, (p.cy + p.dy) / 2);
  gp_Vec2d                      vCD(p.dx - p.cx, p.dy - p.cy);
  gp_Vec2d                      perpCD(-vCD.Y(), vCD.X());
  gp_Vec2d                      v3 = perpCD;
  v3.Normalize();
  gp_Vec2d v4 = perpCD.Reversed();
  v4.Normalize();
  b2.Perform(pC, pD, midCD, v3, v4, 1.0, 1e-6);
  return !b2.Value().IsNull();
}

double inputSpan(const Inputs& p)
{
  double xs[4] = {p.ax, p.bx, p.cx, p.dx};
  double ys[4] = {p.ay, p.by, p.cy, p.dy};
  double span  = 0;
  for (int i = 0; i < 4; ++i)
    for (int j = i + 1; j < 4; ++j)
      span = std::max(span, std::hypot(xs[i] - xs[j], ys[i] - ys[j]));
  return span;
}

IntRes2d_Domain domainFor(const Bisector_Bisec& b, Bound bound, double span)
{
  const Handle(Geom2d_TrimmedCurve)& c  = b.Value();
  double                             lo = 0, hi = 0;
  switch (bound)
  {
    case Bound::Infinite:
      return IntRes2d_Domain();
    case Bound::Shipped:
      lo = -100.0;
      hi = 100.0;
      break;
    case Bound::RealFirstLast:
      lo = RealFirst();
      hi = RealLast();
      break;
    case Bound::PrecisInfinite:
      lo = -Precision::Infinite();
      hi = Precision::Infinite();
      break;
    case Bound::CurveOwnRange:
      lo = c->FirstParameter();
      hi = c->LastParameter();
      break;
    case Bound::InputSpan:
      lo = -(2 * span + 1);
      hi = 2 * span + 1;
      break;
  }
  return IntRes2d_Domain(gp_Pnt2d(c->Value(lo)), lo, 1e-6, gp_Pnt2d(c->Value(hi)), hi, 1e-6);
}

Outcome run(const Inputs& p, Bound bound)
{
  Outcome out;
  try
  {
    Bisector_Bisec b1, b2;
    if (!buildBisectors(p, b1, b2))
      return out;

    const double    span = inputSpan(p);
    IntRes2d_Domain d1   = domainFor(b1, bound, span);
    IntRes2d_Domain d2   = domainFor(b2, bound, span);

    Bisector_Inter inter;
    inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
    if (!inter.IsDone())
      return out;
    for (int i = 1; i <= inter.NbPoints(); ++i)
    {
      const IntRes2d_IntersectionPoint& ip = inter.Point(i);
      out.hits.push_back({ip.Value().X(), ip.Value().Y(), ip.ParamOnFirst()});
    }
  }
  catch (Standard_Failure const& f)
  {
    out.threw = true;
    out.what  = std::string(f.ExceptionType());
  }
  catch (...)
  {
    out.threw = true;
    out.what  = "unknown exception";
  }
  return out;
}

std::string describe(const Outcome& o)
{
  if (o.threw)
    return "THREW " + o.what;
  if (o.hits.empty())
    return "no intersection";
  char buf[96];
  snprintf(buf,
           sizeof(buf),
           "(%.6g, %.6g) u=%.6g",
           o.hits[0].x,
           o.hits[0].y,
           o.hits[0].paramOnFirst);
  std::string s(buf);
  if (o.hits.size() > 1)
    s += " +" + std::to_string(o.hits.size() - 1);
  return s;
}

struct Fixture
{
  const char* name;
  Inputs      p;
};

// Bisector_Bisec builds a HALF-line from the midpoint, so a fixture only has something to find when
// the meeting point lies on the live side of BOTH midpoints. That is measured per fixture by
// reachable() below rather than hand-labelled, because a hand-labelled flag is exactly the thing
// that stops meaning its name when a coordinate is edited.
const Fixture FIXTURES[] = {
  // #1050's own three rows.
  {"meeting point at parameter 50", {0, 0, 0, 10, -55, 0, -45, 0}},
  {"meeting point at parameter 90", {0, 0, 0, 10, -95, 0, -85, 0}},
  {"meeting point at parameter 150", {0, 0, 0, 10, -155, 0, -145, 0}},
  // AB and CD nearly parallel, so the two bisectors are nearly parallel and meet about 1e4 away
  // while all four points sit inside a box about 23 across. This is the row that tells a bound
  // derived from the input's extent apart from one derived from the curve.
  {"near-parallel, meeting point ~1e4 from a 23-wide input",
   {0, 0, 0, 10, -19.9995, 1.01, -20.0005, 10.99}},
  // The same shape mirrored, so the meeting point is on the DEAD side of bisector 1's half-line.
  // Every bound must report nothing here, and for the right reason.
  {"near-parallel, meeting point on the dead side", {0, 0, 0, 10, 19.9995, 1.01, 20.0005, 10.99}},
  // The row that separates a bound derived from the INPUT from one derived from the CURVE, at a
  // healthy crossing angle rather than a near-parallel one. The two bisectors cross at 10.89
  // degrees, the four points span 40.71, and the meeting point sits at parameter 150, so
  // 2 * span + 1 is 82.42 and cuts it off where the curve's own range does not. C and D are solved
  // for rather than guessed, by build-discriminating-fixture.py in this directory.
  {"10.9 degree crossing, u=150 past 2*span+1 (82.42)",
   {0, 0, 0, 10, -19.0558, 25.0900, -20.9442, 34.9100}},
  // Degenerate inputs.
  {"parallel bisectors, a genuine miss", {0, 0, 0, 10, 0, 40, 0, 60}},
  {"coincident points in the first pair", {5, 5, 5, 5, -55, 0, -45, 0}},
  {"coincident points in both pairs", {5, 5, 5, 5, -3, -3, -3, -3}},
  {"all four points collinear", {0, 0, 10, 0, 20, 0, 30, 0}},
};
const int NFIXTURES = 10;

// Closed-form intersection of the two full bisector LINES, independent of OCCT. This is the second
// construction the table is checked against: nothing in it comes from the kernel.
bool circumcentre(const Inputs& p, double& x, double& y)
{
  const double a1  = 2 * (p.bx - p.ax);
  const double b1  = 2 * (p.by - p.ay);
  const double c1  = (p.bx * p.bx + p.by * p.by) - (p.ax * p.ax + p.ay * p.ay);
  const double a2  = 2 * (p.dx - p.cx);
  const double b2  = 2 * (p.dy - p.cy);
  const double c2  = (p.dx * p.dx + p.dy * p.dy) - (p.cx * p.cx + p.cy * p.cy);
  const double det = a1 * b2 - a2 * b1;
  if (std::abs(det) < 1e-9)
    return false;
  x = (c1 * b2 - c2 * b1) / det;
  y = (a1 * c2 - a2 * c1) / det;
  return true;
}

// Is the closed-form meeting point on the live side of both half-lines, and at what parameter on
// each?
//
// The meeting point itself stays closed-form, from circumcentre() above, with no kernel call. WHICH
// of the two opposed rays Bisector_Bisec keeps is a different question and it is NOT derivable from
// the four input points: Bisector_Bisec::Perform picks a ray from the V1/V2/Sense sector the bridge
// hands it, and PART 4 measures rows where that choice points away from the closed-form meeting
// point. An earlier draft of this function assumed the ray was perp(B - A) normalised, which is
// what the bridge passes as v1, and it mislabelled four rows as reachable that are not. So the
// origin and direction are read off the built curve, and only those.
bool reachable(const Bisector_Bisec& b1,
               const Bisector_Bisec& b2,
               double                x,
               double                y,
               double&               paramOnFirst,
               double&               paramOnSecond)
{
  const gp_Pnt2d o1 = b1.Value()->Value(0), e1 = b1.Value()->Value(1);
  const gp_Pnt2d o2 = b2.Value()->Value(0), e2 = b2.Value()->Value(1);
  paramOnFirst  = (x - o1.X()) * (e1.X() - o1.X()) + (y - o1.Y()) * (e1.Y() - o1.Y());
  paramOnSecond = (x - o2.X()) * (e2.X() - o2.X()) + (y - o2.Y()) * (e2.Y() - o2.Y());
  return paramOnFirst >= 0 && paramOnSecond >= 0;
}

} // namespace

int main()
{
  // ---------------------------------------------------------------- PART 1
  printf("PART 1  what a point-point bisector actually is\n\n");
  {
    Bisector_Bisec b1, b2;
    buildBisectors(FIXTURES[2].p, b1, b2);
    const Handle(Geom2d_TrimmedCurve)& c = b1.Value();
    printf("  Value()                    %s\n", c->DynamicType()->Name());
    printf("  Value()->BasisCurve()      %s\n", c->BasisCurve()->DynamicType()->Name());
    printf("  Value()->FirstParameter()  %.17g\n", c->FirstParameter());
    printf("  Value()->LastParameter()   %.17g\n", c->LastParameter());
    printf("  Precision::Infinite()      %.17g\n", Precision::Infinite());
    printf("  RealLast()                 %.17g\n", RealLast());
    Handle(Bisector_Curve) bc = Handle(Bisector_Curve)::DownCast(c->BasisCurve());
    if (!bc.IsNull())
    {
      printf("  BasisCurve NbIntervals()   %d\n", bc->NbIntervals());
      printf("  BasisCurve IntervalFirst   %.17g\n", bc->IntervalFirst(1));
      printf("  BasisCurve IntervalLast    %.17g\n", bc->IntervalLast(1));
    }
    printf("  Value(0)                   (%.6g, %.6g)\n", c->Value(0).X(), c->Value(0).Y());
    printf("  Value(1)                   (%.6g, %.6g)\n", c->Value(1).X(), c->Value(1).Y());
    printf("  Value(-1)                  (%.6g, %.6g)\n", c->Value(-1).X(), c->Value(-1).Y());
    printf("\n  The curve carries its own range, and it is a HALF-line: parameter 0 is the\n");
    printf("  midpoint of the pair and negative parameters run off the curve. So the shipped\n");
    printf("  [-100, 100] spends half its width off the curve and caps the live half at 100,\n");
    printf("  and neither number has any relation to the caller's four points.\n");
  }

  // ---------------------------------------------------------------- PART 2
  printf("\n\nPART 2  is the domain an input to the intersection or a filter on its output?\n\n");
  printf("  Read first, then measured. Bisector_Inter::Perform clips each of the basis curve's\n");
  printf("  continuity intervals against the domain's parameter range, SKIPS any interval that\n");
  printf("  does not overlap it, and hands the clipped sub-domain to Geom2dInt_GInter. It also\n");
  printf("  reads D.FirstTolerance()/LastTolerance(), which raise Standard_DomainError on a\n");
  printf("  domain with no first/last point. So it is an input, and an unbounded domain is not\n");
  printf("  spelled IntRes2d_Domain(). The timing below is the cost question that follows.\n\n");
  {
    // Time inter.Perform alone, with the bisectors and both domains already built, so the column
    // measures the intersection and not the domain construction. Three sweeps, minimum reported,
    // to damp scheduler noise.
    const int      N = 4000;
    const Fixture& f = FIXTURES[2]; // meeting point at parameter 150
    printf("  %-24s %-14s %-34s\n", "bound", "us / Perform", "answer");
    for (int bi = 0; bi < NBOUNDS; ++bi)
    {
      const Bound b    = BOUNDS[bi];
      double      best = 1e300;
      for (int sweep = 0; sweep < 3; ++sweep)
      {
        Bisector_Bisec b1, b2;
        buildBisectors(f.p, b1, b2);
        const double span = inputSpan(f.p);
        double       us   = 1e300;
        try
        {
          IntRes2d_Domain d1 = domainFor(b1, b, span);
          IntRes2d_Domain d2 = domainFor(b2, b, span);
          auto            t0 = std::chrono::steady_clock::now();
          for (int i = 0; i < N; ++i)
          {
            Bisector_Inter inter;
            inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
          }
          auto t1 = std::chrono::steady_clock::now();
          us = std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count() / (1000.0 * N);
        }
        catch (...)
        {
          // Left at 1e300; the answer column names the exception.
        }
        best = std::min(best, us);
      }
      const Outcome shown = run(f.p, b);
      if (best >= 1e299)
        printf("  %-24s %-14s %-34s\n", boundName(b), "n/a", describe(shown).c_str());
      else
        printf("  %-24s %-14.2f %-34s\n", boundName(b), best, describe(shown).c_str());
    }
  }

  // ---------------------------------------------------------------- PART 3
  printf("\n\nPART 3  every candidate bound against every fixture\n\n");
  printf("  %-56s", "fixture");
  for (int bi = 0; bi < NBOUNDS; ++bi)
    printf(" %-32s", boundName(BOUNDS[bi]));
  printf(" %s\n", "closed form (reachable?)");

  int dropped[NBOUNDS] = {0, 0, 0, 0, 0, 0};
  for (int fi = 0; fi < NFIXTURES; ++fi)
  {
    const Fixture& f  = FIXTURES[fi];
    double         wx = 0, wy = 0, wu = 0, wu2 = 0;
    const bool     meets = circumcentre(f.p, wx, wy);

    bool           live = false;
    Bisector_Bisec rb1, rb2;
    try
    {
      live = meets && buildBisectors(f.p, rb1, rb2) && reachable(rb1, rb2, wx, wy, wu, wu2);
    }
    catch (...)
    {
      live = false; // a degenerate pair that cannot build a bisector has nothing to reach.
    }

    printf("  %-56s", f.name);
    for (int bi = 0; bi < NBOUNDS; ++bi)
    {
      Outcome o = run(f.p, BOUNDS[bi]);
      printf(" %-32s", describe(o).c_str());
      // "Dropped" means: the closed form puts a meeting point on the live side of both half-lines
      // and this bound reported nothing. Reporting nothing where there is no reachable solution is
      // the correct answer, not a drop.
      if (live && o.hits.empty())
        ++dropped[bi];
    }
    if (live)
      printf(" (%.6g, %.6g) at u1=%.6g u2=%.6g\n", wx, wy, wu, wu2);
    else if (meets)
      printf(" (%.6g, %.6g) NOT on both half-lines (u1=%.6g u2=%.6g)\n", wx, wy, wu, wu2);
    else
      printf(" parallel, no solution\n");
  }

  printf("\n  fixtures with a reachable meeting point that the bound drops:\n");
  for (int bi = 0; bi < NBOUNDS; ++bi)
    printf("    %-24s %d\n", boundName(BOUNDS[bi]), dropped[bi]);

  // ---------------------------------------------------------------- PART 4
  // Two rows of PART 3 are missed by EVERY bound, including the unbounded ones, so something other
  // than the domain drops them. (Both `near-parallel` rows. Drafts of this comment said "One row"
  // while the file header said "three", which is the same count stated twice with two wrong
  // values.) This sweep walks the meeting point out along the same half-line while
  // holding the four points inside a small box, and the answer is the u2 column: every miss has the
  // kept ray pointing away, which is a choice Bisector_Bisec makes and not a limit of anything.
  //
  // This part was titled "where the kernel itself stops" and cited for there being no kernel
  // accuracy limit. It cannot support that either way: five of its eight rows have the ray pointing
  // away, so it never produces a live crossing past u=300. The accuracy question is answered in
  // occt_1050_review_findings.mm, which keeps every row live and finds no meaningful kernel error.
  printf("\n\nPART 4  why some rows are missed by every bound, which is the ray and not the "
         "domain\n\n");
  printf("  Same construction as build-discriminating-fixture.py, m2 fixed at (-20, 30) so the\n");
  printf("  four points stay inside a box about 41 across while the meeting point walks out.\n\n");
  printf("  u1 and u2 are the target's parameter on each bisector, MEASURED from the built curve\n");
  printf("  rather than assumed from the construction: a negative one means the half-line points\n");
  printf("  away and there is nothing for any bound to find.\n\n");
  printf("  %-10s %-8s %-12s %-12s %-10s %-22s %-22s\n",
         "u",
         "deg",
         "u1 measured",
         "u2 measured",
         "2*span+1",
         "curve own range",
         "2 * input span + 1");
  const double US[] = {50, 100, 150, 300, 1000, 3000, 1e4, 1e5};
  for (double u : US)
  {
    // Bisector 1 of A(0,0) B(0,10) starts at (0,5) and runs along -x, so the target is (-u, 5).
    const double m2x = -20.0, m2y = 30.0;
    const double wx = -u - m2x, wy = 5.0 - m2y;
    const double nw = std::hypot(wx, wy);
    const double vx = wy / nw * 10.0, vy = -wx / nw * 10.0;
    Inputs       p{0, 0, 0, 10, m2x - vx / 2, m2y - vy / 2, m2x + vx / 2, m2y + vy / 2};

    const double crossing = std::acos(std::max(-1.0, std::min(1.0, -wx / nw))) * 180.0 / M_PI;

    // Ask the built curves where the target sits, instead of trusting the construction above.
    double         u1 = 0, u2 = 0;
    Bisector_Bisec b1, b2;
    if (buildBisectors(p, b1, b2))
    {
      const gp_Pnt2d t(-u, 5.0);
      const gp_Pnt2d o1 = b1.Value()->Value(0), e1 = b1.Value()->Value(1);
      const gp_Pnt2d o2 = b2.Value()->Value(0), e2 = b2.Value()->Value(1);
      u1 = (t.X() - o1.X()) * (e1.X() - o1.X()) + (t.Y() - o1.Y()) * (e1.Y() - o1.Y());
      u2 = (t.X() - o2.X()) * (e2.X() - o2.X()) + (t.Y() - o2.Y()) * (e2.Y() - o2.Y());
    }

    const Outcome own  = run(p, Bound::CurveOwnRange);
    const Outcome span = run(p, Bound::InputSpan);
    printf("  %-10.6g %-8.2f %-12.6g %-12.6g %-10.2f %-22s %-22s\n",
           u,
           crossing,
           u1,
           u2,
           2 * inputSpan(p) + 1,
           describe(own).c_str(),
           describe(span).c_str());
  }
  return 0;
}
