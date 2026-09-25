// Epic #766, Tests/OCCTModelingTests/LoftVertexEndpointTests.swift: kernel parity for all three
// tests. OCCTShapeCreateLoftAdvanced is BRepOffsetAPI_ThruSections(solid, ruled) with
// CheckCompatibility(true), AddVertex(first) / AddWire(circle) / AddVertex(last) for the vertices
// given, Build(), nullptr unless IsDone(). Circles are Wire.circle(radius:) at the origin, normal Z.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Edge.hxx>
#include <cstdio>
#include <gp_Circ.hxx>

static void loft(const char* label, double r, bool ruled, const gp_Pnt* first, const gp_Pnt* last)
{
  BRepOffsetAPI_ThruSections maker(Standard_True, ruled);
  maker.CheckCompatibility(Standard_True);
  if (first)
    maker.AddVertex(TopoDS::Vertex(BRepBuilderAPI_MakeVertex(*first).Shape()));
  TopoDS_Wire w = BRepBuilderAPI_MakeWire(
    BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r)).Edge()).Wire();
  maker.AddWire(w);
  if (last)
    maker.AddVertex(TopoDS::Vertex(BRepBuilderAPI_MakeVertex(*last).Shape()));
  maker.Build();
  printf("%s: done=%d", label, maker.IsDone());
  if (maker.IsDone())
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(maker.Shape(), p);
    printf(" type=%d valid=%d volume=%.10g", (int)maker.Shape().ShapeType(),
           BRepCheck_Analyzer(maker.Shape()).IsValid(), p.Mass());
  }
  printf("\n");
}

int main()
{
  gp_Pnt top(0, 0, 10), low(0, 0, -20), high(0, 0, 20);
  loft("coneFromCircle (ruled, r=5, apex z=10)", 5, true, nullptr, &top);
  printf("  analytic cone volume pi*25*10/3 = %.10g\n", M_PI * 25 * 10 / 3);
  loft("bicone (ruled, r=10, apexes z=-20,+20)", 10, true, &low, &high);
  printf("  analytic bicone volume 2*pi*100*20/3 = %.10g\n", 2 * M_PI * 100 * 20 / 3);
  loft("smoothCone (not ruled, r=5, apex z=10)", 5, false, nullptr, &top);
  return 0;
}
