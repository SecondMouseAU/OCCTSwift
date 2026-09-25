// Epic #766 evidence fix, Tests/OCCTModelingTests/BOPAlgoBuilderFaceTests.swift.
// probe.mm printed the total area at %.10g. This probe repeats the same bridge call (OCCTBOPAlgoBuilderFace:
// BOPAlgo_BuilderFace with SetFace, SetShapes(the face's own edges), Perform, Areas(); nothing on
// HasErrors()) on BRepBuilderAPI_MakeFace(Geom_Plane z=0, -5..5, -5..5, 1e-6) at %.17g. The area of each
// returned face is BRepGProp::SurfaceProperties, summed, as Shape.surfaceArea over the returned faces.
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
  printf("buildFaceFromEdges: edges=%d produced=%d count=%d totalArea=%.17g\n", edges.Extent(), !bf.HasErrors(),
         bf.Areas().Extent(), area);
  return 0;
}
