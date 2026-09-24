// Epic #766 kernel-parity probe for TransformExpansionTests.swift. Same OCCT calls, same inputs,
// as OCCTShapeTransformed (occtTrsfFromMatrix12Grouped + BRepBuilderAPI_Transform),
// OCCTShapeGTransformed (gp_GTrsf row by row + BRepBuilderAPI_GTransform),
// OCCTShapeTransformFromMatrix (gp_Trsf::SetValues interleaved + BRepBuilderAPI_Transform), and
// OCCTShapeGetBounds / OCCTShapeBoundingBox (BRepBndLib::Add, useTriangulation = true, no gap).
// typedInitializersReturnNilRatherThanTrapOnWrongCount has no kernel counterpart (pure Swift).
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

static void report(const char* name, const TopoDS_Shape& s)
{
  Bnd_Box box;
  BRepBndLib::Add(s, box, true);
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: valid=%d min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n", name,
         BRepCheck_Analyzer(s).IsValid(), x0, y0, z0, x1, y1, z1);
}

static TopoDS_Shape grouped(const TopoDS_Shape& s, const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[9], m[3], m[4], m[5], m[10], m[6], m[7], m[8], m[11]);
  return BRepBuilderAPI_Transform(s, t, Standard_True).Shape();
}

static TopoDS_Shape gInterleaved(const TopoDS_Shape& s, const double* m)
{
  gp_GTrsf g;
  for (int r = 1; r <= 3; r++)
    for (int c = 1; c <= 4; c++)
      g.SetValue(r, c, m[(r - 1) * 4 + (c - 1)]);
  return BRepBuilderAPI_GTransform(s, g, Standard_True).Shape();
}

static TopoDS_Shape interleaved(const TopoDS_Shape& s, const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

int main()
{
  TopoDS_Shape centred = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape atOrigin = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
  TopoDS_Shape nonCubic = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 20, 30).Shape();

  const double g5[12] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0};
  const double s21h[12] = {2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0.5, 0};
  const double g51015[12] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 10, 15};
  const double i51015[12] = {1, 0, 0, 5, 0, 1, 0, 10, 0, 0, 1, 15};

  report("generalTransform (centred 10-cube, grouped +5x)", grouped(centred, g5));
  report("nonUniformScale (centred 10-cube, gTransform 2,1,0.5)", gInterleaved(centred, s21h));
  report("generalTransformGroupedLayoutTranslatesAsDocumented", grouped(atOrigin, g5));
  report("nonUniformScaleInterleavedLayoutScalesAsDocumented", gInterleaved(nonCubic, s21h));
  report("groupedInterleavedConversionRoundTrips viaGrouped", grouped(atOrigin, g51015));
  report("groupedInterleavedConversionRoundTrips viaInterleaved", interleaved(atOrigin, i51015));
  report("deprecatedArrayOverloadsStillWork a (grouped +5x)", grouped(atOrigin, g5));
  report("deprecatedArrayOverloadsStillWork b (gTransform interleaved)", gInterleaved(atOrigin, i51015));
  report("deprecatedArrayOverloadsStillWork c (transformFromMatrix interleaved)",
         interleaved(atOrigin, i51015));
  return 0;
}
