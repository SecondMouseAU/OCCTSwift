// Epic #766 kernel-parity probe for SurfaceTransformTests.swift and TransformedCurveTests.swift.
// Same OCCT calls, same inputs, as OCCTSurfacePlaneFromPointNormal (GC_MakePlane),
// OCCTSurfaceTransform (occtBuildTrsf3D + Geom_Surface::Transform), OCCTSurfaceGetPoint (D0),
// OCCTSurfaceBezierFill2 (GeomFill_BezierCurves, stretch style, the Swift default),
// and OCCTGeomAdaptorTransformedCurveCreate (copy + Transform by a translation).
#include <GC_MakePlane.hxx>
#include <GeomFill_BezierCurves.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Plane.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_Plane) plane(double z)
{
  return GC_MakePlane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1)).Value();
}

static void pts(const char* name, const Handle(Geom_Surface)& s)
{
  const double uv[4][2] = {{0, 0}, {1, 0}, {0, 1}, {1, 1}};
  printf("%s:", name);
  for (auto& p : uv)
  {
    gp_Pnt q;
    s->D0(p[0], p[1], q);
    printf(" P(%g,%g)=(%.17g, %.17g, %.17g)", p[0], p[1], q.X(), q.Y(), q.Z());
  }
  printf("\n");
}

int main()
{
  pts("plane z=0 before", plane(0));
  pts("plane z=5 before", plane(5));

  gp_Trsf t;
  auto    s = plane(0);
  t.SetTranslation(gp_Vec(10, 0, 5));
  s->Transform(t);
  pts("translateSurface", s);

  s = plane(0);
  t = gp_Trsf();
  t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), M_PI / 4);
  s->Transform(t);
  pts("rotateSurface", s);

  s = plane(0);
  t = gp_Trsf();
  t.SetScale(gp_Pnt(0, 0, 0), 2);
  s->Transform(t);
  pts("scaleSurface (plane z=0, as written)", s);

  s = plane(5);
  t = gp_Trsf();
  t.SetScale(gp_Pnt(0, 0, 0), 2);
  s->Transform(t);
  pts("scaleSurface (plane z=5, rewritten)", s);

  s = plane(5);
  t = gp_Trsf();
  t.SetMirror(gp_Pnt(0, 0, 0));
  s->Transform(t);
  pts("mirrorPointSurface", s);

  s = plane(5);
  t = gp_Trsf();
  t.SetMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  s->Transform(t);
  pts("mirrorAxisSurface", s);

  s = plane(5);
  t = gp_Trsf();
  t.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  s->Transform(t);
  pts("mirrorPlaneSurface", s);

  // transformBezierSurface: bezierFill of two Bezier curves, then translate dz = 100.
  TColgp_Array1OfPnt a(1, 3), b(1, 3);
  a(1) = gp_Pnt(0, 0, 0);
  a(2) = gp_Pnt(5, 0, 3);
  a(3) = gp_Pnt(10, 0, 0);
  b(1) = gp_Pnt(0, 10, 0);
  b(2) = gp_Pnt(5, 10, 3);
  b(3) = gp_Pnt(10, 10, 0);
  GeomFill_BezierCurves fill(new Geom_BezierCurve(a), new Geom_BezierCurve(b), GeomFill_StretchStyle);
  Handle(Geom_BezierSurface) bs = fill.Surface();
  gp_Pnt before = bs->Value(0.5, 0.5);
  t = gp_Trsf();
  t.SetTranslation(gp_Vec(0, 0, 100));
  bs->Transform(t);
  gp_Pnt after = bs->Value(0.5, 0.5);
  printf("transformBezierSurface (OCCTSurfaceBezierFill2, default GeomFill_StretchStyle): before (%.17g, %.17g, %.17g) "
         "after (%.17g, %.17g, %.17g) delta z %.17g\n",
         before.X(), before.Y(), before.Z(), after.X(), after.Y(), after.Z(),
         after.Z() - before.Z());

  // translateCircle
  Handle(Geom_Curve) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  Handle(Geom_Curve) cc = Handle(Geom_Curve)::DownCast(c->Copy());
  t = gp_Trsf();
  t.SetTranslation(gp_Vec(10, 0, 0));
  cc->Transform(t);
  gp_Pnt p0 = cc->Value(cc->FirstParameter());
  printf("translateCircle: domain [%.17g, %.17g] start (%.17g, %.17g, %.17g)\n",
         cc->FirstParameter(), cc->LastParameter(), p0.X(), p0.Y(), p0.Z());
  return 0;
}
