// Ground truth probe for #2748: on a cylinder,
// Shape.convertCurves3dToBezier(lineMode: false, circleMode: true, conicMode: false) converts
// nothing, although the cylinder's two circular edges are exactly what circleMode asks for.
//
// This sits on top of #2732 (PR #2743): before that fix, OCCTShapeUpgradeConvertCurves3dToBezier
// never called ShapeUpgrade_ShapeConvertToBezier::Set3dConversion(true), so every call returned
// null regardless of the per-kind modes. This probe sets the master switch explicitly (as #2743's
// bridge fix does) so the circleMode/conicMode interaction can be measured at all.
//
// Step 1 (per the issue): print, for each edge of a fresh, unconverted cylinder, the dynamic type
// BRep_Tool::Curve returns, and the basis curve type if it is a Geom_TrimmedCurve, so it is clear
// whether the input edges are Geom_Circle at all.
//
// Step 2: read ShapeUpgrade_ConvertCurve3dToBezier::Compute() (Libraries/OCCT.xcframework has no
// .cxx; read from a same-tag V8_0_1 occt-src checkout, ground truth per okf/policies/context-first.md)
// and measure the 2x2 matrix of circleMode x conicMode (lineMode held false throughout, matching
// the fixture in the issue) to confirm what the source predicts.
//
// Build: see README.md in this directory or the ground-truth-probe skill.

#include <BRepAdaptor_Curve.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Conic.hxx>
#include <Geom_Curve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <Standard_Type.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>

// Prints, for every mapped (deduped) edge of `shape`, the dynamic type BRep_Tool::Curve returns,
// and unwraps one level of Geom_TrimmedCurve to show the basis curve type too, since that is
// exactly the distinction ShapeUpgrade_ConvertCurve3dToBezier::Compute() itself unwraps before
// testing IsKind(Geom_Circle)/IsKind(Geom_Conic).
static void printEdgeCurveTypes(const TopoDS_Shape& shape, const char* label)
{
  TopTools_IndexedMapOfShape edgeMap;
  TopExp::MapShapes(shape, TopAbs_EDGE, edgeMap);
  std::printf("[%s] %d mapped edges\n", label, edgeMap.Extent());
  for (int i = 1; i <= edgeMap.Extent(); i++)
  {
    const TopoDS_Edge& e = TopoDS::Edge(edgeMap(i));
    double              f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
    if (c.IsNull())
    {
      std::printf("  edge %d: no 3D curve (degenerate)\n", i);
      continue;
    }
    std::printf("  edge %d: %s [%.6g, %.6g]", i, c->DynamicType()->Name(), f, l);
    if (c->IsKind(STANDARD_TYPE(Geom_TrimmedCurve)))
    {
      Handle(Geom_TrimmedCurve) tc    = Handle(Geom_TrimmedCurve)::DownCast(c);
      Handle(Geom_Curve)        basis = tc->BasisCurve();
      std::printf(" -> basis %s", basis->DynamicType()->Name());
    }
    std::printf(" isKind(Geom_Circle)=%d isKind(Geom_Conic)=%d\n",
                c->IsKind(STANDARD_TYPE(Geom_Circle)) ? 1 : 0,
                c->IsKind(STANDARD_TYPE(Geom_Conic)) ? 1 : 0);
  }
}

static void runConversion(const TopoDS_Shape& cyl, bool lineMode, bool circleMode, bool conicMode)
{
  ShapeUpgrade_ShapeConvertToBezier converter(cyl);
  converter.Set3dConversion(true); // master switch (#2732)
  converter.Set3dLineConversion(lineMode ? Standard_True : Standard_False);
  converter.Set3dCircleConversion(circleMode ? Standard_True : Standard_False);
  converter.Set3dConicConversion(conicMode ? Standard_True : Standard_False);
  converter.SetSurfaceSegmentMode(false);
  bool                ok     = converter.Perform();
  const TopoDS_Shape& result = converter.Result();

  int edgeCount = 0, bezierEdges = 0;
  if (!result.IsNull())
  {
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(result, TopAbs_EDGE, edgeMap);
    for (int i = 1; i <= edgeMap.Extent(); i++)
    {
      const TopoDS_Edge& e = TopoDS::Edge(edgeMap(i));
      double              f, l;
      Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
      if (c.IsNull())
        continue;
      edgeCount++;
      BRepAdaptor_Curve adaptor(e);
      if (adaptor.GetType() == GeomAbs_BezierCurve)
        bezierEdges++;
    }
  }
  std::printf(
      "line=%d circle=%d conic=%d: Perform=%d Result.IsNull=%d edges=%d bezierEdges=%d\n",
      lineMode, circleMode, conicMode, ok ? 1 : 0, result.IsNull() ? 1 : 0, edgeCount,
      bezierEdges);
}

int main()
{
  // Fixture matches OCCTShapeCreateCylinder / the #2732 probe exactly.
  double       radius = 5, height = 10;
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(radius, height).Shape();

  std::printf("=== Step 1: per-edge 3D curve types on the unconverted cylinder ===\n");
  printEdgeCurveTypes(cyl, "cylinder");

  std::printf("\n=== Step 2: circleMode x conicMode matrix (lineMode=false throughout) ===\n");
  runConversion(cyl, false, false, false);
  runConversion(cyl, false, true, false); // the issue's exact reproduction
  runConversion(cyl, false, false, true);
  runConversion(cyl, false, true, true);

  return 0;
}
