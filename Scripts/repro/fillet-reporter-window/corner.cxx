// Programmatic reduction for the junction of the reporter's model (OCCT#1568), no model.brep needed.
//   corner <r> [R] [mode]
// A box L x W x H with the three edges at the corner (L, 0, 0) rounded by R (a vertex blend: two cylinders and a
// sphere patch, all G1 to the front wall F), then a constant-radius fillet on the top edge of F. The blend's contact
// line on F runs at depth r below that edge, so it passes through F's vertex V = (L-R, 0, R) exactly when r = H - R,
// where F's two boundary edges at V (both G1 to a cylinder) meet.   mode 1 = fillet the corner edges one at a time.
// RESULT status=<done|notdone|exception|signal> valid= vol= faces=
#include <BRepAdaptor_Curve.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <unistd.h>
static void onSig(int s) { printf("RESULT status=signal%d\n", s); fflush(stdout); _exit(100 + s % 100); }
static TopoDS_Edge lineEdge(const TopoDS_Shape& s, gp_Pnt a, gp_Pnt b) // the straight edge whose end points are a and b
{
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next())
  { BRepAdaptor_Curve c(TopoDS::Edge(ex.Current())); if (c.GetType() != GeomAbs_Line) continue;
    gp_Pnt p = c.Value(c.FirstParameter()), q = c.Value(c.LastParameter());
    if ((p.Distance(a) < 1e-7 && q.Distance(b) < 1e-7) || (p.Distance(b) < 1e-7 && q.Distance(a) < 1e-7)) return TopoDS::Edge(ex.Current()); }
  return TopoDS_Edge();
}
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  double r = atof(argv[1]), R = argc > 2 ? atof(argv[2]) : 5.0;
  const double L = 40, W = 30, H = 20;
  TopoDS_Shape box = BRepPrimAPI_MakeBox(L, W, H).Shape();
  try
  {
    BRepFilletAPI_MakeFillet c(box);
    c.Add(R, lineEdge(box, gp_Pnt(L, 0, 0), gp_Pnt(L, 0, H)));
    c.Add(R, lineEdge(box, gp_Pnt(0, 0, 0), gp_Pnt(L, 0, 0)));
    c.Add(R, lineEdge(box, gp_Pnt(L, 0, 0), gp_Pnt(L, W, 0)));
    c.Build();
    if (!c.IsDone()) { printf("RESULT status=setup-failed\n"); return 0; }
    TopoDS_Shape body = c.Shape();
    TopoDS_Edge top = lineEdge(body, gp_Pnt(0, 0, H), gp_Pnt(L - R, 0, H));
    if (top.IsNull()) { printf("RESULT status=no-top-edge\n"); return 0; }
    BRepFilletAPI_MakeFillet mk(body); mk.Add(r, top); mk.Build();
    if (!mk.IsDone()) { printf("RESULT status=notdone\n"); return 0; }
    TopoDS_Shape res = mk.Shape(); GProp_GProps p; BRepGProp::VolumeProperties(res, p);
    int nf = 0; for (TopExp_Explorer f(res, TopAbs_FACE); f.More(); f.Next()) ++nf;
    printf("RESULT status=done valid=%d vol=%.9f faces=%d\n", (int)BRepCheck_Analyzer(res).IsValid(), p.Mass(), nf);
  }
  catch (Standard_Failure& f) { printf("RESULT status=exception %s\n", f.GetMessageString()); }
}
