// #766 kernel parity for IntToolsTests, IntfToolTests, IntegrationProfileContouringTests and
// IntegrationSurfaceCurvatureAnalysisTests: the same OCCT calls, on the same inputs, that the
// bridge functions those tests reach make.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_SphericalSurface.hxx>
#include <IntTools_Tools.hxx>
#include <Intf_Tool.hxx>
#include <Precision.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_HSequenceOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void linBox(const char* name, gp_Pnt o, gp_Dir d)
{
  Intf_Tool tool;
  Bnd_Box   box;
  box.Update(0, 0, 0, 10, 10, 10);
  Bnd_Box lineBox;
  tool.LinBox(gp_Lin(o, d), box, lineBox);
  printf("Intf_Tool::LinBox %s: NbSegments=%d\n", name, tool.NbSegments());
  for (int i = 1; i <= tool.NbSegments(); i++)
    printf("  segment %d: BeginParam=%.17g EndParam=%.17g\n", i, tool.BeginParam(i), tool.EndParam(i));
}

int main()
{
  // OCCTIntToolsComputeVV and friends
  TopoDS_Vertex v0 = BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0));
  TopoDS_Vertex v0b = BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0));
  TopoDS_Vertex v100 = BRepBuilderAPI_MakeVertex(gp_Pnt(100, 100, 100));
  printf("IntTools_Tools::ComputeVV coincident=%d distant=%d\n",
         IntTools_Tools::ComputeVV(v0, v0b), IntTools_Tools::ComputeVV(v0, v100));
  printf("IntTools_Tools::IntermediatePoint(0, 1)=%.17g\n", IntTools_Tools::IntermediatePoint(0.0, 1.0));
  printf("IntTools_Tools::IsDirsCoinside X,X=%d X,Y=%d\n",
         IntTools_Tools::IsDirsCoinside(gp_Dir(1, 0, 0), gp_Dir(1, 0, 0)),
         IntTools_Tools::IsDirsCoinside(gp_Dir(1, 0, 0), gp_Dir(0, 1, 0)));
  printf("IntTools_Tools::ComputeIntRange(0.001, 0.001, pi/4)=%.17g\n",
         IntTools_Tools::ComputeIntRange(0.001, 0.001, M_PI / 4));

  // OCCTIntfToolLinBox / BeginParam / EndParam, box (0,0,0)-(10,10,10)
  linBox("clipLineToBox (0,0,-10)+Z", gp_Pnt(0, 0, -10), gp_Dir(0, 0, 1));
  linBox("segmentParameters (5,5,-10)+Z", gp_Pnt(5, 5, -10), gp_Dir(0, 0, 1));
  linBox("lineParallelToFace (5,5,5)+X", gp_Pnt(5, 5, 5), gp_Dir(1, 0, 0));
  linBox("lineMissesBox (100,100,100)+Y", gp_Pnt(100, 100, 100), gp_Dir(0, 1, 0));
  linBox("lineThroughCenter (5,5,-100)+Z", gp_Pnt(5, 5, -100), gp_Dir(0, 0, 1));

  // OCCTShapeSectionWiresAtZ on Shape.box(60,60,10) (centred) fused with Shape.cylinder(15, 20)
  {
    TopoDS_Shape base = BRepPrimAPI_MakeBox(gp_Pnt(-30, -30, -5), 60, 60, 10).Shape();
    TopoDS_Shape boss = BRepPrimAPI_MakeCylinder(15, 20).Shape();
    BRepAlgoAPI_Fuse fuse(base, boss);
    TopoDS_Shape combined = fuse.Shape();
    printf("fuse IsDone=%d valid=%d\n", fuse.IsDone(), BRepCheck_Analyzer(combined).IsValid());
    BRepAlgoAPI_Section section(combined, gp_Pln(gp_Pnt(0, 0, 6), gp_Dir(0, 0, 1)));
    section.Build();
    Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
    for (TopExp_Explorer ex(section.Shape(), TopAbs_EDGE); ex.More(); ex.Next())
      edges->Append(ex.Current());
    Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
    ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges, 1e-6, false, wires);
    printf("section at z=6: edges=%d wires=%d\n", edges->Length(), wires->Length());
    double total = 0;
    for (int i = 1; i <= wires->Length(); i++)
    {
      GProp_GProps p;
      BRepGProp::LinearProperties(wires->Value(i), p);
      BRepAdaptor_CompCurve cc(TopoDS::Wire(wires->Value(i)));
      printf("  wire %d BRepGProp length=%.17g GCPnts_AbscissaPoint::Length=%.17g\n", i, p.Mass(),
             GCPnts_AbscissaPoint::Length(cc));
      total += p.Mass();
    }
    printf("  total length=%.17g (2*pi*15=%.17g)\n", total, 2 * M_PI * 15);
  }

  // occtSurfaceCurvaturePair on Surface.sphere(center: .zero, radius: 10)
  {
    Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 10);
    double uv[5][2] = {{0.0, 0.5}, {1.0, 0.5}, {0.5, 1.0}, {1.5, 0.3}, {2.0, 1.0}};
    for (auto& p : uv)
    {
      GeomLProp_SLProps props(s, p[0], p[1], 2, Precision::Confusion());
      printf("sphere r10 (%.1f, %.1f): defined=%d gaussian=%.17g mean=%.17g\n", p[0], p[1],
             props.IsCurvatureDefined(), props.GaussianCurvature(), props.MeanCurvature());
    }
  }
  return 0;
}
