// Epic #766, Tests/OCCTModelingTests/BOPAlgoBuilderSolidTests.swift: kernel parity.
// OCCTBOPAlgoBuilderSolid runs BOPAlgo_BuilderSolid with SetShapes(faces), Perform, and returns
// Areas(). The faces are the six distinct faces of Shape.box(10,10,10), centred at the origin.
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
  printf("buildSolidFromFaces: faces=%d hasErrors=%d areas=%d", faces.Extent(), bs.HasErrors(), bs.Areas().Extent());
  if (!bs.Areas().IsEmpty())
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(bs.Areas().First(), p);
    printf(" firstValid=%d firstVolume=%.10g", BRepCheck_Analyzer(bs.Areas().First()).IsValid(), p.Mass());
  }
  printf("\n");
  return 0;
}
