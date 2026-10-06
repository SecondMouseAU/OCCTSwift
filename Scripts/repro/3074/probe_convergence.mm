// #3074 review: how many equal parameter spans occtAddEdgeLinearProperties needs on pathological
// curves, the residual left at the 1024-span cap, and whether BRepBuilderAPI_MakeEdge can refuse
// one of the spans the loop builds. Mirrors the loop in OCCTBridge_Properties.mm, with the same
// target (occtAdaptorArcLength) and the same 1e-12 relative test, and reports the residual against
// an independent Simpson integral of |C'(t)|.
#include "OCCTBridge.h"
#include "OCCTBridge_Internal.h"
#include <BRep_Builder.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <GeomConvert.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <cstdio>
#include <typeinfo>
#include <cmath>

static double simpson(const Handle(Geom_Curve)& c, double t0, double t1, double cx[3])
{
  const int n = 4000000;
  double    h = (t1 - t0) / n, L = 0;
  cx[0] = cx[1] = cx[2] = 0;
  for (int i = 0; i <= n; ++i)
  {
    double t = t0 + i * h, w = (i == 0 || i == n) ? 1 : (i % 2 ? 4 : 2);
    gp_Pnt p;
    gp_Vec d;
    c->D1(t, p, d);
    w *= h / 3 * d.Magnitude();
    L += w;
    cx[0] += w * p.X(); cx[1] += w * p.Y(); cx[2] += w * p.Z();
  }
  for (int k = 0; k < 3; ++k) cx[k] /= L;
  return L;
}

static void run(const char* name, const Handle(Geom_Curve)& c, double a, double b)
{
  TopoDS_Edge edge;
  BRep_Builder bb;
  bb.MakeEdge(edge, c, TopLoc_Location(), 1e-7);
  bb.Range(edge, a, b);
  BRepAdaptor_Curve adaptor(edge);
  double target = occtAdaptorArcLength(adaptor, adaptor.FirstParameter(), adaptor.LastParameter());
  double cxr[3];
  double ref = simpson(c, a, b, cxr);
  int    used = 0, failedAt = 0;
  GProp_GProps best;
  bool   met = false;
  for (int pieces = 1; pieces <= 1024; pieces *= 2)
  {
    GProp_GProps summed(gp_Pnt(0, 0, 0));
    bool         bad = false;
    for (int i = 0; i < pieces; ++i)
    {
      double lo = a + (b - a) * i / pieces;
      double hi = (i + 1 == pieces) ? b : a + (b - a) * (i + 1) / pieces;
      BRepBuilderAPI_MakeEdge mk(c, lo, hi);
      if (!mk.IsDone()) { bad = true; failedAt = pieces; break; }
      GProp_GProps piece;
      BRepGProp::LinearProperties(mk.Edge(), piece);
      summed.Add(piece);
    }
    if (bad) break;
    best = summed;
    used = pieces;
    if (std::abs(summed.Mass() - target) <= 1e-12 * std::max(target, 1.0)) { met = true; break; }
  }
  gp_Pnt g = best.CentreOfMass();
  printf("%-28s len %.6g spans %4d met1e-12 %d fail@%d | rel(len vs simpson) %+.2e rel(target vs simpson) %+.2e centroid err %.2e\n",
         name, ref, used, met, failedAt, best.Mass() / ref - 1, target / ref - 1,
         std::max({std::abs(g.X() - cxr[0]), std::abs(g.Y() - cxr[1]), std::abs(g.Z() - cxr[2])}));
}

