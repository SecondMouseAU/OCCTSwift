// Kernel-parity probe for Tests/OCCTAnalysisTests/BRepCheckAnalyzerTests.swift (#1912-#1915).
// Builds the same primitives the Shape factories build (OCCTShapeCreateBox centres the box on
// the origin; OCCTShapeCreateSphere and OCCTShapeCreateCylinder use the plain radius/height
// constructors) and runs BRepCheck_Analyzer exactly as OCCTBRepCheckAnalyzerIsValid does.
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();

  printf("boxValid: BRepCheck_Analyzer(box, true).IsValid()=%d\n",
         BRepCheck_Analyzer(box, true).IsValid());
  printf("sphereValid: BRepCheck_Analyzer(sphere, true).IsValid()=%d\n",
         BRepCheck_Analyzer(sph, true).IsValid());
  printf("cylinderValid: BRepCheck_Analyzer(cylinder, true).IsValid()=%d\n",
         BRepCheck_Analyzer(cyl, true).IsValid());
  printf("noGeomChecks: BRepCheck_Analyzer(box, false).IsValid()=%d\n",
         BRepCheck_Analyzer(box, false).IsValid());
  return 0;
}
