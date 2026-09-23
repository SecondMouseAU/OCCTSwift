// Epic #766 (#1978), kernel parity for the three Integration files, Issue1020ExtremaBoundsTests
// and Issue1399LawKnotSplitFactoryReachTests: the same inputs driven straight through OCCT, so the
// values the rewritten tests pin come from the kernel and not from the bridge under test.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Extrema_ExtPElC.hxx>
#include <GProp_GProps.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Law_BSpFunc.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <Law_Constant.hxx>
#include <Law_Interpol.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cmath>
#include <cstdio>
#include <gp_Lin.hxx>
#include <gp_Parab.hxx>

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

int main()
{
  // Geodesic: sphere R = 30, UV-straight polyline of 200 segments between 30% and 70% of the domain.
  {
    Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(gp_Ax3(), 30.0);
    double u0, u1, v0, v1;
    s->Bounds(u0, u1, v0, v1);
    double ua = u0 + 0.3 * (u1 - u0), va = v0 + 0.3 * (v1 - v0);
    double ub = u0 + 0.7 * (u1 - u0), vb = v0 + 0.7 * (v1 - v0);
    gp_Pnt prev = s->Value(ua, va), a = prev, b = s->Value(ub, vb);
    double len  = 0;
    for (int i = 1; i <= 200; i++)
    {
      double t = i / 200.0;
      gp_Pnt p = s->Value(ua + t * (ub - ua), va + t * (vb - va));
      len += prev.Distance(p);
      prev = p;
    }
    printf("sphere domain u [%.17g, %.17g] v [%.17g, %.17g]\n", u0, u1, v0, v1);
    printf("sphere polyline length %.17g chord %.17g\n", len, a.Distance(b));
  }
  // Golden box 10 x 20 x 30.
  {
    TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    GProp_GProps sp;
    BRepGProp::SurfaceProperties(b, sp);
    TopTools_IndexedMapOfShape f, e, v;
    TopExp::MapShapes(b, TopAbs_FACE, f);
    TopExp::MapShapes(b, TopAbs_EDGE, e);
    TopExp::MapShapes(b, TopAbs_VERTEX, v);
    printf("box volume %.17g area %.17g faces %d edges %d vertices %d\n", volume(b), sp.Mass(),
           f.Extent(), e.Extent(), v.Extent());
  }
  // Gear: cylinder R 20 h 10, six 6 x 2 x 10 slots at radius 15, a through bore of radius 5.
  {
    TopoDS_Shape cur = BRepPrimAPI_MakeCylinder(20, 10).Shape();
    double       v0  = volume(cur);
    for (int i = 0; i < 6; i++)
    {
      double       ang = i * (M_PI / 3.0);
      double       cx = 15 * cos(ang), cy = 15 * sin(ang);
      TopoDS_Shape slot = BRepPrimAPI_MakeBox(gp_Pnt(cx - 3, cy - 1, 0), 6, 2, 10).Shape();
      cur               = BRepAlgoAPI_Cut(cur, slot).Shape();
    }
    double       afterSlots = volume(cur);
    TopoDS_Shape bore =
      BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 10), gp_Dir(0, 0, -1)), 5, 100).Shape();
    cur = BRepAlgoAPI_Cut(cur, bore).Shape();
    printf("gear hub %.17g after slots %.17g final %.17g analytic %.17g\n", v0, afterSlots,
           volume(cur), 3750 * M_PI - 720);
  }
  // #1020 line and parabola, over the full range and over the old clipped bounds.
  {
    gp_Lin l(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    for (auto p : {gp_Pnt(2e10, 3, 0), gp_Pnt(7, 4, 0)})
    {
      Extrema_ExtPElC full(p, l, 1e-6, RealFirst(), RealLast());
      Extrema_ExtPElC old(p, l, 1e-6, -1e10, 1e10);
      printf("line p.x=%g full: done %d n %d", p.X(), full.IsDone(), full.IsDone() ? full.NbExt() : -1);
      if (full.IsDone() && full.NbExt() > 0)
        printf(" sq %.17g foot.x %.17g", full.SquareDistance(1), full.Point(1).Value().X());
      printf(" | old bound: done %d n %d\n", old.IsDone(), old.IsDone() ? old.NbExt() : -1);
    }
    struct Q
    {
      gp_Pnt p;
      double f;
    } qs[] = {{gp_Pnt(0, 1e7, 0), 1e6}, {gp_Pnt(10, 0, 0), 2}};
    for (auto q : qs)
    {
      gp_Parab        pb(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), q.f);
      Extrema_ExtPElC full(q.p, pb, 1e-6, RealFirst(), RealLast());
      Extrema_ExtPElC old(q.p, pb, 1e-6, -1e6, 1e6);
      printf("parabola F=%g p=(%g,%g) full: done %d n %d\n", q.f, q.p.X(), q.p.Y(), full.IsDone(),
             full.IsDone() ? full.NbExt() : -1);
      for (int i = 1; full.IsDone() && i <= full.NbExt(); i++)
      {
        gp_Pnt f = full.Point(i).Value();
        printf("  ext %d sq %.17g foot (%.17g, %.17g, %.17g) u %.17g\n", i, full.SquareDistance(i),
               f.X(), f.Y(), f.Z(), full.Point(i).Parameter());
      }
      printf("  old bound: done %d n %d\n", old.IsDone(), old.IsDone() ? old.NbExt() : -1);
    }
  }
  // #1399: which Law_Function subclasses DownCast to Law_BSpFunc.
  {
    Handle(Law_S) s = new Law_S();
    s->Set(0, 0, 1, 1);
    Handle(Law_Constant) c = new Law_Constant();
    c->Set(2.0, 0, 1);
    Handle(Law_Linear) ln = new Law_Linear();
    ln->Set(0, 0, 1, 1);
    Handle(Law_Function) laws[] = {s, c, ln};
    const char*          names[] = {"Law_S", "Law_Constant", "Law_Linear"};
    for (int i = 0; i < 3; i++)
    {
      Handle(Law_BSpFunc) b = Handle(Law_BSpFunc)::DownCast(laws[i]);
      printf("%s is Law_BSpFunc: %d", names[i], !b.IsNull());
      if (!b.IsNull())
        for (int o = 0; o <= 3; o++)
          printf(" | C%d splits %d", o, Law_BSplineKnotSplitting(b->Curve(), o).NbSplits());
      printf("\n");
    }
  }
  return 0;
}
