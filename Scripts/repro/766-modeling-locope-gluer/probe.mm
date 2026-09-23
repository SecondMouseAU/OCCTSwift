// Epic #766, Tests/OCCTModelingTests/LocOpeGluerTests.swift: kernel parity for glueByFace.
// The test tries every (box1 face, box2 face) pair in TopExp::MapShapes(FACE) order through
// OCCTLocOpeGlue (LocOpe_Gluer(base, glued); Bind(gluedFace, baseFace); Perform(); IsDone();
// ResultingShape()) and keeps the first that succeeds. Same loop here, every pair reported.
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_Gluer.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               b1 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
  TopoDS_Shape               b2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape f1, f2;
  TopExp::MapShapes(b1, TopAbs_FACE, f1);
  TopExp::MapShapes(b2, TopAbs_FACE, f2);
  bool first = true;
  for (int i = 1; i <= f1.Extent(); i++)
    for (int j = 1; j <= f2.Extent(); j++)
    {
      try
      {
        LocOpe_Gluer g(b1, b2);
        g.Bind(TopoDS::Face(f2(j)), TopoDS::Face(f1(i)));
        g.Perform();
        if (!g.IsDone() || g.ResultingShape().IsNull())
        {
          printf("pair (%d,%d): not done\n", i - 1, j - 1);
          continue;
        }
        TopTools_IndexedMapOfShape rf;
        TopExp::MapShapes(g.ResultingShape(), TopAbs_FACE, rf);
        GProp_GProps p;
        BRepGProp::VolumeProperties(g.ResultingShape(), p);
        printf("pair (%d,%d): done faces=%d valid=%d volume=%.10g%s\n", i - 1, j - 1, rf.Extent(),
               BRepCheck_Analyzer(g.ResultingShape()).IsValid(), p.Mass(),
               first ? "  <- first success, what the test keeps" : "");
        first = false;
      }
      catch (Standard_Failure& e)
      {
        printf("pair (%d,%d): threw %s\n", i - 1, j - 1, e.what());
      }
    }
  // The pair that is actually coincident: box1's x=10 face (index 1) against box2's x=10 face
  // (index 0), the pair the test means by "glue two boxes by face".
  {
    LocOpe_Gluer g(b1, b2);
    g.Bind(TopoDS::Face(f2(1)), TopoDS::Face(f1(2)));
    g.Perform();
    const TopoDS_Shape& r = g.ResultingShape();
    TopTools_IndexedMapOfShape rf, rs;
    TopExp::MapShapes(r, TopAbs_FACE, rf);
    TopExp::MapShapes(r, TopAbs_SOLID, rs);
    GProp_GProps p;
    BRepGProp::VolumeProperties(r, p);
    gp_Pnt c = p.CentreOfMass();
    printf("coincident pair (1,0): done=%d type=%d solids=%d faces=%d valid=%d volume=%.10g centre=(%g, %g, %g)\n",
           g.IsDone(), (int)r.ShapeType(), rs.Extent(), rf.Extent(), BRepCheck_Analyzer(r).IsValid(), p.Mass(),
           c.X(), c.Y(), c.Z());
  }
  printf("input faces: %d + %d = %d\n", f1.Extent(), f2.Extent(), f1.Extent() + f2.Extent());
  return 0;
}
