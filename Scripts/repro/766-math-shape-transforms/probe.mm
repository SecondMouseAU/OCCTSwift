// Epic #766 kernel-parity probe for ShapeMirrorTests.swift, ShapeScaleAboutPointTests.swift and
// ShapeTranslateByPointsTests.swift. Same OCCT calls, same inputs, as OCCTShapeCreateBox,
// OCCTShapeCreateBoxAt (OCCTBridge_Modeling_SolidPrimitives.mm), OCCTShapeMirrorAboutPoint,
// OCCTShapeMirrorAboutAxis, OCCTShapeScaleAboutPoint, OCCTShapeTranslateByPoints
// (OCCTBridge_Modeling_Transform.mm) and OCCTShapeGetBounds (occtComputeBoundingBox:
// BRepBndLib::Add with useTriangulation = true, no gap).
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeMirror.hxx>
#include <GC_MakeScale.hxx>
#include <GC_MakeTranslation.hxx>
#include <Geom_Transformation.hxx>
#include <gp_Ax1.hxx>
#include <cstdio>

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void report(const char* name, const TopoDS_Shape& s)
{
  Bnd_Box box;
  BRepBndLib::Add(s, box, true);
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: valid=%d min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g) size=(%.17g, %.17g, "
         "%.17g)\n",
         name, BRepCheck_Analyzer(s).IsValid(), x0, y0, z0, x1, y1, z1, x1 - x0, y1 - y0, z1 - z0);
}

static TopoDS_Shape apply(const TopoDS_Shape& s, const gp_Trsf& t)
{
  BRepBuilderAPI_Transform bt(s, t, true);
  return bt.Shape();
}

int main()
{
  TopoDS_Shape b10 = centredBox(10, 10, 10);
  report("mirrorAboutPoint", apply(b10, GC_MakeMirror(gp_Pnt(20, 0, 0)).Value()->Trsf()));
  report("mirrorAboutAxis (centred box, as originally written)",
         apply(b10, GC_MakeMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).Value()->Trsf()));
  TopoDS_Shape off = BRepPrimAPI_MakeBox(gp_Pnt(1, 2, 3), 10, 10, 10).Shape();
  report("mirrorAboutAxis (box at (1,2,3), rewritten)",
         apply(off, GC_MakeMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).Value()->Trsf()));
  report("scaleAboutOrigin", apply(b10, GC_MakeScale(gp_Pnt(0, 0, 0), 2.0).Value()->Trsf()));
  report("halfScale", apply(centredBox(20, 20, 20), GC_MakeScale(gp_Pnt(0, 0, 0), 0.5).Value()->Trsf()));
  report("translateByPoints",
         apply(b10, GC_MakeTranslation(gp_Pnt(0, 0, 0), gp_Pnt(20, 0, 0)).Value()->Trsf()));
  return 0;
}
