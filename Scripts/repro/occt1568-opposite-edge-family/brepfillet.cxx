// Fillet named edges of a BREP, edges numbered as DRAW's explode (the model of OCCT#1568).
//   brepfillet model.brep radius e1 [e2 ...]       all edges in one operation
// One process per case: before the fix the original defect is an uncatchable SIGSEGV.
#include <BRep_Builder.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_Map.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <cstdlib>
#include <csignal>
#include <unistd.h>
#include <vector>
static void onSig(int s)
{
  printf("RESULT SIGNAL %d\n", s);
  fflush(stdout);
  _exit(100 + s % 100);
}
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig);
  signal(SIGBUS, onSig);
  TopoDS_Shape model;
  BRep_Builder bb;
  BRepTools::Read(model, argv[1], bb);
  const double radius = atof(argv[2]);
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen;
  seen.Add(model);
  std::vector<TopoDS_Edge> edges(1);
  for (TopExp_Explorer ex(model, TopAbs_EDGE); ex.More(); ex.Next())
    if (seen.Add(ex.Current())) edges.push_back(TopoDS::Edge(ex.Current()));
  try
  {
    BRepFilletAPI_MakeFillet mk(model);
    for (int i = 3; i < argc; ++i) mk.Add(radius, edges[atoi(argv[i])]);
    mk.Build();
    bool valid = false;
    double vol = -1;
    if (mk.IsDone())
    {
      valid = BRepCheck_Analyzer(mk.Shape()).IsValid();
      GProp_GProps p;
      BRepGProp::VolumeProperties(mk.Shape(), p);
      vol = p.Mass();
    }
    printf("RESULT done=%d faulty=%d valid=%d vol=%.9g\n", (int)mk.IsDone(), mk.NbFaultyContours(), (int)valid, vol);
  }
  catch (Standard_Failure& f)
  {
    printf("RESULT exception %s\n", f.GetMessageString());
  }
  return 0;
}
