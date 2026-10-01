// Epic #766 (#1978), kernel parity for Issue477ArcLengthAccuracyTests.swift: the zigzag and helix
// interpolations through GeomAPI_Interpolate, measured with GCPnts_AbscissaPoint::Length (the
// composite integrator the bridge uses) and CPnts_AbscissaPoint::Length (the whole-domain one it
// replaced), plus the segment and circle.
//
// #2916 extended it with the independent reference, which is what the suite's comments actually
// quote: every figure in Issue477ArcLengthAccuracyTests is a RELATIVE error against a densely
// sampled, Richardson-extrapolated polyline, not a GCPnts-against-CPnts difference. Without the
// reference this probe could say the two integrators now agree and could not say what either one
// is wrong by, which is the number in the prose. `reference()` below is `referenceLength()` from
// Tests/OCCTCurveTests/CurveTestFixtures.swift transcribed: chord sums at 20,000 and 40,000
// samples, extrapolated as L = L2n + (L2n - Ln) / 3 because the chord sum converges from below as
// O(h^2).
//
// The comments those figures were written for describe the kernel BEFORE carried patch 0021
// (arc-length subdivision inside CPnts). On the pinned asset 0021 has closed the gap, so the
// contrast the prose draws between the two integrators no longer exists on any fixture here.
#include <CPnts_AbscissaPoint.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

static Handle(Geom_BSplineCurve) interp(const std::vector<gp_Pnt>& p)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)p.size());
  for (int i = 0; i < (int)p.size(); i++)
    a->SetValue(i + 1, p[i]);
  GeomAPI_Interpolate ip(a, false, 1e-7);
  ip.Perform();
  return ip.Curve();
}

// Chord sum over `n` evenly spaced parameter samples: polylineLength() from CurveTestFixtures.
static double polyline(const GeomAdaptor_Curve& a, double u1, double u2, int n)
{
  double total = 0.0;
  gp_Pnt prev  = a.Value(u1);
  for (int i = 1; i <= n; i++)
  {
    gp_Pnt p = a.Value(u1 + (u2 - u1) * i / (double)n);
    total += prev.Distance(p);
    prev = p;
  }
  return total;
}

// referenceLength() from CurveTestFixtures: Richardson extrapolation of two chord-sum densities.
static double reference(const GeomAdaptor_Curve& a, double u1, double u2, int n = 20000)
{
  double coarse = polyline(a, u1, u2, n);
  double fine   = polyline(a, u1, u2, 2 * n);
  return fine + (fine - coarse) / 3;
}

// What the bridge ACTUALLY integrates, which is neither of the two kernel entry points above on
// its own: occtAdaptorArcLength (OCCTBridge_Internal.h) transcribed. It splits at the GeomAbs_CN
// interval boundaries, intersects each piece with [lo, hi], and integrates a piece with CPnts;
// only a curve with no interval to split (a conic, a line) reaches GCPnts, through
// occtArcQuadrature's singleSpan arm.
//
// #2916 added this because the suite's comments call GCPnts-whole "the composite integrator", and
// on the zigzag and the helix the bridge does not call it at all. The two happen to agree bit for
// bit here, because GCPnts_AbscissaPoint::Length splits on the same interval array and delegates
// to CPnts per span, which is the finding rather than a reason to leave the prose alone: the
// suite's accuracy is the per-span CPnts sum's, and patch 0021 is what made that sum right.
static double bridgeArcLength(const GeomAdaptor_Curve& a, double u1, double u2)
{
  double lo = std::min(u1, u2), hi = std::max(u1, u2);
  if (!(hi > lo))
    return 0.0;
  int intervals = a.NbIntervals(GeomAbs_CN);
  if (intervals <= 1)
    return GCPnts_AbscissaPoint::Length(a, lo, hi);
  TColStd_Array1OfReal bounds(1, intervals + 1);
  a.Intervals(bounds, GeomAbs_CN);
  double total = 0.0;
  for (int i = 1; i <= intervals; ++i)
  {
    double pieceLo = std::max(bounds(i), lo), pieceHi = std::min(bounds(i + 1), hi);
    if (pieceHi > pieceLo)
      total += CPnts_AbscissaPoint::Length(a, pieceLo, pieceHi);
  }
  return total;
}

// occtAdaptorLengthBetween's non-periodic arm: Curve3D.length(from:to:) reaches the integrator
// through this, and THIS is where the out-of-domain clamp the suite asserts lives
// (occtConfineToDomain), not in GCPnts and not in occtAdaptorArcLength. A curve whose domain
// covers a period takes the other arm and winds instead (#600), so this transcription is only
// valid for the two interpolated BSplines; the circle below is reported for contrast, not as a
// model of what the bridge does with it.
static double bridgeLengthBetween(const GeomAdaptor_Curve& a, double u1, double u2)
{
  double lo = std::min(u1, u2), hi = std::max(u1, u2);
  double first = a.FirstParameter(), last = a.LastParameter();
  lo = std::min(std::max(lo, first), last);
  hi = std::min(std::max(hi, first), last);
  if (hi <= lo)
    return 0.0;
  return bridgeArcLength(a, lo, hi);
}

