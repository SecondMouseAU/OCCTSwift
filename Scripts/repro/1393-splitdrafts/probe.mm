// #1393: get LocOpe_SplitDrafts::Perform to IsDone() == true on a real face + wire.
//
// #818 recorded two failure modes: a neutral plane coincident with the face's own plane makes the
// kernel's NewPlane() helper bail, and a wire built from 3D geometry alone throws "No such curve"
// inside Perform(). This probe tries the remaining candidate: an edge built ON the face from a
// 2D line plus the face's surface, so the pcurve is the primary representation, with the 3D curve
// derived from it by BRepLib.
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <LocOpe_SplitDrafts.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax3.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt2d.hxx>
#include <cstdio>

int main()
{
  // A 10x10x10 box. The top face (z = 10) is the one to split.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  TopoDS_Face top;
  for (TopExp_Explorer exp(box, TopAbs_FACE); exp.More(); exp.Next())
  {
    TopoDS_Face          f = TopoDS::Face(exp.Current());
    Handle(Geom_Surface) s = BRep_Tool::Surface(f);
    Handle(Geom_Plane)   p = Handle(Geom_Plane)::DownCast(s);
    if (p.IsNull()) continue;
    if (fabs(p->Pln().Location().Z() - 10.0) < 1e-9)
    {
      top = f;
      break;
    }
  }
  if (top.IsNull()) { printf("no top face\n"); return 1; }

  Handle(Geom_Surface) surf = BRep_Tool::Surface(top);
  Handle(Geom_Plane)   pln  = Handle(Geom_Plane)::DownCast(surf);
  const gp_Ax3&        pos  = pln->Pln().Position();
  printf("top face plane at z=%g, local origin (%g,%g,%g)\n",
         pln->Pln().Location().Z(), pos.Location().X(), pos.Location().Y(), pos.Location().Z());

  // The splitting line, in the face's own parameter space: u = 5, all v.
  // (For this box the top face's (u, v) is (x, y), confirmed by the printout above.)
  Handle(Geom2d_Line) line2d = new Geom2d_Line(gp_Pnt2d(5.0, 0.0), gp_Dir2d(0.0, 1.0));
  TopoDS_Edge         edge   = BRepBuilderAPI_MakeEdge(line2d, surf, 0.0, 10.0).Edge();
  BRepLib::BuildCurves3d(edge);
  TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
  printf("wire built: null=%d\n", (int)wire.IsNull());

  // The neutral plane must NOT be the face's own plane: its intersection with the face has to be
  // a real line, and that line is where the wire lies. Wire at u=5 means the plane x=5.
  gp_Pln neutral(gp_Pnt(5.0, 0.0, 0.0), gp_Dir(1.0, 0.0, 0.0));

  struct Case
  {
    const char* label;
    gp_Dir      extract;
    double      angle;
  };
  const Case cases[] = {
    {"extract +X, 10 deg", gp_Dir(1, 0, 0), 10.0 * M_PI / 180.0},
    {"extract -X, 10 deg", gp_Dir(-1, 0, 0), 10.0 * M_PI / 180.0},
    {"extract +Z, 10 deg", gp_Dir(0, 0, 1), 10.0 * M_PI / 180.0},
    {"extract +X,  5 deg", gp_Dir(1, 0, 0), 5.0 * M_PI / 180.0},
  };

  for (const Case& c : cases)
  {
    LocOpe_SplitDrafts sd;
    sd.Init(box);
    bool threw = false;
    try
    {
      sd.Perform(top, wire, c.extract, neutral, c.angle);
    }
    catch (Standard_Failure const& f)
    {
      threw = true;
      printf("%-22s THREW %s\n", c.label, f.GetMessageString() ? f.GetMessageString() : "?");
    }
    catch (...)
    {
      threw = true;
      printf("%-22s THREW (unknown)\n", c.label);
    }
    if (!threw)
    {
      int nFaces = 0;
      for (TopExp_Explorer e(sd.Shape(), TopAbs_FACE); e.More(); e.Next()) nFaces++;
      printf("%-22s IsDone=%d  faces=%d (box has 6)\n", c.label, (int)sd.IsDone(), nFaces);
    }
  }
  return 0;
}
