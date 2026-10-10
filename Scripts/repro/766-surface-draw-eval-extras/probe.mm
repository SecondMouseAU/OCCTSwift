// Epic #766, SurfaceDrawTests.swift, SurfaceEvalTests.swift, SurfaceExtrasTests.swift and
// SurfaceExtrasV112Tests.swift: kernel parity for the eleven tests.
//  - drawGrid / drawMesh on the radius-5 Geom_SphericalSurface: D0 on the uniform sweep over
//    Bounds that OCCTSurfaceDrawGrid / OCCTSurfaceDrawMesh use (u-isos then v-isos).
//  - BRep_Tool::Surface of face 1 of BRepPrimAPI_MakeSphere(5) and of the centred 10-box
//    (OCCTFaceExtractSurface), then EvalD0/EvalD1/EvalD2, Bounds, Continuity, Copy.
//  - GeomAdaptor_Surface::GetType of the plane and sphere (OCCTSurfaceGetType).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakePlane.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_Surface) face1(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return BRep_Tool::Surface(TopoDS::Face(m(1)));
}

static double uni(double a, double b, int i, int n)
{
  return n > 1 ? a + (b - a) * i / (n - 1) : a;
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  Handle(Geom_Surface) sphere = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  double               u1, u2, v1, v2;
  sphere->Bounds(u1, u2, v1, v2);
  double worst = 0;
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 20; j++)
    {
      worst = std::max(worst, std::abs(sphere->Value(uni(u1, u2, i, 5), uni(v1, v2, j, 20)).Distance(gp::Origin()) - 5));
      worst = std::max(worst, std::abs(sphere->Value(uni(u1, u2, j, 20), uni(v1, v2, i, 5)).Distance(gp::Origin()) - 5));
    }
  gp_Pnt g0 = sphere->Value(u1, uni(v1, v2, 10, 20)), g5 = sphere->Value(uni(u1, u2, 10, 20), v1 + (v2 - v1) / 2);
  printf("drawGrid: max |r - 5| = %.3g; line 0 point 10 = (%.17g, %.17g, %.17g); line 5 (first v-iso) point 10 at v = %g = (%.17g, %.17g, %.17g)\n",
         worst, g0.X(), g0.Y(), g0.Z(), uni(v1, v2, 0, 5), 0.0, 0.0, 0.0);
  gp_Pnt l5 = sphere->Value(uni(u1, u2, 10, 20), uni(v1, v2, 0, 5));
  printf("  line 5 point 10 = (%.17g, %.17g, %.17g) (v = %g, the south pole)\n", l5.X(), l5.Y(), l5.Z(), uni(v1, v2, 0, 5));
  gp_Pnt l7 = sphere->Value(uni(u1, u2, 5, 20), uni(v1, v2, 2, 5));
  printf("  line 7 point 5 = (%.17g, %.17g, %.17g)\n", l7.X(), l7.Y(), l7.Z());
  gp_Pnt m0 = sphere->Value(u1, v1);
  printf("drawMesh: at(0,0) = (%.17g, %.17g, %.17g)\n", m0.X(), m0.Y(), m0.Z());

  Handle(Geom_Surface) fs = face1(BRepPrimAPI_MakeSphere(5).Shape());
  gp_Pnt               d0 = fs->EvalD0(0, 0);
  printf("evalD0Sphere: %s D0(0,0) = (%.17g, %.17g, %.17g)\n", fs->DynamicType()->Name(), d0.X(), d0.Y(), d0.Z());
  Geom_Surface::ResD1 r1 = fs->EvalD1(0, M_PI / 4);
  printf("evalD1Sphere: P = (%.17g, %.17g, %.17g) D1U = (%.17g, %.17g, %.17g) D1V = (%.17g, %.17g, %.17g)\n", r1.Point.X(), r1.Point.Y(),
         r1.Point.Z(), r1.D1U.X(), r1.D1U.Y(), r1.D1U.Z(), r1.D1V.X(), r1.D1V.Y(), r1.D1V.Z());
  Handle(Geom_Surface) fb = face1(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  Geom_Surface::ResD2 r2 = fb->EvalD2(0.5, 0.5);
  printf("evalD2BoxFace: %s P = (%g, %g, %g) D1U = (%g, %g, %g) |D2U| = %g |D2V| = %g |D2UV| = %g\n", fb->DynamicType()->Name(), r2.Point.X(),
         r2.Point.Y(), r2.Point.Z(), r2.D1U.X(), r2.D1U.Y(), r2.D1U.Z(), r2.D2U.Magnitude(), r2.D2V.Magnitude(), r2.D2UV.Magnitude());
  fb->Bounds(u1, u2, v1, v2);
  printf("surfaceBounds: box face 1 [%g, %g]x[%g, %g]\n", u1, u2, v1, v2);
  printf("planeContinuityClass: Continuity = %d\n", (int)fb->Continuity());
  Handle(Geom_Surface) cp = Handle(Geom_Surface)::DownCast(fb->Copy());
  gp_Pnt               a = fb->Value(1, 2), b = cp->Value(1, 2);
  printf("copySurface: distinct=%d S(1,2) original=(%g,%g,%g) copy=(%g,%g,%g)\n", cp.get() != fb.get(), a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  printf("surfaceTypePlane: %d  surfaceTypeSphere: %d\n", (int)GeomAdaptor_Surface(GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value()).GetType(),
         (int)GeomAdaptor_Surface(sphere).GetType());
  return 0;
}
