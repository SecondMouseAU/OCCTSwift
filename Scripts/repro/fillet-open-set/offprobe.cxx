#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <cstdio>
int main(int argc, char** argv)
{
  TopoDS_Shape s; BRep_Builder bb; BRepTools::Read(s, argv[1], bb);
  BRepOffsetAPI_MakeOffsetShape mk;
  mk.PerformByJoin(s, 1.0, 1e-7, BRepOffset_Skin, false, false, GeomAbs_Arc, false);
  printf("done=%d\n", mk.IsDone());
  if (!mk.IsDone()) return 0;
  TopoDS_Shape r = mk.Shape();
  GProp_GProps g; BRepGProp::VolumeProperties(r, g);
  GProp_GProps g0; BRepGProp::VolumeProperties(s, g0);
  int faces = 0, solids = 0, shells = 0;
  for (TopExp_Explorer e(r, TopAbs_FACE); e.More(); e.Next()) ++faces;
  for (TopExp_Explorer e(r, TopAbs_SOLID); e.More(); e.Next()) ++solids;
  for (TopExp_Explorer e(r, TopAbs_SHELL); e.More(); e.Next()) ++shells;
  BOPAlgo_ArgumentAnalyzer a; a.SetShape1(r); a.SelfInterMode() = true; a.SmallEdgeMode() = true; a.Perform();
  printf("valid=%d bopfaults=%d solids=%d shells=%d faces=%d vol=%.6g (input vol %.6g)\n", BRepCheck_Analyzer(r).IsValid(), a.HasFaulty() ? (int)a.GetCheckResult().Size() : 0, solids, shells, faces, g.Mass(), g0.Mass());
}
