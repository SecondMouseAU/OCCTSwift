// Epic #766, SurfaceOperationsTests.swift, SurfacePipeTests.swift, SurfaceQueriesV123Tests.swift,
// SurfaceSingularityTests.swift, SurfaceSweptTests.swift and SurfaceToBezierTests.swift: kernel
// parity for the twenty tests. Also ShapeAnalysis_Surface NbSingularities / IsDegenerated,
// Geom_SurfaceOfLinearExtrusion / Geom_SurfaceOfRevolution, and
// GeomConvert_BSplineSurfaceToBezierSurface on bounded surfaces. Geom_Surface::Copy + Transform with the gp_Trsf each
// OCCTSurface* transform builds (occtBuildTrsf3D), Geom_RectangularTrimmedSurface,
// Geom_OffsetSurface, GeomFill_Pipe(path, radius) / (path, section) with Perform(true, false),
// and UPeriod / IsUPeriodic.
#include <GC_MakePlane.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <Standard_Failure.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomFill_Pipe.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_Surface) sph(gp_Pnt c, double r)
{
  return new Geom_SphericalSurface(gp_Ax3(c, gp::DZ()), r);
}

static void pt(const char* tag, const Handle(Geom_Surface)& s, double u, double v)
{
  gp_Pnt p = s->Value(u, v);
  printf("%s S(%g,%g)=(%.17g, %.17g, %.17g)\n", tag, u, v, p.X(), p.Y(), p.Z());
}

static Handle(Geom_Surface) tr(const Handle(Geom_Surface)& s, const gp_Trsf& t)
{
  Handle(Geom_Surface) c = Handle(Geom_Surface)::DownCast(s->Copy());
  c->Transform(t);
  return c;
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  Handle(Geom_Surface) s5 = sph(gp_Pnt(0, 0, 0), 5);
  double               u1, u2, v1, v2;
  s5->Bounds(u1, u2, v1, v2);
  Handle(Geom_Surface) t = new Geom_RectangularTrimmedSurface(s5, u1, (u1 + u2) / 2, v1, (v1 + v2) / 2);
  t->Bounds(u1, u2, v1, v2);
  printf("trimSurface: [%.17g, %.17g]x[%.17g, %.17g]\n", u1, u2, v1, v2);
  pt("offsetSurface", new Geom_OffsetSurface(s5, 2), 0, 0);
  gp_Trsf m;
  m.SetTranslation(gp_Vec(10, 0, 0));
  pt("translateSurface", tr(s5, m), 0, 0);
  m.SetScale(gp_Pnt(0, 0, 0), 2);
  pt("scaleSurface", tr(s5, m), 0, 0);
  Handle(Geom_Surface) s2 = sph(gp_Pnt(0, 0, 5), 2);
  m.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  pt("mirrorSurface original", s2, 0, 0);
  pt("mirrorSurface mirrored", tr(s2, m), 0, 0);
  Handle(Geom_Surface) s3 = sph(gp_Pnt(10, 0, 5), 5);
  m.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
  pt("rotateSurface", tr(s3, m), 0.3, 0.2);
  m.SetMirror(gp_Pnt(1, 2, 3));
  pt("mirrorPointSurface", tr(s2, m), 0.4, 0.1);
  m.SetMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  pt("mirrorAxisSurface", tr(sph(gp_Pnt(5, 0, 0), 2), m), M_PI / 4, M_PI / 6);

  Handle(Geom_Curve) path = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10)).Value();
  GeomFill_Pipe      p1(path, 2);
  p1.Perform(Standard_True, Standard_False);
  Handle(Geom_Surface) ps = p1.Surface();
  ps->Bounds(u1, u2, v1, v2);
  printf("pipeCircular: %s bounds=[%.17g, %.17g]x[%.17g, %.17g]\n", ps->DynamicType()->Name(), u1, u2, v1, v2);
  pt("  pipeCircular", ps, u1 + 0.3 * (u2 - u1), v1 + 0.6 * (v2 - v1));
  Handle(Geom_Curve) sec = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3);
  GeomFill_Pipe      p2(path, sec);
  p2.Perform(Standard_True, Standard_False);
  Handle(Geom_Surface) qs = p2.Surface();
  qs->Bounds(u1, u2, v1, v2);
  printf("pipeWithSection: %s bounds=[%.17g, %.17g]x[%.17g, %.17g]\n", qs->DynamicType()->Name(), u1, u2, v1, v2);
  pt("  pipeWithSection", qs, u1 + 0.3 * (u2 - u1), v1 + 0.6 * (v2 - v1));

  Handle(Geom_Surface) cyl   = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  Handle(Geom_Surface) plane = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  printf("cylinderUPeriod: %.17g  planePeriod: IsUPeriodic=%d IsVPeriodic=%d\n", cyl->UPeriod(), plane->IsUPeriodic(), plane->IsVPeriodic());
  {
    ShapeAnalysis_Surface ps(plane), ss(s5), cs(cyl);
    printf("singularities (1e-6): plane=%d sphere=%d cylinder=%d; sphere IsDegenerated((0,0,5), 0.1)=%d\n", ps.NbSingularities(1e-6),
           ss.NbSingularities(1e-6), cs.NbSingularities(1e-6), ss.IsDegenerated(gp_Pnt(0, 0, 5), 0.1));
  }
  {
    Handle(Geom_Curve)   line = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
    Handle(Geom_Surface) ext  = new Geom_SurfaceOfLinearExtrusion(line, gp_Dir(0, 0, 1));
    ext->Bounds(u1, u2, v1, v2);
    pt("linearExtrusion", ext, (u1 + u2) / 2, 2.5);
    Handle(Geom_Curve)   mer = GC_MakeSegment(gp_Pnt(5, 0, 0), gp_Pnt(5, 0, 10)).Value();
    Handle(Geom_Surface) rev = new Geom_SurfaceOfRevolution(mer, gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    rev->Bounds(u1, u2, v1, v2);
    printf("revolution: bounds=[%g, %g]x[%g, %g] periodic=%d\n", u1, u2, v1, v2, rev->IsUPeriodic());
    pt("revolution", rev, 0, v1);
    pt("revolution", rev, M_PI / 2, v1 + 4);
  }
  for (int k = 0; k < 3; k++)
  {
    const char* name[3] = {"untrimmed cylinder", "trimmedCylinder(5, 10)", "plane trimmed to [-5,5]^2"};
    try
    {
      Handle(Geom_Surface) s = k == 0 ? cyl : k == 1 ? Handle(Geom_Surface)(GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10).Value())
                                                     : Handle(Geom_Surface)(new Geom_RectangularTrimmedSurface(plane, -5.0, 5.0, -5.0, 5.0));
      Handle(Geom_BSplineSurface) b = GeomConvert::SurfaceToBSplineSurface(s);
      GeomConvert_BSplineSurfaceToBezierSurface c(b);
      printf("toBezierPatches %s: %d x %d patches\n", name[k], c.NbUPatches(), c.NbVPatches());
    }
    catch (Standard_Failure& e)
    {
      printf("toBezierPatches %s: threw %s\n", name[k], e.GetMessageString());
    }
  }
  return 0;
}
