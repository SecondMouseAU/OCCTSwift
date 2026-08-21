// Adjudication probe for one row of the detect-hardcoded-arguments.py sample (#1001).
//
// OCCTBisectorInterPointPoint (OCCTBridge_Geom2d.mm, behind bisectorIntersections) clamps both
// IntRes2d_Domain parameter ranges to a hardcoded [-100, 100]. The caller supplies four arbitrary
// 2D points and the doc comment advertises "the circumcenter for triangle problems", so the
// question the adjudication turns on is whether a circumcenter further than 100 from a bisector's
// own midpoint is silently dropped.
//
// Rebuilds the bridge function's body twice, identical except for the domain bound: once with the
// shipped +-100 and once with a bound derived from the input points. Both are run on the same three
// fixtures, so the only difference between the two columns is the literal under test.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1001-detector-fp-rates/occt_1001_bisector_domain.mm -o /tmp/occt_1001_bisector
//   /tmp/occt_1001_bisector

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
#include <vector>

namespace
{

struct Hit
{
  double x, y;
};

// The shipped body, with the domain bound lifted to a parameter so the two columns differ in
// exactly one value. `bound < 0` selects a bound derived from the input span instead.
std::vector<Hit> bisectorIntersections(double ax,
                                       double ay,
                                       double bx,
                                       double by,
                                       double cx,
                                       double cy,
                                       double dx,
                                       double dy,
                                       double bound)
{
  std::vector<Hit> out;
  try
  {
    Bisector_Bisec                b1;
    Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
    Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
    gp_Pnt2d                      midAB((ax + bx) / 2, (ay + by) / 2);
    gp_Vec2d                      vAB(bx - ax, by - ay);
    gp_Vec2d                      perpAB(-vAB.Y(), vAB.X());
    gp_Vec2d                      v1 = perpAB;
    v1.Normalize();
    gp_Vec2d v2 = perpAB.Reversed();
    v2.Normalize();
    b1.Perform(pA, pB, midAB, v1, v2, 1.0, 1e-6);
    if (b1.Value().IsNull())
      return out;

    Bisector_Bisec                b2;
    Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(cx, cy));
    Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(dx, dy));
    gp_Pnt2d                      midCD((cx + dx) / 2, (cy + dy) / 2);
    gp_Vec2d                      vCD(dx - cx, dy - cy);
    gp_Vec2d                      perpCD(-vCD.Y(), vCD.X());
    gp_Vec2d                      v3 = perpCD;
    v3.Normalize();
    gp_Vec2d v4 = perpCD.Reversed();
    v4.Normalize();
    b2.Perform(pC, pD, midCD, v3, v4, 1.0, 1e-6);
    if (b2.Value().IsNull())
      return out;

    double r = bound;
    if (r < 0)
    {
      // Derived from the input: the largest pairwise separation of the four points, doubled, so a
      // circumcenter anywhere the four points can put it stays inside the search.
      double xs[4] = {ax, bx, cx, dx};
      double ys[4] = {ay, by, cy, dy};
      double span  = 0;
      for (int i = 0; i < 4; ++i)
        for (int j = i + 1; j < 4; ++j)
          span = std::max(span, std::hypot(xs[i] - xs[j], ys[i] - ys[j]));
      r = 2 * span + 1;
    }

    IntRes2d_Domain d1(gp_Pnt2d(b1.Value()->Value(-r)), -r, 1e-6,
                       gp_Pnt2d(b1.Value()->Value(r)), r, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(b2.Value()->Value(-r)), -r, 1e-6,
                       gp_Pnt2d(b2.Value()->Value(r)), r, 1e-6);

    Bisector_Inter inter;
    inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
    if (!inter.IsDone())
      return out;
    for (int i = 1; i <= inter.NbPoints(); ++i)
    {
      const IntRes2d_IntersectionPoint& ip = inter.Point(i);
      out.push_back({ip.Value().X(), ip.Value().Y()});
    }
  }
  catch (...)
  {
  }
  return out;
}

struct Fixture
{
  const char* name;
  double      ax, ay, bx, by, cx, cy, dx, dy;
  double      wantX, wantY;
};

// Bisector_Bisec builds a HALF-line from the midpoint, range [0, 2e100], not the full bisector, so
// a fixture has to put the meeting point on the correct side of both midpoints or there is nothing
// to find at any bound. Each row below does: bisector 1 is that of A(0,0) B(0,10), the half-line
// running in -x from (0,5); bisector 2 is that of a short horizontal pair centred on x = -X, the
// half-line running in +y from (-X,0). They meet at (-X, 5), at parameter X on the first.
// `want` is that meeting point in closed form, which is the second construction: nothing in it
// comes from OCCT.
const Fixture FIXTURES[] = {
  {"meeting point at parameter 50, inside the shipped bound",
   0, 0, 0, 10, -55, 0, -45, 0, -50, 5},
  {"meeting point at parameter 90, inside the shipped bound",
   0, 0, 0, 10, -95, 0, -85, 0, -90, 5},
  {"meeting point at parameter 150, outside the shipped bound",
   0, 0, 0, 10, -155, 0, -145, 0, -150, 5},
};

} // namespace

int main()
{
  int missed = 0;
  printf("%-56s %-22s %-22s\n", "fixture", "shipped +-100", "bound from the input");
  for (const Fixture& f : FIXTURES)
  {
    std::vector<Hit> shipped =
      bisectorIntersections(f.ax, f.ay, f.bx, f.by, f.cx, f.cy, f.dx, f.dy, 100.0);
    std::vector<Hit> derived =
      bisectorIntersections(f.ax, f.ay, f.bx, f.by, f.cx, f.cy, f.dx, f.dy, -1.0);

    char a[64], b[64];
    if (shipped.empty())
      snprintf(a, sizeof(a), "no intersection");
    else
      snprintf(a, sizeof(a), "(%.4g, %.4g)", shipped[0].x, shipped[0].y);
    if (derived.empty())
      snprintf(b, sizeof(b), "no intersection");
    else
      snprintf(b, sizeof(b), "(%.4g, %.4g)", derived[0].x, derived[0].y);
    printf("%-56s %-22s %-22s\n", f.name, a, b);

    if (shipped.empty() && !derived.empty())
      ++missed;
  }
  printf("\nexpected meeting points, solved in closed form:\n");
  for (const Fixture& f : FIXTURES)
    printf("  %-56s (%.4g, %.4g)\n", f.name, f.wantX, f.wantY);
  printf("\n%d fixture(s) the shipped bound drops and a bound from the input finds\n", missed);
  return 0;
}
