// #600 ground truth: a finite parameter range reaching outside the curve's domain.
//
// Three numbers per case:
//   today     - what GCPnts_AbscissaPoint::Length(adaptor, u1, u2) returns now
//   in-domain - the length of the part of the range that lies on the curve
//               (the range intersected with [FirstParameter, LastParameter])
//   evaluated - a chord sum over the range as the curve evaluates it, which for a periodic
//               curve is the winding and for a Bezier/BSpline is polynomial extrapolation
//
// Also reports IsPeriodic()/NbIntervals(GeomAbs_CN) per fixture, since the decision in #600 is
// "confine unless periodic" and both properties have to be readable from the adaptor.

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>

static std::string fmt(double v)
{
  char buf[64];
  if (std::isnan(v)) return "nan";
  if (std::isinf(v)) return v > 0 ? "+inf" : "-inf";
  snprintf(buf, sizeof(buf), "%.4f", v);
  return buf;
}

static Handle(Geom_BSplineCurve) interpolated3D(bool periodic)
{
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 5);
  if (periodic)
  {
    // Five distinct points around a loop; GeomAPI_Interpolate closes it itself.
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(100, 40, 0));
    pts->SetValue(3, gp_Pnt(160, -30, 20));
    pts->SetValue(4, gp_Pnt(60, -90, -10));
    pts->SetValue(5, gp_Pnt(-40, -30, 30));
  }
  else
  {
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(100, 50, 0));
    pts->SetValue(3, gp_Pnt(150, -60, 40));
    pts->SetValue(4, gp_Pnt(250, 30, -20));
    pts->SetValue(5, gp_Pnt(300, 0, 60));
  }
  GeomAPI_Interpolate interp(pts, periodic ? Standard_True : Standard_False, 1e-7);
  interp.Perform();
  return interp.Curve();
}

static Handle(Geom_BezierCurve) bezier3D()
{
  TColgp_Array1OfPnt poles(1, 4);
  poles.SetValue(1, gp_Pnt(0, 0, 0));
  poles.SetValue(2, gp_Pnt(30, 60, 0));
  poles.SetValue(3, gp_Pnt(70, -40, 20));
  poles.SetValue(4, gp_Pnt(100, 0, 0));
  return new Geom_BezierCurve(poles);
}

// Chord sum over [u1, u2] as the curve evaluates it. Uses the underlying Geom_Curve, which
// happily evaluates outside its own bounds (winding on a periodic curve, extrapolating on a
// polynomial one), so this is "what the requested range traces", not "what is on the curve".
static double evaluatedLength(const Handle(Geom_Curve)& c, double u1, double u2, int n = 200000)
{
  double total = 0;
  gp_Pnt prev = c->Value(u1);
  for (int i = 1; i <= n; ++i)
  {
    gp_Pnt p = c->Value(u1 + (u2 - u1) * double(i) / double(n));
    total += p.Distance(prev);
    prev = p;
  }
  return total;
}

struct Fixture
{
  std::string        name;
  Handle(Geom_Curve) curve;
};

// Richardson-extrapolated chord sum (L ~= L2n + (L2n - Ln)/3), the #477 reference technique.
static double referenceLength(const Handle(Geom_Curve)& c, double u1, double u2, int n = 200000)
{
  const double ln  = evaluatedLength(c, u1, u2, n);
  const double l2n = evaluatedLength(c, u1, u2, 2 * n);
  return l2n + (l2n - ln) / 3.0;
}

// --- The contract proposed in #600, implemented here so it can be measured before it is coded ---
//
// A curve whose parameter domain covers a whole period exists at every parameter, so the whole
// requested range is measured and a range longer than the period winds. Anything else is confined
// to the part of the range that lies on the curve.
template <class TheAdaptor>
static bool windsPeriodically(const TheAdaptor& a)
{
  if (!a.IsPeriodic()) return false;
  return (a.LastParameter() - a.FirstParameter()) >= a.Period() - 1e-9;
}

