// #1979 evidence-fix pass for OCCTGeom2dTests: the kernel side of the 49 parity records whose two
// sides carried different keys. Every line starting "EF " is `EF <record>.<key> = <json>`, read by
// the record generator; the other lines are the human-readable measurement it comes from.
//
// Each measurement makes the OCCT calls the bridge function under test makes, with the same inputs
// as the test: the constructors, the solver classes, the same tolerances. The bridge side of each
// key is what the test itself observes (printed by a temporary, uncommitted test run).
#include <BRepBuilderAPI_MakeEdge2d.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Bisector_Bisec.hxx>
#include <Bisector_BisecPC.hxx>
#include <Bisector_Inter.hxx>
#include <Convert_CircleToBSplineCurve.hxx>
#include <Convert_CompBezierCurves2dToBSplineCurve2d.hxx>
#include <Extrema_ExtPElC2d.hxx>
#include <GC_MakeCircle2d.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GccAna_Circ2d3Tan.hxx>
#include <GccAna_Circ2dBisec.hxx>
#include <GccAna_CircPnt2dBisec.hxx>
#include <GccAna_Pnt2dBisec.hxx>
#include <GccEnt.hxx>
#include <GccEnt_QualifiedCirc.hxx>
#include <Geom2dAPI_ExtremaCurveCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GeomAbs_CurveType.hxx>
#include <Geom_Plane.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <IntRes2d_IntersectionSegment.hxx>
#include <IntTools_FClass2d.hxx>
#include <NCollection_Array1.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TopAbs_State.hxx>
#include <TopoDS_Face.hxx>
#include <gce_MakeCirc2d.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Lin2d.hxx>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

static std::string num(double v)
{
  char b[64];
  if (!std::isfinite(v))
  {
    snprintf(b, sizeof b, "\"%s\"", std::isnan(v) ? "nan" : (v > 0 ? "inf" : "-inf"));
    return b;
  }
  snprintf(b, sizeof b, "%.12g", v);
  return b;
}
static std::string str(const std::string& s)
{
  return "\"" + s + "\"";
}
static std::string boolean(bool b)
{
  return b ? "true" : "false";
}
static void ef(const char* rec, const char* key, const std::string& json)
{
  printf("EF %s.%s = %s\n", rec, key, json.c_str());
}
// The format Geom2dEval results are compared in: "(x, y)" at 12 significant digits.
static std::string pt(double x, double y)
{
  char b[128];
  snprintf(b, sizeof b, "(%.12g, %.12g)", x, y);
  return b;
}

static const gp_Ax2d AX(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));

// How a Geom2dEval_* construction followed by EvalD0(0.5) ends.
template <class F> static std::string howEval(F make)
{
  try
  {
    auto c = make();
    try
    {
      gp_Pnt2d p = c.EvalD0(0.5);
      return (std::isfinite(p.X()) && std::isfinite(p.Y())) ? "finite point" : "non-finite point";
    }
    catch (Standard_Failure&)
    {
      return "EvalD0 raised";
    }
  }
  catch (Standard_Failure&)
  {
    return "constructor raised";
  }
}

