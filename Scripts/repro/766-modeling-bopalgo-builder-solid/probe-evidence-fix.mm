// Epic #766 evidence fix, Tests/OCCTModelingTests/BOPAlgoBuilderSolidTests.swift.
// probe.mm printed the first solid's volume at %.10g. This probe repeats the same bridge call
// (OCCTBOPAlgoBuilderSolid: BOPAlgo_BuilderSolid with SetShapes(faces), Perform, Areas(); nothing on
// HasErrors()) on the six distinct faces of Shape.box(10, 10, 10), centred at the origin, at %.17g.
#include <BOPAlgo_BuilderSolid.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  BOPAlgo_BuilderSolid bs;
  TopTools_ListOfShape shapes;
  for (int i = 1; i <= faces.Extent(); i++)
    shapes.Append(faces(i));
  bs.SetShapes(shapes);
  bs.Perform();
  printf("buildSolidFromFaces: faces=%d produced=%d count=%d", faces.Extent(), !bs.HasErrors(), bs.Areas().Extent());
  if (!bs.Areas().IsEmpty())
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(bs.Areas().First(), p);
    printf(" firstValid=%d firstVolume=%.17g", BRepCheck_Analyzer(bs.Areas().First()).IsValid(), p.Mass());
  }
  printf("\n");
  return 0;
}
