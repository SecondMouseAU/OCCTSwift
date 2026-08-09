// #539 sweep: current Curve3D path (ShapeAnalysis_Curve::Project) vs current Edge path
// (GeomAPI ranged) vs the proposed candidate-minimum, all against brute-force truth.
#include <cstdio>
#include <cmath>
#include <vector>
#include <string>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <Precision.hxx>
#include <gp_Ax2.hxx>

struct Ans { double param, dist; bool valid; };

// --- current Curve3D path -------------------------------------------------
static Ans currentCurve3D(const Handle(Geom_Curve)& c, const gp_Pnt& p) {
  ShapeAnalysis_Curve sac; gp_Pnt proj; double param = 0;
  double d = sac.Project(c, p, 1e-6, proj, param, true);
  return {param, d, true};
}

// --- current Edge path ----------------------------------------------------
static Ans currentEdge(const Handle(Geom_Curve)& c, const gp_Pnt& p) {
  double f = c->FirstParameter(), l = c->LastParameter();
  try {
    GeomAPI_ProjectPointOnCurve proj(p, c, f, l);
    if (proj.NbPoints() == 0) return {0, 0, false};
    return {proj.LowerDistanceParameter(), proj.LowerDistance(), true};
  } catch (...) { return {0, 0, false}; }
}

// --- proposed: candidate minimum over [f, l] ------------------------------
// Mirrors what the bridge would do.
static Ans proposed(const Handle(Geom_Curve)& c, const gp_Pnt& p, double preci) {
  double f = c->FirstParameter(), l = c->LastParameter();
  bool fFinite = !Precision::IsInfinite(f), lFinite = !Precision::IsInfinite(l);

  double bestT = 0, bestD = RealLast();
  bool have = false;
  auto consider = [&](double t) {
    if (fFinite && t < f) return;
    if (lFinite && t > l) return;
    gp_Pnt pt;
    try { pt = c->Value(t); } catch (...) { return; }
    double d = p.Distance(pt);
    if (d < bestD) { bestD = d; bestT = t; have = true; }
  };

  // 1. whatever ShapeAnalysis_Curve found, if it landed inside the domain
  ShapeAnalysis_Curve sac; gp_Pnt sproj; double sparam = 0;
  double sdist = sac.Project(c, p, preci, sproj, sparam, true);
  consider(sparam);

  // 2. every extremum GeomAPI finds inside the domain
  try {
    GeomAPI_ProjectPointOnCurve pc(p, c, f, l);
    for (int i = 1; i <= pc.NbPoints(); i++) consider(pc.Parameter(i));
  } catch (...) {}

  // 3. the domain's own ends, where they are finite
  if (fFinite) consider(f);
  if (lFinite) consider(l);

  if (!have) return {sparam, sdist, true};   // unbounded and no extremum: keep the old answer
  return {bestT, bestD, true};
}

// --- truth ----------------------------------------------------------------
static Ans truth(const Handle(Geom_Curve)& c, const gp_Pnt& p) {
  double f = c->FirstParameter(), l = c->LastParameter();
  if (Precision::IsInfinite(f) || Precision::IsInfinite(l)) return {0, 0, false};
  const int N = 400001; double best = RealLast(), bestT = f;
  for (int i = 0; i < N; i++) {
    double t = f + (l - f) * i / (N - 1);
    double d = p.Distance(c->Value(t));
    if (d < best) { best = d; bestT = t; }
  }
  // polish
  double step = (l - f) / (N - 1);
  for (int it = 0; it < 60; it++) {
    double a = fmax(f, bestT - step), b = fmin(l, bestT + step);
    for (int i = 0; i <= 100; i++) {
      double t = a + (b - a) * i / 100.0;
      double d = p.Distance(c->Value(t));
      if (d < best) { best = d; bestT = t; }
    }
    step *= 0.3;
  }
  return {bestT, best, true};
}

static int nCur3D = 0, nEdge = 0, nProp = 0, nTot = 0;

static void run(const std::string& name, const Handle(Geom_Curve)& c, const std::vector<gp_Pnt>& qs) {
  printf("\n%s   domain [%.6g, %.6g]\n", name.c_str(), c->FirstParameter(), c->LastParameter());
  for (auto& p : qs) {
    Ans a = currentCurve3D(c, p), b = currentEdge(c, p), d = proposed(c, p, 1e-6), t = truth(c, p);
    if (!t.valid) { printf("  (%.3g,%.3g,%.3g) unbounded, truth skipped\n", p.X(), p.Y(), p.Z()); continue; }
    nTot++;
    bool okA = fabs(a.dist - t.dist) <= 1e-6 * (1 + t.dist);
    bool okB = b.valid && fabs(b.dist - t.dist) <= 1e-6 * (1 + t.dist);
    bool okD = fabs(d.dist - t.dist) <= 1e-6 * (1 + t.dist);
    if (okA) nCur3D++;
    if (okB) nEdge++;
    if (okD) nProp++;
    printf("  (%7.3g,%7.3g,%7.3g) truth %10.6g | Curve3D %10.6g %s | Edge %10s %s | proposed %10.6g %s\n",
           p.X(), p.Y(), p.Z(), t.dist,
           a.dist, okA ? "ok " : "BAD",
           b.valid ? (std::to_string(b.dist).substr(0,10)).c_str() : "nil",
           okB ? "ok " : (b.valid ? "BAD" : "nil"),
           d.dist, okD ? "ok " : "BAD");
  }
}

