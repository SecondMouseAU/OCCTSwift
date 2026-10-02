// Epic #766, Tests/OCCTModelingTests/BOPAlgoBuilderFaceTests.swift: kernel parity.
// The face is BRepBuilderAPI_MakeFace(Geom_Plane z=0, -5..5, -5..5, 1e-6)
// (OCCTShapeCreateFaceFromSurface); OCCTBOPAlgoBuilderFace runs BOPAlgo_BuilderFace with SetFace,
// SetShapes(the face's own edges), Perform, and returns Areas().
#include <BOPAlgo_BuilderFace.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Plane.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  TopoDS_Face        face  = BRepBuilderAPI_MakeFace(plane, -5, 5, -5, 5, 1e-6);
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(face, TopAbs_EDGE, edges);
  BOPAlgo_BuilderFace bf;
  bf.SetFace(face);
  TopTools_ListOfShape shapes;
  for (int i = 1; i <= edges.Extent(); i++)
    shapes.Append(edges(i));
  bf.SetShapes(shapes);
  bf.Perform();
  double area = 0;
  for (TopTools_ListOfShape::Iterator it(bf.Areas()); it.More(); it.Next())
  {
    GProp_GProps p;
    BRepGProp::SurfaceProperties(it.Value(), p);
    area += p.Mass();
  }
  printf("buildFaceFromEdges: edges=%d hasErrors=%d areas=%d totalArea=%.10g\n", edges.Extent(), bf.HasErrors(),
         bf.Areas().Extent(), area);
  return 0;
}