static void report(const char* name, const Handle(Geom_Curve)& c)
{
  GeomAdaptor_Curve a(c);
  double            f = a.FirstParameter(), l = a.LastParameter(), s = l - f;
  printf("%s: domain [%.17g, %.17g]\n", name, f, l);
  printf("  GCPnts whole %.17g | CPnts whole %.17g\n", GCPnts_AbscissaPoint::Length(a),
         CPnts_AbscissaPoint::Length(a, f, l));
  printf("  GCPnts [1/3, 2/3] %.17g | CPnts %.17g\n", GCPnts_AbscissaPoint::Length(a, f + s / 3, f + 2 * s / 3),
         CPnts_AbscissaPoint::Length(a, f + s / 3, f + 2 * s / 3));
  printf("  GCPnts [1/4, 3/4] %.17g reversed %.17g\n", GCPnts_AbscissaPoint::Length(a, f + s / 4, f + 3 * s / 4),
         GCPnts_AbscissaPoint::Length(a, f + 3 * s / 4, f + s / 4));
  printf("  CPnts over [f - s, l + s] (unclamped extension) %.17g\n", CPnts_AbscissaPoint::Length(a, f - s, l + s));

  // #2916: the same three ranges against the independent reference, which is what the suite
  // asserts on and what its comments quote.
  double rw = reference(a, f, l);
  double r3 = reference(a, f + s / 3, f + 2 * s / 3);
  double r4 = reference(a, f + s / 4, f + 3 * s / 4);
  printf("  reference whole %.17g | GCPnts rel %.3g | CPnts rel %.3g\n", rw,
         fabs(GCPnts_AbscissaPoint::Length(a) - rw) / rw,
         fabs(CPnts_AbscissaPoint::Length(a, f, l) - rw) / rw);
  printf("  reference [1/3, 2/3] %.17g | GCPnts rel %.3g | CPnts rel %.3g\n", r3,
         fabs(GCPnts_AbscissaPoint::Length(a, f + s / 3, f + 2 * s / 3) - r3) / r3,
         fabs(CPnts_AbscissaPoint::Length(a, f + s / 3, f + 2 * s / 3) - r3) / r3);
  printf("  reference [1/4, 3/4] %.17g | GCPnts rel %.3g | CPnts rel %.3g\n", r4,
         fabs(GCPnts_AbscissaPoint::Length(a, f + s / 4, f + 3 * s / 4) - r4) / r4,
         fabs(CPnts_AbscissaPoint::Length(a, f + s / 4, f + 3 * s / 4) - r4) / r4);
  printf("  unclamped CPnts over [f - s, l + s] is %.4gx the curve's own length %.17g\n",
         CPnts_AbscissaPoint::Length(a, f - s, l + s) / rw, rw);

  // #2916: what Curve3D.length actually returns, through occtAdaptorArcLength. This is the number
  // the suite's assertions compare against the reference; the GCPnts and CPnts lines above are
  // the two kernel entry points it is composed from.
  printf("  bridge (occtAdaptorArcLength) %d interval(s): whole %.17g rel %.3g | [1/3, 2/3] rel "
         "%.3g | [1/4, 3/4] rel %.3g\n",
         a.NbIntervals(GeomAbs_CN), bridgeArcLength(a, f, l),
         fabs(bridgeArcLength(a, f, l) - rw) / rw,
         fabs(bridgeArcLength(a, f + s / 3, f + 2 * s / 3) - r3) / r3,
         fabs(bridgeArcLength(a, f + s / 4, f + 3 * s / 4) - r4) / r4);
  printf("  bridge (occtAdaptorLengthBetween, non-periodic arm) confines [f - s, l + s] to %.17g "
         "and [l + s, l + 2s] to %.17g; CPnts unclamped gives %.17g\n",
         bridgeLengthBetween(a, f - s, l + s), bridgeLengthBetween(a, l + s, l + 2 * s),
         CPnts_AbscissaPoint::Length(a, f - s, l + s));
}

int main()
{
  std::vector<gp_Pnt> z, h;
  for (int i = 0; i < 40; i++)
  {
    double s = i / 39.0;
    z.push_back(gp_Pnt(100 * s * s * s, i % 2 == 0 ? 0.0 : 8.0, 5 * sin(6 * M_PI * s)));
  }
  for (int i = 0; i < 60; i++)
  {
    double t = 2 * M_PI * 3 * i / 59.0;
    h.push_back(gp_Pnt(10 * cos(t), 10 * sin(t), 2 * t));
  }
  report("zigzag 40 points", interp(z));
  report("helix 60 points", interp(h));
  report("segment (0,0,0)-(3,4,0)", GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(3, 4, 0)).Value());
  report("circle r 7", new Geom_Circle(gp_Ax2(), 7));
  return 0;
}