int main()
{
  // High-degree BSpline, many poles, zigzag.
  for (int deg : {9, 25})
  {
    int                nb = 60;
    TColgp_Array1OfPnt poles(1, nb);
    for (int i = 1; i <= nb; ++i) poles(i) = gp_Pnt(i, (i % 2 ? 1.0 : -1.0) * (1 + 0.3 * sin(i)), 0.2 * cos(2.0 * i));
    int                nk = nb - deg + 1;
    TColStd_Array1OfReal    knots(1, nk);
    TColStd_Array1OfInteger mults(1, nk);
    for (int i = 1; i <= nk; ++i) { knots(i) = i - 1; mults(i) = 1; }
    mults(1) = mults(nk) = deg + 1;
    Handle(Geom_BSplineCurve) c = new Geom_BSplineCurve(poles, knots, mults, deg);
    char nm[64]; snprintf(nm, sizeof nm, "zigzag deg %d, 60 poles", deg);
    run(nm, c, c->FirstParameter(), c->LastParameter());
  }
  // Many-knot interpolated BSpline through a rapidly oscillating curve.
  for (int npts : {50, 200, 1000})
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, npts);
    for (int i = 1; i <= npts; ++i) { double t = (i - 1.0) / (npts - 1); pts->SetValue(i, gp_Pnt(10 * t, sin(80 * t) + 0.5 * sin(31 * t * t), 0.3 * cos(55 * t))); }
    GeomAPI_Interpolate interp(pts, false, 1e-9);
    interp.Perform();
    if (!interp.IsDone()) { printf("interpolate %d failed\n", npts); continue; }
    Handle(Geom_BSplineCurve) c = interp.Curve();
    char nm[64]; snprintf(nm, sizeof nm, "interpolated %d pts", npts);
    run(nm, c, c->FirstParameter(), c->LastParameter());
  }
  // Tiny parameter ranges (can MakeEdge refuse a span?).
  Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp::Origin(), gp::DZ(), gp::DX()), 10, 1);
  for (double w : {1e-3, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9})
  {
    char nm[64]; snprintf(nm, sizeof nm, "ellipse range %.0e", w);
    run(nm, e, 0.3, 0.3 + w);
  }
  Handle(Geom_Line) ln = new Geom_Line(gp::Origin(), gp::DX());
  for (double w : {1e-6, 1e-8, 1e-9})
  {
    char nm[64]; snprintf(nm, sizeof nm, "line range %.0e", w);
    run(nm, ln, 0, w);
  }
  // Direct refusal test.
  for (double w : {1e-6, 1e-7, 5e-8, 1e-8, 1e-9, 0.0})
  {
    BRepBuilderAPI_MakeEdge mk(e, 0.3, 0.3 + w);
    printf("MakeEdge(ellipse, 0.3, 0.3+%.0e) IsDone=%d\n", w, (int)mk.IsDone());
  }

  // Extreme eccentricity.
  for (double a : {10.0, 1e3, 1e5})
  {
    Handle(Geom_Ellipse) el = new Geom_Ellipse(gp_Ax2(gp::Origin(), gp::DZ(), gp::DX()), a, 1);
    char nm[64]; snprintf(nm, sizeof nm, "ellipse %.0e x 1 full", a);
    run(nm, el, 0, 2 * M_PI);
  }
  // Large-amplitude, many-pole degree 25 zigzag.
  for (int nb : {200, 800})
  {
    int deg = 25;
    TColgp_Array1OfPnt poles(1, nb);
    for (int i = 1; i <= nb; ++i) poles(i) = gp_Pnt(i * 0.01, (i % 2 ? 1.0 : -1.0) * 100, 0);
    int nk = nb - deg + 1;
    TColStd_Array1OfReal knots(1, nk);
    TColStd_Array1OfInteger mults(1, nk);
    for (int i = 1; i <= nk; ++i) { knots(i) = i - 1; mults(i) = 1; }
    mults(1) = mults(nk) = deg + 1;
    Handle(Geom_BSplineCurve) c = new Geom_BSplineCurve(poles, knots, mults, deg);
    char nm[64]; snprintf(nm, sizeof nm, "amp-100 zigzag deg25 %d poles", nb);
    run(nm, c, c->FirstParameter(), c->LastParameter());
  }
  // Direct refusal tests beyond the equal-split case.
  {
    Handle(Geom_Circle) ci = new Geom_Circle(gp_Ax2(gp::Origin(), gp::DZ()), 1);
    BRepBuilderAPI_MakeEdge m1(ci, 0, 4 * M_PI);
    printf("MakeEdge(circle, 0, 4pi) IsDone=%d\n", (int)m1.IsDone());
    BRepBuilderAPI_MakeEdge m1b(ci, 0, 2 * M_PI);
    printf("MakeEdge(circle, 0, 2pi) IsDone=%d\n", (int)m1b.IsDone());
    BRepBuilderAPI_MakeEdge m2(ln, 5, 3);
    printf("MakeEdge(line, 5, 3) IsDone=%d\n", (int)m2.IsDone());
    Handle(Geom_TrimmedCurve) tr = new Geom_TrimmedCurve(ln, 0, 1);
    BRepBuilderAPI_MakeEdge m3(tr, 0, 2);
    printf("MakeEdge(trimmed [0,1], 0, 2) IsDone=%d\n", (int)m3.IsDone());
    BRepBuilderAPI_MakeEdge m4(tr, 0.5, 0.5);
    printf("MakeEdge(trimmed [0,1], .5, .5) IsDone=%d\n", (int)m4.IsDone());
    try { BRepBuilderAPI_MakeEdge m5(tr, 0, 2); (void)m5.Edge(); printf("Edge() no throw\n"); }
    catch (Standard_Failure& f) { printf("Edge() threw %s\n", typeid(f).name()); }
  }

  // Where does MakeEdge start refusing? Narrow spans on a line, a trimmed line, an ellipse, a BSpline.
  {
    Handle(Geom_Line) l2 = new Geom_Line(gp::Origin(), gp::DX());
    Handle(Geom_TrimmedCurve) tr2 = new Geom_TrimmedCurve(l2, 0, 1);
    TColgp_Array1OfPnt pl(1, 2); pl(1) = gp_Pnt(0, 0, 0); pl(2) = gp_Pnt(1, 0, 0);
    Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(tr2);
    for (double w : {1e-6, 1e-8, 1e-10, 1e-12, 1e-14, 1e-16})
    {
      BRepBuilderAPI_MakeEdge a(l2, 0.5, 0.5 + w), b(tr2, 0.5, 0.5 + w), c(e, 0.5, 0.5 + w), d(bs, 0.5, 0.5 + w);
      printf("width %.0e: line %d trimmed %d ellipse %d bspline %d\n", w, (int)a.IsDone(), (int)b.IsDone(), (int)c.IsDone(), (int)d.IsDone());
    }
  }
}
