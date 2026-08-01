// #548 ground truth: non-finite (and out-of-domain) parameter bounds through every ranged
// arc-length entry point the bridge still has after #506.
//
//   A. GCPnts_AbscissaPoint::Length(GeomAdaptor_Curve&,   u1, u2)  -> OCCTCurve3DGetLengthBetween
//   B. GCPnts_AbscissaPoint::Length(Geom2dAdaptor_Curve&, u1, u2)  -> OCCTCurve2DGetLengthBetween
//   C. Geom2dAdaptor_Curve(c, u1, u2) + Length(adaptor)            -> OCCTCurve2DLength
//   D. GCPnts_AbscissaPoint::Length(BRepAdaptor_Curve&,   u1, u2)  -> OCCTEdgeArcLengthBetween
//
// Swift's guard is `l >= 0 ? l : nil` (3D/2D length) or the raw double (edge).

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
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>

static const double NAN_ = std::nan("");
static const double INF_ = INFINITY;

static std::string fmt(double v)
{
  char buf[64];
  if (std::isnan(v)) return "nan";
  if (std::isinf(v)) return v > 0 ? "+inf" : "-inf";
  snprintf(buf, sizeof(buf), "%.6f", v);
  return buf;
}

// What Swift's `l >= 0 ? l : nil` guard makes of a bridge return value.
static std::string swiftSees(double v)
{
  if (std::isnan(v)) return "nil";          // NaN fails `>= 0`
  if (v < 0) return "nil";
  return fmt(v);
}

struct Curve3DFixture
{
  std::string          name;
  Handle(Geom_Curve)   curve;
};

struct Curve2DFixture
{
  std::string          name;
  Handle(Geom2d_Curve) curve;
};

static Handle(Geom_BSplineCurve) interpolated3D()
{
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 5);
  pts->SetValue(1, gp_Pnt(0, 0, 0));
  pts->SetValue(2, gp_Pnt(100, 50, 0));
  pts->SetValue(3, gp_Pnt(150, -60, 40));
  pts->SetValue(4, gp_Pnt(250, 30, -20));
  pts->SetValue(5, gp_Pnt(300, 0, 60));
  GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
  interp.Perform();
  return interp.Curve();
}

static Handle(Geom2d_BSplineCurve) interpolated2D()
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 5);
  pts->SetValue(1, gp_Pnt2d(0, 0));
  pts->SetValue(2, gp_Pnt2d(100, 50));
  pts->SetValue(3, gp_Pnt2d(150, -60));
  pts->SetValue(4, gp_Pnt2d(250, 30));
  pts->SetValue(5, gp_Pnt2d(300, 0));
  Geom2dAPI_Interpolate interp(pts, Standard_False, 1e-7);
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