int main()
{
  // ---- R01 CompBezier: 60 chained cubics, no capacity limit in the kernel ----------------------
  {
    Convert_CompBezierCurves2dToBSplineCurve2d conv;
    for (int i = 0; i < 60; i++)
    {
      double                       x = i * 3;
      NCollection_Array1<gp_Pnt2d> seg(1, 4);
      seg(1) = gp_Pnt2d(x, 0);
      seg(2) = gp_Pnt2d(x + 1, 1);
      seg(3) = gp_Pnt2d(x + 2, -1);
      seg(4) = gp_Pnt2d(x + 3, 0);
      conv.AddCurve(seg);
    }
    conv.Perform();
    printf("Convert_CompBezierCurves2dToBSplineCurve2d, 60 cubics: poles=%d knots=%d\n", conv.NbPoles(), conv.NbKnots());
    ef("R01", "nb_poles", std::to_string(conv.NbPoles()));
    ef("R01", "nb_knots", std::to_string(conv.NbKnots()));
  }

  // ---- R02 approximated(): Geom2dConvert_ApproxCurve on the tolerance-sensitive zigzag ---------
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 60);
    for (int i = 0; i < 60; i++)
      pts->SetValue(i + 1, gp_Pnt2d(i * 0.5, sin(i * 0.6) * 3.0 + sin(i * 1.3) * 0.6));
    Geom2dAPI_Interpolate interp(pts, false, 1e-6);
    interp.Perform();
    Handle(Geom2d_BSplineCurve) orig = interp.Curve();
    Geom2dConvert_ApproxCurve   ap(orig, 1e-3, GeomAbs_C2, 100, 8);
    Handle(Geom2d_BSplineCurve) fit = ap.Curve();
    double                      f = orig->FirstParameter(), l = orig->LastParameter(), dev = 0;
    for (int i = 0; i <= 300; i++)
    {
      double t = f + (l - f) * i / 300.0;
      dev      = std::max(dev, orig->Value(t).Distance(fit->Value(t)));
    }
    printf("zigzag 60 points, ApproxCurve tol 1e-3 C2 100 8: done=%d MaxError=%.12g max sampled deviation (301 samples)=%.12g poles=%d\n",
           ap.IsDone(), ap.MaxError(), dev, fit->NbPoles());
    ef("R02", "max_sampled_deviation", num(dev));
    ef("R02", "kernel_max_error", num(ap.MaxError()));
  }

  // ---- R03 circle factories: what each OCCT construction does with radius 0, -1, -5 -------------
  {
    for (double r : {0.0, -1.0, -5.0})
    {
      bool direct = false, gce = false;
      try
      {
        Handle(Geom2d_Circle) c = new Geom2d_Circle(AX, r);
        direct                  = true;
      }
      catch (Standard_Failure&)
      {
      }
      try
      {
        gce_MakeCirc2d mc(gp_Pnt2d(0, 0), r);
        gce = mc.IsDone();
      }
      catch (Standard_Failure&)
      {
      }
      printf("radius %g: Geom2d_Circle(ax, r) constructs=%d gce_MakeCirc2d IsDone=%d\n", r, direct, gce);
      const char* suffix = r == 0 ? "r0" : (r == -1 ? "rm1" : "rm5");
      ef("R03", (std::string("direct_") + suffix).c_str(), boolean(direct));
      ef("R03", (std::string("gce_") + suffix).c_str(), boolean(gce));
    }
  }

  // ---- R04/R05 circle involute constructor -------------------------------------------------------
  for (double r : {0.0, -1.0})
  {
    std::string how = howEval([&] { return Geom2dEval_CircleInvoluteCurve(AX, r); });
    printf("Geom2dEval_CircleInvoluteCurve radius %g: %s\n", r, how.c_str());
    ef(r == 0 ? "R04" : "R05", "yields_curve", boolean(how == "finite point"));
  }

  // ---- R06 Approximate circle as BSpline ---------------------------------------------------------
  {
    Handle(Geom2d_Circle)     c5 = new Geom2d_Circle(AX, 5);
    Geom2dConvert_ApproxCurve a(c5, 1e-3, GeomAbs_C2, 100, 8);
    printf("circle r5 ApproxCurve tol 1e-3 C2 100 8: degree=%d poles=%d\n", a.Curve()->Degree(), a.Curve()->NbPoles());
    ef("R06", "degree", std::to_string(a.Curve()->Degree()));
    ef("R06", "poles", std::to_string(a.Curve()->NbPoles()));
  }

  // ---- R07..R09 #1407 evaluator guards -----------------------------------------------------------
  {
    std::string a = howEval([] { return Geom2dEval_SineWaveCurve(AX, 0, 1, 0); });
    std::string b = howEval([] { return Geom2dEval_CircleInvoluteCurve(AX, 0); });
    std::string c = howEval([] { return Geom2dEval_ArchimedeanSpiralCurve(AX, 1, 0); });
    printf("#1407: sine amplitude 0: %s; involute radius 0: %s; archimedean growth 0: %s\n", a.c_str(), b.c_str(), c.c_str());
    ef("R07", "yields_point", boolean(a == "finite point"));
    ef("R08", "yields_point", boolean(b == "finite point"));
    ef("R09", "yields_point", boolean(c == "finite point"));
  }

  // ---- R10/R11 #1477 join: what the raw joiner does after a failed Add ---------------------------
  {
    auto seg = [](double x0, double y0, double x1, double y1) {
      return Geom2dConvert::CurveToBSplineCurve(GCE2d_MakeSegment(gp_Pnt2d(x0, y0), gp_Pnt2d(x1, y1)).Value());
    };
    Geom2dConvert_CompCurveToBSplineCurve g;
    bool g1 = g.Add(seg(0, 0, 1, 0), 1e-6), g2 = g.Add(seg(50, 50, 51, 50), 1e-6);
    bool gy = !g.BSplineCurve().IsNull();
    printf("gapped: Add=[%d, %d] joiner still yields a curve=%d (poles=%d)\n", g1, g2, gy, gy ? g.BSplineCurve()->NbPoles() : 0);
    ef("R10", "yields_curve", boolean(gy));
    Geom2dConvert_CompCurveToBSplineCurve o;
    bool o1 = o.Add(seg(0, 0, 1, 0), 1e-6), o2 = o.Add(seg(1, 1, 0, 1), 1e-6), o3 = o.Add(seg(1, 0, 1, 1), 1e-6);
    bool oy = !o.BSplineCurve().IsNull();
    printf("out of order: Add=[%d, %d, %d] joiner still yields a curve=%d (poles=%d)\n", o1, o2, o3, oy, oy ? o.BSplineCurve()->NbPoles() : 0);
    ef("R11", "yields_curve", boolean(oy));
  }

  // ---- R12 #1511: the enum constant the null-handle fallback has to equal ------------------------
  printf("GeomAbs_OffsetCurve=%d GeomAbs_OtherCurve=%d\n", (int)GeomAbs_OffsetCurve, (int)GeomAbs_OtherCurve);
  ef("R12", "curve_type_ordinal", std::to_string((int)GeomAbs_OtherCurve));

  // R13: both cases have A = B = (5, 5), so the first step of the bridge sequence raises at once and
  // its message can be read in-process: the perpendicular of the zero vector A->B, normalised.
  try
  {
    gp_Vec2d vAB(5 - 5, 5 - 5);
    gp_Vec2d perpAB(-vAB.Y(), vAB.X());
    gp_Vec2d v1 = perpAB;
    v1.Normalize();
    printf("R13 replay: no exception\n");
  }
  catch (Standard_Failure& e)
  {
    printf("R13 replay, A = B: gp_Vec2d::Normalize on the perpendicular of the zero vector raises: %s\n", e.what());
  }
  fflush(stdout);

  // ---- R13, R14..R26: the bisector point-point sequence, each case in its own child --------------
  // The child replays OCCTBisectorInterPointPoint: two Bisector_Bisec, a Bisector_Inter over each
  // bisector's own range, and the bridge's catch(...) returning no points. Exit code: the number of
  // points (segment end points included), or 250 when the sequence raised. A child killed by the
  // 10 s alarm is a hang.
  struct Case
  {
    std::string rec, key;
    double      v[8];
  };
  std::vector<Case> cases;
  const double      base[8] = {0, 0, 0, 10, -55, 0, -45, 0};
  const char*       coord[8] = {"a_x", "a_y", "b_x", "b_y", "c_x", "c_y", "d_x", "d_y"};
  auto add = [&](const std::string& rec, const std::string& key, int idx, double val) {
    Case c;
    c.rec = rec;
    c.key = key;
    for (int i = 0; i < 8; i++)
      c.v[i] = base[i];
    if (idx >= 0)
      c.v[idx] = val;
    cases.push_back(c);
  };
  {
    Case c;
    c.rec = "R13";
    c.key = "a_eq_b";
    double w[8] = {5, 5, 5, 5, -55, 0, -45, 0};
    for (int i = 0; i < 8; i++)
      c.v[i] = w[i];
    cases.push_back(c);
    c.key = "a_eq_b_and_c_eq_d";
    double w2[8] = {5, 5, 5, 5, -3, -3, -3, -3};
    for (int i = 0; i < 8; i++)
      c.v[i] = w2[i];
    cases.push_back(c);
  }
  const double nan = std::nan(""), inf = INFINITY;
  const char*  nanIds[4]  = {"R14", "R15", "R16", "R17"};
  const char*  pinfIds[4] = {"R18", "R19", "R20", "R21"};
  const char*  ninfIds[4] = {"R22", "R23", "R24", "R25"};
  for (int p = 0; p < 4; p++)
    for (int k = 0; k < 2; k++)
    {
      add(nanIds[p], coord[2 * p + k], 2 * p + k, nan);
      add(pinfIds[p], coord[2 * p + k], 2 * p + k, inf);
      add(ninfIds[p], coord[2 * p + k], 2 * p + k, -inf);
    }
  for (int i = 0; i < 8; i++)
    add("R26", coord[i], i, 1e200);
  add("R26", "neg_a_x", 0, -1e200);
  add("R26", "neg_a_y", 1, -1e200);

  std::vector<pid_t> pids;
  for (auto& c : cases)
  {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0)
    {
      alarm(10);
      int code = 0;
      try
      {
        auto bis = [](Bisector_Bisec& b, double ax, double ay, double bx, double by) {
          Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
          Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
          gp_Vec2d                      v(bx - ax, by - ay);
          gp_Vec2d                      perp(-v.Y(), v.X());
          gp_Vec2d                      v1 = perp;
          v1.Normalize();
          gp_Vec2d v2 = perp.Reversed();
          v2.Normalize();
          b.Perform(pA, pB, gp_Pnt2d((ax + bx) / 2, (ay + by) / 2), v1, v2, 1.0, 1e-6);
          return !b.Value().IsNull();
        };
        Bisector_Bisec b1, b2;
        if (!bis(b1, c.v[0], c.v[1], c.v[2], c.v[3]) || !bis(b2, c.v[4], c.v[5], c.v[6], c.v[7]))
          _exit(0);
        const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
        const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
        double f1 = c1->FirstParameter(), l1 = c1->LastParameter(), f2 = c2->FirstParameter(), l2 = c2->LastParameter();
        IntRes2d_Domain d1(c1->Value(f1), f1, 1e-6, c1->Value(l1), l1, 1e-6);
        IntRes2d_Domain d2(c2->Value(f2), f2, 1e-6, c2->Value(l2), l2, 1e-6);
        Bisector_Inter  in;
        in.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
        if (!in.IsDone())
          _exit(0);
        int n = in.NbPoints();
        if (n == 0)
          for (int i = 1; i <= in.NbSegments(); i++)
          {
            if (in.Segment(i).HasFirstPoint())
              n++;
            if (in.Segment(i).HasLastPoint())
              n++;
          }
        code = n > 200 ? 200 : n;
      }
      catch (Standard_Failure&)
      {
        code = 250;
      }
      _exit(code);
    }
    pids.push_back(pid);
  }
  for (size_t i = 0; i < cases.size(); i++)
  {
    int st = 0;
    waitpid(pids[i], &st, 0);
    std::string outcome, detail;
    if (WIFSIGNALED(st))
    {
      outcome = WTERMSIG(st) == SIGALRM ? "hang" : "crash";
      detail  = std::string("killed by signal ") + std::to_string(WTERMSIG(st));
    }
    else
    {
      int code = WEXITSTATUS(st);
      if (code == 250)
      {
        outcome = "no_points";
        detail  = "the sequence raised (the bridge catch returns 0)";
      }
      else if (code == 0)
      {
        outcome = "no_points";
        detail  = "0 points";
      }
      else
      {
        outcome = "points";
        detail  = std::to_string(code) + " points";
      }
    }
    auto& c = cases[i];
    printf("%s.%s inputs a=(%g,%g) b=(%g,%g) c=(%g,%g) d=(%g,%g): %s (%s)\n", c.rec.c_str(), c.key.c_str(), c.v[0], c.v[1], c.v[2],
           c.v[3], c.v[4], c.v[5], c.v[6], c.v[7], outcome.c_str(), detail.c_str());
    ef(c.rec.c_str(), c.key.c_str(), str(outcome));
  }
  fflush(stdout);

  // ---- R27..R30 #1646: what the Geom2dEval constructors and EvalD0/D1 do with these arguments ----
  {
    auto refused = [](auto make) { return howEval(make) != "finite point"; };
    ef("R27", "sine_amplitude_0", boolean(refused([] { return Geom2dEval_SineWaveCurve(AX, 0, 1, 0); })));
    ef("R27", "sine_omega_0", boolean(refused([] { return Geom2dEval_SineWaveCurve(AX, 1, 0, 0); })));
    ef("R27", "involute_radius_0", boolean(refused([] { return Geom2dEval_CircleInvoluteCurve(AX, 0); })));
    ef("R27", "archimedean_growth_0", boolean(refused([] { return Geom2dEval_ArchimedeanSpiralCurve(AX, 1, 0); })));
    ef("R27", "archimedean_initial_radius_minus1", boolean(refused([] { return Geom2dEval_ArchimedeanSpiralCurve(AX, -1, 0.1); })));
    ef("R27", "log_scale_0", boolean(refused([] { return Geom2dEval_LogarithmicSpiralCurve(AX, 0, 0.2); })));
    ef("R27", "log_growth_0", boolean(refused([] { return Geom2dEval_LogarithmicSpiralCurve(AX, 1, 0); })));

    const double nn = std::nan(""), ii = INFINITY;
    auto d0 = [](auto make, double u) {
      try
      {
        auto     c = make();
        gp_Pnt2d p = c.EvalD0(u);
        return pt(p.X(), p.Y());
      }
      catch (Standard_Failure&)
      {
        return std::string("raises");
      }
    };
    auto d1 = [](auto make, double u) {
      try
      {
        auto                c = make();
        Geom2d_Curve::ResD1 r = c.EvalD1(u);
        return pt(r.Point.X(), r.Point.Y()) + " " + pt(r.D1.X(), r.D1.Y());
      }
      catch (Standard_Failure&)
      {
        return std::string("raises");
      }
    };
    ef("R28", "sine_amplitude_nan", str(d0([&] { return Geom2dEval_SineWaveCurve(AX, nn, 1, 0); }, 0.5)));
    ef("R28", "sine_omega_nan", str(d0([&] { return Geom2dEval_SineWaveCurve(AX, 1, nn, 0); }, 0.5)));
    ef("R28", "sine_amplitude_inf", str(d0([&] { return Geom2dEval_SineWaveCurve(AX, ii, 1, 0); }, 0.5)));
    ef("R28", "involute_radius_nan", str(d0([&] { return Geom2dEval_CircleInvoluteCurve(AX, nn); }, 0.5)));
    ef("R28", "archimedean_initial_radius_nan", str(d0([&] { return Geom2dEval_ArchimedeanSpiralCurve(AX, nn, 0.1); }, 0.5)));
    ef("R28", "log_scale_nan", str(d0([&] { return Geom2dEval_LogarithmicSpiralCurve(AX, nn, 0.2); }, 0.5)));
    ef("R28", "sine_d1_amplitude_nan", str(d1([&] { return Geom2dEval_SineWaveCurve(AX, nn, 1, 0); }, 0.5)));
    ef("R29", "sine_u_nan", str(d0([&] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, nn)));
    ef("R29", "sine_u_inf", str(d0([&] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, ii)));
    ef("R29", "involute_d1_u_nan", str(d1([&] { return Geom2dEval_CircleInvoluteCurve(AX, 1); }, nn)));
    gp_Pnt2d lp = Geom2dEval_LogarithmicSpiralCurve(AX, 1, 1).EvalD0(1);
    ef("R30", "log_spiral_u1000", str(d0([&] { return Geom2dEval_LogarithmicSpiralCurve(AX, 1, 1); }, 1000)));
    ef("R30", "log_spiral_u1", "[" + num(lp.X()) + ", " + num(lp.Y()) + "]");
  }

  // ---- R32/R33 #549: GCPnts_AbscissaPoint over the full-curve adaptor, and the pre-bounded one ---
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 5);
    gp_Pnt2d                      p5[] = {{0, 0}, {10, 40}, {20, 0}, {200, 5}, {210, 60}};
    for (int i = 0; i < 5; i++)
      pts->SetValue(i + 1, p5[i]);
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    Handle(Geom2d_BSplineCurve) c = in.Curve();
    double                      f = c->FirstParameter(), l = c->LastParameter(), s = l - f;
    Geom2dAdaptor_Curve         whole(c);
    double                      over  = GCPnts_AbscissaPoint::Length(whole, f - s, l + s);
    double                      outsd = GCPnts_AbscissaPoint::Length(whole, l + 1, l + 2);
    Geom2dAdaptor_Curve         boundedOver(c, f - s, l + s), boundedOut(c, l + 1, l + 2);
    printf("multi-span curve domain [%.12g, %.12g]: full-curve adaptor over [f-span, l+span]=%.12g, over [l+1, l+2]=%.12g\n", f, l, over,
           outsd);
    printf("  pre-bounded adaptor over [f-span, l+span]=%.12g, over [l+1, l+2]=%.12g (the defect #549 removed)\n",
           GCPnts_AbscissaPoint::Length(boundedOver), GCPnts_AbscissaPoint::Length(boundedOut));
    ef("R32", "length", num(over));
    ef("R33", "length", num(outsd));
  }

  // ---- R34 #815: extrema between the two radius-5 circles 20 apart --------------------------------
  {
    Handle(Geom2d_Circle)       c1 = new Geom2d_Circle(AX, 5);
    Handle(Geom2d_Circle)       c2 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(20, 0), gp_Dir2d(1, 0)), 5);
    Geom2dAPI_ExtremaCurveCurve ext(c1, c2, 0, 2 * M_PI, 0, 2 * M_PI);
    std::vector<double>         d;
    for (int i = 1; i <= ext.NbExtrema(); i++)
      d.push_back(ext.Distance(i));
    std::sort(d.begin(), d.end());
    std::string arr = "[";
    for (size_t i = 0; i < d.size(); i++)
      arr += (i ? ", " : "") + num(d[i]);
    arr += "]";
    printf("Geom2dAPI_ExtremaCurveCurve: NbExtrema=%d sorted distances=%s\n", ext.NbExtrema(), arr.c_str());
    ef("R34", "nb_extrema", std::to_string(ext.NbExtrema()));
    ef("R34", "distances_sorted", arr);
  }

  // ---- R35 #840: IntTools_FClass2d on the 10x10 plane face at the default tolerance 1e-6 ----------
  {
    Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    TopoDS_Face        f  = BRepBuilderAPI_MakeFace(pl, 0, 10, 0, 10, 1e-7);
    IntTools_FClass2d  fc(f, 1e-6);
    TopAbs_State       st = fc.Perform(gp_Pnt2d(-5e-7, 5));
    const char*        nm = st == TopAbs_IN ? "IN" : (st == TopAbs_ON ? "ON" : (st == TopAbs_OUT ? "OUT" : "UNKNOWN"));
    printf("IntTools_FClass2d tol 1e-6 at (-5e-7, 5): %s\n", nm);
    ef("R35", "state_at_default_tolerance", str(nm));
  }

  // ---- R36 #881: gp_Ax2's canonical basis for the 15-degree normal --------------------------------
  {
    const double d15 = 15.0 * M_PI / 180.0;
    gp_Ax2       ax(gp_Pnt(0, 0, 0), gp_Dir(sin(d15) * 0.6, sin(d15) * 0.8, cos(d15)));
    char         b[256];
    snprintf(b, sizeof b, "[%.16g, %.16g, %.16g]", ax.XDirection().X(), ax.XDirection().Y(), ax.XDirection().Z());
    ef("R36", "u", b);
    snprintf(b, sizeof b, "[%.16g, %.16g, %.16g]", ax.YDirection().X(), ax.YDirection().Y(), ax.YDirection().Z());
    ef("R36", "v", b);
  }

  // ---- R37/R38 #999 ------------------------------------------------------------------------------
  {
    Handle(Geom2d_Circle) c5 = new Geom2d_Circle(AX, 5);
    for (int k : {1, 2})
    {
      bool        ok  = true;
      std::string how = "yields a curve";
      try
      {
        Handle(Geom2d_BSplineCurve) b = Geom2dConvert::CurveToBSplineCurve(c5, k == 1 ? Convert_TgtThetaOver2_1 : Convert_TgtThetaOver2_2);
        ok                            = !b.IsNull();
      }
      catch (Standard_Failure&)
      {
        ok  = false;
        how = "raised";
      }
      printf("CurveToBSplineCurve(circle r5, Convert_TgtThetaOver2_%d): %s\n", k, how.c_str());
      ef("R37", k == 1 ? "tangentHalfAngle1_yields_curve" : "tangentHalfAngle2_yields_curve", boolean(ok));
    }
    Handle(Geom2d_Line) xaxis = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    for (double md : {10.0, 100.0, 500.0, 5000.0})
    {
      Handle(Bisector_BisecPC) b = new Bisector_BisecPC();
      b->Perform(xaxis, gp_Pnt2d(0, 4), 1.0, md);
      double span = b->IsEmpty() ? -1 : b->LastParameter() - b->FirstParameter();
      printf("Bisector_BisecPC maxDistance %g: empty=%d span=%.12g\n", md, b->IsEmpty(), span);
      ef("R38", (std::string("span_maxDistance_") + std::to_string((int)md)).c_str(), num(span));
    }
    Handle(Bisector_BisecPC) b1 = new Bisector_BisecPC();
    b1->Perform(xaxis, gp_Pnt2d(0, 4), 1.0, 1.0);
    printf("Bisector_BisecPC maxDistance 1: empty=%d\n", b1->IsEmpty());
    ef("R38", "maxDistance_1_yields_curve", boolean(!b1->IsEmpty()));
  }

  // ---- R39..R49 #553 zero-radius circle arguments ----------------------------------------------
  {
    auto circ = [](double x, double y, double r) { return gp_Circ2d(gp_Ax2d(gp_Pnt2d(x, y), gp_Dir2d(1, 0)), r); };
    auto bisCC = [&](double r1, double r2) {
      GccAna_Circ2dBisec b(circ(0, 0, r1), circ(10, 0, r2));
      return b.IsDone() ? b.NbSolutions() : 0;
    };
    printf("GccAna_Circ2dBisec r0/r2=%d r3/r0=%d r0/r0=%d r3/r2=%d\n", bisCC(0, 2), bisCC(3, 0), bisCC(0, 0), bisCC(3, 2));
    ef("R39", "r0_r2", std::to_string(bisCC(0, 2)));
    ef("R39", "r3_r0", std::to_string(bisCC(3, 0)));
    ef("R39", "r0_r0", std::to_string(bisCC(0, 0)));
    ef("R40", "r3_r2", std::to_string(bisCC(3, 2)));

    GccAna_CircPnt2dBisec cp0(circ(0, 0, 0), gp_Pnt2d(6, 0));
    GccAna_CircPnt2dBisec cp2(circ(0, 0, 2), gp_Pnt2d(6, 0));
    GccAna_Pnt2dBisec     pp(gp_Pnt2d(0, 0), gp_Pnt2d(6, 0));
    gp_Lin2d              pl = pp.ThisSolution();
    printf("GccAna_CircPnt2dBisec r0=%d r2=%d; GccAna_Pnt2dBisec (0,0)-(6,0): line location x=%.12g direction x=%.12g\n",
           cp0.IsDone() ? cp0.NbSolutions() : 0, cp2.IsDone() ? cp2.NbSolutions() : 0, pl.Location().X(), pl.Direction().X());
    ef("R41", "circle_r0_point_solutions", std::to_string(cp0.IsDone() ? cp0.NbSolutions() : 0));
    ef("R41", "point_bisector_line_x", num(pl.Location().X()));
    ef("R41", "point_bisector_direction_x", num(std::abs(pl.Direction().X()) < 1e-12 ? 0.0 : pl.Direction().X()));
    ef("R41", "circle_r2_point_solutions", std::to_string(cp2.IsDone() ? cp2.NbSolutions() : 0));

    auto tan3 = [&](double r1) {
      GccAna_Circ2d3Tan s(GccEnt_QualifiedCirc(circ(0, 0, r1), GccEnt_unqualified), GccEnt_QualifiedCirc(circ(10, 0, 2), GccEnt_unqualified),
                          GccEnt_QualifiedCirc(circ(5, 8, 2), GccEnt_unqualified), 1e-6);
      return s.IsDone() ? s.NbSolutions() : 0;
    };
    printf("GccAna_Circ2d3Tan three circles: c1 r0=%d, c1 r2=%d\n", tan3(0), tan3(2));
    ef("R42", "r0_r2_r2", std::to_string(tan3(0)));
    ef("R42", "r2_r2_r2", std::to_string(tan3(2)));

    auto tanCPP = [&](double r) {
      GccAna_Circ2d3Tan s(GccEnt_QualifiedCirc(circ(0, 0, r), GccEnt_unqualified), gp_Pnt2d(10, 0), gp_Pnt2d(5, 8), 1e-6);
      return s.IsDone() ? s.NbSolutions() : 0;
    };
    printf("GccAna_Circ2d3Tan circle + two points: r0=%d r2=%d\n", tanCPP(0), tanCPP(2));
    ef("R43", "r0", std::to_string(tanCPP(0)));
    ef("R43", "r2", std::to_string(tanCPP(2)));

    auto lc = [&](double r, std::vector<double>* p2) {
      IntAna2d_AnaIntersection in(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), circ(0, 0, r));
      int                      n = (in.IsDone() && !in.IsEmpty()) ? in.NbPoints() : 0;
      for (int i = 1; p2 && i <= n; i++)
      {
        try
        {
          p2->push_back(in.Point(i).ParamOnSecond());
        }
        catch (Standard_Failure&)
        {
          p2->push_back(std::nan(""));
        }
      }
      return n;
    };
    std::vector<double> p20, p23;
    int                 n0 = lc(0, &p20), n3 = lc(3, &p23);
    bool                fin3 = !p23.empty();
    for (double v : p23)
      fin3 = fin3 && std::isfinite(v);
    printf("IntAna2d_AnaIntersection x-axis vs circle: r0 points=%d (ParamOnSecond raises: %d), r3 points=%d (ParamOnSecond finite=%d)\n", n0,
           (int)std::isnan(p20.empty() ? 0.0 : p20[0]), n3, fin3);
    ef("R44", "r0_points", std::to_string(n0));
    ef("R44", "r3_points", std::to_string(n3));
    ef("R44", "r3_param2_all_finite", boolean(fin3));

    auto cc = [&](double r1, double x2, double r2) {
      IntAna2d_AnaIntersection in(circ(0, 0, r1), circ(x2, 0, r2));
      return (in.IsDone() && !in.IsEmpty()) ? in.NbPoints() : 0;
    };
    printf("IntAna2d_AnaIntersection circle-circle: r0 vs (3,0) r3=%d; r3 vs (4,0) r3=%d\n", cc(0, 3, 3), cc(3, 4, 3));
    ef("R45", "r0_r3_points", std::to_string(cc(0, 3, 3)));
    ef("R45", "r3_r3_points", std::to_string(cc(3, 4, 3)));

    auto ext = [&](double r) {
      Extrema_ExtPElC2d e(gp_Pnt2d(0, 10), circ(0, 0, r), 1e-6, 0, 2 * M_PI);
      return e.IsDone() ? e.NbExt() : 0;
    };
    printf("Extrema_ExtPElC2d (0,10) to circle: r0=%d r3=%d\n", ext(0), ext(3));
    ef("R46", "r0_extrema", std::to_string(ext(0)));
    ef("R46", "r3_extrema", std::to_string(ext(3)));

    auto gceC = [&](double r) {
      try
      {
        return GC_MakeCircle2d(gp_Pnt2d(0, 0), r).IsDone();
      }
      catch (Standard_Failure&)
      {
        return false;
      }
    };
    auto gceA = [&](double r) {
      try
      {
        return GC_MakeCircle2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), r).IsDone();
      }
      catch (Standard_Failure&)
      {
        return false;
      }
    };
    printf("GC_MakeCircle2d(center, r) IsDone: r0=%d r3=%d; GC_MakeCircle2d(axis, r) IsDone: r0=%d r3=%d\n", gceC(0), gceC(3), gceA(0), gceA(3));
    ef("R47", "center_r0", boolean(gceC(0)));
    ef("R47", "center_r3", boolean(gceC(3)));
    ef("R47", "axis_r0", boolean(gceA(0)));
    ef("R47", "axis_r3", boolean(gceA(3)));

    auto par = [&](double r, double dist) {
      try
      {
        GC_MakeCircle2d m(circ(0, 0, r), dist);
        return m.IsDone() ? num(m.Value()->Radius()) : std::string("null");
      }
      catch (Standard_Failure&)
      {
        return std::string("null");
      }
    };
    printf("GC_MakeCircle2d(circle, dist) radius: r0 d3=%s r5 d-5=%s r5 d-6=%s r5 d-2=%s\n", par(0, 3).c_str(), par(5, -5).c_str(),
           par(5, -6).c_str(), par(5, -2).c_str());
    ef("R48", "r0_d3", par(0, 3));
    ef("R48", "r5_dm5", par(5, -5));
    ef("R48", "r5_dm6", par(5, -6));
    ef("R48", "r5_dm2", par(5, -2));

    // R49: the operation each of the five bridge calls reaches, with radius -1. "Refused" is an
    // exception, or IsDone false, or no result.
    // "refused" is an exception, or IsDone false, or no result; the mechanism is printed.
    auto how = [](auto op) -> std::string {
      try
      {
        return op() ? "yields a result" : "not done / empty";
      }
      catch (Standard_Failure&)
      {
        return "raised";
      }
    };
    std::string h1 = how([&] { GccAna_Circ2dBisec b(circ(0, 0, -1), circ(10, 0, 2)); return b.IsDone() && b.NbSolutions() > 0; });
    std::string h2 = how([&] { IntAna2d_AnaIntersection in(circ(0, 0, -1), circ(3, 0, 3)); return in.IsDone() && !in.IsEmpty(); });
    std::string h3 = how([&] { Extrema_ExtPElC2d e(gp_Pnt2d(0, 10), circ(0, 0, -1), 1e-6, 0, 2 * M_PI); return e.IsDone() && e.NbExt() > 0; });
    std::string h4 = how([&] { return GC_MakeCircle2d(gp_Pnt2d(0, 0), -1.0).IsDone(); });
    std::string h5 = how([&] { BRepBuilderAPI_MakeEdge2d me(circ(0, 0, -1), 0, M_PI); return me.IsDone(); });
    bool r1 = h1 != "yields a result", r2 = h2 != "yields a result", r3 = h3 != "yields a result", r4 = h4 != "yields a result",
         r5 = h5 != "yields a result";
    printf("radius -1: GccAna_Circ2dBisec %s; IntAna2d_AnaIntersection %s; Extrema_ExtPElC2d %s; GC_MakeCircle2d %s; BRepBuilderAPI_MakeEdge2d %s\n",
           h1.c_str(), h2.c_str(), h3.c_str(), h4.c_str(), h5.c_str());
    ef("R49", "circle_bisector", boolean(r1));
    ef("R49", "circle_circle_intersection", boolean(r2));
    ef("R49", "point_circle_extrema", boolean(r3));
    ef("R49", "gce_circle", boolean(r4));
    ef("R49", "edge2d_from_circle", boolean(r5));
  }
  return 0;
}
