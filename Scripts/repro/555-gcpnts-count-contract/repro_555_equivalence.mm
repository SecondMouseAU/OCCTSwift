// OCCTSwift#555 equivalence harness: fingerprint GCPnts_UniformAbscissa and
// GCPnts_QuasiUniformAbscissa across a battery of curves and point counts, so a stock run and a
// patched run can be diffed line for line.

#include <Adaptor3d_Curve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax2.hxx>

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

struct Case
{
  std::string        name;
  Handle(Geom_Curve) curve;
  double             u1, u2;
};

static Handle(Geom_BezierCurve) bezier(int nbPoles, bool coincident)
{
  TColgp_Array1OfPnt poles(1, nbPoles);
  for (int i = 1; i <= nbPoles; ++i)
    poles.SetValue(i, coincident ? gp_Pnt(1, 1, 1) : gp_Pnt(i, (i % 2) ? 2.0 : -1.0, 0));
  return new Geom_BezierCurve(poles);
}

static Handle(Geom_BSplineCurve) bsplineFit(int n)
{
  TColgp_Array1OfPnt pts(1, n);
  for (int i = 1; i <= n; ++i)
    pts.SetValue(i, gp_Pnt(i * 1.3, (i % 3) * 0.7, (i % 5) * 0.2));
  GeomAPI_PointsToBSpline fit(pts);
  return fit.Curve();
}

static std::vector<Case> battery()
{
  std::vector<Case> cs;
  auto              add = [&](const std::string& n, const Handle(Geom_Curve) & c, double a, double b) {
    cs.push_back({n, c, a, b});
  };

  add("line", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 2, 3)), 0.0, 17.0);
  for (double r : {1.0e-6, 1.0, 1.0e3, 1.0e7})
  {
    char nm[64];
    snprintf(nm, sizeof(nm), "circle_r%g", r);
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r);
    add(nm, c, c->FirstParameter(), c->LastParameter());
  }
  // The pathological one: the walk lands outside the parametric epsilon near the end.
  Handle(Geom_Ellipse) badEll =
    new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0e6, 1.0e-3);
  add("ellipse_1e6x1e-3", badEll, badEll->FirstParameter(), badEll->LastParameter());
  Handle(Geom_Ellipse) okEll = new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0, 2.0);
  add("ellipse_5x2", okEll, okEll->FirstParameter(), okEll->LastParameter());
  add("hyperbola", new Geom_Hyperbola(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0, 2.0), -1.0, 1.0);
  add("parabola", new Geom_Parabola(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0), -4.0, 4.0);

  Handle(Geom_BezierCurve) b4 = bezier(4, false);
  add("bezier4", b4, b4->FirstParameter(), b4->LastParameter());
  Handle(Geom_BezierCurve) b2 = bezier(2, false);
  add("bezier2", b2, b2->FirstParameter(), b2->LastParameter());
  Handle(Geom_BSplineCurve) bs8 = bsplineFit(8);
  add("bspline8", bs8, bs8->FirstParameter(), bs8->LastParameter());
  Handle(Geom_BSplineCurve) bs40 = bsplineFit(40);
  add("bspline40", bs40, bs40->FirstParameter(), bs40->LastParameter());

  Handle(Geom_Circle) oc = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 6.0);
  Handle(Geom_OffsetCurve) off = new Geom_OffsetCurve(oc, 1.5, gp_Dir(0, 0, 1));
  add("offset_circle", off, off->FirstParameter(), off->LastParameter());
  Handle(Geom_OffsetCurve) offb = new Geom_OffsetCurve(bs8, 0.4, gp_Dir(0, 0, 1));
  add("offset_bspline", offb, offb->FirstParameter(), offb->LastParameter());

  Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(oc, 0.3, 4.1);
  add("trimmed_circle", tr, tr->FirstParameter(), tr->LastParameter());

  // Half-period slices of the pathological ellipse, where the local derivative is largest.
  add("ellipse_bad_firsthalf", badEll, 0.0, 3.14159265358979);
  return cs;
}

// A compact, order-sensitive digest of the parameter list.
static uint64_t digest(const std::vector<double>& v)
{
  uint64_t h = 1469598103934665603ull;
  for (double d : v)
  {
    uint64_t b;
    std::memcpy(&b, &d, sizeof(b));
    h ^= b;
    h *= 1099511628211ull;
  }
  return h;
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  const std::vector<Case> cs = battery();
  for (const Case& c : cs)
  {
    GeomAdaptor_Curve ad(c.curve);
    for (int n = 2; n <= 200; ++n)
    {
      for (int which = 0; which < 2; ++which)
      {
        std::vector<double> ps;
        bool                done = false;
        int                 nb   = -1;
        if (which == 0)
        {
          GCPnts_UniformAbscissa a(ad, n, c.u1, c.u2);
          done = a.IsDone();
          if (done)
          {
            nb = a.NbPoints();
            for (int i = 1; i <= nb; ++i)
              ps.push_back(a.Parameter(i));
          }
        }
        else
        {
          GCPnts_QuasiUniformAbscissa a(ad, n, c.u1, c.u2);
          done = a.IsDone();
          if (done)
          {
            nb = a.NbPoints();
            for (int i = 1; i <= nb; ++i)
              ps.push_back(a.Parameter(i));
          }
        }
        printf("%-22s %-6s n=%-4d done=%d nb=%-4d excess=%-3d first=%.17g last=%.17g h=%016llx\n",
               c.name.c_str(), which == 0 ? "UA" : "QUA", n, (int)done, nb,
               done ? nb - n : 0, ps.empty() ? 0.0 : ps.front(), ps.empty() ? 0.0 : ps.back(),
               (unsigned long long)digest(ps));
      }
    }
  }
  printf("DONE\n");
  return 0;
}
