// #1050, second probe. Two claims written into the fix's own documentation turned out to be
// wrong, and this is what corrected them. Both were raised by the pre-PR review and then measured
// again here, from a separate construction, because a finding is not evidence either.
//
//   f1  Coincident bisectors. The two bisectors overlap along their whole length, and
//       Bisector_Inter reports that as a SEGMENT rather than a point. The bridge reads only
//       NbPoints(), so the caller gets an empty array for two bisectors that meet everywhere.
//       That makes the reference doc's "an empty result has two causes" an undercount: there are
//       three. Tracked separately, this probe only establishes the behaviour.
//
//   f2  Accuracy at large parameter. PART 4 of the main probe is titled "where the kernel itself
//       stops" but five of its eight rows have the kept ray pointing away, so it never produced a
//       live crossing past u=300 and could not support the "no kernel accuracy limit" it was cited
//       for. Here C and D are swapped when the ray points the wrong way, so every row is live, and
//       the error is real and grows: 1e-13 at u=100, 0.073 at 1e8, 614 at 1e10.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1050-bisector-domain/occt_1050_review_findings.mm -o /tmp/occt_1050_findings
//   /tmp/occt_1050_findings
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

struct R
{
  int    pts, segs;
  double x, y, u1, u2;
  bool   threw;
};

static R go(double ax, double ay, double bx, double by, double cx, double cy, double dx, double dy)
{
  R r{0, 0, 0, 0, 0, 0, false};
  try
  {
    Bisector_Bisec                b1, b2;
    Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
    Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
    gp_Vec2d                      perpAB(-(by - ay), bx - ax);
    gp_Vec2d                      v1 = perpAB;
    v1.Normalize();
    gp_Vec2d v2 = perpAB.Reversed();
    v2.Normalize();
    b1.Perform(pA, pB, gp_Pnt2d((ax + bx) / 2, (ay + by) / 2), v1, v2, 1.0, 1e-6);
    Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(cx, cy));
    Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(dx, dy));
    gp_Vec2d                      perpCD(-(dy - cy), dx - cx);
    gp_Vec2d                      v3 = perpCD;
    v3.Normalize();
    gp_Vec2d v4 = perpCD.Reversed();
    v4.Normalize();
    b2.Perform(pC, pD, gp_Pnt2d((cx + dx) / 2, (cy + dy) / 2), v3, v4, 1.0, 1e-6);
    if (b1.Value().IsNull() || b2.Value().IsNull())
      return r;
    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    double f1 = c1->FirstParameter(), l1 = c1->LastParameter();
    double f2 = c2->FirstParameter(), l2 = c2->LastParameter();
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(f1)), f1, 1e-6, gp_Pnt2d(c1->Value(l1)), l1, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(f2)), f2, 1e-6, gp_Pnt2d(c2->Value(l2)), l2, 1e-6);
    Bisector_Inter  inter;
    inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
    if (!inter.IsDone())
      return r;
    r.pts  = inter.NbPoints();
    r.segs = inter.NbSegments();
    if (r.pts > 0)
    {
      r.x  = inter.Point(1).Value().X();
      r.y  = inter.Point(1).Value().Y();
      r.u1 = inter.Point(1).ParamOnFirst();
      r.u2 = inter.Point(1).ParamOnSecond();
    }
  }
  catch (...)
  {
    r.threw = true;
  }
  return r;
}

int main()
{
  printf("f1  coincident bisectors: both pairs vertical on the same x, so both bisectors are y=5\n\n");
  struct
  {
    const char* n;
    double      a[8];
  } F1[] = {
    {"c,d = (0,4),(0,6)  same order", {0, 0, 0, 10, 0, 4, 0, 6}},
    {"c,d = (0,6),(0,4)  reversed", {0, 0, 0, 10, 0, 6, 0, 4}},
    {"c,d = (0,-10),(0,20) wider", {0, 0, 0, 10, 0, -10, 0, 20}},
    {"identical pair", {0, 0, 0, 10, 0, 0, 0, 10}},
  };
  for (auto& f : F1)
  {
    R r = go(f.a[0], f.a[1], f.a[2], f.a[3], f.a[4], f.a[5], f.a[6], f.a[7]);
    printf("  %-34s NbPoints=%d NbSegments=%d %s\n",
           f.n,
           r.pts,
           r.segs,
           r.pts ? "" : "(bridge returns [] since it reads NbPoints only)");
  }

  printf("\n\nf2  accuracy at large u, BOTH rays live\n\n");
  printf("  Construction: bisector 1 of A(0,0) B(0,10) runs -x from (0,5), target (-u,5).\n");
  printf("  C and D are solved so bisector 2 reaches the target, swapped if the ray points away.\n\n");
  printf("  %-12s %-16s %-18s %-16s %-14s\n",
         "u",
         "u1 reported",
         "x reported",
         "abs error in x",
         "rel error");
  const double US[] = {1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10};
  for (double u : US)
  {
    const double m2x = -20.0, m2y = 30.0;
    const double wx = -u - m2x, wy = 5.0 - m2y, nw = std::hypot(wx, wy);
    double       vx = wy / nw * 10.0, vy = -wx / nw * 10.0;
    double       cx = m2x - vx / 2, cy = m2y - vy / 2, dx = m2x + vx / 2, dy = m2y + vy / 2;
    R            r = go(0, 0, 0, 10, cx, cy, dx, dy);
    if (r.pts == 0)
    {
      R s = go(0, 0, 0, 10, dx, dy, cx, cy); // kept ray points away, flip the pair
      if (s.pts)
        r = s;
    }
    if (r.pts == 0)
    {
      printf("  %-12.4g %-16s\n", u, "no intersection either ordering");
      continue;
    }
    double err = std::fabs(r.x - (-u));
    printf("  %-12.4g %-16.10g %-18.12g %-16.6g %-14.3g\n", u, r.u1, r.x, err, err / u);
  }
  return 0;
}
