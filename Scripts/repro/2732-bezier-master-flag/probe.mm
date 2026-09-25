// Ground truth probe for #2732: OCCTShapeUpgradeConvertCurves3dToBezier and
// OCCTShapeUpgradeConvertSurfaceToBezier never call the ShapeUpgrade_ShapeConvertToBezier master
// switch (Set3dConversion / SetSurfaceConversion), so Perform() is a no-op and Result() is null.
//
// This probe answers the "One thing to check before fixing" question in the issue: with the
// master flag on, several converted shapes report valid=0 from BRepCheck_Analyzer. Is that the
// kernel's own behaviour for a Bezier conversion, a tolerance effect, or something the wrapper
// should repair?
//
// Fixtures match Sources/OCCTBridge/src/OCCTBridge_Modeling_SolidPrimitives.mm exactly:
//   OCCTShapeCreateBox(w,h,d)      -> BRepPrimAPI_MakeBox(gp_Pnt(-w/2,-h/2,-d/2), w, h, d)
//   OCCTShapeCreateCylinder(r,h)   -> BRepPrimAPI_MakeCylinder(r, h)
// and every conversion call reproduces the exact bool arguments the six affected Swift tests use.
//
// Build: see Scripts/repro/2732-bezier-master-flag/README.md or the ground-truth-probe skill.

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepGProp.hxx>
#include <BRepLib_CheckCurveOnSurface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <cmath>

static const char* statusName(BRepCheck_Status s)
{
  switch (s)
  {
  case BRepCheck_NoError: return "NoError";
  case BRepCheck_InvalidPointOnCurve: return "InvalidPointOnCurve";
  case BRepCheck_InvalidPointOnCurveOnSurface: return "InvalidPointOnCurveOnSurface";
  case BRepCheck_InvalidPointOnSurface: return "InvalidPointOnSurface";
  case BRepCheck_No3DCurve: return "No3DCurve";
  case BRepCheck_Multiple3DCurve: return "Multiple3DCurve";
  case BRepCheck_Invalid3DCurve: return "Invalid3DCurve";
  case BRepCheck_NoCurveOnSurface: return "NoCurveOnSurface";
  case BRepCheck_InvalidCurveOnSurface: return "InvalidCurveOnSurface";
  case BRepCheck_InvalidCurveOnClosedSurface: return "InvalidCurveOnClosedSurface";
  case BRepCheck_InvalidSameRangeFlag: return "InvalidSameRangeFlag";
  case BRepCheck_InvalidSameParameterFlag: return "InvalidSameParameterFlag";
  case BRepCheck_InvalidDegeneratedFlag: return "InvalidDegeneratedFlag";
  case BRepCheck_FreeEdge: return "FreeEdge";
  case BRepCheck_InvalidMultiConnexity: return "InvalidMultiConnexity";
  case BRepCheck_InvalidRange: return "InvalidRange";
  case BRepCheck_EmptyWire: return "EmptyWire";
  case BRepCheck_RedundantEdge: return "RedundantEdge";
  case BRepCheck_SelfIntersectingWire: return "SelfIntersectingWire";
  case BRepCheck_NoSurface: return "NoSurface";
  case BRepCheck_InvalidWire: return "InvalidWire";
  case BRepCheck_RedundantWire: return "RedundantWire";
  case BRepCheck_IntersectingWires: return "IntersectingWires";
  case BRepCheck_InvalidImbricationOfWires: return "InvalidImbricationOfWires";
  case BRepCheck_EmptyShell: return "EmptyShell";
  case BRepCheck_RedundantFace: return "RedundantFace";
  case BRepCheck_InvalidImbricationOfShells: return "InvalidImbricationOfShells";
  case BRepCheck_UnorientableShape: return "UnorientableShape";
  case BRepCheck_NotClosed: return "NotClosed";
  case BRepCheck_NotConnected: return "NotConnected";
  case BRepCheck_SubshapeNotInShape: return "SubshapeNotInShape";
  case BRepCheck_BadOrientation: return "BadOrientation";
  case BRepCheck_BadOrientationOfSubshape: return "BadOrientationOfSubshape";
  case BRepCheck_InvalidPolygonOnTriangulation: return "InvalidPolygonOnTriangulation";
  case BRepCheck_InvalidToleranceValue: return "InvalidToleranceValue";
  case BRepCheck_EnclosedRegion: return "EnclosedRegion";
  case BRepCheck_CheckFail: return "CheckFail";
  }
  return "Unknown";
}

