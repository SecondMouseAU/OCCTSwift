// #603: every arc length in the bridge was ONE fixed-order Gauss quadrature per GeomAbs_CN
// interval. #477 made that per-interval instead of per-curve, which fixed multi-span BSplines; a
// conic has exactly one interval, so the single quadrature survived there.
//
// This probe measures, for a spread of curves and through every adaptor the bridge uses:
//
//   today      GCPnts_AbscissaPoint::Length(adaptor, u1, u2), what the bridge called before #603
//   fixed      the same call subdivided inside each GeomAbs_CN interval until it converges,
//              i.e. the algorithm occtAdaptorArcLength (OCCTBridge_Internal.h) implements
//   reference  a 16-point composite Gauss-Legendre quadrature of |C'(u)| over 40,000 panels,
//              evaluated through the adaptor's own D1 so it measures the same curve
//
// plus the inverse (parameter at a given arc length), the neighbours the issue lists as
// downstream, and the two convergence traps the design has to avoid.
//
// Build and run (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w -O2 \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/603-single-span-quadrature/occt_603_probe.mm -o /tmp/occt_603_probe
//   /tmp/occt_603_probe

#include <chrono>
#include <cmath>
#include <cstdio>

#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <CPnts_AbscissaPoint.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GProp_GProps.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_Ellipse.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_Parabola.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>

// ------------------------------------------------------------------------------------------
// Reference: composite 16-point Gauss-Legendre of |C'(u)|, through the adaptor's own D1.
// ------------------------------------------------------------------------------------------

static const double GL_X[8] = {0.0950125098376374, 0.2816035507792589, 0.4580167776572274,
                               0.6178762444026438, 0.7554044083550030, 0.8656312023878318,
                               0.9445750230732326, 0.9894009349916499};
static const double GL_W[8] = {0.1894506104550685, 0.1826034150449236, 0.1691565193950025,
                               0.1495959888165767, 0.1246289712555339, 0.0951585116824928,
                               0.0622535239386479, 0.0271524594117541};

static double speed(const Adaptor3d_Curve& a, double u)
{
  gp_Pnt p;
  gp_Vec v;
  a.D1(u, p, v);
  return v.Magnitude();
}
static double speed(const Adaptor2d_Curve2d& a, double u)
{
  gp_Pnt2d p;
  gp_Vec2d v;
  a.D1(u, p, v);
  return v.Magnitude();
}

template <class TheAdaptor>
static double reference(const TheAdaptor& a, double u1, double u2, int panels = 40000)
{
  const double h   = (u2 - u1) / panels;
  double       sum = 0.0;
  for (int i = 0; i < panels; ++i)
  {
    const double mid = u1 + i * h + h / 2, half = h / 2;
    for (int k = 0; k < 8; ++k)
      sum += GL_W[k] * (speed(a, mid - half * GL_X[k]) + speed(a, mid + half * GL_X[k]));
  }
  return sum * (h / 2);
}

/// Second, structurally different reference: chord sum, Richardson-extrapolated (chord length
/// converges from below as O(h^2)). Used to settle which of the two numbers is the wrong one when
/// GCPnts and the Gauss-Legendre reference disagree.
static double chordReference(const Adaptor3d_Curve& a, double u1, double u2, int n = 20000)
{
  auto sum = [&](int m) {
    double total = 0.0;
    gp_Pnt prev  = a.Value(u1);
    for (int i = 1; i <= m; ++i)
    {
      gp_Pnt p = a.Value(u1 + (u2 - u1) * i / m);
      total += prev.Distance(p);
      prev = p;
    }
    return total;
  };
  const double coarse = sum(n), fine = sum(2 * n);
  return fine + (fine - coarse) / 3.0;
}

// ------------------------------------------------------------------------------------------
// The fix, transcribed from occtAdaptorArcLength / occtArcWalkToLength (OCCTBridge_Internal.h).
// ------------------------------------------------------------------------------------------