template <class TheAdaptor>
static double proposedLength(const TheAdaptor& a, double u1, double u2)
{
  const double first = a.FirstParameter(), last = a.LastParameter();
  double       lo = std::min(u1, u2), hi = std::max(u1, u2);

  if (windsPeriodically(a))
  {
    const double period = a.Period();
    const double seam   = first + period;
    // One period's worth, not the whole domain: a curve trimmed to more than a period would
    // otherwise multiply the wrong number.
    const double perPeriod = GCPnts_AbscissaPoint::Length(a, first, seam);
    const double span      = hi - lo;
    const double turns     = std::floor(span / period);
    double       total     = turns * perPeriod;
    const double rest      = span - turns * period;
    if (rest > 0)
    {
      double s = first + std::fmod(lo - first, period);
      if (s < first) s += period;
      const double e = s + rest;
      total += (e <= seam) ? GCPnts_AbscissaPoint::Length(a, s, e)
                           : GCPnts_AbscissaPoint::Length(a, s, seam)
                                 + GCPnts_AbscissaPoint::Length(a, first, first + (e - seam));
    }
    return total;
  }
  (void)last;

  lo = std::max(lo, first);
  hi = std::min(hi, last);
  if (hi <= lo) return 0.0;
  return GCPnts_AbscissaPoint::Length(a, lo, hi);
}