// Explains every invalid edge/face by walking the analyzer's per-subshape and in-context status
// lists, and for InvalidCurveOnSurface/InvalidSameParameterFlag on an edge, measures the actual
// max 3D deviation between the edge's curve and its pcurve-on-surface with
// BRepLib_CheckCurveOnSurface so a tolerance-sized gap can be told apart from a structural one.
static void explainInvalid(const TopoDS_Shape& shape, const char* label)
{
  BRepCheck_Analyzer analyzer(shape, /*GeomControls*/ true);
  bool                valid = analyzer.IsValid();
  std::printf("  [%s] BRepCheck_Analyzer.IsValid() = %d\n", label, valid ? 1 : 0);
  if (valid)
    return;

  TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
  TopExp::MapShapesAndAncestors(shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);

  // Deduped via TopExp::MapShapes, same as Shape.edges(): a bare TopExp_Explorer walk visits
  // each edge once per adjoining face and would print every diagnosis twice on a closed solid.
  TopTools_IndexedMapOfShape edgeMap;
  TopExp::MapShapes(shape, TopAbs_EDGE, edgeMap);
  int invalidEdges = 0, printedEdges = 0;
  for (int ei = 1; ei <= edgeMap.Extent(); ei++)
  {
    const TopoDS_Edge& edge = TopoDS::Edge(edgeMap(ei));
    if (analyzer.IsValid(edge))
      continue;
    invalidEdges++;
    if (!analyzer.Result(edge).IsNull() && printedEdges < 2)
    {
      printedEdges++;
      const Handle(BRepCheck_Result)& res = analyzer.Result(edge);
      for (NCollection_List<BRepCheck_Status>::Iterator it(res->Status()); it.More(); it.Next())
        std::printf("    EDGE direct status: %s\n", statusName(it.Value()));
      bool sameParam = BRep_Tool::SameParameter(edge);
      bool sameRange = BRep_Tool::SameRange(edge);
      double tol     = BRep_Tool::Tolerance(edge);
      std::printf(
          "    EDGE SameParameter=%d SameRange=%d Tolerance=%.9g\n", sameParam, sameRange, tol);
      for (res->InitContextIterator(); res->MoreShapeInContext(); res->NextShapeInContext())
      {
        for (NCollection_List<BRepCheck_Status>::Iterator it(res->StatusOnShape()); it.More();
             it.Next())
          std::printf("    EDGE in-context status: %s\n", statusName(it.Value()));
      }
      // Measure the actual curve-on-surface deviation against every adjacent face, regardless
      // of SameParameter, so a false SameParameter flag doesn't hide the number.
      if (edgeFaceMap.Contains(edge))
      {
        const TopTools_ListOfShape& faces = edgeFaceMap.FindFromKey(edge);
        for (TopTools_ListIteratorOfListOfShape fit(faces); fit.More(); fit.Next())
        {
          const TopoDS_Face&           face = TopoDS::Face(fit.Value());
          BRepLib_CheckCurveOnSurface  check(edge, face);
          check.Perform();
          std::printf(
              "    EDGE vs FACE: CheckCurveOnSurface IsDone=%d ErrorStatus=%d MaxDistance=%.9g "
              "(edge tol=%.9g)\n",
              check.IsDone(), check.ErrorStatus(), check.IsDone() ? check.MaxDistance() : -1.0,
              tol);
        }
      }
    }
  }
  std::printf("    (%d of %d mapped edges invalid, %d shown in detail)\n", invalidEdges,
              edgeMap.Extent(), printedEdges);

  TopTools_IndexedMapOfShape faceMap;
  TopExp::MapShapes(shape, TopAbs_FACE, faceMap);
  int invalidFaces = 0, printedFaces = 0;
  for (int fi = 1; fi <= faceMap.Extent(); fi++)
  {
    const TopoDS_Face& face = TopoDS::Face(faceMap(fi));
    if (analyzer.IsValid(face))
      continue;
    invalidFaces++;
    if (!analyzer.Result(face).IsNull() && printedFaces < 2)
    {
      printedFaces++;
      const Handle(BRepCheck_Result)& res = analyzer.Result(face);
      for (NCollection_List<BRepCheck_Status>::Iterator it(res->Status()); it.More(); it.Next())
        std::printf("    FACE direct status: %s\n", statusName(it.Value()));
      for (res->InitContextIterator(); res->MoreShapeInContext(); res->NextShapeInContext())
      {
        for (NCollection_List<BRepCheck_Status>::Iterator it(res->StatusOnShape()); it.More();
             it.Next())
          std::printf("    FACE in-context status: %s\n", statusName(it.Value()));
      }
    }
  }
  std::printf("    (%d of %d mapped faces invalid, %d shown in detail)\n", invalidFaces,
              faceMap.Extent(), printedFaces);
}