static const double kTol = 1e-9;
static const int    kCap = 512;
static long         gCalls = 0;

template <class TheAdaptor>
static double quadrature(const TheAdaptor& a, double lo, double hi, bool singleSpan)
{
  ++gCalls;
  return singleSpan ? GCPnts_AbscissaPoint::Length(a, lo, hi)
                    : CPnts_AbscissaPoint::Length(a, lo, hi);
}

template <class TheAdaptor>
static double convergedLength(const TheAdaptor& a, double lo, double hi, bool singleSpan,
                              int& pieces)
{
  double previous = quadrature(a, lo, hi, singleSpan);
  pieces          = 1;
  for (int n = 2; n <= kCap; n *= 2)
  {
    const double h     = (hi - lo) / n;
    double       total = 0.0;
    for (int i = 0; i < n; ++i)
      total += quadrature(a, lo + i * h, (i + 1 == n) ? hi : lo + (i + 1) * h, singleSpan);
    pieces = n;
    if (std::abs(total - previous) <= kTol * std::abs(total)) return total;
    previous = total;
  }
  return previous;
}

template <class TheAdaptor>
static double fixedLength(const TheAdaptor& a, double u1, double u2)
{
  const double lo = std::min(u1, u2), hi = std::max(u1, u2);
  if (!(hi > lo)) return 0.0;
  const int intervals = a.NbIntervals(GeomAbs_CN);
  int       pieces    = 0;
  if (intervals <= 1) return convergedLength(a, lo, hi, true, pieces);

  TColStd_Array1OfReal bounds(1, intervals + 1);
  a.Intervals(bounds, GeomAbs_CN);
  double total = 0.0;
  for (int i = 1; i <= intervals; ++i)
  {
    const double pieceLo = std::max(bounds(i), lo), pieceHi = std::min(bounds(i + 1), hi);
    if (pieceHi > pieceLo) total += convergedLength(a, pieceLo, pieceHi, false, pieces);
  }
  return total;
}

template <class TheAdaptor>
static bool fixedParameterAt(const TheAdaptor& a, double abscissa, double u0, double& parameter)
{
  if (abscissa == 0.0) { parameter = u0; return true; }
  const bool   backwards = abscissa < 0.0;
  const double want = std::abs(abscissa);
  const double first = a.FirstParameter(), last = a.LastParameter();
  const int    intervals = a.NbIntervals(GeomAbs_CN);
  const bool   singleSpan = intervals <= 1;
  const int    count      = singleSpan ? 1 : intervals;

  TColStd_Array1OfReal bounds(1, count + 1);
  if (singleSpan) { bounds(1) = first; bounds(2) = last; }
  else a.Intervals(bounds, GeomAbs_CN);

  double walked = 0.0;
  for (int k = 0; k < count; ++k)
  {
    const int    i  = backwards ? count - k : k + 1;
    const double lo = std::max(bounds(i), backwards ? first : u0);
    const double hi = std::min(bounds(i + 1), backwards ? u0 : last);
    if (!(hi > lo)) continue;
    int          pieces = 0;
    const double whole  = convergedLength(a, lo, hi, singleSpan, pieces);
    if (walked + whole < want) { walked += whole; continue; }
    const double h = (hi - lo) / pieces;
    for (int j = 0; j < pieces; ++j)
    {
      const double pieceLo = backwards ? hi - (j + 1) * h : lo + j * h;
      const double pieceHi = backwards ? hi - j * h : lo + (j + 1) * h;
      const double piece   = quadrature(a, pieceLo, pieceHi, singleSpan);
      if (walked + piece < want && j + 1 < pieces) { walked += piece; continue; }
      GCPnts_AbscissaPoint solver(a, backwards ? -(want - walked) : (want - walked),
                                  backwards ? pieceHi : pieceLo);
      if (!solver.IsDone()) return false;
      parameter = solver.Parameter();
      return true;
    }
    walked += whole;
  }
  return false;
}

