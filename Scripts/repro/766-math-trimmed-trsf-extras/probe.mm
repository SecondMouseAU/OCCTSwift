// Epic #766 kernel-parity probe for TrimmedConeTests.swift, TrimmedCylinderTests.swift and
// TrsfExtrasTests.swift. Same OCCT calls, same inputs, as OCCTSurfaceTrimmedCone
// (GC_MakeTrimmedCone), OCCTSurfaceTrimmedCylinder (GC_MakeTrimmedCylinder), OCCTSurfaceGetDomain
// (Bounds), OCCTSurfaceGetPoint (D0), OCCTShapeTransformFromMatrix (gp_Trsf::SetValues,
// BRepBuilderAPI_Transform copy = true), OCCTShapeBoundingBox (BRepBndLib::Add, triangulation,
// no gap), OCCTShapeTransformIsNegative, OCCTTrsfDisplacement (SetDisplacement) and
// OCCTTrsfTransformation (SetTransformation). invalidMatrixSize has no kernel counterpart: the
// wrong-count array is refused in Swift before any bridge call.
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <gp_Ax3.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

static void surf(const char* name, const Handle(Geom_Surface)& s)
{
  double u0, u1, v0, v1;
  s->Bounds(u0, u1, v0, v1);
  gp_Pnt a = s->Value(0, v0), b = s->Value(0, v1);
  printf("%s: domain u [%.17g, %.17g] v [%.17g, %.17g] P(0, vMin)=(%.17g, %.17g, %.17g) "
         "P(0, vMax)=(%.17g, %.17g, %.17g)\n",
         name, u0, u1, v0, v1, a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
}

static void bbox(const char* name, const TopoDS_Shape& s)
{
  Bnd_Box box;
  BRepBndLib::Add(s, box, true);
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n", name, x0, y0, z0, x1, y1,
         z1);
}

static TopoDS_Shape byMatrix(const TopoDS_Shape& s, const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

static void trsf(const char* name, const gp_Trsf& t)
{
  printf("%s: [", name);
  for (int r = 1; r <= 3; r++)
    for (int c = 1; c <= 4; c++)
      printf(" %.17g", t.Value(r, c));
  printf(" ]\n");
}

int main()
{
  surf("trimmedCone", GC_MakeTrimmedCone(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 5.0, 2.0).Value());
  surf("trimmedCylinder",
       GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0, 8.0).Value());

  const double t51015[12] = {1, 0, 0, 5, 0, 1, 0, 10, 0, 0, 1, 15};
  const double mirX[12] = {-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0};
  bbox("transformFromMatrix (centred unit box)",
       byMatrix(BRepPrimAPI_MakeBox(gp_Pnt(-0.5, -0.5, -0.5), 1, 1, 1).Shape(), t51015));
  TopoDS_Shape b10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  const TopLoc_Location& loc = b10.Location();
  printf("transformIsNegative: location identity=%d -> %d\n", loc.IsIdentity(),
         loc.IsIdentity() ? 0 : (int)loc.Transformation().IsNegative());
  bbox("mirrorTransformProducesResult",
       byMatrix(BRepPrimAPI_MakeBox(gp_Pnt(5, 0, 0), 10, 10, 10).Shape(), mirX));

  gp_Trsf d;
  d.SetDisplacement(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), gp_Ax3(gp_Pnt(10, 0, 0), gp_Dir(0, 0, 1)));
  trsf("displacement", d);
  gp_Trsf tf;
  tf.SetTransformation(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), gp_Ax3(gp_Pnt(5, 5, 5), gp_Dir(0, 0, 1)));
  trsf("transformation", tf);

  bbox("transformFromMatrixInterleavedLayoutTranslatesAsDocumented",
       byMatrix(BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape(), t51015));
  return 0;
}
