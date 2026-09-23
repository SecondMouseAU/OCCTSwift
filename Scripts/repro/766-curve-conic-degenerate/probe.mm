// Epic #766 (#1978), kernel parity for Issue554Conic3dDegenerateTests.swift: what the unguarded
// kernel does with each degenerate conic the bridge now refuses, and with the inputs the kernel
// refuses on its own (negative / inverted radii, the three-point forms), which the tests rely on.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BndLib.hxx>
#include <Bnd_Box.hxx>
#include <ElCLib.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <GC_MakeArcOfHyperbola.hxx>
#include <GC_MakeArcOfParabola.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Parabola.hxx>
#include <cmath>
#include <cstdio>
#include <functional>

static void tryit(const char* name, const std::function<int()>& f)
{
  try
  {
    printf("%s: %d\n", name, f());
  }
  catch (Standard_Failure& e)
  {
    printf("%s: throws %s\n", name, e.what());
  }
}

int main()
{
  gp_Ax2 ax;
  tryit("GC_MakeArcOfEllipse (0,0) IsDone", [&] { return (int)GC_MakeArcOfEllipse(gp_Elips(ax, 0, 0), 0, M_PI, true).IsDone(); });
  tryit("GC_MakeArcOfEllipse (5,0) IsDone", [&] { return (int)GC_MakeArcOfEllipse(gp_Elips(ax, 5, 0), 0, M_PI, true).IsDone(); });
  tryit("gp_Elips (5,-3)", [&] { gp_Elips e(ax, 5, -3); return 1; });
  tryit("gp_Elips (3,5)", [&] { gp_Elips e(ax, 3, 5); return 1; });
  tryit("GC_MakeArcOfEllipse (5,0) two-point, first param is NaN", [&] {
    GC_MakeArcOfEllipse m(gp_Elips(ax, 5, 0), gp_Pnt(5, 0, 0), gp_Pnt(-5, 0, 0), true);
    return m.IsDone() ? (int)std::isnan(m.Value()->FirstParameter()) : -1;
  });
  tryit("GC_MakeArcOfHyperbola (5,0) IsDone", [&] { return (int)GC_MakeArcOfHyperbola(gp_Hypr(ax, 5, 0), 0, 1, true).IsDone(); });
  tryit("GC_MakeArcOfHyperbola (3,5) IsDone", [&] { return (int)GC_MakeArcOfHyperbola(gp_Hypr(ax, 3, 5), 0, 1, true).IsDone(); });
  tryit("GC_MakeArcOfParabola focal 0 IsDone", [&] { return (int)GC_MakeArcOfParabola(gp_Parab(ax, 0), 0, 1, true).IsDone(); });
  tryit("GC_MakeEllipse (5,0) IsDone", [&] { return (int)GC_MakeEllipse(ax, 5, 0).IsDone(); });
  tryit("GC_MakeHyperbola (0,5) IsDone", [&] { return (int)GC_MakeHyperbola(ax, 0, 5).IsDone(); });
  tryit("GC_MakeEllipse 3pt coincident IsDone", [&] { return (int)GC_MakeEllipse(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0)).IsDone(); });
  tryit("GC_MakeEllipse 3pt S2 on axis IsDone", [&] { return (int)GC_MakeEllipse(gp_Pnt(5, 0, 0), gp_Pnt(2, 0, 0), gp_Pnt(0, 0, 0)).IsDone(); });
  tryit("GC_MakeEllipse 3pt healthy IsDone", [&] { return (int)GC_MakeEllipse(gp_Pnt(5, 0, 0), gp_Pnt(0, 3, 0), gp_Pnt(0, 0, 0)).IsDone(); });
  tryit("GC_MakeHyperbola 3pt coincident IsDone", [&] { return (int)GC_MakeHyperbola(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0)).IsDone(); });
  tryit("MakeEdge gp_Elips (5,0) IsDone", [&] { return (int)BRepBuilderAPI_MakeEdge(gp_Elips(ax, 5, 0)).IsDone(); });
  tryit("MakeEdge gp_Parab focal 0 arc IsDone", [&] { return (int)BRepBuilderAPI_MakeEdge(gp_Parab(ax, 0), 0, 1).IsDone(); });
  tryit("Geom_Ellipse(5,3)::SetMinorRadius(0) accepted", [&] { Handle(Geom_Ellipse) e = new Geom_Ellipse(ax, 5, 3); e->SetMinorRadius(0); return 1; });
  tryit("Geom_Ellipse(5,3)::SetMajorRadius(1)", [&] { Handle(Geom_Ellipse) e = new Geom_Ellipse(ax, 5, 3); e->SetMajorRadius(1); return 1; });
  tryit("Geom_Hyperbola(5,3)::SetMajorRadius(0) accepted", [&] { Handle(Geom_Hyperbola) h = new Geom_Hyperbola(ax, 5, 3); h->SetMajorRadius(0); return 1; });
  tryit("Geom_Parabola(2)::SetFocal(0) accepted", [&] { Handle(Geom_Parabola) p = new Geom_Parabola(ax, 2); p->SetFocal(0); return 1; });
  tryit("Geom_Circle(5)::SetRadius(0) accepted", [&] { Handle(Geom_Circle) c = new Geom_Circle(ax, 5); c->SetRadius(0); return 1; });
  gp_Pnt v = ElCLib::Value(1.0, gp_Elips(ax, 5, 0));
  printf("ElCLib::Value(1, elips(5,0)) = (%.17g, %.3g, %.3g), 5cos(1) = %.17g\n", v.X(), v.Y(), v.Z(), 5 * cos(1.0));
  Bnd_Box b;
  BndLib::Add(gp_Elips(ax, 5, 0), 0, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("BndLib elips(5,0): x [%.9g, %.9g] y [%.3g, %.3g]\n", x0, x1, y0, y1);
  return 0;
}