int main()
{
  printf("=== #600 ground truth: a finite range reaching outside the curve's domain ===\n\n");

  std::vector<Fixture> fixtures;
  fixtures.push_back({"segment (trimmed line, [0,10])",
                      new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10)});
  fixtures.push_back({"unbounded line", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0))});
  fixtures.push_back({"circle r=5", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0)});
  fixtures.push_back({"ellipse 8x3",
                      new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 8.0, 3.0)});
  fixtures.push_back({"arc (trimmed circle, [0, pi])",
                      new Geom_TrimmedCurve(
                          new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0), 0, M_PI)});
  fixtures.push_back({"bezier (4 poles)", bezier3D()});
  fixtures.push_back({"bspline (5-pt interpolated)", interpolated3D(false)});
  fixtures.push_back({"bspline periodic (5-pt closed)", interpolated3D(true)});

  for (const Fixture& f : fixtures)
  {
    GeomAdaptor_Curve ad(f.curve);
    const double      lo = ad.FirstParameter();
    const double      hi = ad.LastParameter();
    const bool        unbounded = std::abs(hi) > 1e50;
    const double      span = unbounded ? 1.0 : (hi - lo);

    printf("--- %s\n", f.name.c_str());
    printf("    domain [%s, %s]  IsPeriodic=%d  Period=%s  NbIntervals(CN)=%d  whole=%s\n",
           fmt(lo).c_str(), fmt(hi).c_str(), (int)ad.IsPeriodic(),
           ad.IsPeriodic() ? fmt(ad.Period()).c_str() : "-", ad.NbIntervals(GeomAbs_CN),
           fmt(GCPnts_AbscissaPoint::Length(ad)).c_str());

    struct Probe { const char* label; double u1; double u2; };
    const Probe probes[] = {
      {"in domain, whole      ", lo, hi},
      {"past the end          ", lo, hi + span},
      {"past both ends        ", lo - span, hi + span},
      {"wholly past the end   ", hi + span, hi + 2 * span},
      {"wholly before the start", lo - 2 * span, lo - span},
    };

    for (const Probe& p : probes)
    {
      double today = -12345;
      try { today = GCPnts_AbscissaPoint::Length(ad, p.u1, p.u2); }
      catch (const Standard_Failure&) { today = NAN; }

      // The part of the requested range that lies on the curve.
      const double c1 = std::max(std::min(p.u1, p.u2), lo);
      const double c2 = std::min(std::max(p.u1, p.u2), hi);
      double confined = 0;
      if (c2 > c1)
      {
        try { confined = GCPnts_AbscissaPoint::Length(ad, c1, c2); }
        catch (const Standard_Failure&) { confined = NAN; }
      }

      const double evaluated = unbounded ? today : referenceLength(f.curve, p.u1, p.u2);
      const double proposed  = proposedLength(ad, p.u1, p.u2);

      // What the proposal claims to equal: the traced length for a winding curve, the in-domain
      // part otherwise.
      const double want = windsPeriodically(ad) ? evaluated : confined;
      const bool   ok   = std::abs(proposed - want) < 1e-4 * std::max(1.0, std::abs(want));

      printf("    %s today=%-12s confined=%-12s traced=%-12s proposed=%-12s %s\n", p.label,
             fmt(today).c_str(), fmt(confined).c_str(), fmt(evaluated).c_str(),
             fmt(proposed).c_str(), ok ? "ok" : "MISMATCH");
    }
    printf("\n");
  }

  // --- Does the same split show up on an edge (BRepAdaptor_Curve)? ------------------------
  {
    printf("--- edges (BRepAdaptor_Curve)\n");
    struct EdgeFixture { const char* name; TopoDS_Edge edge; };
    EdgeFixture edges[] = {
      {"straight edge", BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0))},
      {"full circle edge",
       BRepBuilderAPI_MakeEdge(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0))},
      {"arc edge [0, pi]",
       BRepBuilderAPI_MakeEdge(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0), 0.0,
                               M_PI)},
      {"bspline edge", BRepBuilderAPI_MakeEdge(interpolated3D(false))},
      {"periodic bspline edge", BRepBuilderAPI_MakeEdge(interpolated3D(true))},
    };
    for (const EdgeFixture& e : edges)
    {
      BRepAdaptor_Curve ad(e.edge);
      const double      lo = ad.FirstParameter(), hi = ad.LastParameter(), span = hi - lo;
      printf("    %-22s domain [%s, %s] IsPeriodic=%d winds=%d NbIntervals=%d whole=%s "
             "past-the-end: today=%s proposed=%s\n",
             e.name, fmt(lo).c_str(), fmt(hi).c_str(), (int)ad.IsPeriodic(),
             (int)windsPeriodically(ad), ad.NbIntervals(GeomAbs_CN),
             fmt(GCPnts_AbscissaPoint::Length(ad)).c_str(),
             fmt(GCPnts_AbscissaPoint::Length(ad, lo, hi + span)).c_str(),
             fmt(proposedLength(ad, lo, hi + span)).c_str());
    }
    printf("\n");
  }

  // --- 2D: same question, both spellings ---------------------------------------------------
  {
    printf("--- 2D\n");
    Handle(Geom2d_Curve) seg =
        new Geom2d_TrimmedCurve(new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0, 10);
    Handle(Geom2d_Curve) circ =
        new Geom2d_Circle(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 5.0);
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 5);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(100, 50));
    pts->SetValue(3, gp_Pnt2d(150, -60));
    pts->SetValue(4, gp_Pnt2d(250, 30));
    pts->SetValue(5, gp_Pnt2d(300, 0));
    Geom2dAPI_Interpolate interp(pts, Standard_False, 1e-7);
    interp.Perform();
    Handle(Geom2d_Curve) spline = interp.Curve();

    struct C2 { const char* name; Handle(Geom2d_Curve) c; };
    C2 cs[] = {{"segment", seg}, {"circle", circ}, {"bspline", spline}};
    for (const C2& c : cs)
    {
      Geom2dAdaptor_Curve ad(c.c);
      const double        lo = ad.FirstParameter(), hi = ad.LastParameter(), span = hi - lo;
      double ranged = GCPnts_AbscissaPoint::Length(ad, lo, hi + span);
      double prebounded = NAN;
      try
      {
        Geom2dAdaptor_Curve bounded(c.c, lo, hi + span);
        prebounded = GCPnts_AbscissaPoint::Length(bounded);
      }
      catch (const Standard_Failure&) {}
      printf("    %-8s IsPeriodic=%d NbIntervals=%d whole=%-10s past-the-end: ranged=%-10s "
             "pre-bounded=%s\n",
             c.name, (int)ad.IsPeriodic(), ad.NbIntervals(GeomAbs_CN),
             fmt(GCPnts_AbscissaPoint::Length(ad)).c_str(), fmt(ranged).c_str(),
             fmt(prebounded).c_str());
    }
  }
  return 0;
}