static void report(const char* label, const TopoDS_Shape& before, bool performed,
                    const TopoDS_Shape& result)
{
  std::printf("%s: Perform=%d Result.IsNull=%d\n", label, performed ? 1 : 0,
              result.IsNull() ? 1 : 0);
  if (result.IsNull())
    return;

  int edgeCount = 0, bezierEdges = 0;
  for (TopExp_Explorer exp(result, TopAbs_EDGE); exp.More(); exp.Next())
  {
    const TopoDS_Edge& e = TopoDS::Edge(exp.Current());
    double              f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
    if (c.IsNull())
      continue; // degenerate
    edgeCount++;
    BRepAdaptor_Curve adaptor(e);
    if (adaptor.GetType() == GeomAbs_BezierCurve)
      bezierEdges++;
  }

  int faceCount = 0, bezierFaces = 0;
  for (TopExp_Explorer exp(result, TopAbs_FACE); exp.More(); exp.Next())
  {
    faceCount++;
    BRepAdaptor_Surface adaptor(TopoDS::Face(exp.Current()));
    if (adaptor.GetType() == GeomAbs_BezierSurface)
      bezierFaces++;
  }
  (void)edgeCount;
  (void)faceCount;

  // Shape.edges()/Shape.faces(), the Swift-level API the tests read, go through
  // OCCTShapeGetSubShapeCount -> occtMapSubShapes -> TopExp::MapShapes, an INDEXED MAP that
  // dedupes by TopoDS_Shape::IsSame (same TShape + location, orientation ignored). A bare
  // TopExp_Explorer walk (used above and by explainInvalid below) visits an edge/face once per
  // adjoining face/shell and roughly doubles the count on a closed solid: confirmed on a
  // freshly built, unconverted box (24 raw vs 12 mapped) and cylinder (6 raw vs 3 mapped) in
  // edgecount.mm in this same directory. Recount with the map so the numbers below are the ones
  // Shape.edges().count / Shape.faces().count will actually report.
  TopTools_IndexedMapOfShape edgeMap, faceMap;
  TopExp::MapShapes(result, TopAbs_EDGE, edgeMap);
  TopExp::MapShapes(result, TopAbs_FACE, faceMap);
  int mappedEdgeCount = 0, mappedBezierEdges = 0;
  for (int i = 1; i <= edgeMap.Extent(); i++)
  {
    const TopoDS_Edge& e = TopoDS::Edge(edgeMap(i));
    double              f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
    if (c.IsNull())
      continue; // degenerate
    mappedEdgeCount++;
    BRepAdaptor_Curve adaptor(e);
    if (adaptor.GetType() == GeomAbs_BezierCurve)
      mappedBezierEdges++;
  }
  int mappedFaceCount = faceMap.Extent(), mappedBezierFaces = 0;
  for (int i = 1; i <= faceMap.Extent(); i++)
  {
    BRepAdaptor_Surface adaptor(TopoDS::Face(faceMap(i)));
    if (adaptor.GetType() == GeomAbs_BezierSurface)
      mappedBezierFaces++;
  }
  edgeCount   = mappedEdgeCount;
  bezierEdges = mappedBezierEdges;
  faceCount   = mappedFaceCount;
  bezierFaces = mappedBezierFaces;

  GProp_GProps volProps;
  BRepGProp::VolumeProperties(result, volProps);
  double volume = volProps.Mass();

  std::printf("  edges(non-degenerate)=%d bezierEdges=%d faces=%d bezierFaces=%d volume=%.9g\n",
              edgeCount, bezierEdges, faceCount, bezierFaces, volume);

  explainInvalid(result, label);

  // Compare against the ORIGINAL shape's own edge/face count and volume, so a passing volume
  // check is known to be comparing the same solid rather than a coincidence.
  GProp_GProps origVol;
  BRepGProp::VolumeProperties(before, origVol);
  std::printf("  (original volume=%.9g, %s)\n", origVol.Mass(),
              std::fabs(origVol.Mass() - volume) < 1e-6 ? "MATCHES" : "DIFFERS");
}

