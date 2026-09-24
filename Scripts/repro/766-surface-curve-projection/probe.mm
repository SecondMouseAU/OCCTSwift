// Epic #766, SurfaceCurveProjectionTests.swift: kernel parity for the nine tests. Same inputs:
// GeomProjLib::Curve2d(curve, first, last, surface, 1e-4) (OCCTSurfaceProjectCurve2D),
// GeomProjLib::Project (OCCTSurfaceProjectCurve3D), ProjLib_CompProjectedCurve (…Segments),
// GeomAPI_ProjectPointOnSurf (OCCTSurfaceProjectPoint), on the GC_MakePlane z = 0 plane, the
// radius-5 sphere and the radius-3 / radius-5 Z cylinders; segments from GC_MakeSegment.
#include <GC_MakePlane.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom2d_Curve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomProjLib.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <ProjLib_CompProjectedCurve.hxx>
#include <StdFail_NotDone.hxx>
#include <cstdio>

static void c2(const char* name, const Handle(Geom2d_Curve)& c)
{
  if (c.IsNull())
  {
    printf("%s: nil\n", name);
    return;
  }
  gp_Pnt2d a = c->Value(c->FirstParameter()), b = c->Value(c->LastParameter());
  printf("%s: domain=[%.17g, %.17g] start=(%.17g, %.17g) end=(%.17g, %.17g)\n", name, c->FirstParameter(), c->LastParameter(), a.X(), a.Y(),
         b.X(), b.Y());
}

static Handle(Geom2d_Curve) proj(const Handle(Geom_Curve)& c, const Handle(Geom_Surface)& s)
{
  double tol = 1e-4; // in/out, as OCCTSurfaceProjectCurve2D passes it
  return GeomProjLib::Curve2d(c, c->FirstParameter(), c->LastParameter(), s, tol);
}

static void pp(const char* name, const Handle(Geom_Surface)& s, gp_Pnt p)
{
  GeomAPI_ProjectPointOnSurf pr(p, s);
  double                     u, v;
  pr.LowerDistanceParameters(u, v);
  printf("%s: distance=%.17g u=%.17g v=%.17g\n", name, pr.LowerDistance(), u, v);
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  gp_Ax3               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_Surface) plane = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  Handle(Geom_Curve)   line  = GC_MakeSegment(gp_Pnt(0, 0, 5), gp_Pnt(10, 0, 5)).Value();
  c2("projectLineOntoPlane", proj(line, plane));
  Handle(Geom_Surface) cyl5   = new Geom_CylindricalSurface(ax, 5);
  Handle(Geom_Curve)   circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 3), gp_Dir(0, 0, 1)), 5);
  Handle(Geom2d_Curve) pc = proj(circle, cyl5);
  c2("projectCircleOntoCylinder", pc);
  printf("  %s, value at 1 = (%.17g, %.17g)\n", pc->DynamicType()->Name(), pc->Value(1).X(), pc->Value(1).Y());
  Handle(Geom_Curve) diag = GC_MakeSegment(gp_Pnt(0, 0, 5), gp_Pnt(10, 7, 5)).Value();
  Handle(Geom_Curve) p3   = GeomProjLib::Project(diag, plane);
  gp_Pnt             mid  = p3->Value((p3->FirstParameter() + p3->LastParameter()) / 2);
  printf("projectCurve3DOntoPlane: mid=(%.17g, %.17g, %.17g)\n", mid.X(), mid.Y(), mid.Z());
  pp("projectPointOntoPlane", plane, gp_Pnt(5, 3, 7));
  pp("projectPointOntoSphere", new Geom_SphericalSurface(ax, 5), gp_Pnt(10, 0, 0));
  pp("projectPointOntoCylinder", new Geom_CylindricalSurface(ax, 3), gp_Pnt(6, 0, 5));
  Handle(Geom_Curve) seg = GC_MakeSegment(gp_Pnt(0, 0, 3), gp_Pnt(4, 3, 3)).Value();
  c2("projectSegmentOntoPlaneLength", proj(seg, plane));
  ProjLib_CompProjectedCurve comp(1e-4, new GeomAdaptor_Surface(plane), new GeomAdaptor_Curve(line));
  comp.Perform();
  printf("compositeProjectionBasic: NbCurves=%d\n", comp.NbCurves());
  if (comp.NbCurves() > 0)
    c2("  segment 1", comp.GetResult2dC(1));
  // projectionNilSafety: GC_MakeSegment itself faults on coincident points in this kernel (an
  // earlier run of this probe died there), and OCCTCurve3DCreateSegment refuses coincident points (distance below
  // Precision::Confusion()) before any kernel call, so there is no kernel counterpart to probe.
  return 0;
}