int main()
{
  printf("=== #548 ground truth: non-finite bounds through the ranged arc-length entry points ===\n\n");

  // --- 3D fixtures -----------------------------------------------------------------------
  std::vector<Curve3DFixture> f3;
  f3.push_back({"segment (trimmed line)",
                new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10)});
  f3.push_back({"unbounded line", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0))});
  f3.push_back({"circle", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0)});
  f3.push_back({"bezier (4 poles)", bezier3D()});
  f3.push_back({"bspline (5-pt interpolated)", interpolated3D()});

  for (size_t i = 0; i < f3.size(); ++i)
  {
    GeomAdaptor_Curve ad(f3[i].curve);
    const double      f = ad.FirstParameter();
    const double      l = ad.LastParameter();
    printf("--- 3D %s\n", f3[i].name.c_str());
    printf("    domain [%s, %s], NbIntervals(CN)=%d, type=%d, whole length=%s\n",
           fmt(f).c_str(), fmt(l).c_str(), ad.NbIntervals(GeomAbs_CN), (int)ad.GetType(),
           fmt(GCPnts_AbscissaPoint::Length(ad)).c_str());

    struct Probe { const char* label; double u1; double u2; };
    const double span = (std::isinf(l) || l > 1e50) ? 1.0 : (l - f);
    const Probe probes[] = {
      {"(f, l)          valid whole    ", f, l},
      {"(f, nan)        NaN upper      ", f, NAN_},
      {"(nan, l)        NaN lower      ", NAN_, l},
      {"(nan, nan)      both NaN       ", NAN_, NAN_},
      {"(f, +inf)       inf upper      ", f, INF_},
      {"(-inf, l)       inf lower      ", -INF_, l},
      {"(-inf, +inf)    both inf       ", -INF_, INF_},
      {"(f, l+span)     past the end   ", f, l + span},
      {"(l+span, l+2sp) wholly outside ", l + span, l + 2 * span},
    };
    for (const Probe& p : probes)
    {
      double v = -12345.0;
      try
      {
        v = GCPnts_AbscissaPoint::Length(ad, p.u1, p.u2);
        printf("    A %s -> %-18s Swift: %s\n", p.label, fmt(v).c_str(), swiftSees(v).c_str());
      }
      catch (const Standard_Failure& e)
      {
        printf("    A %s -> THROW %-12s Swift: nil\n", p.label, e.GetMessageString());
      }
    }
    printf("\n");
  }

  // --- 2D fixtures -----------------------------------------------------------------------
  std::vector<Curve2DFixture> f2;
  f2.push_back({"segment (trimmed line)",
                new Geom2d_TrimmedCurve(new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0, 10)});
  f2.push_back({"circle", new Geom2d_Circle(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 5.0)});
  f2.push_back({"bspline (5-pt interpolated)", interpolated2D()});

  for (size_t i = 0; i < f2.size(); ++i)
  {
    Geom2dAdaptor_Curve ad(f2[i].curve);
    const double        f = ad.FirstParameter();
    const double        l = ad.LastParameter();
    printf("--- 2D %s\n", f2[i].name.c_str());
    printf("    domain [%s, %s], NbIntervals(CN)=%d, whole length=%s\n",
           fmt(f).c_str(), fmt(l).c_str(), ad.NbIntervals(GeomAbs_CN),
           fmt(GCPnts_AbscissaPoint::Length(ad)).c_str());

    struct Probe { const char* label; double u1; double u2; };
    const double span = l - f;
    const Probe probes[] = {
      {"(f, l)          valid whole    ", f, l},
      {"(f, nan)        NaN upper      ", f, NAN_},
      {"(nan, l)        NaN lower      ", NAN_, l},
      {"(f, +inf)       inf upper      ", f, INF_},
      {"(-inf, +inf)    both inf       ", -INF_, INF_},
      {"(f, l+span)     past the end   ", f, l + span},
    };
    for (const Probe& p : probes)
    {
      // B: range-taking overload (OCCTCurve2DGetLengthBetween)
      try
      {
        double v = GCPnts_AbscissaPoint::Length(ad, p.u1, p.u2);
        printf("    B %s -> %-18s Swift: %s\n", p.label, fmt(v).c_str(), swiftSees(v).c_str());
      }
      catch (const Standard_Failure& e)
      {
        printf("    B %s -> THROW %-12s Swift: nil\n", p.label, e.GetMessageString());
      }
      // C: pre-bounded adaptor ctor (OCCTCurve2DLength -> Curve2D.arcLength(from:to:))
      try
      {
        Geom2dAdaptor_Curve bounded(f2[i].curve, p.u1, p.u2);
        double              v = GCPnts_AbscissaPoint::Length(bounded);
        printf("    C %s -> %-18s Swift: %s\n", p.label, fmt(v).c_str(), swiftSees(v).c_str());
      }
      catch (const Standard_Failure& e)
      {
        printf("    C %s -> THROW %-12s Swift: -1.0\n", p.label, e.GetMessageString());
      }
    }
    printf("\n");
  }

  // --- D: edge (BRepAdaptor_Curve), Shape.edgeArcLength(from:to:) -------------------------
  {
    TopoDS_Edge straight = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge spline   = BRepBuilderAPI_MakeEdge(interpolated3D());
    struct EdgeFixture { const char* name; TopoDS_Edge edge; };
    EdgeFixture edges[] = {{"straight edge", straight}, {"bspline edge", spline}};
    for (const EdgeFixture& e : edges)
    {
      BRepAdaptor_Curve ad(e.edge);
      const double      f = ad.FirstParameter();
      const double      l = ad.LastParameter();
      printf("--- edge %s: domain [%s, %s], NbIntervals(CN)=%d, whole=%s\n", e.name,
             fmt(f).c_str(), fmt(l).c_str(), ad.NbIntervals(GeomAbs_CN),
             fmt(GCPnts_AbscissaPoint::Length(ad)).c_str());
      struct Probe { const char* label; double u1; double u2; };
      const Probe probes[] = {
        {"(f, nan)     NaN upper ", f, NAN_},
        {"(nan, l)     NaN lower ", NAN_, l},
        {"(-inf, +inf) both inf  ", -INF_, INF_},
      };
      for (const Probe& p : probes)
      {
        try
        {
          double v = GCPnts_AbscissaPoint::Length(ad, p.u1, p.u2);
          // Shape.edgeArcLength returns the raw double; the bridge's catch(...) returns 0.
          printf("    D %s -> %-18s Swift: %s\n", p.label, fmt(v).c_str(), fmt(v).c_str());
        }
        catch (const Standard_Failure& ex)
        {
          printf("    D %s -> THROW %-12s Swift: 0\n", p.label, ex.GetMessageString());
        }
      }
    }
    printf("\n");
  }

  // --- The mechanism, checked directly ----------------------------------------------------
  printf("--- std::min/std::max NaN semantics (the composite branch's bound handling)\n");
  printf("    std::min(3.0, nan) = %s   std::max(3.0, nan) = %s\n",
         fmt(std::min(3.0, NAN_)).c_str(), fmt(std::max(3.0, NAN_)).c_str());
  printf("    std::min(nan, 3.0) = %s   std::max(nan, 3.0) = %s\n",
         fmt(std::min(NAN_, 3.0)).c_str(), fmt(std::max(NAN_, 3.0)).c_str());
  return 0;
}
