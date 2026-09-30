// Epic #766, PR #2361 evidence fix. The six Issue446UnifyInputMutationTests records all carried one
// generic payload ({resultFaces, inputUnchanged} against {inputFaces, resultFaces, volume,
// inputFacesAfter, boxSharedFaces}), so none of them compared what its own test observes. This probe
// makes, per test, the same OCCT calls the bridge makes and prints exactly the quantities that test
// asserts, at %.17g where a number:
//   Shape.unified()            OCCTShapeUnifySameDomain -> occtUnifySameDomain: BRepBuilderAPI_Copy, then
//                              ShapeUpgrade_UnifySameDomain(copy, edges, faces, concatBSplines) Build
//   Shape.simplified()         OCCTShapeSimplify: occtUnifySameDomain(true,true,true), then
//                              ShapeFix_Shape(unified) SetPrecision(1e-6) Perform
//   UnifySameDomainBuilder     OCCTUnifySameDomainCreate/Build: the same on a private copy the builder owns;
//                              keepShape maps the caller's sub-shape through copier.ModifiedShape
//   isSelfIntersecting         OCCTShapeSelfIntersectsBounded: BOPAlgo_ArgumentAnalyzer with
//                              ArgumentTypeMode, SelfInterMode, StopOnFirstFaulty, no parallel run
//   Exporter.brepData          BRepTools::Write(shape, stream, withTriangles=false, withNormals=false,
//                              TopTools_FormatVersion_CURRENT)
// Fixture: two coaxial r=5 h=10 cylinders fused end to end (4 faces); and a centred 10 x 10 x 10 box.
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BOPAlgo_CheckResult.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <GProp_GProps.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <sstream>
#include <string>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static std::string brep(const TopoDS_Shape& s)
{
  std::ostringstream os;
  BRepTools::Write(s, os, false, false, TopTools_FormatVersion_CURRENT);
  return os.str();
}

// OCCTShapeSelfIntersectsBounded with no watchdog: 1 self-intersects, 0 clean, -1 anything else.
static int selfIntersects(const TopoDS_Shape& s)
{
  BOPAlgo_ArgumentAnalyzer aa;
  aa.SetShape1(s);
  aa.ArgumentTypeMode()  = true;
  aa.SelfInterMode()     = true;
  aa.StopOnFirstFaulty() = true;
  aa.SetRunParallel(false);
  aa.Perform();
  bool selfInt = false, other = false;
  for (NCollection_List<BOPAlgo_CheckResult>::Iterator it(aa.GetCheckResult()); it.More(); it.Next())
  {
    if (it.Value().GetCheckStatus() == BOPAlgo_SelfIntersect)
      selfInt = true;
    else
      other = true;
  }
  return other ? -1 : (selfInt ? 1 : 0);
}

static TopoDS_Shape stacked()
{
  TopoDS_Shape lower = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape upper = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1)), 5, 10).Shape();
  return BRepAlgoAPI_Fuse(lower, upper).Shape();
}

int main()
{
  TopoDS_Shape body = stacked();
  printf("fixture stacked cylinders: faces=%d volume=%.17g\n", unique(body, TopAbs_FACE), vol(body));

  // a) Shape.unified()
  {
    std::string         before = brep(body);
    double              vb     = vol(body);
    BRepBuilderAPI_Copy copier(body);
    ShapeUpgrade_UnifySameDomain u(copier.Shape(), true, true, true);
    u.Build();
    printf("a unified: resultFaces=%d inputFaces=%d bytesIdentical=%d volBefore=%.17g volAfter=%.17g mergedVol=%.17g\n",
           unique(u.Shape(), TopAbs_FACE), unique(body, TopAbs_FACE), (int)(brep(body) == before), vb, vol(body), vol(u.Shape()));
  }
  // b) a box: nothing to merge, and the result shares no face with the input
  {
    TopoDS_Shape        box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepBuilderAPI_Copy copier(box);
    ShapeUpgrade_UnifySameDomain u(copier.Shape(), true, true, true);
    u.Build();
    TopTools_IndexedMapOfShape in, out;
    TopExp::MapShapes(box, TopAbs_FACE, in);
    TopExp::MapShapes(u.Shape(), TopAbs_FACE, out);
    int shared = 0;
    for (int i = 1; i <= in.Extent(); i++)
      for (int j = 1; j <= out.Extent(); j++)
        if (out(j).IsSame(in(i)))
          shared++;
    printf("b share: resultFaces=%d boxFaces=%d isSame=%d shared=%d\n", out.Extent(), in.Extent(), (int)u.Shape().IsSame(box), shared);
  }
  // c) UnifySameDomainBuilder(unifyEdges, unifyFaces) with a 10 degree angular tolerance
  {
    std::string         before = brep(body);
    BRepBuilderAPI_Copy copier(body);
    ShapeUpgrade_UnifySameDomain u(copier.Shape(), true, true, true);
    u.SetAngularTolerance(10.0 * M_PI / 180);
    u.Build();
    printf("c builder: resultFaces=%d bytesIdentical=%d\n", unique(u.Shape(), TopAbs_FACE), (int)(brep(body) == before));
  }
  // d) a declined merge: the builder runs, the caller keeps its own shape
  {
    int    siBefore = selfIntersects(body);
    int    validB   = BRepCheck_Analyzer(body).IsValid() ? 1 : 0;
    double vb       = vol(body);
    BRepBuilderAPI_Copy copier(body);
    ShapeUpgrade_UnifySameDomain u(copier.Shape(), true, true, true);
    u.Build();
    printf("d declined: resultFaces=%d inputFaces=%d siBefore=%d siAfter=%d validBefore=%d validAfter=%d volBefore=%.17g volAfter=%.17g\n",
           unique(u.Shape(), TopAbs_FACE), unique(body, TopAbs_FACE), siBefore, selfIntersects(body), validB,
           BRepCheck_Analyzer(body).IsValid() ? 1 : 0, vb, vol(body));
  }
  // e) Shape.simplified(): unify on a copy, then ShapeFix_Shape at 1e-6
  {
    std::string         before = brep(body);
    BRepBuilderAPI_Copy copier(body);
    ShapeUpgrade_UnifySameDomain u(copier.Shape(), true, true, true);
    u.Build();
    Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(u.Shape());
    fixer->SetPrecision(1e-6);
    fixer->Perform();
    TopoDS_Shape r = fixer->Shape();
    printf("e simplified: nonNil=%d bytesIdentical=%d faces=%d\n", (int)!r.IsNull(), (int)(brep(body) == before), r.IsNull() ? -1 : unique(r, TopAbs_FACE));
  }
  // f) keepShape: each circular edge of the caller's body, mapped onto the builder's copy
  {
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(body, TopAbs_EDGE, edges);
    for (int i = 1; i <= edges.Extent(); i++)
    {
      BRepAdaptor_Curve c(TopoDS::Edge(edges(i)));
      if (c.GetType() != GeomAbs_Circle)
        continue;
      BRepBuilderAPI_Copy copier(body);
      ShapeUpgrade_UnifySameDomain u(copier.Shape(), true, true, true);
      u.KeepShape(copier.ModifiedShape(edges(i)));
      u.Build();
      printf("f keep: edgeIndex=%d centerZ=%.17g faces=%d\n", i - 1, c.Circle().Location().Z(), unique(u.Shape(), TopAbs_FACE));
    }
  }
  return 0;
}