int main() {
  gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0,0,0), gp_Dir(1,0,0));
  Handle(Geom_Circle) circ = new Geom_Circle(ax, 5);

  TColgp_Array1OfPnt pts(1, 5);
  pts.SetValue(1, gp_Pnt(0,0,0)); pts.SetValue(2, gp_Pnt(1,2,0));
  pts.SetValue(3, gp_Pnt(3,3,0)); pts.SetValue(4, gp_Pnt(5,1,0));
  pts.SetValue(5, gp_Pnt(7,0,0));
  Handle(Geom_BSplineCurve) bspl = GeomAPI_PointsToBSpline(pts).Curve();

  TColgp_Array1OfPnt poles(1, 4);
  poles.SetValue(1, gp_Pnt(0,0,0)); poles.SetValue(2, gp_Pnt(1,3,0));
  poles.SetValue(3, gp_Pnt(4,3,0)); poles.SetValue(4, gp_Pnt(6,0,0));
  Handle(Geom_BezierCurve) bez = new Geom_BezierCurve(poles);

  run("trimmed line [3,8]", new Geom_TrimmedCurve(line, 3, 8),
      {gp_Pnt(100,0,0), gp_Pnt(0,0,0), gp_Pnt(5,2,0), gp_Pnt(-50,3,0), gp_Pnt(3,4,0), gp_Pnt(8,-1,0), gp_Pnt(8.001,0,0)});

  run("half arc [0,pi] r=5", new Geom_TrimmedCurve(circ, 0, M_PI),
      {gp_Pnt(0,-6,0), gp_Pnt(0,6,0), gp_Pnt(0,0,0), gp_Pnt(6,0,0), gp_Pnt(-6,0,0), gp_Pnt(3,-4,0), gp_Pnt(0,-1,0)});

  run("quarter arc [0,pi/2] r=5", new Geom_TrimmedCurve(circ, 0, M_PI/2),
      {gp_Pnt(0,-6,0), gp_Pnt(-6,0,0), gp_Pnt(4,4,0), gp_Pnt(0,0,0)});

  run("seam arc [5.5,7.0] r=5", new Geom_TrimmedCurve(circ, 5.5, 7.0),
      {gp_Pnt(6*cos(0.3), 6*sin(0.3), 0), gp_Pnt(6*cos(3.0), 6*sin(3.0), 0), gp_Pnt(0,0,0)});

  run("full circle r=5", circ,
      {gp_Pnt(0,0,0), gp_Pnt(6,0,0), gp_Pnt(0,-9,0), gp_Pnt(0,0,4)});

  run("ellipse arc [0,pi] a=8 b=4", new Geom_TrimmedCurve(new Geom_Ellipse(ax, 8, 4), 0, M_PI),
      {gp_Pnt(0,-6,0), gp_Pnt(0,6,0), gp_Pnt(9,0,0), gp_Pnt(0,0,0)});

  run("parabola [0,2] f=2", new Geom_TrimmedCurve(new Geom_Parabola(ax, 2.0), 0, 2),
      {gp_Pnt(20,0,0), gp_Pnt(0,3,0), gp_Pnt(-5,1,0), gp_Pnt(1,1,0)});

  run("hyperbola [0,1] 3/2", new Geom_TrimmedCurve(new Geom_Hyperbola(ax, 3, 2), 0, 1),
      {gp_Pnt(30,0,0), gp_Pnt(0,5,0), gp_Pnt(4,1,0)});

  run("bezier [0.4,0.6]", new Geom_TrimmedCurve(bez, 0.4, 0.6),
      {gp_Pnt(6,0,0), gp_Pnt(0,0,0), gp_Pnt(3,5,0)});

  run("bspline full", bspl,
      {gp_Pnt(7,0,0), gp_Pnt(3,5,0), gp_Pnt(-3,0,0)});

  run("bspline [0.4,0.6]", new Geom_TrimmedCurve(bspl, 0.4*(bspl->LastParameter()-bspl->FirstParameter())+bspl->FirstParameter(),
                                                  0.6*(bspl->LastParameter()-bspl->FirstParameter())+bspl->FirstParameter()),
      {gp_Pnt(7,0,0), gp_Pnt(0,0,0), gp_Pnt(3,5,0)});

  run("offset(trimmed line) [3,8] d=2",
      new Geom_OffsetCurve(new Geom_TrimmedCurve(line, 3, 8), 2.0, gp_Dir(0,0,1)),
      {gp_Pnt(100,0,0), gp_Pnt(0,0,0), gp_Pnt(5,5,0)});

  run("offset(arc) [0,pi] d=1",
      new Geom_OffsetCurve(new Geom_TrimmedCurve(circ, 0, M_PI), 1.0, gp_Dir(0,0,1)),
      {gp_Pnt(0,-9,0), gp_Pnt(0,9,0), gp_Pnt(0,0,0)});

  printf("\n=========================================================\n");
  printf("correct distances: Curve3D(now) %d/%d   Edge(now) %d/%d   proposed %d/%d\n",
         nCur3D, nTot, nEdge, nTot, nProp, nTot);
  return 0;
}
