// Epic #766 evidence fix, Tests/OCCTModelingTests/LocOpeGluerTests.swift.
// probe.mm printed the coincident pair's volume at %.10g. This probe repeats the bridge's call
// (OCCTLocOpeGlue: LocOpe_Gluer(base, glued); Bind(gluedFace, baseFace); Perform(); IsDone();
// ResultingShape()) for the one pair the test binds, box1's x=10 face (index 1) against box2's x=10
// face (index 0), at %.17g, with the type spelled the way Shape.shapeTypeString spells it.
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_Gluer.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cctype>
#include <cstdio>
#include <string>

static std::string lower(const char* s)
{
  std::string r(s);
  for (auto& c : r)
    c = (char)std::tolower((unsigned char)c);
  return r;
}

int main()
{
  TopoDS_Shape               b1 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
  TopoDS_Shape               b2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape f1, f2;
  TopExp::MapShapes(b1, TopAbs_FACE, f1);
  TopExp::MapShapes(b2, TopAbs_FACE, f2);
  printf("input faces: %d + %d\n", f1.Extent(), f2.Extent());
  LocOpe_Gluer g(b1, b2);
  g.Bind(TopoDS::Face(f2(1)), TopoDS::Face(f1(2)));
  g.Perform();
  const TopoDS_Shape& r        = g.ResultingShape();
  bool                produced = g.IsDone() && !r.IsNull();
  TopTools_IndexedMapOfShape rf;
  TopExp::MapShapes(r, TopAbs_FACE, rf);
  GProp_GProps p;
  BRepGProp::VolumeProperties(r, p);
  printf("glueByFace pair (1,0): produced=%d type=%s faces=%d valid=%d volume=%.17g\n", produced,
         lower(TopAbs::ShapeTypeToString(r.ShapeType())).c_str(), rf.Extent(), BRepCheck_Analyzer(r).IsValid(), p.Mass());
  return 0;
}