int main()
{
  // Fixtures, matching OCCTShapeCreateBox / OCCTShapeCreateCylinder exactly.
  double     w = 10, h = 10, d = 10;
  gp_Pnt     boxOrigin(-w / 2, -h / 2, -d / 2);
  TopoDS_Shape box = BRepPrimAPI_MakeBox(boxOrigin, w, h, d).Shape();

  double       radius = 5, height = 10;
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(radius, height).Shape();

  std::printf("=== curves3dToBezier ===\n");
  {
    ShapeUpgrade_ShapeConvertToBezier converter(box);
    converter.Set3dLineConversion(true);
    converter.Set3dCircleConversion(true);
    converter.Set3dConicConversion(true);
    converter.SetSurfaceSegmentMode(false);
    converter.Set3dConversion(true);
    bool ok = converter.Perform();
    report("curves3dToBezier(box, line=T circle=T conic=T)", box, ok, converter.Result());
  }
  {
    ShapeUpgrade_ShapeConvertToBezier converter(cyl);
    converter.Set3dLineConversion(true);
    converter.Set3dCircleConversion(true);
    converter.Set3dConicConversion(true);
    converter.SetSurfaceSegmentMode(false);
    converter.Set3dConversion(true);
    bool ok = converter.Perform();
    report("curves3dToBezier(cyl, line=T circle=T conic=T)", cyl, ok, converter.Result());
  }
  {
    ShapeUpgrade_ShapeConvertToBezier converter(cyl);
    converter.Set3dLineConversion(false);
    converter.Set3dCircleConversion(true);
    converter.Set3dConicConversion(false);
    converter.SetSurfaceSegmentMode(false);
    converter.Set3dConversion(true);
    bool ok = converter.Perform();
    report("curves3dToBezier(cyl, line=F circle=T conic=F)", cyl, ok, converter.Result());
  }

  std::printf("=== surfacesToBezier ===\n");
  {
    ShapeUpgrade_ShapeConvertToBezier converter(cyl);
    converter.SetPlaneMode(true);
    converter.SetRevolutionMode(true);
    converter.SetExtrusionMode(true);
    converter.SetBSplineMode(true);
    converter.SetSurfaceSegmentMode(true);
    converter.SetSurfaceConversion(true);
    bool ok = converter.Perform();
    report("surfacesToBezier(cyl, plane=T rev=T ext=T bspline=T)", cyl, ok, converter.Result());
  }
  {
    ShapeUpgrade_ShapeConvertToBezier converter(cyl);
    converter.SetPlaneMode(false);
    converter.SetRevolutionMode(true);
    converter.SetExtrusionMode(false);
    converter.SetBSplineMode(false);
    converter.SetSurfaceSegmentMode(true);
    converter.SetSurfaceConversion(true);
    bool ok = converter.Perform();
    report("surfacesToBezier(cyl, plane=F rev=T ext=F bspline=F)", cyl, ok, converter.Result());
  }
  {
    ShapeUpgrade_ShapeConvertToBezier converter(box);
    converter.SetPlaneMode(true);
    converter.SetRevolutionMode(false);
    converter.SetExtrusionMode(false);
    converter.SetBSplineMode(false);
    converter.SetSurfaceSegmentMode(true);
    converter.SetSurfaceConversion(true);
    bool ok = converter.Perform();
    report("surfacesToBezier(box, plane=T rev=F ext=F bspline=F)", box, ok, converter.Result());
  }

  return 0;
}
