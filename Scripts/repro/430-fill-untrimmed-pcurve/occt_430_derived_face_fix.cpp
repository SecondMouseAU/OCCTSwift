// OCCTSwift#430/#432 reproducer, part 3 of 3: the fix, and its equivalence check.
//
// Same sphere rim that SIGSEGVs in part 2, but routed through a support face
// derived from the edge's own pcurve, then added with the face-carrying
// Add(edge, face, order) overload. supportFaceFromPCurve below is a verbatim port
// of OCCTFillingSupportFaceFromPCurve from PR #435 (OCCTBridge_Healing.mm).
//
// Two things this establishes:
//
//   1. The bridge-side fix holds: the process survives, IsDone=1, and the cap has
//      real z extent, so tangency is actually delivered rather than degraded to a
//      flat disc.
//   2. Fixing the still-crashing FillingSurface path (#432) is a call-site swap,
//      not a redesign. Nothing here needs the kernel patched.
//
// Reference values on OCCT 8.0.0p1, which match what PR #435 measured against a
// kernel-patched build (one-line Geom2dAdaptor_Curve(C2d, f, l)):
//
//     cap z-extent = 7.5112   (a flat disc would be ~0)
//     G0Error      = 1.43184e-05
//     G1Error      = 1.0434e-06
//
// Build:
//   clang++ -std=c++17 -w -g -O0 \
//     -I Libraries/OCCT.xcframework/macos-arm64/Headers \
//     -L Libraries/OCCT.xcframework/macos-arm64 \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/430-fill-untrimmed-pcurve/occt_430_derived_face_fix.cpp \
//     -o /tmp/occt_430_fixed

#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>

#include <cmath>
#include <csignal>
#include <cstdio>
#include <unistd.h>

static void onFatal(int sig)
{
  fprintf(stderr, "\n*** CRASH: signal %d, the fix did NOT hold ***\n", sig);
  _exit(sig);
}

// Verbatim port of OCCTFillingSupportFaceFromPCurve (PR #435).
// Builds a face carrying the edge's own pcurve surface, so the face-carrying
// Add() overload can be used even when the caller nominated no support face.
static bool supportFaceFromPCurve(const TopoDS_Edge& edge, TopoDS_Face& outFace)
{
  Handle(Geom2d_Curve) pcurve;
  Handle(Geom_Surface) surface;
  TopLoc_Location      location;
  double               first = 0.0, last = 0.0;

  BRep_Tool::CurveOnSurface(edge, pcurve, surface, location, first, last);
  if (pcurve.IsNull() || surface.IsNull())
    return false;

  BRep_Builder builder;
  builder.MakeFace(outFace, surface, location, BRep_Tool::Tolerance(edge));
  // Only useful if the edge really does resolve a pcurve against the face just built.
  double checkFirst = 0.0, checkLast = 0.0;
  return !BRep_Tool::CurveOnSurface(edge, outFace, checkFirst, checkLast).IsNull();
}

static TopoDS_Edge rimOfTruncatedSphere(const TopoDS_Shape& bowl, double& outZ)
{
  TopoDS_Edge rim;
  double      bestZ = -1e100;
  for (TopExp_Explorer e(bowl, TopAbs_EDGE); e.More(); e.Next())
  {
    TopoDS_Edge        edge = TopoDS::Edge(e.Current());
    double             f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(edge, f, l);
    if (c.IsNull())
      continue;
    if (c->Value(f).Distance(c->Value(l)) > 1e-7)
      continue;
    if (c->Value(f).Z() > bestZ)
    {
      bestZ = c->Value(f).Z();
      rim   = edge;
    }
  }
  outZ = bestZ;
  return rim;
}

int main()
{
  signal(SIGSEGV, onFatal);
  signal(SIGBUS, onFatal);

  TopoDS_Shape bowl =
    BRepPrimAPI_MakeSphere(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10.0, -M_PI / 2.0,
                           50.0 * M_PI / 180.0)
      .Shape();

  double      rimZ = 0.0;
  TopoDS_Edge rim  = rimOfTruncatedSphere(bowl, rimZ);
  if (rim.IsNull())
  {
    printf("FIXTURE FAIL: no closed rim edge found\n");
    return 2;
  }
  printf("Rim at z = %.4f\n", rimZ);

  TopoDS_Face derived;
  if (!supportFaceFromPCurve(rim, derived))
  {
    printf("RESULT: could not derive a support face\n");
    return 2;
  }
  printf("Derived a support face from the rim's own pcurve.\n");
  fflush(stdout);

  try
  {
    BRepOffsetAPI_MakeFilling filling;
    filling.Add(rim, derived, GeomAbs_G1, true);
    filling.Build();
    printf("RESULT: IsDone=%d\n", filling.IsDone() ? 1 : 0);
    if (filling.IsDone())
    {
      Bnd_Box bb;
      BRepBndLib::Add(filling.Shape(), bb);
      double xm, ym, zm, xM, yM, zM;
      bb.Get(xm, ym, zm, xM, yM, zM);
      printf("        cap z-extent = %.4f (a flat disc would be ~0)\n", zM - zm);
      printf("        G0Error=%.6g G1Error=%.6g\n", filling.G0Error(), filling.G1Error());
    }
  }
  catch (Standard_Failure const& f)
  {
    printf("RESULT: threw Standard_Failure(\"%s\")\n",
           f.GetMessageString() ? f.GetMessageString() : "?");
  }

  printf("Process survived.\n");
  return 0;
}
