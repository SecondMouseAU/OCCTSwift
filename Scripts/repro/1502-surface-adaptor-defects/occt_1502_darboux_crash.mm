// #1502 finding 1: GeomFill_Darboux::D0/D1/D2 unconditionally static_cast<>s the handle
// SetCurve() was given to Adaptor3d_CurveOnSurface* and reads its private myCurve/mySurface
// fields (GeomFill_Darboux.cxx:369-372). OCCTGeomFillDarbouxTrihedron used to hand it a plain
// BRepAdaptor_Curve, an unrelated Adaptor3d_Curve sibling with neither field at those offsets,
// an uncatchable bus error.
//
// This probe builds the issue's own fixture (a circular edge lying on a planar face) and drives
// GeomFill_Darboux both ways, selected by argv[1]:
//
//   old   the original bridge code: BRepAdaptor_Curve handed to SetCurve
//   new   the fixed bridge code: a real Adaptor3d_CurveOnSurface built from the edge's pcurve
//         on the face, via BRep_Tool::CurveOnSurface + BRepAdaptor_Surface + Geom2dAdaptor_Curve
//
// A SIGBUS/SIGSEGV handler exits 86 so a crash is a readable transcript line rather than a bare
// signal, matching Scripts/repro/1022-datum-point-from-plane-array/'s probe convention.

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <TopExp_Explorer.hxx>
#include <TopAbs.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>
#include <GeomFill_Darboux.hxx>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unistd.h>

static void crashHandler(int sig)
{
  const char* name = (sig == SIGBUS) ? "SIGBUS" : (sig == SIGSEGV) ? "SIGSEGV" : "signal";
  fprintf(stderr, "\n*** caught %s (%d) -- exiting 86 ***\n", name, sig);
  fflush(stderr);
  _exit(86);
}

static void installHandler()
{
  signal(SIGBUS, crashHandler);
  signal(SIGSEGV, crashHandler);
}

// The issue's own fixture: a circular edge belting a planar disc face, the simplest shape with
// a genuine pcurve on a real face.
static bool buildFixture(TopoDS_Edge& edge, TopoDS_Face& face)
{
  gp_Ax2 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  gp_Circ circ(axis, 5.0);
  TopoDS_Edge circEdge = BRepBuilderAPI_MakeEdge(circ);
  TopoDS_Wire wire     = BRepBuilderAPI_MakeWire(circEdge);
  TopoDS_Face f        = BRepBuilderAPI_MakeFace(wire, /* OnlyPlane */ true);
  if (f.IsNull())
    return false;
  TopExp_Explorer exp(f, TopAbs_EDGE);
  if (!exp.More())
    return false;
  edge = TopoDS::Edge(exp.Current());
  face = f;
  return true;
}

static int runOld(const TopoDS_Edge& edge)
{
  // The ORIGINAL bridge code (OCCTGeomFillDarbouxTrihedron before the #1502 fix).
  Handle(GeomFill_Darboux)  darboux = new GeomFill_Darboux();
  Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
  darboux->SetCurve(adaptor);
  gp_Vec t, n, b;
  bool   ok = darboux->D0(0.1, t, n, b);
  printf("OLD: D0 returned %s, t=(%g,%g,%g)\n", ok ? "true" : "false", t.X(), t.Y(), t.Z());
  return 0;
}

static int runNew(const TopoDS_Edge& edge, const TopoDS_Face& face)
{
  // The FIXED bridge code (OCCTGeomFillDarbouxTrihedron after the #1502 fix).
  double                first, last;
  Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(edge, face, first, last);
  if (pcurve.IsNull())
  {
    printf("NEW: no pcurve found (fixture problem, not the defect under test)\n");
    return 1;
  }

  Handle(BRepAdaptor_Surface)      brepSurf  = new BRepAdaptor_Surface(face);
  Handle(Geom2dAdaptor_Curve)      adapCurve = new Geom2dAdaptor_Curve(pcurve, first, last);
  Handle(Adaptor3d_CurveOnSurface) cos       = new Adaptor3d_CurveOnSurface(adapCurve, brepSurf);

  Handle(GeomFill_Darboux) darboux = new GeomFill_Darboux();
  darboux->SetCurve(cos);

  gp_Vec t, n, b;
  bool   ok = darboux->D0(0.1, t, n, b);
  printf("NEW: D0 returned %s, t=(%g,%g,%g), n=(%g,%g,%g), b=(%g,%g,%g)\n",
        ok ? "true" : "false",
        t.X(),
        t.Y(),
        t.Z(),
        n.X(),
        n.Y(),
        n.Z(),
        b.X(),
        b.Y(),
        b.Z());
  return ok ? 0 : 2;
}

int main(int argc, char** argv)
{
  installHandler();

  TopoDS_Edge edge;
  TopoDS_Face face;
  if (!buildFixture(edge, face))
  {
    fprintf(stderr, "fixture build failed\n");
    return 3;
  }

  std::string mode = (argc > 1) ? argv[1] : "old";
  if (mode == "old")
    return runOld(edge);
  if (mode == "new")
    return runNew(edge, face);

  fprintf(stderr, "usage: %s [old|new]\n", argv[0]);
  return 2;
}
