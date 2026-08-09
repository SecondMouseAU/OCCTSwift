// #539 probe 2: (1) can Project return an out-of-domain periodic representative when an
// in-domain one exists? (2) which curve types take the range-ignoring analytic path?
// (3) does the Edge path (GeomAPI, ranged) report a maximum as "nearest"?
#include <cstdio>
#include <cmath>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRep_Tool.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>

static void line1(const char* tag, const Handle(Geom_Curve)& c, const gp_Pnt& p) {
  ShapeAnalysis_Curve sac;
  gp_Pnt proj; double param = -999;
  double d = sac.Project(c, p, 1e-6, proj, param, true);
  double f = c->FirstParameter(), l = c->LastParameter();
  double cl = param < f ? f : (param > l ? l : param);
  gp_Pnt pc = c->Value(cl);
  // truth
  const int N = 1000001; double best = 1e300, bestT = f;
  for (int i = 0; i < N; i++) {
    double t = f + (l - f) * i / (N - 1);
    double dd = p.Distance(c->Value(t));
    if (dd < best) { best = dd; bestT = t; }
  }
  printf("  %-26s domain[%.4g,%.4g] raw(param=%.6g dist=%.6g) clamped(param=%.6g dist=%.6g) truth(param=%.6g dist=%.6g)%s\n",
         tag, f, l, param, d, cl, p.Distance(pc), bestT, best,
         fabs(p.Distance(pc) - best) < 1e-6 ? "" : "   <-- CLAMP WRONG");
}

int main() {
  printf("=== 1. periodic wrap: does Project ever return an out-of-domain representative\n");
  printf("       when an in-domain one exists? ===\n");
  {
    Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 5);
    // domain straddling the seam negatively: [-1, 1]
    Handle(Geom_Curve) arc = new Geom_TrimmedCurve(circ, -1.0, 1.0);
    printf("  arc trimmed [-1, 1] (IsPeriodic=%d)\n", (int)arc->IsPeriodic());
    for (double ang : {6.0, 5.5, 0.5, 2.0, 3.2}) {
      char tag[80]; snprintf(tag, sizeof tag, "query angle %.2f", ang);
      line1(tag, arc, gp_Pnt(6*cos(ang), 6*sin(ang), 0));
    }
    // domain wholly beyond one period: [7, 9]  (== angles 0.717 .. 2.717)
    Handle(Geom_Curve) arc2 = new Geom_TrimmedCurve(circ, 7.0, 9.0);
    printf("  arc trimmed [7, 9]\n");
    for (double ang : {1.5, 0.717, 2.717, 4.5, 6.0}) {
      char tag[80]; snprintf(tag, sizeof tag, "query angle %.2f", ang);
      line1(tag, arc2, gp_Pnt(6*cos(ang), 6*sin(ang), 0));
    }
  }

  printf("\n=== 2. which curve types ignore the trim range? ===\n");
  {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    struct Case { const char* name; Handle(Geom_Curve) basis; double a, b; gp_Pnt q; };
    Handle(Geom_Curve) bez;
    {
      TColgp_Array1OfPnt poles(1, 4);
      poles.SetValue(1, gp_Pnt(0,0,0)); poles.SetValue(2, gp_Pnt(1,3,0));
      poles.SetValue(3, gp_Pnt(4,3,0)); poles.SetValue(4, gp_Pnt(6,0,0));
      bez = new Geom_BezierCurve(poles);
    }
    TColgp_Array1OfPnt pts(1, 5);
    pts.SetValue(1, gp_Pnt(0,0,0)); pts.SetValue(2, gp_Pnt(1,2,0));
    pts.SetValue(3, gp_Pnt(3,3,0)); pts.SetValue(4, gp_Pnt(5,1,0));
    pts.SetValue(5, gp_Pnt(7,0,0));
    Handle(Geom_Curve) bspl = GeomAPI_PointsToBSpline(pts).Curve();

    Case cases[] = {
      {"line [3,8]",      new Geom_Line(gp_Pnt(0,0,0), gp_Dir(1,0,0)), 3, 8,            gp_Pnt(100, 0, 0)},
      {"circle [0,pi]",   new Geom_Circle(ax, 5),                      0, M_PI,         gp_Pnt(0, -6, 0)},
      {"ellipse [0,pi]",  new Geom_Ellipse(ax, 8, 4),                  0, M_PI,         gp_Pnt(0, -6, 0)},
      {"parabola [0,2]",  new Geom_Parabola(ax, 2.0),                  0, 2,            gp_Pnt(20, 0, 0)},
      {"hyperbola [0,1]", new Geom_Hyperbola(ax, 3, 2),                0, 1,            gp_Pnt(30, 0, 0)},
      {"bezier [.4,.6]",  bez,                                         0.4, 0.6,        gp_Pnt(6, 0, 0)},
      {"bspline [.4,.6]", bspl,                                        0.4, 0.6,        gp_Pnt(7, 0, 0)},
    };
    for (auto& c : cases) {
      Handle(Geom_Curve) t = new Geom_TrimmedCurve(Handle(Geom_BoundedCurve)::DownCast(c.basis).IsNull()
                                                   ? c.basis : c.basis, c.a, c.b);
      GeomAdaptor_Curve ad(t);
      char tag[80]; snprintf(tag, sizeof tag, "%s", c.name);
      line1(tag, t, c.q);
    }
    // offset curve over a trimmed line
    Handle(Geom_Curve) baseSeg = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0,0,0), gp_Dir(1,0,0)), 3, 8);
    Handle(Geom_Curve) off = new Geom_OffsetCurve(baseSeg, 2.0, gp_Dir(0,0,1));
    line1("offset(line) [3,8]", off, gp_Pnt(100, 0, 0));
  }

  printf("\n=== 3. Edge path (GeomAPI ranged): does it report a maximum as nearest? ===\n");
  {
    Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 5);
    TopoDS_Edge e = BRepBuilderAPI_MakeEdge(circ, 0.0, M_PI);
    double first, last;
    Handle(Geom_Curve) c = BRep_Tool::Curve(e, first, last);
    printf("  half-circle edge, BRep_Tool first=%.4g last=%.4g\n", first, last);
    for (gp_Pnt p : {gp_Pnt(0,-6,0), gp_Pnt(0,6,0), gp_Pnt(0,-1,0)}) {
      GeomAPI_ProjectPointOnCurve proj(p, c, first, last);
      double truthBest = 1e300, truthT = first;
      for (int i = 0; i <= 1000000; i++) {
        double t = first + (last - first) * i / 1000000.0;
        double d = p.Distance(c->Value(t));
        if (d < truthBest) { truthBest = d; truthT = t; }
      }
      if (proj.NbPoints() == 0) {
        printf("    (%.4g,%.4g,%.4g): NbPoints=0 -> isValid=false;   truth param=%.6g dist=%.6g\n",
               p.X(), p.Y(), p.Z(), truthT, truthBest);
      } else {
        printf("    (%.4g,%.4g,%.4g): NbPoints=%d param=%.6g dist=%.6g;   truth param=%.6g dist=%.6g%s\n",
               p.X(), p.Y(), p.Z(), proj.NbPoints(), proj.LowerDistanceParameter(), proj.LowerDistance(),
               truthT, truthBest,
               fabs(proj.LowerDistance() - truthBest) < 1e-6 ? "" : "   <-- NOT the nearest");
      }
    }
  }
  printf("\ndone\n");
  return 0;
}
