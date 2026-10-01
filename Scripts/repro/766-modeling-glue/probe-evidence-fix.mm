// Epic #766 evidence fix, Tests/OCCTModelingTests/GlueTests.swift.
// probe.mm reported that the glue fuse is not done and printed the fallback's volume at %.10g. This probe
// repeats OCCTShapeGlue exactly as the bridge runs it: BRepAlgoAPI_Fuse with SetGlue(BOPAlgo_GlueShift),
// SetFuzzyValue(1e-6), both boxes as arguments and no tools, Build(); when that is not done, a plain
// BRepAlgoAPI_Fuse of the two boxes, whose shape is what the bridge returns. It prints the returned
// shape's type (as Shape.shapeTypeString spells it), face count, validity and volume at %.17g.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
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
  // Shape.box(width:height:depth:) is centred on the origin; the second box is translated by (10, 0, 0).
  TopoDS_Shape         a = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape         b = BRepPrimAPI_MakeBox(gp_Pnt(5, -5, -5), 10, 10, 10).Shape();
  BRepAlgoAPI_Fuse     fuse;
  TopTools_ListOfShape args;
  args.Append(a);
  args.Append(b);
  fuse.SetGlue(BOPAlgo_GlueShift);
  fuse.SetFuzzyValue(1e-6);
  fuse.SetArguments(args);
  fuse.Build();
  printf("glue fuse as OCCTShapeGlue calls it: done=%d hasErrors=%d null=%d\n", fuse.IsDone(), fuse.HasErrors(),
         fuse.Shape().IsNull());
  TopoDS_Shape result;
  if (!fuse.IsDone())
  {
    BRepAlgoAPI_Fuse plain(a, b);
    printf("plain fuse fallback: done=%d\n", plain.IsDone());
    result = plain.Shape();
  }
  else
    result = fuse.Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(result, TopAbs_FACE, faces);
  GProp_GProps p;
  BRepGProp::VolumeProperties(result, p);
  printf("glueTwoBoxes returned shape: produced=%d type=%s faces=%d valid=%d volume=%.17g\n", !result.IsNull(),
         lower(TopAbs::ShapeTypeToString(result.ShapeType())).c_str(), faces.Extent(), BRepCheck_Analyzer(result).IsValid(),
         p.Mass());
  return 0;
}
