// #2943: IntTools_BeanFaceIntersector reports a zero-length [0, 0] range for an edge lying in the
// face, with MinimalSquareDistance() left at RealLast().
//
// The two fixtures are the ones Tests/OCCTAnalysisTests/Intersection/IntToolsBeanFaceIntersectorTests.swift
// builds: a plane face trimmed to u,v in [-10, 10] with normal +Z, and (a) an edge from
// (-3, 0, 0) to (3, 0, 0) lying in that face, (b) an edge from (0, 0, -5) to (0, 0, 5) crossing
// it.
//
// Each fixture is run twice: once the way OCCTIntToolsBeanFaceIntersect ran it before this issue
// (construct from (edge, face), Perform), and once the way OCCT's own two callers run it
// (construct, then SetBeanParameters(BRep_Tool::Range(edge)), then Perform), see
// BRepFill_TrimShellCorner.cxx:2579-2582 and IntTools_EdgeFace.cxx:565-566.

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Plane.hxx>
#include <IntTools_BeanFaceIntersector.hxx>
#include <IntTools_Range.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

static void run(const char* label, const TopoDS_Edge& e, const TopoDS_Face& f, bool setBean)
{
  double ef = 0., el = 0.;
  BRep_Tool::Range(e, ef, el);

  IntTools_BeanFaceIntersector bfi(e, f);
  if (setBean)
  {
    bfi.SetBeanParameters(ef, el);
  }
  bfi.Perform();

  printf("%s setBean=%d BRep_Tool::Range=[%.17g, %.17g] IsDone=%d",
         label,
         setBean ? 1 : 0,
         ef,
         el,
         bfi.IsDone() ? 1 : 0);
  const double sq = bfi.MinimalSquareDistance();
  if (sq >= RealLast())
  {
    printf(" MinSqDist=RealLast(SENTINEL)");
  }
  else
  {
    printf(" MinSqDist=%.17g", sq);
  }
  const NCollection_Sequence<IntTools_Range>& r = bfi.Result();
  printf(" NbRanges=%d", r.Length());
  for (int i = 1; i <= r.Length(); i++)
  {
    printf(" [%d]=(%.17g, %.17g)", i, r.Value(i).First(), r.Value(i).Last());
  }
  printf("\n");
}

int main()
{
  occ::handle<Geom_Plane>  plane = new Geom_Plane(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  BRepBuilderAPI_MakeFace  mf(plane, -10., 10., -10., 10., Precision::Confusion());
  if (!mf.IsDone())
  {
    printf("FACE FAILED\n");
    return 1;
  }
  const TopoDS_Face f = mf.Face();

  BRepBuilderAPI_MakeEdge meOn(gp_Pnt(-3, 0, 0), gp_Pnt(3, 0, 0));
  BRepBuilderAPI_MakeEdge meCross(gp_Pnt(0, 0, -5), gp_Pnt(0, 0, 5));
  if (!meOn.IsDone() || !meCross.IsDone())
  {
    printf("EDGE FAILED\n");
    return 1;
  }
  const TopoDS_Edge eOn    = meOn.Edge();
  const TopoDS_Edge eCross = meCross.Edge();

  run("edgeOnFace", eOn, f, false);
  run("edgeOnFace", eOn, f, true);
  run("edgeCrossingFace", eCross, f, false);
  run("edgeCrossingFace", eCross, f, true);

  // A third fixture: an edge parallel to the face but 4 away from it, which lies on no part of
  // the surface. Establishes whether a correctly-ranged run that finds nothing still leaves
  // MinimalSquareDistance at the sentinel (the #726 question the issue raises).
  BRepBuilderAPI_MakeEdge meOff(gp_Pnt(-3, 0, 4), gp_Pnt(3, 0, 4));
  if (meOff.IsDone())
  {
    run("edgeOffFace", meOff.Edge(), f, false);
    run("edgeOffFace", meOff.Edge(), f, true);
  }
  return 0;
}
