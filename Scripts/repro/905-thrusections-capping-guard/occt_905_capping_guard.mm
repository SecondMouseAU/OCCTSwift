// Ground truth probe for OCCTSwift#905:
// BRepOffsetAPI_ThruSections(isSolid: true) silently omits both end-cap faces for a closed
// section wire with k >= 2 periods of out-of-plane variation around the loop, and still reports
// IsDone() == true.
//
// MakeSolid() (static helper in BRepOffsetAPI_ThruSections.cxx, shared by CreateRuled() and
// CreateSmoothed()) caps each end via PerformPlan(), which only fits a plane
// (BRepBuilderAPI_FindPlane) or reuses a surface already attached to the wire's edges
// (BRepLib_FindSurface-backed MakeFace(wire)). A wire with k >= 2 out-of-plane periods has
// neither. MakeSolid() already tracks whether capping succeeded in a local `bool B` (threaded
// through both PerformPlan() calls) and discards it: it marks the shell/solid Closed(true)
// unconditionally regardless.
//
// This probe runs two cases and prints IsDone()/face count/checkResult for each:
//
//   1. saddle: two closed k=2 "saddle" wires (genuinely non-planar, no fitting plane). Stock:
//      IsDone() == true, wall-only face count, BRepCheck_Analyzer invalid. Patched: IsDone() ==
//      false.
//   2. cone: a circular wire lofted to a degenerate vertex (AddVertex(), a cone's apex) --
//      PerformPlan()'s degenerate-wire shortcut returns success with a null face; this must NOT
//      be treated as a capping failure. Stock and patched: both IsDone() == true. This is
//      BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge's own shape (TKBO GTests),
//      reproduced standalone here since that test needs BRepAlgoAPI_Fuse + a box, which this
//      probe doesn't need to reproduce the mechanism.
//
// Compile once against the stock archive and once with a patched
// BRepOffsetAPI_ThruSections.cxx override-linked in front (see README.md), and diff.

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <gce_MakeCirc.hxx>
#include <gp.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <Standard_Failure.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Wire.hxx>

#include <cmath>
#include <cstdio>

namespace
{
TopoDS_Wire saddleWire(double theRadius, int theK, double theAmp, double theZOffset, int theN)
{
  BRepBuilderAPI_MakePolygon aPolygon;
  for (int i = 0; i < theN; ++i)
  {
    double aTheta = 2.0 * M_PI * i / theN;
    double aZ     = theAmp * cos(theK * aTheta) + theZOffset;
    aPolygon.Add(gp_Pnt(theRadius * cos(aTheta), theRadius * sin(aTheta), aZ));
  }
  aPolygon.Close();
  return aPolygon.Wire();
}

int faceCount(const TopoDS_Shape& theShape)
{
  int aCount = 0;
  for (TopExp_Explorer anExp(theShape, TopAbs_FACE); anExp.More(); anExp.Next())
  {
    ++aCount;
  }
  return aCount;
}
} // namespace

int main()
{
  // Case 1: saddle -- the actual defect.
  {
    TopoDS_Wire anOuter = saddleWire(20.0, 2, 5.0, 0.0, 60);
    TopoDS_Wire anInner = saddleWire(15.0, 2, 5.0, -10.0, 60);

    BRepOffsetAPI_ThruSections aLoft(true, false); // solid, smoothed
    aLoft.CheckCompatibility(true);
    aLoft.AddWire(anOuter);
    aLoft.AddWire(anInner);
    bool aThrew = false;
    try
    {
      aLoft.Build();
    }
    catch (Standard_Failure const& theExc)
    {
      aThrew = true;
      printf("saddle: Build() threw: %s\n", theExc.GetMessageString());
    }
    printf("saddle: IsDone()=%d  threw=%d", aLoft.IsDone(), aThrew);
    if (aLoft.IsDone())
    {
      TopoDS_Shape aShape = aLoft.Shape();
      BRepCheck_Analyzer anAnalyzer(aShape);
      printf("  faceCount=%d  checkValid=%d", faceCount(aShape), anAnalyzer.IsValid());
    }
    printf("\n");
  }

  // Case 2: cone/apex -- the regression the first (null-face) fix attempt hit.
  {
    gce_MakeCirc aMakeCirc(gp_Ax2(gp_Pnt(0, 0, 0), gp::DZ()), 10.0);
    BRepBuilderAPI_MakeEdge aMakeEdge(aMakeCirc.Value());
    BRepBuilderAPI_MakeWire aMakeWire(aMakeEdge.Edge());
    BRepBuilderAPI_MakeVertex aMakeApex(gp_Pnt(0, 0, 20.0));

    BRepOffsetAPI_ThruSections aLoft(true, true); // solid, ruled
    aLoft.AddWire(aMakeWire.Wire());
    aLoft.AddVertex(aMakeApex.Vertex());
    bool aThrew = false;
    try
    {
      aLoft.Build();
    }
    catch (Standard_Failure const& theExc)
    {
      aThrew = true;
      printf("cone: Build() threw: %s\n", theExc.GetMessageString());
    }
    printf("cone: IsDone()=%d  threw=%d", aLoft.IsDone(), aThrew);
    if (aLoft.IsDone())
    {
      TopoDS_Shape aShape = aLoft.Shape();
      BRepCheck_Analyzer anAnalyzer(aShape);
      printf("  faceCount=%d  checkValid=%d", faceCount(aShape), anAnalyzer.IsValid());
    }
    printf("\n");
  }

  return 0;
}