// --- fixtures -------------------------------------------------------------------------------

static Handle(Geom_BSplineCurve) interpolated(int n)
{
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, n);
  for (int i = 1; i <= n; ++i)
    pts->SetValue(i, gp_Pnt(i * 3.0, (i % 2) ? 12.0 : -12.0, (i % 3) ? 4.0 : -4.0));
  GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
  interp.Perform();
  return interp.Curve();
}

template <class TheAdaptor>
static void row(const char* name, const TheAdaptor& a, double u1, double u2)
{
  const double ref   = reference(a, u1, u2);
  const double today = GCPnts_AbscissaPoint::Length(a, u1, u2);
  const double fixed = fixedLength(a, u1, u2);
  auto         time  = [&](bool useFixed) {
    const int reps = 200;
    auto      t0   = std::chrono::steady_clock::now();
    double    s    = 0;
    for (int i = 0; i < reps; ++i)
      s += useFixed ? fixedLength(a, u1, u2) : GCPnts_AbscissaPoint::Length(a, u1, u2);
    (void)s;
    return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0)
               .count() /
           reps;
  };
  const double base = time(false), after = time(true);
  printf("%-26s %3d %15.9f %15.9f %+9.4f%% %9.1e %8.2f %9.2f\n", name, a.NbIntervals(GeomAbs_CN),
         today, fixed, 100.0 * (today - ref) / ref, std::abs(fixed - ref) / ref, base, after);
}

