// Epic #766, GeomFill{Frenet,Generator,Gordon,GordonReport}Tests.swift: kernel parity.
//  - GeomFill_Frenet / GeomFill_ConstantBiNormal(+Z) / GeomFill_Fixed D0 at 0 on edge 0 of
//    BRepPrimAPI_MakeCylinder(10, 5) (OCCTGeomFillFrenetTrihedron, ...ConstantBiNormalTrihedron,
//    ...FixedTrihedron)
//  - GeomFill_Generator on 2 and 3 coaxial circles, Perform(1e-6) (OCCTGeomFillGenerator)
//  - GeomFill_Gordon on the quarter-cylinder network (V-isos at 0, 5, 10 and U-isos at 0, pi/4,
//    pi/2 of a radius-5 cylinder trimmed to [0, pi/2] x [0, 10], as makeQuarterCylinderGordonNetwork
//    builds it) in ExactOnly and AllowApproximateFallback, and on the 3-point interpolated line
//    network (GeomAPI_Interpolate), reporting Status, IsApproximate and the reference points.
#include <BRepAdaptor_Curve.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomFill_ConstantBiNormal.hxx>
#include <GeomFill_Fixed.hxx>
#include <GeomFill_Frenet.hxx>
#include <GeomFill_Generator.hxx>
#include <GeomFill_Gordon.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <NCollection_Array1.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void frame(const char* tag, bool ok, const gp_Vec& t, const gp_Vec& n, const gp_Vec& b)
{
  printf("%s: ok=%d T=(%.12g, %.12g, %.12g) N=(%.12g, %.12g, %.12g) B=(%.12g, %.12g, %.12g)\n", tag, ok, t.X(), t.Y(),
         t.Z(), n.X(), n.Y(), n.Z(), b.X(), b.Y(), b.Z());
}

static Handle(Geom_Curve) interp(std::vector<gp_Pnt> pts)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)pts.size());
  for (size_t i = 0; i < pts.size(); i++)
    a->SetValue((int)i + 1, pts[i]);
  GeomAPI_Interpolate in(a, false, 1e-6);
  in.Perform();
  return in.Curve();
}

static void gordonRun(const char* tag, NCollection_Array1<occ::handle<Geom_Curve>>& p,
                      NCollection_Array1<occ::handle<Geom_Curve>>& g, double tol, bool fallback, bool quarter)
{
  GeomFill_Gordon gd;
  gd.SetApproximationMode(fallback ? GeomFill_Gordon::ApproximationMode::AllowApproximateFallback
                                   : GeomFill_Gordon::ApproximationMode::ExactOnly);
  gd.Init(p, g, tol);
  gd.Perform();
  printf("%s: IsDone=%d Status=%d IsApproximate=%d", tag, gd.IsDone(), (int)gd.Status(), gd.IsApproximate());
  if (gd.IsDone())
  {
    Handle(Geom_BSplineSurface) s = Handle(Geom_BSplineSurface)::DownCast(gd.Surface());
    double                      u1, u2, v1, v2;
    gd.Surface()->Bounds(u1, u2, v1, v2);
    if (!s.IsNull())
      printf(" URational=%d VRational=%d", s->IsURational(), s->IsVRational());
    double fr[3] = {0, 0.5, 1};
    double worst = 0;
    for (double f : fr)
    {
      gp_Pnt q = gd.Surface()->Value(u1 + (u2 - u1) * f, v1 + (v2 - v1) * f);
      if (quarter)
      {
        double a = f * M_PI / 2;
        worst    = std::max(worst, q.Distance(gp_Pnt(5 * std::cos(a), 5 * std::sin(a), f * 10)));
      }
      printf(" S(%g,%g)=(%.12g, %.12g, %.12g)", f, f, q.X(), q.Y(), q.Z());
    }
    printf(" corners: (%.9g,%.9g,%.9g) (%.9g,%.9g,%.9g)", gd.Surface()->Value(u2, v1).X(), gd.Surface()->Value(u2, v1).Y(),
           gd.Surface()->Value(u2, v1).Z(), gd.Surface()->Value(u1, v2).X(), gd.Surface()->Value(u1, v2).Y(),
           gd.Surface()->Value(u1, v2).Z());
    if (quarter)
      printf(" max|S - reference| over (0,0),(.5,.5),(1,1)=%.3g", worst);
  }
  printf("\n");
}

