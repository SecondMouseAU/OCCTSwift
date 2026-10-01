// Epic #766 evidence fix, Tests/OCCTModelingTests/HalfSpaceTests.swift.
// probe.mm printed the classifier states as integers. This probe repeats OCCTShapeCreateHalfSpace
// (BRepPrimAPI_MakeHalfSpace(first face, refPoint).Solid(), returned without a null check) on the planar
// face of the 20 x 20 rectangle Wire.rectangle builds (centred at the origin, z = 0) with reference
// point (0, 0, 5), and classifies (0, 0, 5) and (0, 0, -5) against the solid the way Shape.classify(point:)
// does (BRepClass3d_SolidClassifier, tolerance 1e-6). The shape type is spelled as Shape.shapeTypeString
// spells it and the states as PointClassification spells them.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepPrimAPI_MakeHalfSpace.hxx>
#include <TopAbs.hxx>
#include <TopoDS_Solid.hxx>
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

static const char* state(TopAbs_State s)
{
  switch (s)
  {
    case TopAbs_IN:
      return "inside";
    case TopAbs_OUT:
      return "outside";
    case TopAbs_ON:
      return "onBoundary";
    default:
      return "unknown";
  }
}

int main()
{
  gp_Pnt                  p1(-10, -10, 0), p2(10, -10, 0), p3(10, 10, 0), p4(-10, 10, 0);
  BRepBuilderAPI_MakeWire w;
  w.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  w.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  w.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  w.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  BRepBuilderAPI_MakeFace   mf(w.Wire(), Standard_True);
  BRepPrimAPI_MakeHalfSpace hs(mf.Face(), gp_Pnt(0, 0, 5));
  TopoDS_Solid              s = hs.Solid();
  BRepClass3d_SolidClassifier above(s, gp_Pnt(0, 0, 5), 1e-6), below(s, gp_Pnt(0, 0, -5), 1e-6);
  printf("halfSpaceFromFace: faceDone=%d done=%d produced=%d type=%s state(0,0,5)=%s state(0,0,-5)=%s\n", mf.IsDone(),
         hs.IsDone(), !s.IsNull(), lower(TopAbs::ShapeTypeToString(s.ShapeType())).c_str(), state(above.State()),
         state(below.State()));
  return 0;
}