int main()
{
  printf("=== forward: whole-curve arc length =========================================\n");
  printf("%-26s %3s %15s %15s %10s %9s %8s %9s\n", "curve", "iv", "today", "fixed", "today err",
         "fixed err", "us", "us fixed");

  const double ell[][2] = {{5, 5}, {8, 3}, {8, 7}, {10, 1}, {100, 30}, {1, 0.05}, {1, 0.001}};
  for (const auto& c : ell)
  {
    const double b = (c[1] == c[0]) ? c[1] * 0.999999 : c[1];
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), c[0], b);
    GeomAdaptor_Curve    a(e);
    char                 label[64];
    snprintf(label, sizeof label, "ellipse %g x %g", c[0], b);
    row(label, a, a.FirstParameter(), a.LastParameter());
  }

  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 5.0);
  GeomAdaptor_Curve   cad(circ);
  row("circle r=5", cad, cad.FirstParameter(), cad.LastParameter());
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(), gp_Dir(1, 2, 3));
  GeomAdaptor_Curve lad(line, 0, 25);
  row("line, trimmed [0,25]", lad, 0, 25);

  Handle(Geom_Hyperbola) hyp = new Geom_Hyperbola(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 5.0, 2.0);
  for (double h : {1.0, 2.0, 4.0})
  {
    GeomAdaptor_Curve a(hyp, -h, h);
    char              label[64];
    snprintf(label, sizeof label, "hyperbola 5/2 [-%g,%g]", h, h);
    row(label, a, -h, h);
  }
  Handle(Geom_Parabola) par = new Geom_Parabola(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 3.0);
  for (double h : {5.0, 20.0, 100.0})
  {
    GeomAdaptor_Curve a(par, -h, h);
    char              label[64];
    snprintf(label, sizeof label, "parabola f=3 [-%g,%g]", h, h);
    row(label, a, -h, h);
  }
  {
    TColgp_Array1OfPnt poles(1, 4);
    poles(1) = gp_Pnt(0, 0, 0);
    poles(2) = gp_Pnt(0.2, 40, 0);
    poles(3) = gp_Pnt(9.8, -40, 0);
    poles(4) = gp_Pnt(10, 0, 0);
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(poles);
    GeomAdaptor_Curve        a(b);
    row("Bezier deg 3, whipping", a, 0, 1);
  }
  {
    TColgp_Array1OfPnt poles(1, 4);
    poles(1) = gp_Pnt(0, 0, 0);
    poles(2) = gp_Pnt(10, 0, 0);
    poles(3) = gp_Pnt(-10, 0, 0);
    poles(4) = gp_Pnt(0, 10, 0);
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(poles);
    GeomAdaptor_Curve        a(b);
    row("Bezier deg 3, near-cusp", a, 0, 1);
  }
  for (int n : {5, 8, 40, 200})
  {
    Handle(Geom_BSplineCurve) bs = interpolated(n);
    GeomAdaptor_Curve         a(bs);
    char                      label[64];
    snprintf(label, sizeof label, "interpolated BSpline, %d", n);
    row(label, a, a.FirstParameter(), a.LastParameter());
  }

  printf("\n=== the same 8x3 ellipse over sub-ranges: the error follows the interval width ===\n");
  {
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 8, 3);
    GeomAdaptor_Curve    a(e);
    row("[0, 2pi] (whole)", a, 0, 2 * M_PI);
    row("[0, pi]", a, 0, M_PI);
    row("[0, pi/2]", a, 0, M_PI / 2);
    row("[0.3, 5.9]", a, 0.3, 5.9);
  }

  printf("\n=== 2D and the topological adaptors ==========================================\n");
  {
    Handle(Geom2d_Ellipse) e2 = new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 8, 3);
    Geom2dAdaptor_Curve    a(e2);
    row("2D ellipse 8 x 3", a, a.FirstParameter(), a.LastParameter());

    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 10, 1);
    TopoDS_Edge          ed = BRepBuilderAPI_MakeEdge(e);
    BRepAdaptor_Curve    ea(ed);
    row("edge: ellipse 10 x 1", ea, ea.FirstParameter(), ea.LastParameter());
    TopoDS_Wire           w = BRepBuilderAPI_MakeWire(ed);
    BRepAdaptor_CompCurve wa(w);
    row("wire: one such edge", wa, wa.FirstParameter(), wa.LastParameter());
  }

  printf("\n=== trap 1: which number is wrong, GCPnts or the reference? =================\n");
  printf("Two independent references on the 5-point interpolation, which GCPnts puts 6.0e-5 out:\n");
  {
    Handle(Geom_BSplineCurve) bs = interpolated(5);
    GeomAdaptor_Curve         a(bs);
    const double              f = a.FirstParameter(), l = a.LastParameter();
    printf("  GCPnts                    %.12f\n", GCPnts_AbscissaPoint::Length(a, f, l));
    printf("  Gauss-Legendre, 40k panels %.12f\n", reference(a, f, l));
    printf("  chord sum, Richardson      %.12f\n", chordReference(a, f, l));
    printf("  subdivided (the fix)       %.12f\n", fixedLength(a, f, l));
  }

  printf("\n=== trap 2: halving the WHOLE range aliases onto the knots it already splits at ==\n");
  {
    Handle(Geom_BSplineCurve) bs = interpolated(5);
    GeomAdaptor_Curve         a(bs);
    const double              f = a.FirstParameter(), l = a.LastParameter(), ref = reference(a, f, l);
    for (int n : {1, 2, 4, 8, 16, 32, 64})
    {
      const double h = (l - f) / n;
      double       s = 0;
      for (int i = 0; i < n; ++i) s += GCPnts_AbscissaPoint::Length(a, f + i * h, f + (i + 1) * h);
      printf("  whole range in %2d: %.12f  rel err %.3e%s\n", n, s, std::abs(s - ref) / ref,
             n == 2 ? "   <- identical to n=1: the split landed on a knot" : "");
    }
    printf("  ...so the subdivision has to happen inside each interval, where there is no\n");
    printf("  boundary of GCPnts' own for the split points to coincide with.\n");
  }

  printf("\n=== the inverse: parameter at a given arc length ==============================\n");
  printf("Fed the ACCURATE total, the kernel's root finder (which inverts the very quadrature\n");
  printf("the fix replaces) stops landing on the end of the curve:\n");
  for (const auto& c : {ell[1], ell[3], ell[5]})
  {
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), c[0], c[1]);
    GeomAdaptor_Curve    a(e);
    const double         f = a.FirstParameter(), l = a.LastParameter();
    const double         total = fixedLength(a, f, l);
    printf("  ellipse %g x %g, total %.9f, domain ends at %.9f\n", c[0], c[1], total, l);
    for (double frac : {0.25, 0.5, 1.0})
    {
      const double         want = total * frac;
      GCPnts_AbscissaPoint kernel(a, want, f);
      double               mine = 0;
      const bool           ok = fixedParameterAt(a, want, f, mine);
      printf("    frac %.2f: kernel u=%.9f (arc err %8.1e) | walked u=%.9f (arc err %8.1e)%s\n",
             frac, kernel.IsDone() ? kernel.Parameter() : NAN,
             kernel.IsDone() ? std::abs(reference(a, f, kernel.Parameter()) - want) / want : NAN,
             mine, ok ? std::abs(reference(a, f, mine) - want) / want : NAN,
             ok ? "" : "  NOT DONE");
    }
  }

  printf("\n=== a target longer than the curve: today's answer is kept ====================\n");
  {
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 8, 3);
    GeomAdaptor_Curve    a(e);
    GCPnts_AbscissaPoint kernel(a, 1000.0, a.FirstParameter());
    double               mine = 0;
    printf("  abscissa 1000 on a curve %.3f long, domain [0, %.6f]:\n", fixedLength(a, 0, 2 * M_PI),
           a.LastParameter());
    printf("    kernel: done=%d u=%.9f   (outside the curve's own domain, yet reported done)\n",
           kernel.IsDone(), kernel.IsDone() ? kernel.Parameter() : NAN);
    printf("    walk:   done=%d          -> falls back to the kernel, so the contract is unchanged\n",
           fixedParameterAt(a, 1000.0, a.FirstParameter(), mine));
  }

  printf("\n=== downstream, measured rather than assumed ==================================\n");
  {
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 1, 0.05);
    GeomAdaptor_Curve    a(e);
    const double         total = fixedLength(a, a.FirstParameter(), a.LastParameter());
    printf("GCPnts_UniformAbscissa is NOT affected: true arc between consecutive samples,\n");
    printf("on the worst ellipse, at an odd and an even count:\n");
    for (int n : {7, 9})
    {
      GCPnts_UniformAbscissa s(a, n);
      if (!s.IsDone()) { printf("  n=%d not done\n", n); continue; }
      const double ideal = total / (s.NbPoints() - 1);
      double       worst = 0;
      for (int i = 1; i < s.NbPoints(); ++i)
        worst = std::max(worst, std::abs(reference(a, s.Parameter(i), s.Parameter(i + 1)) - ideal) /
                                    ideal);
      printf("  n=%d: %d points, worst spacing error %.2e\n", n, s.NbPoints(), worst);
    }
  }
  {
    // ...but BRepGProp does its own integration, with the same defect, and #603 does not reach it.
    Handle(Geom_Ellipse) e  = new Geom_Ellipse(gp_Ax2(gp_Pnt(), gp_Dir(0, 0, 1)), 10, 1);
    TopoDS_Edge          ed = BRepBuilderAPI_MakeEdge(e);
    BRepAdaptor_Curve    a(ed);
    GProp_GProps         props;
    BRepGProp::LinearProperties(ed, props);
    const double ref = reference(a, a.FirstParameter(), a.LastParameter());
    printf("BRepGProp::LinearProperties IS affected, on its own integrator (Shape.linearProperties):\n");
    printf("  mass %.9f, truth %.9f, err %+.4f%% -- unchanged by #603, so it now DISAGREES\n",
           props.Mass(), ref, 100.0 * (props.Mass() - ref) / ref);
    printf("  with Shape.edgeArcLength (%.9f) on the same edge, where before both were wrong.\n",
           fixedLength(a, a.FirstParameter(), a.LastParameter()));
  }
  return 0;
}