int main()
{
  printf("GeomFill_Gordon::ResultStatus: NotStarted=%d Done=%d InvalidInput=%d\n",
         (int)GeomFill_Gordon::ResultStatus::NotStarted, (int)GeomFill_Gordon::ResultStatus::Done,
         (int)GeomFill_Gordon::ResultStatus::InvalidInput);
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 5).Shape();
    TopTools_IndexedMapOfShape em;
    TopExp::MapShapes(cyl, TopAbs_EDGE, em);
    Handle(BRepAdaptor_Curve) ad = new BRepAdaptor_Curve(TopoDS::Edge(em(1)));
    gp_Vec                    t, n, b;
    Handle(GeomFill_Frenet)   fr = new GeomFill_Frenet();
    fr->SetCurve(ad);
    frame("frenetOnEdge edge 0 at 0", fr->D0(0, t, n, b), t, n, b);
    Handle(GeomFill_ConstantBiNormal) cb = new GeomFill_ConstantBiNormal(gp_Dir(0, 0, 1));
    cb->SetCurve(ad);
    frame("constantBiNormal edge 0 at 0 (+Z)", cb->D0(0, t, n, b), t, n, b);
    Handle(GeomFill_Fixed) fx = new GeomFill_Fixed(gp_Vec(1, 0, 0), gp_Vec(0, 1, 0));
    frame("fixedTrihedron", fx->D0(0, t, n, b), t, n, b);
  }
  {
    auto circ = [](double z, double r) { return new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1)), r); };
    for (int k = 2; k <= 3; k++)
    {
      GeomFill_Generator gen;
      gen.AddCurve(circ(0, 1.0));
      gen.AddCurve(circ(2, 1.5));
      if (k == 3)
        gen.AddCurve(circ(4, 0.5));
      gen.Perform(1e-6);
      Handle(Geom_Surface) s = gen.Surface();
      double               u1, u2, v1, v2;
      s->Bounds(u1, u2, v1, v2);
      gp_Pnt m = s->Value((u1 + u2) / 2, (v1 + v2) / 2);
      printf("generator %d sections: %s bounds=[%.12g, %.12g]x[%.12g, %.12g] S(mid)=(%.12g, %.12g, %.12g) S(u1,v2)=(%.12g, %.12g, %.12g)\n", k,
             s->DynamicType()->Name(), u1, u2, v1, v2, m.X(), m.Y(), m.Z(), s->Value(u1, v2).X(), s->Value(u1, v2).Y(),
             s->Value(u1, v2).Z());
    }
  }
  {
    Handle(Geom_RectangularTrimmedSurface) q = new Geom_RectangularTrimmedSurface(
      Handle(Geom_Surface)(new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5)), 0.0, M_PI / 2, 0.0, 10.0, true, true);
    NCollection_Array1<occ::handle<Geom_Curve>> p(0, 2), g(0, 2);
    double                                      hv[3] = {0, 5, 10}, au[3] = {0, M_PI / 4, M_PI / 2};
    for (int i = 0; i < 3; i++)
    {
      p.SetValue(i, q->VIso(hv[i]));
      g.SetValue(i, q->UIso(au[i]));
    }
    gordonRun("quarterCylinder ExactOnly tol 1e-6", p, g, 1e-6, false, true);
    gordonRun("quarterCylinder AllowApproximateFallback tol 1e-6", p, g, 1e-6, true, true);
  }
  {
    NCollection_Array1<occ::handle<Geom_Curve>> p(0, 1), g(0, 1);
    p.SetValue(0, interp({gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0), gp_Pnt(10, 0, 0)}));
    p.SetValue(1, interp({gp_Pnt(0, 10, 0), gp_Pnt(5, 10, 0), gp_Pnt(10, 10, 0)}));
    g.SetValue(0, interp({gp_Pnt(0, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(0, 10, 0)}));
    g.SetValue(1, interp({gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(10, 10, 0)}));
    gordonRun("gordonFromLineNetwork tol 1e-3", p, g, 1e-3, false, false);
  }
  {
    NCollection_Array1<occ::handle<Geom_Curve>> p(0, 0), g(0, 0);
    p.SetValue(0, interp({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)}));
    g.SetValue(0, p.Value(0));
    try
    {
      gordonRun("one profile, one guide (unguarded)", p, g, 1e-6, false, false);
    }
    catch (Standard_Failure& e)
    {
      printf("one profile, one guide (unguarded): threw %s\n", e.GetMessageString());
    }
  }
  return 0;
}
