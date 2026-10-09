// Programmatic reduction: a block whose vertical corner edge is sharp below depth h and rounded (radius rc) above it,
// then a constant-radius fillet on the top edge of one side wall.  The blend's contact line on that wall runs at depth
// r below the top edge, so it passes through the wall's vertex at depth h when r == h.
//   mini <r> <h> <rc> [mode]   mode: 0 = fuse of sharp block and rounded cap (default), 1 = box minus a corner cutter
// RESULT status=<done|notdone|exception|signal> valid= free= vol= faces=
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_List.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <gp_Ax2.hxx>
static void onSig(int s) { printf("RESULT status=signal%d\n", s); fflush(stdout); _exit(100 + s % 100); }
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  double r = atof(argv[1]), h = atof(argv[2]), rc = atof(argv[3]); int mode = argc > 4 ? atoi(argv[4]) : 0;
  const double L = 40, W = 30, H = 20;      // block L x W x H, corner at the origin
  TopoDS_Shape body = BRepPrimAPI_MakeBox(L, W, H).Shape();
  // Round the vertical corner edge at (L, 0) only above depth h: cut away the corner prism's outer part, z in [H-h, H]
  // The cutter is (square rc x rc at the corner) minus (cylinder radius rc centred rc inside the corner).
  TopoDS_Shape sq = BRepPrimAPI_MakeBox(gp_Pnt(L - rc, 0, H - h), gp_Pnt(L + 1, rc, H + 1)).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(L - rc, rc, H - h - 0.0), gp_Dir(0, 0, 1)), rc, h + 1).Shape();
  TopoDS_Shape cutter = BRepAlgoAPI_Cut(sq, cyl).Shape();
  TopoDS_Shape rounded = BRepAlgoAPI_Cut(body, cutter).Shape();
  ShapeUpgrade_UnifySameDomain u(rounded, true, true, true); u.Build(); rounded = u.Shape();
  // top edge of the wall y = 0: the line z = H, y = 0, x from 0 to L - rc (ends where the round begins)
  TopoDS_Edge target; NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher> e2f;
  for (TopExp_Explorer ex(rounded, TopAbs_EDGE); ex.More(); ex.Next())
  { BRepAdaptor_Curve c(TopoDS::Edge(ex.Current())); if (c.GetType() != GeomAbs_Line) continue;
    gp_Pnt a = c.Value(c.FirstParameter()), b = c.Value(c.LastParameter());
    if (fabs(a.Y()) < 1e-9 && fabs(b.Y()) < 1e-9 && fabs(a.Z() - H) < 1e-9 && fabs(b.Z() - H) < 1e-9) target = TopoDS::Edge(ex.Current()); }
  if (target.IsNull()) { printf("RESULT status=setup-failed\n"); return 0; }
  try
  {
    BRepFilletAPI_MakeFillet mk(rounded); mk.Add(r, target); mk.Build();
    if (!mk.IsDone()) { printf("RESULT status=notdone\n"); return 0; }
    TopoDS_Shape res = mk.Shape(); GProp_GProps p; BRepGProp::VolumeProperties(res, p);
    int nf = 0; for (TopExp_Explorer f(res, TopAbs_FACE); f.More(); f.Next()) ++nf;
    printf("RESULT status=done valid=%d vol=%.9f faces=%d\n", (int)BRepCheck_Analyzer(res).IsValid(), p.Mass(), nf);
  }
  catch (Standard_Failure& f) { printf("RESULT status=exception %s\n", f.GetMessageString()); }
}
