// Epic #766 evidence fix, Tests/OCCTModelingTests/LoftVertexEndpointTests.swift.
// probe.mm printed the volume at %.10g, the shape type as an integer and no face count. This probe repeats
// the same bridge call (OCCTShapeCreateLoftAdvanced: BRepOffsetAPI_ThruSections(solid, ruled) with
// CheckCompatibility(true), AddVertex(first) / AddWire(circle) / AddVertex(last) for the vertices given,
// Build(), a result only when IsDone()) and prints whether a shape came back, its type (as
// Shape.shapeTypeString spells it), face count, validity and volume at %.17g.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Wire.hxx>
#include <cctype>
#include <cstdio>
#include <gp_Circ.hxx>
#include <string>

static std::string lower(const char* s)
{
  std::string r(s);
  for (auto& c : r)
    c = (char)std::tolower((unsigned char)c);
  return r;
}

static void loft(const char* label, double r, bool ruled, const gp_Pnt* first, const gp_Pnt* last)
{
  BRepOffsetAPI_ThruSections maker(Standard_True, ruled);
  maker.CheckCompatibility(Standard_True);
  if (first)
    maker.AddVertex(TopoDS::Vertex(BRepBuilderAPI_MakeVertex(*first).Shape()));
  TopoDS_Wire w = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r)).Edge()).Wire();
  maker.AddWire(w);
  if (last)
    maker.AddVertex(TopoDS::Vertex(BRepBuilderAPI_MakeVertex(*last).Shape()));
  maker.Build();
  printf("%s: produced=%d", label, maker.IsDone());
  if (maker.IsDone())
  {
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(maker.Shape(), TopAbs_FACE, faces);
    GProp_GProps p;
    BRepGProp::VolumeProperties(maker.Shape(), p);
    printf(" type=%s faces=%d valid=%d volume=%.17g", lower(TopAbs::ShapeTypeToString(maker.Shape().ShapeType())).c_str(),
           faces.Extent(), BRepCheck_Analyzer(maker.Shape()).IsValid(), p.Mass());
  }
  printf("\n");
}

int main()
{
  gp_Pnt top(0, 0, 10), low(0, 0, -20), high(0, 0, 20);
  loft("coneFromCircle (ruled, r=5, apex z=10)", 5, true, nullptr, &top);
  printf("  analytic cone volume pi*25*10/3 = %.17g\n", M_PI * 25 * 10 / 3);
  loft("bicone (ruled, r=10, apexes z=-20,+20)", 10, true, &low, &high);
  printf("  analytic bicone volume 2*pi*100*20/3 = %.17g\n", 2 * M_PI * 100 * 20 / 3);
  loft("smoothCone (not ruled, r=5, apex z=10)", 5, false, nullptr, &top);
  return 0;
}
