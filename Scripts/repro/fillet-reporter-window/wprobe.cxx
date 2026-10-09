// Reporter-model fillet probe (OCCT#1568, OCCTSwift#2881): one edge, one radius, one process.
//   wprobe model.brep <radius> <draw edge number> [draw|def] [out.brep]
// draw = BRepTest_FilletCommands parameters (what the reporter's DRAW script used), def = the OCCTSwift
// bridge (no SetParams). Edge numbering follows DBRep explode(): TopExp_Explorer, IsSame-deduplicated.
// The last stdout line is machine-read:  RESULT status=<done|notdone|exception|signal> valid= closed= vol= faces= mesh=
#include <BRepBndLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <ChFi3d_FilletShape.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_List.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_Map.hxx>
#include <Poly_Triangulation.hxx>
#include <Standard_Failure.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <BRep_Tool.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <unistd.h>
static void onSig(int s) { printf("RESULT status=signal%d\n", s); fflush(stdout); _exit(100 + s % 100); }
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  TopoDS_Shape s; BRep_Builder b; BRepTools::Read(s, argv[1], b);
  if (getenv("TOLCAP")) { ShapeFix_ShapeTolerance t; double c = atof(getenv("TOLCAP")); t.LimitTolerance(s, 0., c, TopAbs_VERTEX); t.LimitTolerance(s, 0., c, TopAbs_EDGE); } // experiment only: cap the input tolerances
  double R = atof(argv[2]); int want = atoi(argv[3]);
  bool draw = argc > 4 && !strcmp(argv[4], "draw");
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(s);
  int n = 0; TopoDS_Edge E;
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) { if (++n == want) E = TopoDS::Edge(ex.Current()); }
  if (getenv("EDGEMAP")) { // TopExp::MapShapes numbering, unique edges
    NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> em; TopExp::MapShapes(s, TopAbs_EDGE, em);
    if (want > em.Extent()) { printf("RESULT status=noedge nedges=%d\n", em.Extent()); return 0; }
    E = TopoDS::Edge(em(want)); }
  if (E.IsNull()) { printf("RESULT status=noedge distinct=%d\n", n); return 0; }
  try
  {
    BRepFilletAPI_MakeFillet mk(s, ChFi3d_Rational);
    if (draw) { mk.SetParams(1e-2, 1e-4, 1e-5, 1e-4, 1e-5, 1e-3); mk.SetContinuity(GeomAbs_C1, 1e-2); }
    mk.Add(R, E);
    mk.Build();
    if (!mk.IsDone()) { printf("faulty=%d stripe=%d\nRESULT status=notdone\n", mk.NbFaultyContours(), mk.NbFaultyContours() ? (int)mk.StripeStatus(mk.FaultyContour(1)) : -1); return 0; }
    TopoDS_Shape r = mk.Shape();
    bool valid = BRepCheck_Analyzer(r).IsValid();
    GProp_GProps p; BRepGProp::VolumeProperties(r, p);
    int nf = 0; for (TopExp_Explorer e(r, TopAbs_FACE); e.More(); e.Next()) ++nf;
    NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher> e2f;
    TopExp::MapShapesAndAncestors(r, TopAbs_EDGE, TopAbs_FACE, e2f);
    int freeE = 0;
    for (int i = 1; i <= e2f.Extent(); ++i)
    { const TopoDS_Edge& e = TopoDS::Edge(e2f.FindKey(i)); if (BRep_Tool::Degenerated(e)) continue; if (e2f(i).Size() < 2) { // a seam shows once per face: count distinct faces/orientations
        int cnt = 0; for (TopExp_Explorer fx(r, TopAbs_FACE); fx.More(); fx.Next()) for (TopExp_Explorer ex2(fx.Current(), TopAbs_EDGE); ex2.More(); ex2.Next()) if (ex2.Current().IsSame(e)) ++cnt;
        if (cnt < 2) ++freeE; } }
    int meshOk = 1;
    try { BRepMesh_IncrementalMesh m(r, 0.05, false, 0.5, true); TopLoc_Location l;
      for (TopExp_Explorer fx(r, TopAbs_FACE); fx.More(); fx.Next()) { auto t = BRep_Tool::Triangulation(TopoDS::Face(fx.Current()), l); if (t.IsNull() || t->NbTriangles() == 0) meshOk = 0; } }
    catch (...) { meshOk = -1; }
    if (argc > 5) BRepTools::Write(r, argv[5]);
    printf("RESULT status=done valid=%d free=%d vol=%.9f faces=%d mesh=%d\n", (int)valid, freeE, p.Mass(), nf, meshOk);
  }
  catch (Standard_Failure& f) { printf("RESULT status=exception %s\n", f.GetMessageString()); }
  catch (...) { printf("RESULT status=exception unknown\n"); }
  return 0;
}
