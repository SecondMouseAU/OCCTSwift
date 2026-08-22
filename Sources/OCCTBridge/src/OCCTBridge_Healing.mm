//
//  OCCTBridge_Healing.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  Shape healing & analysis (v0.13) + Advanced blends & surface filling
//  (v0.14):
//
//  - Shape healing: ShapeFix_Shape / Face / Wire, tolerance analysis,
//    shell + wire validators, BRepCheck_Analyzer
//  - Surface upgrade: ShapeUpgrade_UnifySameDomain
//  - Advanced blends: filling surfaces with point + curve constraints
//    (GeomPlate_*), filleting with sigil controls, surface filling
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_Shell.hxx>
#include <BRepCheck_Solid.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <ShapeAnalysis_ShapeContents.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_ConstructionError.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepTools.hxx>

#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <GeomAbs_Shape.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>

#include <gp_Pnt.hxx>
#include <GProp_GProps.hxx>

#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeAnalysis.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeExtend_Status.hxx>
#include <NCollection_Sequence.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <BRepAlgo_FaceRestrictor.hxx>
#include <ShapeAnalysis_FreeBoundData.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <ShapeAnalysis_Geom.hxx>
#include <ShapeAnalysis_WireVertex.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeFix_Edge.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeFix_SplitTool.hxx>
#include <BRepTools_Substitution.hxx>
#include <ShapeAnalysis_TransferParametersProj.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_Vertex.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <ShapeCustom_TrsfModification.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <ShapeUpgrade_ClosedEdgeDivide.hxx>
#include <ShapeUpgrade_ConvertCurve3dToBezier.hxx>
#include <ShapeUpgrade_ConvertSurfaceToBezierBasis.hxx>
#include <ShapeUpgrade_EdgeDivide.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_FixSmallBezierCurves.hxx>
#include <ShapeUpgrade_FixSmallCurves.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <BRepLib_ValidateEdge.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_ConvertToRevolution.hxx>
#include <ShapeUpgrade_SplitSurfaceAngle.hxx>
#include <ShapeUpgrade_SplitSurfaceArea.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeUpgrade_ClosedFaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeUpgrade_ShellSewing.hxx>
#include <ShapeFix_FaceConnect.hxx>
#include <ShapeFix_FixSmallSolid.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <ShapeFix_SplitCommonVertex.hxx>
#include <ShapeFix_WireVertex.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeAnalysis_WireOrder.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepLib.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shell.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <BRep_Builder.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Surface.hxx>

#include <vector>

// MARK: - Shape Healing & Analysis (v0.13.0)

// Comments here name a #717 review finding by what it said, never by its number. That PR drew two
// automated review passes and the second retracted the first, renumbering as it went: the
// try/catch below was the first pass's finding 4, while the second pass's finding 4 is an
// unrelated missing doc snippet. A bare ordinal is not a stable citation when the thing it indexes
// can be reissued, and a cross-reference that silently comes to mean something else is worse than
// none (the #549 tombstone lesson). Cite the substance.
//
// #717 review (the checkinternaledges divergence and the duplicated scan, filed against #702):
// OCCTShapeAnalyze and OCCTShapeAnalyzeShell
// both ran ShapeAnalysis_Shell::CheckOrientedShells and then read HasFreeEdges()/FreeEdges() off
// it, hand-duplicated in each function. That duplication is how the divergence happened: this
// file's two copies drifted apart on the third argument, checkinternaledges, so the two entry
// points could silently disagree on a shell with a TopAbs_INTERNAL-oriented edge, contradicting the
// #702 test's own "analyze() must agree with analyzeShell()" invariant. Per
// ShapeAnalysis_Shell.cxx: an edge with no FORWARD/REVERSED partner is unconditionally free when
// checkinternaledges is false, but is instead read as connected (through that occurrence) when
// checkinternaledges is true and the same shape (by IsSame: same TShape and Location, ignoring
// Orientation) also occurs with TopAbs_INTERNAL orientation elsewhere in the shell.
// OCCTShapeAnalyzeShell already passed true; this scan now always does, for both callers, by
// construction rather than by keeping two copies in sync by hand.
struct OCCTShellOrientationScan
{
  bool checkResult       = false; // ShapeAnalysis_Shell::CheckOrientedShells' own return value
  bool hasFreeEdges      = false;
  bool hasBadEdges       = false;
  bool hasConnectedEdges = false;
  int  freeEdgeCount     = 0;
};

static OCCTShellOrientationScan occtAnalyzeShellOrientation(const TopoDS_Shape& shape)
{
  OCCTShellOrientationScan scan;
  ShapeAnalysis_Shell      analyzer;
  scan.checkResult =
    analyzer.CheckOrientedShells(shape, /*alsofree*/ true, /*checkinternaledges*/ true);
  scan.hasFreeEdges      = analyzer.HasFreeEdges();
  scan.hasBadEdges       = analyzer.HasBadEdges();
  scan.hasConnectedEdges = analyzer.HasConnectedEdges();
  if (scan.hasFreeEdges)
  {
    TopoDS_Compound freeEdgesCompound = analyzer.FreeEdges();
    for (TopExp_Explorer edgeExp(freeEdgesCompound, TopAbs_EDGE); edgeExp.More(); edgeExp.Next())
    {
      scan.freeEdgeCount++;
    }
  }
  return scan;
}

OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance)
{
  OCCTShapeAnalysisResult result = {0, 0, 0, 0, 0, false, false};
  if (!shape)
    return result;

  try
  {
    // Use BRepCheck_Analyzer for comprehensive validation
    BRepCheck_Analyzer analyzer(shape->shape, true);
    result.hasInvalidTopology = !analyzer.IsValid();

    // Count small edges using ShapeAnalysis_ShapeTolerance
    ShapeAnalysis_ShapeTolerance shapeTol;

    // Count free edges and faces (topology analysis)
    int freeEdges  = 0;
    int freeFaces  = 0;
    int smallEdges = 0;
    int smallFaces = 0;
    int gaps       = 0;

    // Analyze shells for free faces and closure, via the shared occtAnalyzeShellOrientation
    // (see its comment above for the #702/#717 history: this used to call LoadShells(shell)
    // and read HasFreeEdges()/FreeEdges(), which are populated only by CheckOrientedShells(),
    // never by LoadShells(); that hardcoded freeEdges/freeFaces to 0 for every shape, however
    // open, regardless of tolerance).
    //
    // #717 review (the missing per-shell try/catch): CheckOrientedShells is a real OCCT computation
    // now, not the near-no-op LoadShells() was, so it can raise Standard_Failure on a malformed
    // shell. The try/catch is scoped to one shell's iteration: a shell that throws contributes
    // nothing to freeEdges/freeFaces and the loop continues, rather than one bad shell discarding
    // the free-edge counts already accumulated for prior shells and the smallEdge/smallFace/gap
    // counts computed further below (an exception here used to escape to this function's
    // outer catch, which resets the whole result to all-zero/invalid).
    for (TopExp_Explorer shellExp(shape->shape, TopAbs_SHELL); shellExp.More(); shellExp.Next())
    {
      TopoDS_Shell shell = TopoDS::Shell(shellExp.Current());
      try
      {
        OCCTShellOrientationScan scan = occtAnalyzeShellOrientation(shell);
        if (scan.hasFreeEdges)
        {
          freeEdges += scan.freeEdgeCount;
          freeFaces++; // this shell is not fully closed (freeFaceCount's own contract)
        }
      }
      catch (...)
      {
        // Skip just this shell's contribution; other shells and the categories below
        // still get computed.
      }
    }

    // Analyze edges for small size
    for (TopExp_Explorer edgeExp(shape->shape, TopAbs_EDGE); edgeExp.More(); edgeExp.Next())
    {
      TopoDS_Edge edge = TopoDS::Edge(edgeExp.Current());

      // #318: a degenerate edge has zero extent by construction (it isn't a "small
      // edge" defect to flag) and BRepGProp::LinearProperties can crash on one whose
      // sole representation is a Bezier/BSpline curve-on-surface pcurve (kernel patch
      // 0006 fixes the underlying BRepGProp_EdgeTool::IntegrationOrder bug, but this
      // bridge also skips degenerate edges outright, no xcframework rebuild needed).
      if (BRep_Tool::Degenerated(edge))
      {
        continue;
      }

      // Get edge length
      GProp_GProps props;
      BRepGProp::LinearProperties(edge, props);
      double length = props.Mass();

      if (length < tolerance)
      {
        smallEdges++;
      }
    }

    // Analyze faces for small size
    for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next())
    {
      TopoDS_Face face = TopoDS::Face(faceExp.Current());

      // Get face area
      GProp_GProps props;
      BRepGProp::SurfaceProperties(face, props);
      double area = props.Mass();

      if (area < tolerance * tolerance)
      {
        smallFaces++;
      }
    }

    // Analyze wires for gaps
    for (TopExp_Explorer wireExp(shape->shape, TopAbs_WIRE); wireExp.More(); wireExp.Next())
    {
      TopoDS_Wire wire = TopoDS::Wire(wireExp.Current());

      // Find a face containing this wire for context
      TopoDS_Face face;
      for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next())
      {
        TopoDS_Face testFace = TopoDS::Face(faceExp.Current());
        for (TopExp_Explorer innerWireExp(testFace, TopAbs_WIRE); innerWireExp.More();
             innerWireExp.Next())
        {
          if (innerWireExp.Current().IsSame(wire))
          {
            face = testFace;
            break;
          }
        }
        if (!face.IsNull())
          break;
      }

      if (!face.IsNull())
      {
        ShapeAnalysis_Wire wireAnalysis(wire, face, tolerance);
        gaps += wireAnalysis.CheckGaps3d();
      }
    }

    result.smallEdgeCount = smallEdges;
    result.smallFaceCount = smallFaces;
    result.gapCount       = gaps;
    // selfIntersectionCount REMOVED (#726/#763): see OCCTBridge_Healing.h's field comment.
    result.freeEdgeCount = freeEdges;
    result.freeFaceCount = freeFaces;
    result.isValid       = true;

    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance)
{
  if (!wire)
    return nullptr;

  try
  {
    // Create a planar face for wire fixing context
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
    {
      // Try without planar check
      makeFace = BRepBuilderAPI_MakeFace(wire->wire, false);
      if (!makeFace.IsDone())
        return nullptr;
    }
    TopoDS_Face face = makeFace.Face();

    // Fix the wire
    Handle(ShapeFix_Wire) fixer = new ShapeFix_Wire(wire->wire, face, tolerance);
    fixer->SetPrecision(tolerance);

    // Enable all fixing modes
    fixer->FixReorderMode()          = 1;
    fixer->FixConnectedMode()        = 1;
    fixer->FixEdgeCurvesMode()       = 1;
    fixer->FixDegeneratedMode()      = 1;
    fixer->FixSelfIntersectionMode() = 1;
    fixer->FixLackingMode()          = 1;
    fixer->FixGaps3dMode()           = 1;

    if (!fixer->Perform())
    {
      // Fixing failed, return original
      return new OCCTWire(wire->wire);
    }

    TopoDS_Wire fixedWire = fixer->Wire();
    if (fixedWire.IsNull())
      return nullptr;

    return new OCCTWire(fixedWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance)
{
  if (!face)
    return nullptr;

  try
  {
    Handle(ShapeFix_Face) fixer = new ShapeFix_Face(face->face);
    // #317/#484: ShapeFix_Face's base constructor leaves Context() null, and the fixes that
    // need one then silently no-op (or, on an unpatched kernel, null-deref in
    // FixPeriodicDegenerated). This was the fourth ShapeFix_Face call site in the bridge and
    // the only one the #317 pass missed. Give it a context, as the other three do.
    fixer->SetContext(new ShapeBuild_ReShape);
    fixer->SetPrecision(tolerance);

    // Enable fixing modes
    fixer->FixWireMode()            = 1;
    fixer->FixOrientationMode()     = 1;
    fixer->FixAddNaturalBoundMode() = 1;
    fixer->FixMissingSeamMode()     = 1;
    fixer->FixSmallAreaWireMode()   = 1;

    if (!fixer->Perform())
    {
      // Fixing failed, return original
      return new OCCTShape(face->face);
    }

    TopoDS_Face fixedFace = fixer->Face();
    if (fixedFace.IsNull())
      return nullptr;

    return new OCCTShape(fixedFace);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape,
                                  double       tolerance,
                                  bool         fixSolid,
                                  bool         fixShell,
                                  bool         fixFace,
                                  bool         fixWire)
{
  if (!shape)
    return nullptr;

  try
  {
    Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
    fixer->SetPrecision(tolerance);

    // #837: fixShell/fixFace/fixWire used to be accepted and silently discarded here --
    // only FixSolidMode() was ever set, so ShapeFix_Shape's own always-on default ran for
    // the other three regardless of what the caller passed. Each flag now maps to
    // ShapeFix_Shape's own accessor: FixSolidMode() fixes solids; FixFreeShellMode() /
    // FixFreeFaceMode() / FixFreeWireMode() fix shells/faces/wires that are FREE --
    // standalone, not attached to a solid/shell/face respectively (there is no
    // "FixShellMode"/"FixFaceMode"/"FixWireMode" in this OCCT version; content that IS
    // attached is always fixed by Perform() regardless of these three flags).
    fixer->FixSolidMode()     = fixSolid ? 1 : 0;
    fixer->FixFreeShellMode() = fixShell ? 1 : 0;
    fixer->FixFreeFaceMode()  = fixFace ? 1 : 0;
    fixer->FixFreeWireMode()  = fixWire ? 1 : 0;

    // Perform the fix
    if (!fixer->Perform())
    {
      // Fixing might still produce a result even if Perform returns false
    }

    TopoDS_Shape fixedShape = fixer->Shape();
    if (fixedShape.IsNull())
    {
      return new OCCTShape(shape->shape); // Return original if fix failed
    }

    return new OCCTShape(fixedShape);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #446: the three shared helpers declared in OCCTBridge_Internal.h, see the block comment there
// for why every unify entry point works on a copy.
TopoDS_Shape occtUnifySameDomainInput(const TopoDS_Shape& shape, BRepBuilderAPI_Copy& copier)
{
  try
  {
    copier.Perform(shape);
    return copier.Shape();
  }
  catch (...)
  {
    return TopoDS_Shape();
  }
}

TopoDS_Shape occtUnifySameDomainMapped(const TopoDS_Shape& sub, BRepBuilderAPI_Copy& copier)
{
  try
  {
    // ModifiedShape raises Standard_NoSuchObject for a shape that was not part of the copy.
    TopoDS_Shape mapped = copier.ModifiedShape(sub);
    return mapped.IsNull() ? sub : mapped;
  }
  catch (...)
  {
    return sub;
  }
}

TopoDS_Shape occtUnifySameDomain(const TopoDS_Shape& shape,
                                 bool                unifyEdges,
                                 bool                unifyFaces,
                                 bool                concatBSplines)
{
  try
  {
    BRepBuilderAPI_Copy copier;
    TopoDS_Shape        work = occtUnifySameDomainInput(shape, copier);
    if (work.IsNull())
      return TopoDS_Shape();

    ShapeUpgrade_UnifySameDomain unifier(work, unifyEdges, unifyFaces, concatBSplines);
    unifier.Build();
    return unifier.Shape();
  }
  catch (...)
  {
    return TopoDS_Shape();
  }
}

OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                      bool         unifyEdges,
                                      bool         unifyFaces,
                                      bool         concatBSplines)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape result = occtUnifySameDomain(shape->shape, unifyEdges, unifyFaces, concatBSplines);
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea)
{
  if (!shape || minArea <= 0)
    return nullptr;

  try
  {
    // Collect faces to remove
    TopTools_ListOfShape facesToRemove;

    for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      TopoDS_Face face = TopoDS::Face(exp.Current());

      GProp_GProps props;
      BRepGProp::SurfaceProperties(face, props);
      double area = props.Mass();

      if (area < minArea)
      {
        facesToRemove.Append(face);
      }
    }

    if (facesToRemove.IsEmpty())
    {
      // No faces to remove
      return new OCCTShape(shape->shape);
    }

    // Use defeaturing to remove small faces. This entry point picks the faces itself, so it
    // needs no face-resolution helper, but it runs the same skeleton as the rest. #497
    BRepAlgoAPI_Defeaturing defeaturing;
    TopoDS_Shape            result;
    if (!occtDefeaturePerform(defeaturing, shape->shape, facesToRemove, result))
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;

  try
  {
    // First unify same domain (#446: on a private copy, the caller's shape is not an input
    // this algorithm may consume)
    TopoDS_Shape unified = occtUnifySameDomain(shape->shape, true, true, true);
    if (unified.IsNull())
      return nullptr;

    // Then heal the shape
    Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(unified);
    fixer->SetPrecision(tolerance);
    fixer->Perform();
    TopoDS_Shape result = fixer->Shape();

    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

// The single-edge member of the radius-law pair, sharing occtFilletAddEdges (the edge lookup and
// its bounds check) and occtFilletSetRadiusProfile (the law itself) with OCCTShapeFilletEvolving in
// OCCTBridge_Modeling.mm. See OCCTBridge_Internal.h for what OCCT does with a profile.
//
// This used to map each relative parameter onto the edge's own curve parameter range and pass the
// result to SetRadius(radii[i], param, 1). BRepFilletAPI_MakeFillet has no (Real, Real, Integer)
// overload: `param` was truncated to an int and taken as the *contour* index, so the profile was
// never applied. What the caller got was a constant radius, whichever profile point happened to
// truncate to a live contour index, and, for any edge whose parameter range does not start at 0,
// no radius at all, which SIGSEGVs in Build(). Both measured in
// Scripts/repro/520-fillet-edge-index-contracts/. #520
OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef  shape,
                                     int32_t       edgeIndex,
                                     const double* radii,
                                     const double* params,
                                     int32_t       count)
{
  if (!shape || !radii || !params || count < 2)
    return nullptr;

  try
  {
    BRepFilletAPI_MakeFillet fillet(shape->shape);
    TopoDS_Edge              added;
    if (!occtFilletAddEdges(
          fillet,
          shape->shape,
          &edgeIndex,
          1,
          [&added](BRepFilletAPI_MakeFillet& f, const TopoDS_Edge& edge, int32_t) {
            f.Add(edge); // the radius-law overload: the profile below supplies the radius
            added = edge;
            return true;
          }))
      return nullptr;

    // #612: the profile goes to this edge's own slot in this edge's own contour. One edge is
    // added, so the contour index agreed with NbContours() whenever there was one at all, but
    // when OCCT *declines* the edge (a free-boundary edge of an open shell) NbContours() is 0,
    // and SetRadius(law, 0, 1) is the unchecked low side #505 measured: it used to SIGSEGV,
    // uncatchably, rather than fail. Resolving the slot returns no slot instead, and the empty
    // fillet then fails in Build().
    if (!occtFilletSetRadiusProfile(fillet, added, count, [radii, params](int32_t i) {
          return gp_Pnt2d(params[i], radii[i]);
        }))
      return nullptr;

    fillet.Build();
    if (!fillet.IsDone())
      return nullptr;

    TopoDS_Shape result = fillet.Shape();
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius)
{
  if (!wire || radius <= 0 || vertexIndex < 0)
    return nullptr;

  try
  {
    // Create a face from the wire for 2D operations
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get vertex at index
    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

    if (vertexIndex >= vertexMap.Extent())
      return nullptr;

    TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

    // Use ChFi2d_Builder for 2D fillet on face
    ChFi2d_Builder fillet2d(face);
    TopoDS_Edge    filletEdge = fillet2d.AddFillet(vertex, radius);

    if (filletEdge.IsNull())
      return nullptr;
    if (fillet2d.Status() != ChFi2d_IsDone)
      return nullptr;

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius)
{
  if (!wire || radius <= 0)
    return nullptr;

  try
  {
    // Create a face from the wire
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get all vertices
    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

    if (vertexMap.Extent() < 2)
      return nullptr;

    // Use ChFi2d_Builder to fillet all vertices
    ChFi2d_Builder fillet2d(face);

    // Add fillet to each vertex
    for (int v = 1; v <= vertexMap.Extent(); v++)
    {
      TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(v));
      fillet2d.AddFillet(vertex, radius);
    }

    if (fillet2d.Status() != ChFi2d_IsDone)
    {
      // Some vertices might not be fillettable; return original
      return new OCCTWire(wire->wire);
    }

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2)
{
  if (!wire || dist1 <= 0 || dist2 <= 0 || vertexIndex < 0)
    return nullptr;

  try
  {
    // Create face from wire
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get edges and vertices
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

    if (vertexIndex >= vertexMap.Extent())
      return nullptr;

    TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

    // Find edges sharing this vertex
    TopoDS_Edge edge1, edge2;
    for (int i = 1; i <= edgeMap.Extent(); i++)
    {
      TopoDS_Edge   edge = TopoDS::Edge(edgeMap(i));
      TopoDS_Vertex v1, v2;
      TopExp::Vertices(edge, v1, v2);
      if (v1.IsSame(vertex) || v2.IsSame(vertex))
      {
        if (edge1.IsNull())
        {
          edge1 = edge;
        }
        else
        {
          edge2 = edge;
          break;
        }
      }
    }

    if (edge1.IsNull() || edge2.IsNull())
      return nullptr;

    // Use ChFi2d_Builder for 2D chamfer
    ChFi2d_Builder chamfer2d(face);
    TopoDS_Edge    chamferEdge = chamfer2d.AddChamfer(edge1, edge2, dist1, dist2);

    if (chamferEdge.IsNull())
      return nullptr;
    if (chamfer2d.Status() != ChFi2d_IsDone)
      return nullptr;

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance)
{
  if (!wire || distance <= 0)
    return nullptr;

  try
  {
    // Create face from wire
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get edges and vertices
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

    if (edgeMap.Extent() < 2)
      return nullptr;

    // Use ChFi2d_Builder for 2D chamfers
    ChFi2d_Builder chamfer2d(face);

    // For each pair of adjacent edges, add chamfer
    // We need to find adjacent edge pairs
    for (int i = 1; i <= edgeMap.Extent(); i++)
    {
      TopoDS_Edge edge1   = TopoDS::Edge(edgeMap(i));
      int         nextIdx = (i % edgeMap.Extent()) + 1;
      TopoDS_Edge edge2   = TopoDS::Edge(edgeMap(nextIdx));

      // Check if edges share a vertex
      TopoDS_Vertex v1_1, v1_2, v2_1, v2_2;
      TopExp::Vertices(edge1, v1_1, v1_2);
      TopExp::Vertices(edge2, v2_1, v2_2);

      bool sharesVertex =
        v1_1.IsSame(v2_1) || v1_1.IsSame(v2_2) || v1_2.IsSame(v2_1) || v1_2.IsSame(v2_2);

      if (sharesVertex)
      {
        chamfer2d.AddChamfer(edge1, edge2, distance, distance);
      }
    }

    if (chamfer2d.Status() != ChFi2d_IsDone)
    {
      // Some edges might not be chamferable; return original
      return new OCCTWire(wire->wire);
    }

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Shares occtShapeFilletEdgeList (OCCTBridge_Internal.h) with OCCTShapeFilletEdges and
// OCCTShapeFilletEdgesLinear in OCCTBridge_Modeling.mm, supplying only the per-edge radius.
// This is the entry point that had no radius precondition at all; see that helper. #489
//
// #633: `declinedEdgeIndices`/`outDeclinedCount` report which of `edgeIndices` OCCT declined
// (occtFilletWriteDeclined), the same contract #639 gave the other three edge-list entry points.
// Both are nullable and the existing skip behaviour is unchanged when they are null.
OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef   shape,
                                 const int32_t* edgeIndices,
                                 const double*  radii,
                                 int32_t        count,
                                 int32_t*       declinedEdgeIndices,
                                 int32_t*       outDeclinedCount)
{
  if (outDeclinedCount)
    *outDeclinedCount = 0;
  if (!occtValidFilletRadii(radii, count))
    return nullptr;

  return occtShapeFilletEdgeList(
    shape,
    edgeIndices,
    count,
    [radii](BRepFilletAPI_MakeFillet& fillet, const TopoDS_Edge& edge, int32_t entry) {
      fillet.Add(radii[entry], edge);
      return true;
    },
    declinedEdgeIndices,
    outDeclinedCount);
}

// MARK: - Surface filling (#430/#434)
//
// occtFillingSupportFaceFromPCurve / occtFillingAddConstraint / occtFillingMakeBuilder are
// shared with OCCTBridge_Modeling.mm's OCCTFilling* family, declared, and documented at length,
// in OCCTBridge_Internal.h, alongside occtGeomAbsFromSurfaceContinuity, the continuity decoder
// this family uses (#490 renamed it from occtFillingContinuityToGeomAbs and moved it next to its
// two siblings). The OCCTShapeFill* helpers below are local to this file.

bool occtFillingSupportFaceFromPCurve(const TopoDS_Edge& edge, TopoDS_Face& outFace)
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
  // Only useful if the edge really does resolve a pcurve against the face we just built.
  // BRep_Tool matches representations by surface handle and location, so this confirms the
  // synthesized face is the same support the edge already referenced rather than a lookalike.
  double checkFirst = 0.0, checkLast = 0.0;
  return !BRep_Tool::CurveOnSurface(edge, outFace, checkFirst, checkLast).IsNull();
}

bool occtFillingAddConstraint(BRepOffsetAPI_MakeFilling& filling,
                              const TopoDS_Edge&         edge,
                              const TopoDS_Face&         support,
                              OCCTFillingSupport         kind,
                              GeomAbs_Shape              order,
                              bool                       isBound)
{
  if (order != GeomAbs_C0)
  {
    if (!support.IsNull())
    {
      // A support face still has to carry a pcurve for this edge; BRepFill_Filling raises
      // "no 2d representation" if it does not (common on imported shapes).
      double first = 0.0, last = 0.0;
      if (!BRep_Tool::CurveOnSurface(edge, support, first, last).IsNull())
      {
        filling.Add(edge, support, order, isBound);
        return true;
      }
      if (kind == OCCTFillingSupport::Nominated)
        return false;
    }
    TopoDS_Face derived;
    if (occtFillingSupportFaceFromPCurve(edge, derived))
    {
      filling.Add(edge, derived, order, isBound);
      return true;
    }
    // No pcurve anywhere: nothing to be tangent to. The face-less overload raises
    // Standard_Failure here, which is OCCT's documented contract for this case.
  }
  filling.Add(edge, order, isBound);
  return true;
}

// Binds every argument to the parameter it names, the pre-#431 code passed
// maxDegree/maxSegments/continuity into Degree/NbPtsOnCur/TolAng, which left MaxDeg/MaxSegments
// at their defaults and made TolAng the continuity ordinal. Measured effect on a cylinder-rim
// fill: G0Error 0.615 vs 0.00040.
BRepOffsetAPI_MakeFilling occtFillingMakeBuilder(int32_t degree,
                                                 int32_t nbPtsOnCur,
                                                 int32_t maxDegree,
                                                 int32_t maxSegments,
                                                 double  tolerance3d)
{
  const double tol3d = tolerance3d > 0 ? tolerance3d : 1e-4;
  return BRepOffsetAPI_MakeFilling(
    degree > 0 ? degree : 3,          // Degree (energy criterion)
    nbPtsOnCur > 0 ? nbPtsOnCur : 15, // NbPtsOnCur
    2,                                // NbIter
    false,                            // Anisotropie
    // Tol2d is a parameter-space tolerance and Tol3d a model-space one, so no ratio is
    // universally right. A tenth reproduces OCCT's own default pair (1e-5 / 1e-4) at our
    // default tolerance; callers wanting them decoupled should set them via OCCT directly.
    tol3d * 0.1,                      // Tol2d
    tol3d,                            // Tol3d
    0.01,                             // TolAng
    0.1,                              // TolCurv
    maxDegree > 0 ? maxDegree : 8,    // MaxDeg
    maxSegments > 0 ? maxSegments : 9 // MaxSegments
  );
}

// Fixed at the degree/nbPtsOnCur OCCTShapeFill's public API doesn't expose per-call control
// over (FillingParameters has no such fields); OCCTFillingCreate's caller-supplied variants
// go straight to occtFillingMakeBuilder.
static BRepOffsetAPI_MakeFilling OCCTShapeFillMakeBuilder(OCCTFillingParams params)
{
  return occtFillingMakeBuilder(3, 15, params.maxDegree, params.maxSegments, params.tolerance);
}

// Collect the boundary edges of every wire, in order.
static void OCCTShapeFillCollectEdges(const OCCTWireRef*        boundaries,
                                      int32_t                   wireCount,
                                      std::vector<TopoDS_Edge>& outEdges)
{
  for (int32_t i = 0; i < wireCount; i++)
  {
    if (!boundaries[i])
      continue;
    for (TopExp_Explorer exp(boundaries[i]->wire, TopAbs_EDGE); exp.More(); exp.Next())
    {
      outEdges.push_back(TopoDS::Edge(exp.Current()));
    }
  }
}

// #597 investigated gating this on G0Error() > Tol3d (the same "read the error" shape #741 fixed
// for OCCTGeomFillSweep in OCCTBridge_Surface.mm). Measured and reverted: unlike that site's fixed
// 1e-4, `Shape.fill`'s effective Tol3d is ALWAYS 1e-4 too (FillingParameters' own Swift default,
// not a fallback for an unset value), and G0Error(). BRepFill_Filling's own header: "the maximum
// distance between the result and the constraints", routinely and legitimately exceeds it for
// exactly the demanding fills this API exists for: FillingSupportFaceTests' own curvature-vs-
// tangency and interior-pull cases build correct, already-tested surfaces whose G0Error() is
// several times 1e-4. Gating on it breaks two existing, passing tests without those surfaces being
// wrong. Unlike the plate case, G0Error() is a meaningful distance-to-constraints figure here, not
// the wrong metric, the problem is 1e-4 was never a real, enforced promise for this family, and
// nothing establishes what the right one would be without inventing a number (#726). See
// Scripts/repro/597-bridge-modeling-healing-approx-error. FillingSurface's manual builder API
// already exposes G0Error()/G1Error()/G2Error() for a caller who wants to check it themselves.
static OCCTShapeRef OCCTShapeFillBuildResult(BRepOffsetAPI_MakeFilling& filling)
{
  filling.Build();
  if (!filling.IsDone())
    return nullptr;

  TopoDS_Shape result = filling.Shape();
  if (result.IsNull())
    return nullptr;

  return new OCCTShape(result);
}

OCCTShapeRef OCCTShapeFill(const OCCTWireRef* boundaries,
                           int32_t            wireCount,
                           OCCTFillingParams  params)
{
  if (!boundaries || wireCount < 1)
    return nullptr;

  try
  {
    BRepOffsetAPI_MakeFilling filling = OCCTShapeFillMakeBuilder(params);
    const GeomAbs_Shape       order   = occtGeomAbsFromSurfaceContinuity(params.continuity);

    std::vector<TopoDS_Edge> edges;
    OCCTShapeFillCollectEdges(boundaries, wireCount, edges);
    if (edges.empty())
      return nullptr;

    TopoDS_Face noSupport;
    for (const TopoDS_Edge& edge : edges)
    {
      occtFillingAddConstraint(filling,
                               edge,
                               noSupport,
                               OCCTFillingSupport::Inferred,
                               order,
                               /*isBound=*/true);
    }

    return OCCTShapeFillBuildResult(filling);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFillWithSupport(const OCCTWireRef* boundaries,
                                      int32_t            wireCount,
                                      OCCTShapeRef       support,
                                      OCCTFillingParams  params)
{
  if (!boundaries || wireCount < 1)
    return nullptr;

  try
  {
    BRepOffsetAPI_MakeFilling filling = OCCTShapeFillMakeBuilder(params);
    const GeomAbs_Shape       order   = occtGeomAbsFromSurfaceContinuity(params.continuity);

    std::vector<TopoDS_Edge> edges;
    OCCTShapeFillCollectEdges(boundaries, wireCount, edges);
    if (edges.empty())
      return nullptr;

    TopTools_IndexedDataMapOfShapeListOfShape edgeToFaces;
    if (support)
    {
      TopExp::MapShapesAndAncestors(support->shape, TopAbs_EDGE, TopAbs_FACE, edgeToFaces);
    }

    for (const TopoDS_Edge& edge : edges)
    {
      TopoDS_Face supportFace;
      if (edgeToFaces.Contains(edge))
      {
        // An interior edge has two ancestor faces and this picks the first
        // arbitrarily. Fine for the capping case these boundaries describe, where the
        // opening side has no face; callers needing a specific one use
        // OCCTShapeFillConstraints. The face is Inferred, not Nominated, so
        // occtFillingAddConstraint degrades per edge if the chosen one turns out to
        // carry no pcurve for it, rather than failing the whole fill.
        const TopTools_ListOfShape& faces = edgeToFaces.FindFromKey(edge);
        if (!faces.IsEmpty())
          supportFace = TopoDS::Face(faces.First());
      }
      occtFillingAddConstraint(filling,
                               edge,
                               supportFace,
                               OCCTFillingSupport::Inferred,
                               order,
                               /*isBound=*/true);
    }

    return OCCTShapeFillBuildResult(filling);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFillConstraints(const OCCTFillConstraint* constraints,
                                      int32_t                   count,
                                      OCCTFillingParams         params)
{
  if (!constraints || count < 1)
    return nullptr;

  try
  {
    BRepOffsetAPI_MakeFilling filling = OCCTShapeFillMakeBuilder(params);

    int32_t added = 0;
    for (int32_t i = 0; i < count; i++)
    {
      const OCCTFillConstraint& c = constraints[i];
      if (!c.edge)
        continue;

      TopoDS_Face support;
      if (c.support)
        support = c.support->face;

      // A face the caller named is Nominated: if it cannot carry this edge's continuity,
      // fail rather than silently answering with a different reference surface.
      if (!occtFillingAddConstraint(filling,
                                    c.edge->edge,
                                    support,
                                    c.support ? OCCTFillingSupport::Nominated
                                              : OCCTFillingSupport::Inferred,
                                    occtGeomAbsFromSurfaceContinuity(c.continuity),
                                    c.isBound != 0))
      {
        return nullptr;
      }
      added++;
    }
    if (added == 0)
      return nullptr;

    return OCCTShapeFillBuildResult(filling);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePlatePoints(const double* points, int32_t pointCount, double tolerance)
{
  if (!points || pointCount < 3 || tolerance <= 0)
    return nullptr;

  try
  {
    // Create plate surface builder
    GeomPlate_BuildPlateSurface plateBuilder(3, 15, 2); // degree, nbPtsOnCur, nbIter

    // Add point constraints
    for (int32_t i = 0; i < pointCount; i++)
    {
      gp_Pnt                            pt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
      Handle(GeomPlate_PointConstraint) constraint =
        new GeomPlate_PointConstraint(pt, 0); // 0 = order (just pass through)
      plateBuilder.Add(constraint);
    }

    // Perform the computation
    plateBuilder.Perform();
    if (!plateBuilder.IsDone())
      return nullptr;

    // Get the plate surface
    Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
    if (plateSurface.IsNull())
      return nullptr;

    // Approximate with B-spline surface
    Handle(Geom_BSplineSurface) bsplineSurf =
      occtPlateApproxSurface(plateSurface,
                             tolerance,
                             occtPlateApproxDefaultMaxDegree(),
                             occtPlateApproxDefaultMaxSegments(),
                             occtPlateApproxDefaultContinuity());
    if (bsplineSurf.IsNull())
      return nullptr;

    // Create face from surface
    BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
    if (!makeFace.IsDone())
      return nullptr;

    return new OCCTShape(makeFace.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePlateCurves(const OCCTWireRef* curves,
                                  int32_t            curveCount,
                                  int32_t            continuity,
                                  double             tolerance)
{
  if (!curves || curveCount < 1 || tolerance <= 0)
    return nullptr;

  try
  {
    // Create plate surface builder
    GeomPlate_BuildPlateSurface plateBuilder(3, 15, 2);

    // Add curve constraints from each wire
    for (int32_t i = 0; i < curveCount; i++)
    {
      if (!curves[i])
        continue;

      for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next())
      {
        TopoDS_Edge edge = TopoDS::Edge(exp.Current());

        // Create adaptor for edge
        BRepAdaptor_Curve       adaptor(edge);
        Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);

        Handle(GeomPlate_CurveConstraint) constraint =
          new GeomPlate_CurveConstraint(curve, continuity);
        plateBuilder.Add(constraint);
      }
    }

    // Perform computation
    plateBuilder.Perform();
    if (!plateBuilder.IsDone())
      return nullptr;

    // Get and approximate surface
    Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
    if (plateSurface.IsNull())
      return nullptr;

    // The caller's `continuity` is the CONSTRAINT order (applied to each GeomPlate_CurveConstraint
    // above); the approximation's own continuity is the join between Bezier patches, a separate
    // axis, so it keeps the shared default rather than following it. See OCCTBridge_Internal.h.
    Handle(Geom_BSplineSurface) bsplineSurf =
      occtPlateApproxSurface(plateSurface,
                             tolerance,
                             occtPlateApproxDefaultMaxDegree(),
                             occtPlateApproxDefaultMaxSegments(),
                             occtPlateApproxDefaultContinuity());
    if (bsplineSurf.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
    if (!makeFace.IsDone())
      return nullptr;

    return new OCCTShape(makeFace.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - NURBS Conversion (v0.29.0)

#include <BRepBuilderAPI_NurbsConvert.hxx>

OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_NurbsConvert converter(shape->shape);
    if (!converter.IsDone())
      return nullptr;
    return new OCCTShape(converter.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Fast Sewing (v0.29.0)

#include <BRepBuilderAPI_FastSewing.hxx>

OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_FastSewing sewer(tolerance);
    sewer.Add(shape->shape);
    sewer.Perform();
    return new OCCTShape(sewer.GetResult());
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Shape Fix Wireframe (v0.30.0)

#include <ShapeFix_Wireframe.hxx>

OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
    fixer->SetPrecision(tolerance);
    fixer->FixSmallEdges();
    fixer->FixWireGaps();
    TopoDS_Shape result = fixer->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Remove Internal Wires (v0.30.0)

#include <ShapeUpgrade_RemoveInternalWires.hxx>

OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeUpgrade_RemoveInternalWires) remover =
      new ShapeUpgrade_RemoveInternalWires(shape->shape);
    remover->MinArea() = minArea;
    remover->Perform();
    TopoDS_Shape result = remover->GetResult();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Fix Small Faces (v0.31.0)

#include <ShapeFix_FixSmallFace.hxx>

OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_FixSmallFace) fixer = new ShapeFix_FixSmallFace();
    fixer->Init(shape->shape);
    fixer->SetPrecision(tolerance);
    fixer->Perform();
    TopoDS_Shape result = fixer->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Remove Locations (v0.31.0)

#include <ShapeUpgrade_RemoveLocations.hxx>

OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_RemoveLocations remover;
    remover.Remove(shape->shape);
    TopoDS_Shape result = remover.GetResult();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Advanced Healing (v0.17.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>

// #438: the sole entry point behind Shape.divided(at:tolerance:) now, folding in what used to be
// a second, narrower bridge function (OCCTShapeUpgradeDivideContinuity) behind the now-deprecated
// Shape.dividedByContinuity(criterion:tolerance:). That second function set ONLY
// SetBoundaryCriterion, leaving SetPCurveCriterion/SetSurfaceCriterion pinned at the class's own
// GeomAbs_C1 constructor default regardless of the requested continuity, measured
// (Scripts/repro/cluster-d-continuity) as a flat result across every criterion 0..6 on a fixture
// where this function's own three-criteria version varies (nil/4/4/25 faces at C0/C1/C2/C3). Per
// the OCCT shape-healing guide's own worked example, all three criteria are meant to be set
// together to the same target continuity.
OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity, double tolerance)
{
  if (!shape)
    return nullptr;

  try
  {
    // Shape.ContinuityLevel is ParametricContinuity's ladder (0=C0 .. 3=C3, 4=CN, which is
    // where occtGeomAbsFromParametricContinuity saturates anyway) with the two geometric
    // classes tacked on at 5 and 6. Those two are the only values here that are not the
    // shared parametric decoding, and they are also the two ShapeUpgrade_Split*Continuity:
    // SetCriterion does not recognise at all, so OCCT quietly substitutes its own C1 default
    // for them. Kept because the public enum has always advertised them. #490, moved here
    // from the now-removed OCCTShapeUpgradeDivideContinuity by #438.
    const GeomAbs_Shape cont = continuity == 5   ? GeomAbs_G1
                               : continuity == 6 ? GeomAbs_G2
                                                 : occtGeomAbsFromParametricContinuity(continuity);

    ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);
    divider.SetBoundaryCriterion(cont);
    divider.SetPCurveCriterion(cont);
    divider.SetSurfaceCriterion(cont);
    divider.SetTolerance(tolerance);
    divider.SetSurfaceSegmentMode(Standard_True);
    if (!divider.Perform())
      return nullptr;

    TopoDS_Shape result = divider.Result();
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape result = ShapeCustom::DirectFaces(shape->shape);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape result = ShapeCustom::ScaleShape(shape->shape, factor);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                         double       surfaceTol,
                                         double       curveTol,
                                         int32_t      maxDegree,
                                         int32_t      maxSegments)
{
  if (!shape)
    return nullptr;

  try
  {
    // Static method signature:
    // BSplineRestriction(shape, Tol3d, Tol2d, MaxDegree, MaxNbSegment,
    //                    Continuity3d, Continuity2d, Degree, Rational, aParameters)
    Handle(ShapeCustom_RestrictionParameters) params = new ShapeCustom_RestrictionParameters();
    TopoDS_Shape result = ShapeCustom::BSplineRestriction(shape->shape,
                                                          surfaceTol,
                                                          curveTol,
                                                          maxDegree,
                                                          maxSegments,
                                                          GeomAbs_C1,    // Continuity3d
                                                          GeomAbs_C1,    // Continuity2d
                                                          Standard_True, // Degree priority
                                                          Standard_True, // Rational
                                                          params);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape result = ShapeCustom::SweptToElementary(shape->shape);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape result = ShapeCustom::ConvertToRevolution(shape->shape);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;

  try
  {
    // ConvertToBSpline(shape, extrMode, revolMode, offsetMode, planeMode)
    TopoDS_Shape result =
      ShapeCustom::ConvertToBSpline(shape->shape,
                                    Standard_True, // Convert extrusion surfaces
                                    Standard_True, // Convert revolution surfaces
                                    Standard_True, // Convert offset surfaces
                                    Standard_False // Don't convert planes
      );
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;

  try
  {
    BRepBuilderAPI_Sewing sewing(tolerance);
    sewing.Add(shape->shape);
    sewing.Perform();
    TopoDS_Shape sewn = sewing.SewedShape();
    if (sewn.IsNull())
      return nullptr;

    // Try to make a solid if we got a closed shell
    if (sewn.ShapeType() == TopAbs_SHELL)
    {
      TopoDS_Shell shell = TopoDS::Shell(sewn);
      if (shell.Closed())
      {
        BRepBuilderAPI_MakeSolid makeSolid(shell);
        if (makeSolid.IsDone())
        {
          return new OCCTShape(makeSolid.Solid());
        }
      }
    }

    return new OCCTShape(sewn);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;

  try
  {
    // Step 1: Sew
    BRepBuilderAPI_Sewing sewing(tolerance);
    sewing.Add(shape->shape);
    sewing.Perform();
    TopoDS_Shape sewedShape = sewing.SewedShape();
    // #1026: this IsNull() test is a fallback, not a guard. When sewing produced nothing it
    // reinstates the caller's own shape, so a null input arrives back here still null and the
    // ShapeType() read below dereferences it. The opener now rejects that input instead.
    if (sewedShape.IsNull())
      sewedShape = shape->shape;

    // Step 2: Try to create solids from the sewn shells. One solid per body-bounding
    // shell, not just the first shell an explorer yields (#443). Sewing a multi-body
    // part is the ordinary way to reach this function, and taking one shell reduced
    // every such part to a single body. Cavity shells stay out for the reason
    // documented on occtBodyBoundingShells.
    //
    // As before, this step replaces the sewn shape outright rather than merging into
    // it, so non-shell content (a loose face sewing could not attach) does not reach
    // the result; only the count of bodies changes here.
    TopoDS_Shape resultShape = sewedShape;
    if (sewedShape.ShapeType() != TopAbs_SOLID)
    {
      std::vector<TopoDS_Shape> made;
      for (const TopoDS_Shell& shell : occtBodyBoundingShells(sewedShape))
      {
        BRepBuilderAPI_MakeSolid makeSolid(shell);
        // IsDone() false is dead code today. BRepLib_MakeSolid's single-shell
        // constructor always Done()s, same finding as OCCTShapeCreateSolidFromShell,
        // but kept push-not-drop for defense in depth rather than silently reducing
        // the body count, matching every sibling per-body solid-construction loop
        // this diff touches (#443 review).
        made.push_back(makeSolid.IsDone() ? TopoDS_Shape(makeSolid.Solid()) : TopoDS_Shape(shell));
      }
      TopoDS_Shape solids = occtSolidBodiesToShape(made);
      if (!solids.IsNull())
        resultShape = solids;
    }

    // Step 3: Apply shape healing
    ShapeFix_Shape fixer(resultShape);
    fixer.Perform();
    TopoDS_Shape fixed = fixer.Shape();
    return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Split Shape by Angle (v0.34.0)

#include <ShapeUpgrade_ShapeDivideAngle.hxx>

OCCTShapeRef OCCTShapeSplitByAngle(OCCTShapeRef shape, double maxAngleDegrees)
{
  if (!shape)
    return nullptr;
  try
  {
    double                        maxAngleRadians = maxAngleDegrees * M_PI / 180.0;
    ShapeUpgrade_ShapeDivideAngle divider(maxAngleRadians, shape->shape);
    if (!divider.Perform())
      return nullptr;
    TopoDS_Shape result = divider.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Drop Small Edges (v0.34.0)

OCCTShapeRef OCCTShapeDropSmallEdges(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_Wireframe) wireframe = new ShapeFix_Wireframe(shape->shape);
    wireframe->SetPrecision(tolerance);
    wireframe->ModeDropSmallEdges() = true;
    wireframe->FixSmallEdges();
    TopoDS_Shape result = wireframe->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Same Parameter (v0.35.0)

#include <BRepLib.hxx>

OCCTShapeRef OCCTShapeSameParameter(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    // Make a copy so we don't modify the original
    BRepBuilderAPI_Copy copier(shape->shape);
    if (!copier.IsDone())
      return nullptr;
    TopoDS_Shape result = copier.Shape();
    BRepLib::SameParameter(result, tolerance);
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Encode Regularity (v0.36.0)

OCCTShapeRef OCCTShapeEncodeRegularity(OCCTShapeRef shape, double toleranceAngleDegrees)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_Copy copier(shape->shape);
    if (!copier.IsDone())
      return nullptr;
    TopoDS_Shape result   = copier.Shape();
    double       tolAngle = toleranceAngleDegrees * M_PI / 180.0;
    BRepLib::EncodeRegularity(result, tolAngle);
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Update Tolerances (v0.36.0)

OCCTShapeRef OCCTShapeUpdateTolerances(OCCTShapeRef shape, bool verifyFaceTolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_Copy copier(shape->shape);
    if (!copier.IsDone())
      return nullptr;
    TopoDS_Shape result = copier.Shape();
    BRepLib::UpdateTolerances(result, verifyFaceTolerance);
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Shape Divide by Number (v0.36.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>

OCCTShapeRef OCCTShapeDivideByNumber(OCCTShapeRef shape, int32_t nbU, int32_t nbV)
{
  if (!shape || nbU < 1 || nbV < 1)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivide divider(shape->shape);
    // Use FaceDivideArea with splitting-by-number mode
    Handle(ShapeUpgrade_FaceDivideArea) faceDivide = new ShapeUpgrade_FaceDivideArea();
    faceDivide->SetSplittingByNumber(true);
    faceDivide->NbParts() = nbU * nbV;
    divider.SetSplitFaceTool(faceDivide);
    if (!divider.Perform())
      return nullptr;
    TopoDS_Shape result = divider.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFreeBounds(OCCTShapeRef shape,
                                 double       sewingTolerance,
                                 int32_t*     outClosedCount,
                                 int32_t*     outOpenCount)
{
  if (!shape || !outClosedCount || !outOpenCount)
    return nullptr;
  try
  {
    ShapeAnalysis_FreeBounds analyzer(shape->shape, sewingTolerance);

    TopoDS_Compound closedWires = analyzer.GetClosedWires();
    TopoDS_Compound openWires   = analyzer.GetOpenWires();

    // Count wires in each compound
    int32_t         closedCount = 0, openCount = 0;
    TopExp_Explorer expClosed(closedWires, TopAbs_WIRE);
    while (expClosed.More())
    {
      closedCount++;
      expClosed.Next();
    }
    TopExp_Explorer expOpen(openWires, TopAbs_WIRE);
    while (expOpen.More())
    {
      openCount++;
      expOpen.Next();
    }

    *outClosedCount = closedCount;
    *outOpenCount   = openCount;

    // Return compound of all free boundary wires
    BRep_Builder    builder;
    TopoDS_Compound result;
    builder.MakeCompound(result);
    if (!closedWires.IsNull())
      builder.Add(result, closedWires);
    if (!openWires.IsNull())
      builder.Add(result, openWires);

    if (closedCount == 0 && openCount == 0)
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFixFreeBounds(OCCTShapeRef shape,
                                    double       sewingTolerance,
                                    double       closingTolerance,
                                    int32_t*     outFixedCount)
{
  if (!shape || !outFixedCount)
    return nullptr;
  try
  {
    ShapeFix_FreeBounds fixer(shape->shape,
                              sewingTolerance,
                              closingTolerance,
                              Standard_True,
                              Standard_True);

    TopoDS_Compound closedWires = fixer.GetClosedWires();
    TopoDS_Compound openWires   = fixer.GetOpenWires();

    int32_t         closedCount = 0;
    TopExp_Explorer exp(closedWires, TopAbs_WIRE);
    while (exp.More())
    {
      closedCount++;
      exp.Next();
    }

    *outFixedCount = closedCount;

    BRep_Builder    builder;
    TopoDS_Compound result;
    builder.MakeCompound(result);
    if (!closedWires.IsNull())
      builder.Add(result, closedWires);
    if (!openWires.IsNull())
      builder.Add(result, openWires);

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDivideClosedEdges(OCCTShapeRef shape, int32_t nbSplitPoints)
{
  if (!shape || nbSplitPoints < 1)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivideClosedEdges divider(shape->shape);
    divider.SetNbSplitPoints(nbSplitPoints);
    if (!divider.Perform())
      return nullptr;
    TopoDS_Shape result = divider.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCustomConvertToBSpline(OCCTShapeRef shape,
                                             bool         extrusion,
                                             bool         revolution,
                                             bool         offset,
                                             bool         plane)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Shape result =
      ShapeCustom::ConvertToBSpline(shape->shape, extrusion, revolution, offset, plane);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCustomConvertToRevolution(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Shape result = ShapeCustom::ConvertToRevolution(shape->shape);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeFaceRestrict(OCCTShapeRef  faceShape,
                              OCCTWireRef*  wires,
                              int32_t       wireCount,
                              OCCTShapeRef* outFaces,
                              int32_t       maxFaces)
{
  if (!faceShape || !wires || wireCount <= 0 || !outFaces || maxFaces <= 0)
    return -1;
  try
  {
    // Get the face from the shape
    TopoDS_Face     face;
    TopExp_Explorer exp(faceShape->shape, TopAbs_FACE);
    if (exp.More())
    {
      face = TopoDS::Face(exp.Current());
    }
    else
    {
      return -1;
    }

    BRepAlgo_FaceRestrictor restrictor;
    restrictor.Init(face, false, true);

    for (int32_t i = 0; i < wireCount; i++)
    {
      if (wires[i])
      {
        TopoDS_Wire w = wires[i]->wire;
        restrictor.Add(w);
      }
    }
    restrictor.Perform();
    if (!restrictor.IsDone())
      return -1;

    int32_t count = 0;
    for (; restrictor.More() && count < maxFaces; restrictor.Next())
    {
      TopoDS_Face resultFace = restrictor.Current();
      outFaces[count]        = new OCCTShape(resultFace);
      count++;
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

// MARK: - v0.43.0: Face Subdivision, Small Face Detection, BSpline Fill, Location Purge

#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeAnalysis_CheckSmallFace.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <BRepTools_PurgeLocations.hxx>

OCCTShapeRef OCCTShapeDivideByArea(OCCTShapeRef shape, double maxArea)
{
  if (!shape || maxArea <= 0)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivideArea divider(shape->shape);
    divider.MaxArea() = maxArea;
    divider.Perform();
    // Result() is valid even when Perform returns false (nothing to split)
    TopoDS_Shape result = divider.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDivideByParts(OCCTShapeRef shape, int32_t nbParts)
{
  if (!shape || nbParts <= 0)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivideArea divider(shape->shape);
    divider.SetSplittingByNumber(true);
    divider.NbParts() = nbParts;
    if (!divider.Perform())
      return nullptr;
    return new OCCTShape(divider.Result());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeCheckSmallFaces(OCCTShapeRef         shape,
                                 double               tolerance,
                                 OCCTSmallFaceResult* outResults,
                                 int32_t              maxResults)
{
  if (!shape || !outResults || maxResults <= 0)
    return 0;
  try
  {
    ShapeAnalysis_CheckSmallFace checker;
    int32_t                      found = 0;

    TopExp_Explorer exp(shape->shape, TopAbs_FACE);
    int32_t         faceIdx = 0;
    while (exp.More() && found < maxResults)
    {
      TopoDS_Face          face = TopoDS::Face(exp.Current());
      OCCTSmallFaceResult& r    = outResults[found];
      r.isSpotFace              = false;
      r.isStripFace             = false;
      r.isTwisted               = false;
      r.spotX = r.spotY = r.spotZ = 0;

      bool isDegenerate = false;

      // Check spot face
      gp_Pnt spot;
      double spotTol;
      int    spotResult = checker.IsSpotFace(face, spot, spotTol, tolerance);
      if (spotResult != 0)
      {
        r.isSpotFace = true;
        r.spotX      = spot.X();
        r.spotY      = spot.Y();
        r.spotZ      = spot.Z();
        isDegenerate = true;
      }

      // Check strip face
      if (checker.IsStripSupport(face, tolerance))
      {
        r.isStripFace = true;
        isDegenerate  = true;
      }

      // Check twisted
      double paramu, paramv;
      if (checker.CheckTwisted(face, paramu, paramv))
      {
        r.isTwisted  = true;
        isDegenerate = true;
      }

      if (isDegenerate)
        found++;
      exp.Next();
      faceIdx++;
    }
    return found;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTShapePurgeLocations(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepTools_PurgeLocations purger;
    purger.Perform(shape->shape);
    if (purger.IsDone())
    {
      return new OCCTShape(purger.GetResult());
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeConnectEdges(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeFix_EdgeConnect connector;
    connector.Add(shape->shape);
    connector.Build();
    // EdgeConnect modifies edges in place, return a copy of the shape
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeUpgrade_ShapeConvertToBezier (v0.45)
OCCTShapeRef OCCTShapeConvertToBezier(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeConvertToBezier converter(shape->shape);
    converter.Set2dConversion(true);
    converter.Set3dConversion(true);
    converter.SetSurfaceConversion(true);
    converter.Set3dLineConversion(true);
    converter.Set3dCircleConversion(true);
    converter.Set3dConicConversion(true);
    converter.SetPlaneMode(true);
    converter.SetRevolutionMode(true);
    converter.SetExtrusionMode(true);
    converter.SetBSplineMode(true);
    if (!converter.Perform())
      return nullptr;
    TopoDS_Shape result = converter.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeAnalysis_WireOrder (v0.45)
OCCTWireOrderResult OCCTWireOrderAnalyze(const double*       starts,
                                         const double*       ends,
                                         int32_t             nbEdges,
                                         double              tolerance,
                                         OCCTWireOrderEntry* outOrder)
{
  OCCTWireOrderResult result = {-1, 0};
  if (!starts || !ends || nbEdges <= 0 || !outOrder)
    return result;
  try
  {
    ShapeAnalysis_WireOrder order(true, tolerance);

    for (int32_t i = 0; i < nbEdges; i++)
    {
      gp_XYZ s(starts[i * 3], starts[i * 3 + 1], starts[i * 3 + 2]);
      gp_XYZ e(ends[i * 3], ends[i * 3 + 1], ends[i * 3 + 2]);
      order.Add(s, e);
    }

    order.Perform();
    result.status  = order.Status();
    result.nbEdges = order.NbEdges();

    for (int32_t i = 1; i <= result.nbEdges; i++)
    {
      outOrder[i - 1].originalIndex = order.Ordered(i);
    }

    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTWireOrderResult OCCTWireOrderAnalyzeWire(OCCTWireRef         wire,
                                             double              tolerance,
                                             OCCTWireOrderEntry* outOrder,
                                             int32_t             maxEntries)
{
  OCCTWireOrderResult result = {-1, 0};
  if (!wire || !outOrder || maxEntries <= 0)
    return result;
  try
  {
    ShapeAnalysis_WireOrder order(true, tolerance);

    // Extract edge endpoints from the wire
    for (TopExp_Explorer exp(wire->wire, TopAbs_EDGE); exp.More(); exp.Next())
    {
      TopoDS_Edge        edge = TopoDS::Edge(exp.Current());
      double             first, last;
      Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
      if (curve.IsNull())
        continue;

      gp_Pnt p1 = curve->Value(first);
      gp_Pnt p2 = curve->Value(last);
      order.Add(p1.XYZ(), p2.XYZ());
    }

    order.Perform();
    result.status  = order.Status();
    result.nbEdges = std::min(order.NbEdges(), maxEntries);

    for (int32_t i = 1; i <= result.nbEdges; i++)
    {
      outOrder[i - 1].originalIndex = order.Ordered(i);
    }

    return result;
  }
  catch (...)
  {
    return result;
  }
}

// MARK: - BRepCheck Validators (v0.47)
// --- BRepCheck ---

static OCCTCheckStatus mapBRepCheckStatus(BRepCheck_Status status)
{
  switch (status)
  {
    case BRepCheck_NoError:
      return OCCTCheckNoError;
    case BRepCheck_InvalidPointOnCurve:
      return OCCTCheckInvalidPointOnCurve;
    case BRepCheck_InvalidPointOnCurveOnSurface:
      return OCCTCheckInvalidPointOnCurveOnSurface;
    case BRepCheck_InvalidPointOnSurface:
      return OCCTCheckInvalidPointOnSurface;
    case BRepCheck_No3DCurve:
      return OCCTCheckNo3DCurve;
    case BRepCheck_Multiple3DCurve:
      return OCCTCheckMultiple3DCurve;
    case BRepCheck_Invalid3DCurve:
      return OCCTCheckInvalid3DCurve;
    case BRepCheck_NoCurveOnSurface:
      return OCCTCheckNoCurveOnSurface;
    case BRepCheck_InvalidCurveOnSurface:
      return OCCTCheckInvalidCurveOnSurface;
    case BRepCheck_InvalidCurveOnClosedSurface:
      return OCCTCheckInvalidCurveOnClosedSurface;
    case BRepCheck_InvalidSameRangeFlag:
      return OCCTCheckInvalidSameRangeFlag;
    case BRepCheck_InvalidSameParameterFlag:
      return OCCTCheckInvalidSameParameterFlag;
    case BRepCheck_InvalidDegeneratedFlag:
      return OCCTCheckInvalidDegeneratedFlag;
    case BRepCheck_FreeEdge:
      return OCCTCheckFreeEdge;
    case BRepCheck_InvalidMultiConnexity:
      return OCCTCheckInvalidMultiConnexity;
    case BRepCheck_InvalidRange:
      return OCCTCheckInvalidRange;
    case BRepCheck_EmptyWire:
      return OCCTCheckEmptyWire;
    case BRepCheck_RedundantEdge:
      return OCCTCheckRedundantEdge;
    case BRepCheck_SelfIntersectingWire:
      return OCCTCheckSelfIntersectingWire;
    case BRepCheck_NoSurface:
      return OCCTCheckNoSurface;
    case BRepCheck_InvalidWire:
      return OCCTCheckInvalidWire;
    case BRepCheck_RedundantWire:
      return OCCTCheckRedundantWire;
    case BRepCheck_IntersectingWires:
      return OCCTCheckIntersectingWires;
    case BRepCheck_InvalidImbricationOfWires:
      return OCCTCheckInvalidImbricationOfWires;
    case BRepCheck_EmptyShell:
      return OCCTCheckEmptyShell;
    case BRepCheck_RedundantFace:
      return OCCTCheckRedundantFace;
    case BRepCheck_InvalidImbricationOfShells:
      return OCCTCheckInvalidImbricationOfShells;
    case BRepCheck_UnorientableShape:
      return OCCTCheckUnorientableShape;
    case BRepCheck_NotClosed:
      return OCCTCheckNotClosed;
    case BRepCheck_NotConnected:
      return OCCTCheckNotConnected;
    case BRepCheck_SubshapeNotInShape:
      return OCCTCheckSubshapeNotInShape;
    case BRepCheck_BadOrientation:
      return OCCTCheckBadOrientation;
    case BRepCheck_BadOrientationOfSubshape:
      return OCCTCheckBadOrientationOfSubshape;
    case BRepCheck_InvalidPolygonOnTriangulation:
      return OCCTCheckInvalidPolygonOnTriangulation;
    case BRepCheck_InvalidToleranceValue:
      return OCCTCheckInvalidToleranceValue;
    case BRepCheck_EnclosedRegion:
      return OCCTCheckEnclosedRegion;
    case BRepCheck_CheckFail:
      return OCCTCheckCheckFail;
    default:
      return OCCTCheckCheckFail;
  }
}

OCCTShapeCheckResult OCCTCheckFace(OCCTFaceRef face)
{
  OCCTShapeCheckResult result = {true, 0, OCCTCheckNoError};
  if (!face)
  {
    result.isValid    = false;
    result.firstError = OCCTCheckCheckFail;
    return result;
  }
  try
  {
    Handle(BRepCheck_Face) checker = new BRepCheck_Face(face->face);
    checker->Minimum();
    const auto& statusList = checker->Status();
    for (auto it = statusList.begin(); it != statusList.end(); ++it)
    {
      if (*it != BRepCheck_NoError)
      {
        if (result.errorCount == 0)
        {
          result.firstError = mapBRepCheckStatus(*it);
        }
        result.errorCount++;
        result.isValid = false;
      }
    }
    return result;
  }
  catch (...)
  {
    result.isValid    = false;
    result.firstError = OCCTCheckCheckFail;
    return result;
  }
}

// --- BRepCheck_Face per-check diagnostics (#266 follow-up) ---
// Each returns the specific BRepCheck_Status for one wire-topology check. The checks build on each
// other (intersection → imbrication/classification → orientation), so the later ones run the
// prerequisite passes first to be robust when called standalone.

OCCTCheckStatus OCCTBRepCheckFaceIntersectWires(OCCTShapeRef face, bool geometricControls)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return OCCTCheckCheckFail;
  try
  {
    Handle(BRepCheck_Face) checker = new BRepCheck_Face(TopoDS::Face(face->shape));
    checker->GeometricControls(geometricControls);
    return mapBRepCheckStatus(checker->IntersectWires());
  }
  catch (...)
  {
    return OCCTCheckCheckFail;
  }
}

OCCTCheckStatus OCCTBRepCheckFaceClassifyWires(OCCTShapeRef face, bool geometricControls)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return OCCTCheckCheckFail;
  try
  {
    Handle(BRepCheck_Face) checker = new BRepCheck_Face(TopoDS::Face(face->shape));
    checker->GeometricControls(geometricControls);
    checker->IntersectWires();
    return mapBRepCheckStatus(checker->ClassifyWires());
  }
  catch (...)
  {
    return OCCTCheckCheckFail;
  }
}

OCCTCheckStatus OCCTBRepCheckFaceOrientationOfWires(OCCTShapeRef face, bool geometricControls)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return OCCTCheckCheckFail;
  try
  {
    Handle(BRepCheck_Face) checker = new BRepCheck_Face(TopoDS::Face(face->shape));
    checker->GeometricControls(geometricControls);
    checker->IntersectWires();
    checker->ClassifyWires();
    BRepCheck_Status st = checker->OrientationOfWires();
    return mapBRepCheckStatus(st);
  }
  catch (...)
  {
    return OCCTCheckCheckFail;
  }
}

OCCTShapeCheckResult OCCTCheckSolid(OCCTShapeRef shape)
{
  OCCTShapeCheckResult result = {true, 0, OCCTCheckNoError};
  if (!shape)
  {
    result.isValid    = false;
    result.firstError = OCCTCheckCheckFail;
    return result;
  }
  try
  {
    for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More(); exp.Next())
    {
      TopoDS_Solid            solid   = TopoDS::Solid(exp.Current());
      Handle(BRepCheck_Solid) checker = new BRepCheck_Solid(solid);
      checker->Minimum();
      const auto& statusList = checker->Status();
      for (auto it = statusList.begin(); it != statusList.end(); ++it)
      {
        if (*it != BRepCheck_NoError)
        {
          if (result.errorCount == 0)
          {
            result.firstError = mapBRepCheckStatus(*it);
          }
          result.errorCount++;
          result.isValid = false;
        }
      }
    }
    return result;
  }
  catch (...)
  {
    result.isValid    = false;
    result.firstError = OCCTCheckCheckFail;
    return result;
  }
}

OCCTShapeCheckResult OCCTCheckShape(OCCTShapeRef shape)
{
  OCCTShapeCheckResult result = {true, 0, OCCTCheckNoError};
  if (!shape)
  {
    result.isValid    = false;
    result.firstError = OCCTCheckCheckFail;
    return result;
  }
  try
  {
    BRepCheck_Analyzer analyzer(shape->shape, true);
    result.isValid = analyzer.IsValid();
    if (!result.isValid)
    {
      // Count errors from sub-shapes
      for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next())
      {
        const Handle(BRepCheck_Result)& res = analyzer.Result(exp.Current());
        if (!res.IsNull())
        {
          const auto& statusList = res->Status();
          for (auto it = statusList.begin(); it != statusList.end(); ++it)
          {
            if (*it != BRepCheck_NoError)
            {
              if (result.errorCount == 0)
              {
                result.firstError = mapBRepCheckStatus(*it);
              }
              result.errorCount++;
            }
          }
        }
      }
      for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next())
      {
        const Handle(BRepCheck_Result)& res = analyzer.Result(exp.Current());
        if (!res.IsNull())
        {
          const auto& statusList = res->Status();
          for (auto it = statusList.begin(); it != statusList.end(); ++it)
          {
            if (*it != BRepCheck_NoError)
            {
              if (result.errorCount == 0)
              {
                result.firstError = mapBRepCheckStatus(*it);
              }
              result.errorCount++;
            }
          }
        }
      }
    }
    return result;
  }
  catch (...)
  {
    result.isValid    = false;
    result.firstError = OCCTCheckCheckFail;
    return result;
  }
}

int32_t OCCTCheckShapeDetailed(OCCTShapeRef     shape,
                               OCCTCheckStatus* outStatuses,
                               int32_t          maxStatuses)
{
  if (!shape || !outStatuses || maxStatuses <= 0)
    return 0;
  try
  {
    BRepCheck_Analyzer analyzer(shape->shape, true);
    int32_t            count = 0;

    auto collectStatuses = [&](TopAbs_ShapeEnum type) {
      for (TopExp_Explorer exp(shape->shape, type); exp.More(); exp.Next())
      {
        const Handle(BRepCheck_Result)& res = analyzer.Result(exp.Current());
        if (!res.IsNull())
        {
          const auto& statusList = res->Status();
          for (auto it = statusList.begin(); it != statusList.end(); ++it)
          {
            if (*it != BRepCheck_NoError && count < maxStatuses)
            {
              outStatuses[count++] = mapBRepCheckStatus(*it);
            }
          }
        }
      }
    };

    collectStatuses(TopAbs_VERTEX);
    collectStatuses(TopAbs_EDGE);
    collectStatuses(TopAbs_WIRE);
    collectStatuses(TopAbs_FACE);
    collectStatuses(TopAbs_SHELL);
    collectStatuses(TopAbs_SOLID);

    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - BRepCheck Analyzer + Sub-Shape Validators (v0.48)
bool OCCTBRepCheckAnalyzerIsValid(OCCTShapeRef shape, bool geometryChecks)
{
  if (!shape)
    return false;
  try
  {
    BRepCheck_Analyzer analyzer(shape->shape, geometryChecks);
    return analyzer.IsValid();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepCheckSubShapeValid(OCCTShapeRef parentShape,
                                int32_t      subShapeType,
                                int32_t      subShapeIndex)
{
  if (!parentShape)
    return false;
  try
  {
    BRepCheck_Analyzer analyzer(parentShape->shape, true);

    // #541: the shared enumeration, so this names the same sub-shape every other
    // type+index entry point does.
    TopoDS_Shape sub = occtSubShapeAt(parentShape->shape, subShapeType, subShapeIndex);
    if (sub.IsNull())
      return false;
    return analyzer.IsValid(sub);
  }
  catch (...)
  {
    return false;
  }
}

// #613: this walked a bare TopExp_Explorer while OCCTBRepCheckSubShapeValid ten lines above -- the
// other half of the same "is this sub-shape valid" surface -- reads occtSubShapeAt. So
// checkEdge(at:) and isSubShapeValid(type:.edge, at:) counted different things. Measured on a 10mm
// box (24 edge occurrences over 12 edges, 48 vertex occurrences over 8 vertices): checkEdge(at: 12)
// reported a valid edge although edge(at: 12) is nil, and it kept answering all the way to index
// 23; checkVertex answered to index 47 on an 8-vertex shape.
//
// Safe on the map rather than the traversal: BRepCheck_Edge/Wire/Shell/Vertex are handed the
// sub-shape as geometry+topology, not as a key selecting one side of a shared boundary. Measured
// rather than assumed -- over every box edge (12) and vertex (8) present in both orientations, the
// full BRepCheck status list was identical for the FORWARD and the REVERSED occurrence, 0
// differing.
//
// A plain box has no WIRE or SHELL occurring twice, so six fixtures were built to reach those:
// compound{solid, solid.Reversed()} and the same for a shell, a face, a wire, an open (invalid,
// non-closed) wire, and a fused two-body solid. Together 26 WIRE pairs and 4 SHELL pairs, BRepCheck
// identical across orientation in every one, 0 differing, invalid geometry included. Note this does
// NOT mean the conversion is a no-op for them: their index DOMAIN moves, and should -- on
// compound{solid, solid.Reversed()} the WIRE enumeration goes 12 occurrences to 6 distinct. What is
// unchanged is the answer for a wire or shell that both enumerations name.
//
// This function never handles FACE, which is the one type where the map/traversal choice changes a
// result (#614) -- OCCTCheckFace takes an OCCTFaceRef directly and never indexes.
static OCCTShapeCheckResult checkSubShape(OCCTShapeRef shape, TopAbs_ShapeEnum type, int32_t index)
{
  OCCTShapeCheckResult result = {};
  result.isValid              = false;
  result.firstError           = OCCTCheckNoError;
  if (!shape)
    return result;

  try
  {
    TopoDS_Shape subShape = occtSubShapeAt(shape->shape, type, index);
    if (subShape.IsNull())
      return result;

    Handle(BRepCheck_Result) checker;
    switch (type)
    {
      case TopAbs_EDGE:
        checker = new BRepCheck_Edge(TopoDS::Edge(subShape));
        break;
      case TopAbs_WIRE:
        checker = new BRepCheck_Wire(TopoDS::Wire(subShape));
        break;
      case TopAbs_SHELL:
        checker = new BRepCheck_Shell(TopoDS::Shell(subShape));
        break;
      case TopAbs_VERTEX:
        checker = new BRepCheck_Vertex(TopoDS::Vertex(subShape));
        break;
      default:
        return result;
    }

    checker->Minimum();
    auto& statusList = checker->Status();

    result.isValid = true;
    for (auto it = statusList.begin(); it != statusList.end(); ++it)
    {
      if (*it != BRepCheck_NoError)
      {
        result.isValid = false;
        if (result.firstError == OCCTCheckNoError)
        {
          result.firstError = mapBRepCheckStatus(*it);
        }
      }
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTShapeCheckResult OCCTCheckEdge(OCCTShapeRef shape, int32_t edgeIndex)
{
  return checkSubShape(shape, TopAbs_EDGE, edgeIndex);
}

OCCTShapeCheckResult OCCTCheckWire(OCCTShapeRef shape, int32_t wireIndex)
{
  return checkSubShape(shape, TopAbs_WIRE, wireIndex);
}

OCCTShapeCheckResult OCCTCheckShell(OCCTShapeRef shape, int32_t shellIndex)
{
  return checkSubShape(shape, TopAbs_SHELL, shellIndex);
}

OCCTShapeCheckResult OCCTCheckVertex(OCCTShapeRef shape, int32_t vertexIndex)
{
  return checkSubShape(shape, TopAbs_VERTEX, vertexIndex);
}

// MARK: - ShapeFix Tolerance + Vertex/Connect Repair (v0.48)
bool OCCTShapeFixLimitTolerance(OCCTShapeRef shape, double minTolerance, double maxTolerance)
{
  if (!shape)
    return false;
  try
  {
    ShapeFix_ShapeTolerance tolFixer;
    return tolFixer.LimitTolerance(shape->shape, minTolerance, maxTolerance);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTShapeFixSetTolerance(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return;
  try
  {
    ShapeFix_ShapeTolerance tolFixer;
    tolFixer.SetTolerance(shape->shape, tolerance);
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTShapeFixSplitCommonVertex(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeFix_SplitCommonVertex splitter;
    splitter.Init(shape->shape);
    splitter.Perform();
    TopoDS_Shape result = splitter.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Connect adjacent faces in every shell of the input, not just the first one an explorer yields
// (#484, same first-of-N family as #439/#442/#443). ShapeFix_FaceConnect::Build takes one shell,
// so a multi-shell input has to be driven one shell at a time; the results are reassembled with
// the shared helper, so a single-shell input still returns a bare shell and multi-shell input
// returns a compound.
// #1026: the ShapeType() read below is an unguarded myTShape dereference; the pointer test alone
// said nothing about the shape, and Shape.nullified reaches this through Shape.fixedFaceConnect.
OCCTShapeRef OCCTShapeFixFaceConnect(OCCTShapeRef shape, double tolerance)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;
  try
  {
    std::vector<TopoDS_Shape> shells;
    if (shape->shape.ShapeType() == TopAbs_SHELL)
    {
      shells.push_back(shape->shape);
    }
    else
    {
      for (TopExp_Explorer exp(shape->shape, TopAbs_SHELL); exp.More(); exp.Next())
      {
        shells.push_back(exp.Current());
      }
    }
    if (shells.empty())
      return nullptr;

    std::vector<TopoDS_Shape> connected;
    bool                      anyConnected = false;
    for (const TopoDS_Shape& shellShape : shells)
    {
      TopoDS_Shell shell = TopoDS::Shell(shellShape);

      // Get face pairs and connect them
      ShapeFix_FaceConnect connector;

      // Collect all faces
      std::vector<TopoDS_Face> faces;
      for (TopExp_Explorer exp(shell, TopAbs_FACE); exp.More(); exp.Next())
      {
        faces.push_back(TopoDS::Face(exp.Current()));
      }

      // Add adjacent face pairs
      for (size_t i = 0; i + 1 < faces.size(); i++)
      {
        connector.Add(faces[i], faces[i + 1]);
      }

      TopoDS_Shell result = connector.Build(shell, tolerance, tolerance);
      // Defensive, not reachable: read ShapeFix_FaceConnect::Build (occt-src) end to end --
      // `result` starts as the input shell and is only ever reassigned via TopoDS::Shell() on
      // a ReShape::Apply() result or a rebuilt shell, never a default-constructed TopoDS_Shell.
      // Probed directly (Add() consecutive face pairs then Build(), matching this loop exactly)
      // against a real connect, a no-Add() no-op, and a single-face shell: IsNull() is false in
      // all three (#484). Kept for the same reason #443's equivalent branch was kept once its
      // own "failure" was found to be dead code: the alternative is trusting an internal OCCT
      // invariant to hold forever, and the cost of being wrong (silently dropping a shell from
      // a multi-shell result) is worse than one unreachable branch.
      anyConnected = anyConnected || !result.IsNull();
      connected.push_back(result.IsNull() ? shell : (TopoDS_Shape)result);
    }
    // Unchanged contract for the single-shell case: nil when nothing could be connected.
    if (!anyConnected)
      return nullptr;

    TopoDS_Shape out = occtSolidBodiesToShape(connected);
    if (out.IsNull())
      return nullptr;
    return new OCCTShape(out);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeFixEdgeSameParameter(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return 0;
  try
  {
    Handle(ShapeFix_Edge) edgeFixer = new ShapeFix_Edge();
    int32_t               count     = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next())
    {
      TopoDS_Edge edge = TopoDS::Edge(exp.Current());
      if (edgeFixer->FixSameParameter(edge, tolerance))
      {
        count++;
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTShapeFixEdgeVertexTolerance(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    Handle(ShapeFix_Edge) edgeFixer = new ShapeFix_Edge();
    int32_t               count     = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next())
    {
      TopoDS_Edge edge = TopoDS::Edge(exp.Current());
      if (edgeFixer->FixVertexTolerance(edge))
      {
        count++;
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTShapeFixWireVertex(OCCTShapeRef shape, double precision)
{
  if (!shape)
    return 0;
  try
  {
    int32_t totalFixed = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_WIRE); exp.More(); exp.Next())
    {
      TopoDS_Wire         wire = TopoDS::Wire(exp.Current());
      ShapeFix_WireVertex wireVertex;
      wireVertex.Init(wire, precision);
      totalFixed += wireVertex.Fix();
    }
    return totalFixed;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeUpgrade Divide Closed/Continuity (v0.48)
OCCTShapeRef OCCTShapeUpgradeDivideClosed(OCCTShapeRef shape, int32_t nbSplitPoints)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivideClosed divider(shape->shape);
    divider.SetNbSplitPoints(nbSplitPoints);
    bool ok = divider.Perform();
    if (!ok)
      return nullptr;
    TopoDS_Shape result = divider.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// OCCTShapeUpgradeDivideContinuity, the boundary-only entry point behind the now-deprecated
// Shape.dividedByContinuity(criterion:tolerance:), was removed here (#438): it wrapped the same
// ShapeUpgrade_ShapeDivideContinuity as OCCTShapeDivide above with a narrower, measurably
// different call (SetBoundaryCriterion only, no SetPCurveCriterion/SetSurfaceCriterion). The
// deprecated Swift entry point now forwards to Shape.divided(at:tolerance:), so this bridge
// function has no remaining caller.

// MARK: - ShapeFix Small Solids (v0.49)
// --- ShapeFix_FixSmallSolid ---

OCCTShapeRef OCCTShapeFixRemoveSmallSolids(OCCTShapeRef shape, double volumeThreshold)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_FixSmallSolid) fixer = new ShapeFix_FixSmallSolid();
    fixer->SetFixMode(2); // volume only
    fixer->SetVolumeThreshold(volumeThreshold);
    Handle(ShapeBuild_ReShape) ctx    = new ShapeBuild_ReShape();
    TopoDS_Shape               result = fixer->Remove(shape->shape, ctx);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFixMergeSmallSolids(OCCTShapeRef shape, double widthFactorThreshold)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_FixSmallSolid) fixer = new ShapeFix_FixSmallSolid();
    fixer->SetFixMode(1); // width only
    fixer->SetWidthFactorThreshold(widthFactorThreshold);
    Handle(ShapeBuild_ReShape) ctx    = new ShapeBuild_ReShape();
    TopoDS_Shape               result = fixer->Merge(shape->shape, ctx);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeCustom Direct Faces / BSpline Restriction (v0.49)
// --- ShapeCustom ---

OCCTShapeRef OCCTShapeCustomDirectFaces(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Shape result = ShapeCustom::DirectFaces(shape->shape);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCustomBSplineRestriction(OCCTShapeRef shape,
                                               double       tol3d,
                                               double       tol2d,
                                               int32_t      maxDegree,
                                               int32_t      maxSegments,
                                               int32_t      continuity3d,
                                               int32_t      continuity2d,
                                               bool         degreePriority,
                                               bool         rational)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeCustom_RestrictionParameters) params = new ShapeCustom_RestrictionParameters();
    TopoDS_Shape                              result =
      ShapeCustom::BSplineRestriction(shape->shape,
                                      tol3d,
                                      tol2d,
                                      maxDegree,
                                      maxSegments,
                                      occtGeomAbsFromParametricContinuity(continuity3d),
                                      occtGeomAbsFromParametricContinuity(continuity2d),
                                      degreePriority,
                                      rational,
                                      params);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeAnalysis_FreeBoundsProperties (v0.49)
//
// OCCTFreeBoundsAnalyze, OCCTFreeBoundsGetClosedBoundInfo, OCCTFreeBoundsGetOpenBoundInfo,
// OCCTFreeBoundsGetClosedBoundWire and OCCTFreeBoundsGetOpenBoundWire were implemented here,
// each constructing its own ShapeAnalysis_FreeBoundsProperties and calling Perform() again.
// Removed by #504; the one implementation is with the v0.114 block below.

// MARK: - ShapeAnalysis_WireVertex (v0.50)
OCCTWireVertexResult OCCTShapeWireVertexAnalysis(OCCTShapeRef wire, double precision)
{
  OCCTWireVertexResult result = {};
  if (!wire)
    return result;
  try
  {
    TopoDS_Wire              w = TopoDS::Wire(wire->shape);
    ShapeAnalysis_WireVertex wv;
    wv.Init(w, precision);
    wv.Analyze();
    result.isDone  = wv.IsDone();
    result.nbEdges = wv.NbEdges();
  }
  catch (...)
  {
  }
  return result;
}

int32_t OCCTShapeWireVertexStatus(OCCTShapeRef wire, double precision, int32_t vertexIndex)
{
  if (!wire)
    return -2;
  try
  {
    TopoDS_Wire              w = TopoDS::Wire(wire->shape);
    ShapeAnalysis_WireVertex wv;
    wv.Init(w, precision);
    wv.Analyze();
    if (!wv.IsDone())
      return -2;
    if (vertexIndex < 0 || vertexIndex >= wv.NbEdges())
      return -2;
    return wv.Status(vertexIndex + 1);
  }
  catch (...)
  {
    return -2;
  }
}

// MARK: - ShapeAnalysis_Geom NearestPlane (v0.50)
OCCTNearestPlaneResult OCCTShapeNearestPlane(const double* points, int32_t nPoints)
{
  OCCTNearestPlaneResult result = {};
  if (!points || nPoints < 3)
    return result;
  try
  {
    TColgp_Array1OfPnt pts(1, nPoints);
    for (int32_t i = 0; i < nPoints; i++)
    {
      pts.SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }
    gp_Pln        pln;
    Standard_Real dmax;
    if (ShapeAnalysis_Geom::NearestPlane(pts, pln, dmax))
    {
      result.success      = true;
      result.maxDeviation = dmax;
      gp_Dir normal       = pln.Axis().Direction();
      result.normalX      = normal.X();
      result.normalY      = normal.Y();
      result.normalZ      = normal.Z();
      gp_Pnt loc          = pln.Location();
      result.originX      = loc.X();
      result.originY      = loc.Y();
      result.originZ      = loc.Z();
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - BRepTools_Substitution + ShapeUpgrade_ShellSewing (v0.52)
// --- BRepTools_Substitution ---

OCCTShapeRef _Nullable OCCTBRepToolsSubstitute(OCCTShapeRef parentShape,
                                               OCCTShapeRef oldSubShape,
                                               OCCTShapeRef newSubShape)
{
  if (!parentShape || !oldSubShape || !newSubShape)
    return nullptr;
  try
  {
    TopTools_ListOfShape newShapes;
    newShapes.Append(newSubShape->shape);
    BRepTools_Substitution sub;
    sub.Substitute(oldSubShape->shape, newShapes);
    sub.Build(parentShape->shape);
    if (!sub.IsCopied(parentShape->shape))
      return nullptr;
    auto& copies = sub.Copy(parentShape->shape);
    if (copies.Size() == 0)
      return nullptr;
    auto* result  = new OCCTShape();
    result->shape = copies.First();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_ShellSewing ---

OCCTShapeRef _Nullable OCCTShapeUpgradeShellSewing(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShellSewing ss;
    TopoDS_Shape             sewn = ss.ApplySewing(shape->shape, tolerance);
    if (sewn.IsNull())
      return nullptr;
    auto* result  = new OCCTShape();
    result->shape = sewn;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeFix_SplitTool (v0.52)
// --- ShapeFix_SplitTool ---

bool OCCTShapeFixSplitEdge(OCCTEdgeRef edge,
                           double      param,
                           double      vertexX,
                           double      vertexY,
                           double      vertexZ,
                           OCCTEdgeRef _Nullable* _Nonnull outEdge1,
                           OCCTEdgeRef _Nullable* _Nonnull outEdge2)
{
  if (!occtShapeIsPresent(edge) || !outEdge1 || !outEdge2)
    return false;
  try
  {
    TopoDS_Vertex      vert = BRepBuilderAPI_MakeVertex(gp_Pnt(vertexX, vertexY, vertexZ)).Vertex();
    double             f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    // Refuse a parameter outside the edge's own range. ShapeFix_SplitTool::SplitEdge checks only
    // for a parameter AT either end, within tol2d, and has nothing to say about one beyond them:
    // measured on a line trimmed to [-5, 5], param 6 returns halves of length 11 and 1, and param
    // 100 returns 105 and 95, against an original length of 10. Those are extrapolations of the
    // underlying unbounded line handed back as "the two halves of your edge". The bound has to
    // come from the edge, and nothing else here supplies it (#1020).
    if (param <= f + Precision::PConfusion() || param >= l - Precision::PConfusion())
      return false;

    // A minimal planar face, only to satisfy the signature. Its normal, position and trim are all
    // inert: no pcurve for this edge exists on a face built for the occasion, so
    // BRep_Tool::CurveOnSurface falls through to CurveOnPlane, which projects the edge onto the
    // plane and returns the edge's own parameter range whatever plane it is. Measured across four
    // deliberately incompatible faces (a +-0.001 trim, a (1,1,1) normal, a plane at
    // (1e6, 1e6, 1e6)) on five edges including one 5000 units outside this trim and one whose
    // natural plane is XZ: byte-identical halves in every row. So the +Z and the +-1000 are
    // arbitrary and stay arbitrary; deriving them from the edge would buy nothing. See
    // Scripts/repro/1020-fabricated-arguments.
    gp_Pnt      mid = curve->Value((f + l) / 2.0);
    gp_Pln      plane(mid, gp_Dir(0, 0, 1));
    TopoDS_Face face = BRepBuilderAPI_MakeFace(plane, -1000, 1000, -1000, 1000).Face();

    ShapeFix_SplitTool tool;
    TopoDS_Edge        newE1, newE2;
    bool               ok = tool.SplitEdge(edge->edge, param, vert, face, newE1, newE2, 1e-6, 1e-6);
    if (!ok || newE1.IsNull() || newE2.IsNull())
      return false;

    auto* e1  = new OCCTEdge();
    e1->edge  = newE1;
    *outEdge1 = e1;

    auto* e2  = new OCCTEdge();
    e2->edge  = newE2;
    *outEdge2 = e2;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - ShapeCustom Direct + Trsf Modification (v0.62)
// --- ShapeCustom_DirectModification ---

OCCTShapeRef _Nullable OCCTShapeCustomDirectModification(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeCustom_DirectModification) mod = new ShapeCustom_DirectModification();
    BRepTools_Modifier                     modifier(shape->shape);
    modifier.Perform(mod);
    if (!modifier.IsDone())
      return nullptr;
    return new OCCTShape(modifier.ModifiedShape(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeCustom_TrsfModification ---

OCCTShapeRef _Nullable OCCTShapeCustomTrsfModificationScale(OCCTShapeRef shape, double scaleFactor)
{
  if (!shape)
    return nullptr;
  try
  {
    gp_Trsf trsf;
    trsf.SetScale(gp_Pnt(0, 0, 0), scaleFactor);
    Handle(ShapeCustom_TrsfModification) mod = new ShapeCustom_TrsfModification(trsf);
    BRepTools_Modifier                   modifier(shape->shape);
    modifier.Perform(mod);
    if (!modifier.IsDone())
      return nullptr;
    return new OCCTShape(modifier.ModifiedShape(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeUpgrade ClosedFaceDivide / SplitSurfaceAngle / SplitSurfaceArea (v0.62)
// --- ShapeUpgrade_ClosedFaceDivide ---

OCCTShapeRef _Nullable OCCTShapeUpgradeClosedFaceDivide(OCCTShapeRef shape, int32_t nbSplitPoints)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivide              sd(shape->shape);
    Handle(ShapeUpgrade_ClosedFaceDivide) cfd = new ShapeUpgrade_ClosedFaceDivide();
    cfd->SetNbSplitPoints(nbSplitPoints > 0 ? nbSplitPoints : 1);
    sd.SetSplitFaceTool(cfd);
    if (!sd.Perform())
      return nullptr;
    TopoDS_Shape result = sd.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_SplitSurfaceAngle ---

OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceAngle(OCCTShapeRef shape, double maxAngleDegrees)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivideAngle sd(maxAngleDegrees * M_PI / 180.0, shape->shape);
    if (!sd.Perform())
      return nullptr;
    TopoDS_Shape result = sd.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_SplitSurfaceArea ---

OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceArea(OCCTShapeRef shape, int32_t nbParts)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivideArea sd(shape->shape);
    sd.SetSplittingByNumber(true);
    sd.NbParts() = (nbParts > 0 ? nbParts : 4);
    if (!sd.Perform())
      return nullptr;
    TopoDS_Shape result = sd.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeAnalysis_TransferParametersProj (v0.64)
// --- ShapeAnalysis_TransferParametersProj ---

double OCCTShapeAnalysisTransferParam(OCCTShapeRef edgeShape,
                                      OCCTShapeRef faceShape,
                                      double       param,
                                      bool         toFace)
{
  if (!edgeShape || !faceShape)
    return param;
  try
  {
    TopoDS_Edge                          edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face                          face = TopoDS::Face(faceShape->shape);
    ShapeAnalysis_TransferParametersProj transfer(edge, face);
    return transfer.Perform(param, toFace);
  }
  catch (...)
  {
    return param;
  }
}

// ============================================================
// v0.65.0: Shape Processing Completions + Boolean Completions
// ============================================================

#include <BOPAlgo_Section.hxx>
#include <BOPAlgo_BuilderFace.hxx>
#include <BOPAlgo_BuilderSolid.hxx>
#include <BOPAlgo_ShellSplitter.hxx>
#include <BOPAlgo_Tools.hxx>
#include <BOPTools_AlgoTools.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_FaceFace.hxx>
#include <IntTools_FClass2d.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_SequenceOfCommonPrts.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_PntOn2Faces.hxx>
#include <IntTools_SequenceOfCurves.hxx>
#include <IntTools_SequenceOfPntOn2Faces.hxx>
#include <IntTools_Context.hxx>
#include <IntTools_Range.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <BRepTools_Modifier.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_Vertex.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeUpgrade_EdgeDivide.hxx>
#include <ShapeUpgrade_ClosedEdgeDivide.hxx>
#include <ShapeUpgrade_FixSmallCurves.hxx>
#include <ShapeUpgrade_FixSmallBezierCurves.hxx>
#include <ShapeUpgrade_ConvertCurve3dToBezier.hxx>
#include <ShapeUpgrade_ConvertSurfaceToBezierBasis.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>

// MARK: - ShapeBuild_Edge (v0.64)
// --- ShapeBuild_Edge ---

OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopy(OCCTShapeRef edgeShape, bool sharePCurves)
{
  if (!edgeShape)
    return nullptr;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge   = TopoDS::Edge(edgeShape->shape);
    TopoDS_Edge     result = sbe.Copy(edge, sharePCurves ? Standard_True : Standard_False);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopyReplaceVertices(OCCTShapeRef edgeShape,
                                                             OCCTShapeRef vertex1Shape,
                                                             OCCTShapeRef vertex2Shape)
{
  if (!edgeShape)
    return nullptr;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Vertex   v1, v2;
    if (vertex1Shape)
      v1 = TopoDS::Vertex(vertex1Shape->shape);
    if (vertex2Shape)
      v2 = TopoDS::Vertex(vertex2Shape->shape);
    TopoDS_Edge result = sbe.CopyReplaceVertices(edge, v1, v2);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTShapeBuildEdgeSetRange3d(OCCTShapeRef edgeShape, double first, double last)
{
  if (!edgeShape)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    sbe.SetRange3d(edge, first, last);
    edgeShape->shape = edge;
  }
  catch (...)
  {
  }
}

bool OCCTShapeBuildEdgeBuildCurve3d(OCCTShapeRef edgeShape)
{
  if (!edgeShape)
    return false;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    return sbe.BuildCurve3d(edge) ? true : false;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTShapeBuildEdgeRemoveCurve3d(OCCTShapeRef edgeShape)
{
  if (!edgeShape)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    sbe.RemoveCurve3d(edge);
    edgeShape->shape = edge;
  }
  catch (...)
  {
  }
}

void OCCTShapeBuildEdgeCopyRanges(OCCTShapeRef toEdge, OCCTShapeRef fromEdge)
{
  if (!toEdge || !fromEdge)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     to   = TopoDS::Edge(toEdge->shape);
    TopoDS_Edge     from = TopoDS::Edge(fromEdge->shape);
    sbe.CopyRanges(to, from);
    toEdge->shape = to;
  }
  catch (...)
  {
  }
}

void OCCTShapeBuildEdgeCopyPCurves(OCCTShapeRef toEdge, OCCTShapeRef fromEdge)
{
  if (!toEdge || !fromEdge)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     to   = TopoDS::Edge(toEdge->shape);
    TopoDS_Edge     from = TopoDS::Edge(fromEdge->shape);
    sbe.CopyPCurves(to, from);
    toEdge->shape = to;
  }
  catch (...)
  {
  }
}

void OCCTShapeBuildEdgeRemovePCurve(OCCTShapeRef edgeShape, OCCTShapeRef faceShape)
{
  if (!edgeShape || !faceShape)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face     face = TopoDS::Face(faceShape->shape);
    sbe.RemovePCurve(edge, face);
    edgeShape->shape = edge;
  }
  catch (...)
  {
  }
}

bool OCCTShapeBuildEdgeReassignPCurve(OCCTShapeRef edgeShape,
                                      OCCTShapeRef oldFaceShape,
                                      OCCTShapeRef newFaceShape)
{
  if (!edgeShape || !oldFaceShape || !newFaceShape)
    return false;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge    = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face     oldFace = TopoDS::Face(oldFaceShape->shape);
    TopoDS_Face     newFace = TopoDS::Face(newFaceShape->shape);
    return sbe.ReassignPCurve(edge, oldFace, newFace) ? true : false;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - ShapeBuild_Vertex (v0.64)
// --- ShapeBuild_Vertex ---

OCCTShapeRef _Nullable OCCTShapeBuildVertexCombine(OCCTShapeRef v1Shape,
                                                   OCCTShapeRef v2Shape,
                                                   double       tolFactor)
{
  if (!v1Shape || !v2Shape)
    return nullptr;
  try
  {
    ShapeBuild_Vertex sbv;
    TopoDS_Vertex     v1     = TopoDS::Vertex(v1Shape->shape);
    TopoDS_Vertex     v2     = TopoDS::Vertex(v2Shape->shape);
    TopoDS_Vertex     result = sbv.CombineVertex(v1, v2, tolFactor);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTShapeBuildVertexCombineFromPoints(double x1,
                                                             double y1,
                                                             double z1,
                                                             double tol1,
                                                             double x2,
                                                             double y2,
                                                             double z2,
                                                             double tol2,
                                                             double tolFactor)
{
  try
  {
    ShapeBuild_Vertex sbv;
    TopoDS_Vertex     result =
      sbv.CombineVertex(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), tol1, tol2, tolFactor);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeExtend_Explorer (v0.64)
// --- ShapeExtend_Explorer ---

OCCTShapeRef _Nullable OCCTShapeExtendSortedCompound(OCCTShapeRef shape,
                                                     int32_t      shapeType,
                                                     bool         explore)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeExtend_Explorer explorer;
    TopoDS_Shape         result = explorer.SortedCompound(shape->shape,
                                                          (TopAbs_ShapeEnum)shapeType,
                                                          explore ? Standard_True : Standard_False,
                                                          Standard_True);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeExtendShapeType(OCCTShapeRef shape, bool compound)
{
  // #844 left this fallback as `7` (TopAbs_VERTEX, a real, legitimate case) though the comment
  // on this line at the time said TopAbs_SHAPE (8) -- so a null shape or a caught exception
  // silently decoded as ".vertex" in predominantShapeType() (Shape+ShapeHealing.swift) rather
  // than signaling failure. Fixed (PR #870 aggregate review): -1, matching ShapeType's own
  // `.unknown = -1` decode-failure sentinel -- predominantShapeType()'s
  // `ShapeFilterType(rawValue: Int(raw)) ?? .compound` decodes -1 to `.unknown` directly (a
  // defined case, so the `?? .compound` fallback never fires for this), rather than falling
  // through to a plausible-looking real answer. See Issue870ShapeExtendShapeTypeFailureTests.
  if (!shape)
    return -1; // ShapeType.unknown
  try
  {
    ShapeExtend_Explorer explorer;
    return (int32_t)explorer.ShapeType(shape->shape, compound ? Standard_True : Standard_False);
  }
  catch (...)
  {
    return -1;
  } // ShapeType.unknown
}

// MARK: - ShapeUpgrade FaceDivide / WireDivide / EdgeDivide / FixSmall / ConvertToBezier (v0.64)
// --- ShapeUpgrade_FaceDivide ---

OCCTShapeRef _Nullable OCCTShapeUpgradeFaceDivide(OCCTShapeRef faceShape)
{
  if (!faceShape)
    return nullptr;
  try
  {
    TopoDS_Face                     face = TopoDS::Face(faceShape->shape);
    Handle(ShapeUpgrade_FaceDivide) fd   = new ShapeUpgrade_FaceDivide(face);
    fd->SetSurfaceSegmentMode(Standard_True);
    fd->Perform();
    TopoDS_Shape result = fd->Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_WireDivide ---

OCCTShapeRef _Nullable OCCTShapeUpgradeWireDivideOnFace(OCCTShapeRef wireShape,
                                                        OCCTShapeRef faceShape)
{
  if (!wireShape || !faceShape)
    return nullptr;
  try
  {
    TopoDS_Wire wire = TopoDS::Wire(wireShape->shape);
    TopoDS_Face face = TopoDS::Face(faceShape->shape);
    // OCCT 8.0.0p1: ShapeUpgrade_WireDivide::Perform() null-derefs (SIGSEGV, Address 0) when a wire
    // edge has no pcurve on the target face (e.g. a wire that doesn't lie on the face), an OS
    // signal catch(...) cannot trap. Guard by requiring every edge to carry a pcurve on the face.
    // OCCTWireCheckOuterBound below runs the near-sibling of this walk with the opposite
    // quantifier, for the reason recorded there (#1058).
    for (TopExp_Explorer ex(wire, TopAbs_EDGE); ex.More(); ex.Next())
    {
      double f2 = 0, l2 = 0;
      if (BRep_Tool::CurveOnSurface(TopoDS::Edge(ex.Current()), face, f2, l2).IsNull())
        return nullptr;
    }
    Handle(ShapeUpgrade_WireDivide) wd = new ShapeUpgrade_WireDivide();
    // OCCT 8.0.0p1: ShapeUpgrade_WireDivide::Perform() null-derefs its ReShape context when none is
    // set (SIGSEGV, Address 0). ShapeUpgrade_FaceDivide always sets a context before driving its
    // internal WireDivide; mirror that here.
    wd->SetContext(new ShapeBuild_ReShape());
    wd->Init(wire, face);
    wd->Perform();
    TopoDS_Wire resultWire = wd->Wire();
    if (resultWire.IsNull())
      return nullptr;
    return new OCCTShape(resultWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_EdgeDivide ---

bool OCCTShapeUpgradeEdgeDivideCompute(OCCTShapeRef edgeShape,
                                       OCCTShapeRef faceShape,
                                       bool*        outHasCurve2d,
                                       bool*        outHasCurve3d)
{
  if (!edgeShape || !faceShape)
    return false;
  try
  {
    TopoDS_Edge                     edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face                     face = TopoDS::Face(faceShape->shape);
    Handle(ShapeUpgrade_EdgeDivide) ed   = new ShapeUpgrade_EdgeDivide();
    ed->SetFace(face);
    bool computed = ed->Compute(edge);
    if (outHasCurve2d)
      *outHasCurve2d = ed->HasCurve2d();
    if (outHasCurve3d)
      *outHasCurve3d = ed->HasCurve3d();
    return computed;
  }
  catch (...)
  {
    return false;
  }
}

// --- ShapeUpgrade_ClosedEdgeDivide ---

bool OCCTShapeUpgradeClosedEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape)
{
  if (!edgeShape || !faceShape)
    return false;
  try
  {
    TopoDS_Edge                           edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face                           face = TopoDS::Face(faceShape->shape);
    Handle(ShapeUpgrade_ClosedEdgeDivide) ced  = new ShapeUpgrade_ClosedEdgeDivide();
    ced->SetFace(face);
    return ced->Compute(edge);
  }
  catch (...)
  {
    return false;
  }
}

// --- ShapeUpgrade_FixSmallCurves ---

OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallCurves(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    // Use ShapeFix_Wireframe which internally uses FixSmallCurves logic
    // to fix small edges across the entire shape
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    if (faceMap.Extent() == 0)
      return nullptr;

    BRep_Builder    bb;
    TopoDS_Compound result;
    bb.MakeCompound(result);
    bool anyFixed = false;

    for (int i = 1; i <= faceMap.Extent(); i++)
    {
      TopoDS_Face                face = TopoDS::Face(faceMap(i));
      TopTools_IndexedMapOfShape edgeMap;
      TopExp::MapShapes(face, TopAbs_EDGE, edgeMap);
      for (int j = 1; j <= edgeMap.Extent(); j++)
      {
        TopoDS_Edge                         edge = TopoDS::Edge(edgeMap(j));
        Handle(ShapeUpgrade_FixSmallCurves) fsc  = new ShapeUpgrade_FixSmallCurves();
        fsc->SetPrecision(tolerance);
        fsc->Init(edge, face);
        anyFixed = true;
      }
    }
    // Return original shape (fix is in-place via shape healing)
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_FixSmallBezierCurves ---

OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallBezierCurves(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    if (faceMap.Extent() == 0)
      return nullptr;

    for (int i = 1; i <= faceMap.Extent(); i++)
    {
      TopoDS_Face                face = TopoDS::Face(faceMap(i));
      TopTools_IndexedMapOfShape edgeMap;
      TopExp::MapShapes(face, TopAbs_EDGE, edgeMap);
      for (int j = 1; j <= edgeMap.Extent(); j++)
      {
        TopoDS_Edge                               edge = TopoDS::Edge(edgeMap(j));
        Handle(ShapeUpgrade_FixSmallBezierCurves) fsbc = new ShapeUpgrade_FixSmallBezierCurves();
        fsbc->SetPrecision(tolerance);
        fsbc->Init(edge, face);
      }
    }
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_ConvertCurve3dToBezier (shape-level) ---

OCCTShapeRef _Nullable OCCTShapeUpgradeConvertCurves3dToBezier(OCCTShapeRef shape,
                                                               bool         lineMode,
                                                               bool         circleMode,
                                                               bool         conicMode)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeConvertToBezier converter(shape->shape);
    converter.Set3dLineConversion(lineMode ? Standard_True : Standard_False);
    converter.Set3dCircleConversion(circleMode ? Standard_True : Standard_False);
    converter.Set3dConicConversion(conicMode ? Standard_True : Standard_False);
    converter.SetSurfaceSegmentMode(Standard_False); // curves only
    converter.Perform();
    TopoDS_Shape result = converter.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeUpgrade_ConvertSurfaceToBezierBasis (shape-level) ---

OCCTShapeRef _Nullable OCCTShapeUpgradeConvertSurfaceToBezier(OCCTShapeRef shape,
                                                              bool         planeMode,
                                                              bool         revolutionMode,
                                                              bool         extrusionMode,
                                                              bool         bsplineMode)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeConvertToBezier converter(shape->shape);
    converter.SetPlaneMode(planeMode ? Standard_True : Standard_False);
    converter.SetRevolutionMode(revolutionMode ? Standard_True : Standard_False);
    converter.SetExtrusionMode(extrusionMode ? Standard_True : Standard_False);
    converter.SetBSplineMode(bsplineMode ? Standard_True : Standard_False);
    converter.SetSurfaceSegmentMode(Standard_True);
    converter.Perform();
    TopoDS_Shape result = converter.Result();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// ============================================================
// v0.66.0: Full TkG2d Toolkit Coverage
// ============================================================

#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Point.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <Geom2d_VectorWithMagnitude.hxx>
#include <Geom2d_Direction.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <LProp_CurAndInf.hxx>

// MARK: - BRepLib_ValidateEdge (v0.74)
// --- BRepLib_ValidateEdge ---

OCCTValidateEdgeResult OCCTValidateEdge(OCCTEdgeRef _Nonnull edge,
                                        OCCTFaceRef _Nonnull face,
                                        double tolerance)
{
  OCCTValidateEdgeResult result = {};
  if (!edge || !face)
    return result;
  try
  {
    TopoDS_Edge e = TopoDS::Edge(edge->edge);
    TopoDS_Face f = TopoDS::Face(face->face);

    Handle(BRepAdaptor_Curve) curve3d = new BRepAdaptor_Curve(e);

    double               first, last;
    Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(e, f, first, last);
    if (pcurve.IsNull())
      return result;

    Handle(BRepAdaptor_Surface)      brepSurf    = new BRepAdaptor_Surface(f);
    Handle(Geom2dAdaptor_Curve)      gac2d       = new Geom2dAdaptor_Curve(pcurve, first, last);
    Handle(Adaptor3d_CurveOnSurface) curveOnSurf = new Adaptor3d_CurveOnSurface(gac2d, brepSurf);

    BRepLib_ValidateEdge validator(curve3d, curveOnSurf, Standard_True);
    validator.Process();

    result.isDone = validator.IsDone();
    if (result.isDone)
    {
      result.maxDistance       = validator.GetMaxDistance();
      result.tolerance         = tolerance;
      result.isWithinTolerance = validator.CheckTolerance(tolerance);
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - ShapeCustom_BSplineRestriction + ConvertToBSpline (v0.78)
// MARK: - ShapeCustom_BSplineRestriction

// #490: this function and OCCTSplitSurfaceContinuity below used to read their continuity as a
// GeomAbs_Shape ordinal (a local continuityFromInt78 helper: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3,
// 6=CN) while the sibling entry point for the very same OCCT operation read it as a required
// parametric continuity. OCCTShapeCustomBSplineRestriction drives ShapeCustom::BSplineRestriction,
// which is itself just a ShapeCustom_BSplineRestriction run through BRepTools_Modifier, exactly
// what OCCTShapeBSplineRestrictionAdvanced constructs by hand, and OCCTSurfaceSplitByContinuity
// wraps the same ShapeUpgrade_SplitSurfaceContinuity as OCCTSplitSurfaceContinuity. So the same
// integer meant two different continuities in each pair. Both now decode as
// ParametricContinuity, and the ordinal reading is gone: of the seven values it advertised, only
// 0/2/4 ever worked here anyway (measured, ShapeCustom_BSplineRestriction returns a null shape
// for G1, G2, C3 and CN).

OCCTShapeRef _Nullable OCCTShapeBSplineRestrictionAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                           bool   approxSurface,
                                                           bool   approxCurve3d,
                                                           bool   approxCurve2d,
                                                           double tol3d,
                                                           double tol2d,
                                                           int    continuity3d,
                                                           int    continuity2d,
                                                           int    maxDegree,
                                                           int    maxSegments,
                                                           bool   priorityDegree,
                                                           bool   convertRational)
{
  try
  {
    auto&                                  shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
    Handle(ShapeCustom_BSplineRestriction) mod =
      new ShapeCustom_BSplineRestriction(approxSurface,
                                         approxCurve3d,
                                         approxCurve2d,
                                         tol3d,
                                         tol2d,
                                         occtGeomAbsFromParametricContinuity(continuity3d),
                                         occtGeomAbsFromParametricContinuity(continuity2d),
                                         maxDegree,
                                         maxSegments,
                                         priorityDegree,
                                         convertRational);
    BRepTools_Modifier modifier(shape, mod);
    if (!modifier.IsDone())
      return nullptr;
    TopoDS_Shape result = modifier.ModifiedShape(shape);
    if (result.IsNull())
      return nullptr;
    return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeCustom_ConvertToBSpline

OCCTShapeRef _Nullable OCCTShapeConvertToBSplineAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                         bool extrusionMode,
                                                         bool revolutionMode,
                                                         bool offsetMode,
                                                         bool planeMode)
{
  try
  {
    auto&                                shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
    Handle(ShapeCustom_ConvertToBSpline) mod   = new ShapeCustom_ConvertToBSpline();
    mod->SetExtrusionMode(extrusionMode);
    mod->SetRevolutionMode(revolutionMode);
    mod->SetOffsetMode(offsetMode);
    mod->SetPlaneMode(planeMode);
    BRepTools_Modifier modifier(shape, mod);
    if (!modifier.IsDone())
      return nullptr;
    TopoDS_Shape result = modifier.ModifiedShape(shape);
    if (result.IsNull())
      return nullptr;
    return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeUpgrade_SplitSurface Continuity / Angle / Area (v0.78)
// MARK: - ShapeUpgrade_SplitSurfaceContinuity

int OCCTSplitSurfaceContinuity(OCCTSurfaceRef _Nonnull surfaceRef,
                               int    criterion,
                               double tolerance,
                               int* _Nullable outUSplitCount,
                               int* _Nullable outVSplitCount)
{
  try
  {
    auto* wrapper = reinterpret_cast<OCCTSurface*>(surfaceRef);
    if (!wrapper || wrapper->surface.IsNull())
      return 0;
    auto&                                       surface = wrapper->surface;
    Handle(ShapeUpgrade_SplitSurfaceContinuity) splitter =
      new ShapeUpgrade_SplitSurfaceContinuity();
    splitter->Init(surface);
    splitter->SetCriterion(occtGeomAbsFromParametricContinuity(criterion));
    splitter->SetTolerance(tolerance);
    splitter->Perform(true);
    int uCount = splitter->USplitValues()->Length();
    int vCount = splitter->VSplitValues()->Length();
    if (outUSplitCount)
      *outUSplitCount = uCount;
    if (outVSplitCount)
      *outVSplitCount = vCount;
    return uCount;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeUpgrade_SplitSurfaceAngle

int OCCTSplitSurfaceAngle(OCCTSurfaceRef _Nonnull surfaceRef,
                          double maxAngle,
                          int* _Nullable outUSplitCount,
                          int* _Nullable outVSplitCount)
{
  try
  {
    auto* wrapper = reinterpret_cast<OCCTSurface*>(surfaceRef);
    if (!wrapper || wrapper->surface.IsNull())
      return 0;
    auto&                                  surface  = wrapper->surface;
    Handle(ShapeUpgrade_SplitSurfaceAngle) splitter = new ShapeUpgrade_SplitSurfaceAngle(maxAngle);
    splitter->Init(surface);
    splitter->Perform(true);
    int uCount = splitter->USplitValues()->Length();
    int vCount = splitter->VSplitValues()->Length();
    if (outUSplitCount)
      *outUSplitCount = uCount;
    if (outVSplitCount)
      *outVSplitCount = vCount;
    return uCount;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeUpgrade_SplitSurfaceArea

int OCCTSplitSurfaceArea(OCCTSurfaceRef _Nonnull surfaceRef,
                         int  nbParts,
                         bool intoSquares,
                         int* _Nullable outUSplitCount,
                         int* _Nullable outVSplitCount)
{
  try
  {
    auto* wrapper = reinterpret_cast<OCCTSurface*>(surfaceRef);
    if (!wrapper || wrapper->surface.IsNull())
      return 0;
    auto&                                 surface  = wrapper->surface;
    Handle(ShapeUpgrade_SplitSurfaceArea) splitter = new ShapeUpgrade_SplitSurfaceArea();
    splitter->Init(surface);
    splitter->NbParts() = nbParts;
    splitter->SetSplittingIntoSquares(intoSquares);
    splitter->Perform(true);
    int uCount = splitter->USplitValues()->Length();
    int vCount = splitter->VSplitValues()->Length();
    if (outUSplitCount)
      *outUSplitCount = uCount;
    if (outVSplitCount)
      *outVSplitCount = vCount;
    return uCount;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeFix_ComposeShell (v0.79)
// --- ShapeFix_ComposeShell ---
OCCTShapeRef _Nullable OCCTShapeFixComposeShell(OCCTShapeRef _Nonnull faceRef, double precision)
{
  try
  {
    const TopoDS_Shape& shape = *(const TopoDS_Shape*)faceRef;
    TopoDS_Face         face  = TopoDS::Face(shape);

    // Get the surface from the face
    Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
    if (surf.IsNull())
      return nullptr;

    // Create a 1x1 composite surface grid
    Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
      new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
    grid->SetValue(1, 1, surf);

    Handle(ShapeExtend_CompositeSurface) compSurf = new ShapeExtend_CompositeSurface(grid);

    Handle(ShapeFix_ComposeShell) cs = new ShapeFix_ComposeShell();
    // OCCT 8.0.0p1: ShapeFix_ComposeShell::Perform() null-derefs its ReShape context if none is set
    // (SIGSEGV, Address 0). Provide one (the fix-tools that drive it expect a live context).
    cs->SetContext(new ShapeBuild_ReShape());
    cs->Init(compSurf, TopLoc_Location(), face, precision);
    bool ok = cs->Perform();

    if (ok)
    {
      const TopoDS_Shape& result = cs->Result();
      if (!result.IsNull())
        return (OCCTShapeRef) new TopoDS_Shape(result);
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeFix_Solid + EdgeConnect (v0.85)
// MARK: - ShapeFix_Solid

#include <ShapeFix_Solid.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <Precision.hxx>
#include <TopoDS_Iterator.hxx>

// Assemble one result shape from healed bodies: the body itself when there is exactly
// one, a compound when there are several. ShapeFix_Solid::Shape() already returns a
// compound for a multiconnex input, so a compound result is nothing new for callers.
// Declared in OCCTBridge_Internal.h, because the solid-from-shell entry points in
// OCCTBridge_Modeling.mm share it (#443).
TopoDS_Shape occtSolidBodiesToShape(const std::vector<TopoDS_Shape>& bodies)
{
  if (bodies.empty())
    return TopoDS_Shape();
  if (bodies.size() == 1)
    return bodies[0];
  TopoDS_Compound compound;
  BRep_Builder    builder;
  builder.MakeCompound(compound);
  for (const TopoDS_Shape& body : bodies)
    builder.Add(compound, body);
  return compound;
}

// Heal EVERY solid, not just the first one an explorer yields (#442). ShapeFix_Solid
// cannot take a compound. Init/the constructor want a TopoDS_Solid, and TopoDS:Solid
// throws on anything else, so multi-body input has to be driven one solid at a time.
OCCTShapeRef OCCTShapeFixSolid(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    std::vector<TopoDS_Shape> fixed;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More(); exp.Next())
    {
      ShapeFix_Solid fixer(TopoDS::Solid(exp.Current()));
      fixer.Perform();
      TopoDS_Shape result = fixer.Shape();

      // No body may leave by the failure path either: a solid ShapeFix_Solid
      // cannot heal comes back unhealed rather than vanishing from the result,
      // which is the silent drop this function is being fixed for.
      if (result.IsNull())
      {
        fixed.push_back(exp.Current());
        continue;
      }

      // Flatten one level: Shape() hands back a compound when one solid's shells
      // resolve into several bodies, and nesting it would hide them a level down.
      // Its children are taken as they are, usually solids, but Perform() also
      // puts back a shell it could not close, and exploring for TopAbs_SOLID here
      // would drop exactly that. COMPSOLID is not a case: Shape() only ever
      // returns the input solid, one fixed solid, or a compound.
      if (result.ShapeType() == TopAbs_COMPOUND)
      {
        size_t before = fixed.size();
        for (TopoDS_Iterator it(result); it.More(); it.Next())
          fixed.push_back(it.Value());
        if (fixed.size() == before)
          fixed.push_back(exp.Current()); // empty compound
      }
      else
      {
        fixed.push_back(result);
      }
    }
    TopoDS_Shape result = occtSolidBodiesToShape(fixed);
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape();
    ref->shape = result;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// Does `shell` lie inside the solid the classifier was loaded with? `insideState` is the
// caller's once-per-reference reading of which state means "inside" for it (see
// occtBodyBoundingShells).
static bool occtShellIsInsideSolid(const TopoDS_Shell&          shell,
                                   BRepClass3d_SolidClassifier& classifier,
                                   TopAbs_State                 insideState)
{
  TopExp_Explorer ve(shell, TopAbs_VERTEX);
  if (!ve.More())
    return false;
  gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(ve.Current()));
  classifier.Perform(p, Precision::Confusion());
  return classifier.State() == insideState;
}

// Append the body-bounding members of one group of shells to `selected`, in the order
// given. Enclosure parity: a shell bounds a body iff an EVEN number of the others in its
// group enclose it. Nothing here assumes one shell encloses all the rest, which is what both
// simpler rules got wrong: picking a single reference (BRepClass3d::OuterShell or the widest
// box) and calling everything outside it a body double-counts one body's cavity as soon as a
// *different* body is the reference. Parity also reads a body nested inside another body's
// cavity correctly: enclosed twice, so even.
//
// Cost: this is O(N²) classifications in the size of ONE group. Inside a solid N is 1-3 on any
// real input. The free-shell group is not bounded that way (sewing a raw imported mesh can
// yield hundreds of disjoint shells), so the bounding-box pre-filter below is load-bearing
// there, not an optimisation: without it, 200 disjoint shells cost 200 classifier loads and
// ~40,000 ray casts. Measured at N=200, disjoint: 160 ms without the pre-filter, 0.7 ms with.
static void occtSelectBodyShells(const std::vector<TopoDS_Shell>& shells,
                                 std::vector<TopoDS_Shell>&       selected)
{
  if (shells.empty())
    return;
  if (shells.size() == 1)
  {
    selected.push_back(shells[0]);
    return;
  }

  // Enclosure implies bounding-box containment, so a pair whose boxes do not overlap can be
  // skipped before any ray cast, and a reference whose box overlaps nobody's need not be
  // built at all. This only removes pairs that could never have been enclosed, so no parity
  // verdict changes. Note this is NOT the Bnd_Box rule #442 rejected: that failed as the
  // DECISION rule (a box can contain another whose shell does not), which is exactly why it
  // is sound in the opposite direction, as a conservative pre-filter.
  std::vector<Bnd_Box> boxes(shells.size());
  for (size_t k = 0; k < shells.size(); k++)
    BRepBndLib::Add(shells[k], boxes[k]);

  std::vector<int> enclosedBy(shells.size(), 0);
  for (size_t i = 0; i < shells.size(); i++)
  {
    // An open shell cannot enclose anything, and every shell is a reference under
    // parity, so letting one classify would add a spurious ±1 to the others and
    // flip their verdicts. Measured on {A_outer, A_cavity, openShell wrapping both}:
    // without this the outer shell is DROPPED (count 1) and the cavity emitted as a
    // body. BRep_Tool::IsClosed on a shell is a real edge-pairing check rather than
    // the Closed() flag, so a genuine cavity shell still qualifies as a reference.
    // Open shells reach here routinely; this function accepts them by contract.
    //
    // Deliberate trade-off, do not "fix" a double-count back out of this: on a body
    // whose OUTER shell is the open one, the cavity becomes the only eligible
    // reference, both end even, and the cavity is emitted as a positive body. Input
    // that broken has no right answer, and an extra body beats a dropped one for a
    // call whose whole contract is that bodies do not vanish silently.
    if (!BRep_Tool::IsClosed(shells[i]))
      continue;

    // Nothing this shell could possibly enclose: skip before paying for the classifier,
    // whose constructor loads every face of the reference and builds a UB-tree.
    bool anyCandidate = false;
    for (size_t j = 0; j < shells.size() && !anyCandidate; j++)
      if (i != j && !boxes[i].IsOut(boxes[j]))
        anyCandidate = true;
    if (!anyCandidate)
      continue;

    // Reference built directly rather than through ShapeFix_Solid::SolidFromShell:
    // that call does sh.Free(true), a TShape-level write to state shared with the
    // caller's shape, and nothing here needs the reorientation it pays that for.
    TopoDS_Solid reference;
    BRep_Builder builder;
    builder.MakeSolid(reference);
    builder.Add(reference, shells[i]);

    BRepClass3d_SolidClassifier classifier(reference);
    classifier.PerformInfinitePoint(Precision::Confusion());
    // A shell added as-is can bound "everything outside" instead, which flips the
    // sense of every later classification rather than making it wrong.
    const TopAbs_State insideState = (classifier.State() == TopAbs_IN) ? TopAbs_OUT : TopAbs_IN;

    for (size_t j = 0; j < shells.size(); j++)
    {
      if (i == j)
        continue;
      if (boxes[i].IsOut(boxes[j]))
        continue; // cannot be enclosed
      if (occtShellIsInsideSolid(shells[j], classifier, insideState))
        enclosedBy[j]++;
    }
  }
  for (size_t i = 0; i < shells.size(); i++)
    if (enclosedBy[i] % 2 == 0)
      selected.push_back(shells[i]);
}

// The shells that bound a body, in exploration order: every shell an even number of the
// others in its group enclose, where a group is one solid's own shells, or all the shells
// belonging to no solid at all. A cavity shell is left out, because a hole is not a body and
// turning one into a positive solid would give a compound whose volume double-counts the
// part.
// Declared in OCCTBridge_Internal.h, because the solid-from-shell entry points in
// OCCTBridge_Modeling.mm share it (#443).
std::vector<TopoDS_Shell> occtBodyBoundingShells(const TopoDS_Shape& shape)
{
  std::vector<TopoDS_Shell>  selected;
  TopTools_IndexedMapOfShape claimed;

  for (TopExp_Explorer se(shape, TopAbs_SOLID); se.More(); se.Next())
  {
    TopoDS_Solid              solid = TopoDS::Solid(se.Current());
    std::vector<TopoDS_Shell> shells;
    for (TopExp_Explorer sh(solid, TopAbs_SHELL); sh.More(); sh.Next())
    {
      claimed.Add(sh.Current());
      shells.push_back(TopoDS::Shell(sh.Current()));
    }
    // Each solid is its own group: a free shell must not be able to perturb a declared
    // body's cavity verdict, and vice versa.
    occtSelectBodyShells(shells, selected);
  }

  // Free shells form one further group and go through the same parity pass (#443).
  // They used to be added unconditionally, on the grounds that a shell outside any solid
  // has no declared cavity relationship. But sewing DISSOLVES the solid that carried
  // that declaration, and sewing is the ordinary way these calls are reached. Measured on
  // a sewn hollow box: unconditional gives 2 bodies where the same two shells inside a
  // solid give 1, and on {hollow body, body inside its cavity} it gives 3 instead of 2.
  // Containment among free shells is geometric rather than declared, so a closed shell
  // sitting alone inside another is read as that one's cavity: the same reading OCCT's
  // own solid convention would give it, and the only one available without a declaration.
  std::vector<TopoDS_Shell> freeShells;
  for (TopExp_Explorer sh(shape, TopAbs_SHELL); sh.More(); sh.Next())
  {
    // Contains, not Add: IndexedMap::Add returns an index, never a "was new" flag.
    // Without this a compound holding the same free shell twice yields two identical
    // solids.
    if (claimed.Contains(sh.Current()))
      continue;
    claimed.Add(sh.Current());
    freeShells.push_back(TopoDS::Shell(sh.Current()));
  }
  occtSelectBodyShells(freeShells, selected);

  return selected;
}

// One solid per body-bounding shell, not just the first shell an explorer yields (#442).
// Note ShapeFix_Solid::SolidFromShell does sh.Free(true) on each shell it is given, which
// writes a flag on the TShape shared with the caller's shape; that is inherent to the call
// this function exists to make, and is why the enclosure reference above avoids it.
OCCTShapeRef OCCTShapeSolidFromShell(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    std::vector<TopoDS_Shape> made;
    for (const TopoDS_Shell& shell : occtBodyBoundingShells(shape->shape))
    {
      ShapeFix_Solid fixer;
      TopoDS_Solid   solid = fixer.SolidFromShell(shell);
      // SolidFromShell builds its solid before any classification and never returns
      // a null one, so this keeps a body rather than dropping it if that changes.
      made.push_back(solid.IsNull() ? TopoDS_Shape(shell) : TopoDS_Shape(solid));
    }
    TopoDS_Shape result = occtSolidBodiesToShape(made);
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape();
    ref->shape = result;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeFix_EdgeConnect

#include <ShapeFix_EdgeConnect.hxx>

OCCTShapeRef OCCTShapeFixEdgeConnect(OCCTShapeRef shape)
{
  try
  {
    ShapeFix_EdgeConnect connector;
    connector.Add(shape->shape);
    connector.Build();
    // EdgeConnect modifies edges in-place; return the original shape
    auto* ref  = new OCCTShape();
    ref->shape = shape->shape;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeAnalysis_Shell + CanonicalRecognition (v0.85)
// MARK: - ShapeAnalysis_Shell

#include <ShapeAnalysis_Shell.hxx>

OCCTShellAnalysisResult OCCTShapeAnalyzeShell(OCCTShapeRef shape)
{
  OCCTShellAnalysisResult result = {false, false, false, false, 0};
  if (!shape)
    return result;
  try
  {
    // Shared with OCCTShapeAnalyze's per-shell loop above; see its comment for why (#717).
    OCCTShellOrientationScan scan = occtAnalyzeShellOrientation(shape->shape);
    result.hasOrientationProblems = scan.checkResult; // true if BAD orientation found
    result.hasFreeEdges           = scan.hasFreeEdges;
    result.hasBadEdges            = scan.hasBadEdges;
    result.hasConnectedEdges      = scan.hasConnectedEdges;
    result.freeEdgeCount          = scan.freeEdgeCount;
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - ShapeAnalysis_CanonicalRecognition

#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Lin.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>

OCCTCanonicalResult OCCTShapeRecognizeCanonicalSurface(OCCTShapeRef faceShape, double tolerance)
{
  OCCTCanonicalResult result = {};
  try
  {
    ShapeAnalysis_CanonicalRecognition recog(faceShape->shape);

    gp_Pln pln;
    if (recog.IsPlane(tolerance, pln))
    {
      result.type    = OCCTCanonicalTypePlane;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = pln.Location();
      gp_Dir dir     = pln.Axis().Direction();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.dirX    = dir.X();
      result.dirY    = dir.Y();
      result.dirZ    = dir.Z();
      return result;
    }

    gp_Cylinder cyl;
    if (recog.IsCylinder(tolerance, cyl))
    {
      result.type    = OCCTCanonicalTypeCylinder;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = cyl.Location();
      gp_Dir dir     = cyl.Axis().Direction();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.dirX    = dir.X();
      result.dirY    = dir.Y();
      result.dirZ    = dir.Z();
      result.param1  = cyl.Radius();
      return result;
    }

    gp_Cone cone;
    if (recog.IsCone(tolerance, cone))
    {
      result.type    = OCCTCanonicalTypeCone;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = cone.Location();
      gp_Dir dir     = cone.Axis().Direction();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.dirX    = dir.X();
      result.dirY    = dir.Y();
      result.dirZ    = dir.Z();
      result.param1  = cone.RefRadius();
      result.param2  = cone.SemiAngle();
      return result;
    }

    gp_Sphere sph;
    if (recog.IsSphere(tolerance, sph))
    {
      result.type    = OCCTCanonicalTypeSphere;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = sph.Location();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.param1  = sph.Radius();
      return result;
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTCanonicalResult OCCTShapeRecognizeCanonicalCurve(OCCTShapeRef edgeShape, double tolerance)
{
  OCCTCanonicalResult result = {};
  try
  {
    ShapeAnalysis_CanonicalRecognition recog(edgeShape->shape);

    gp_Lin lin;
    if (recog.IsLine(tolerance, lin))
    {
      result.type    = OCCTCanonicalTypeLine;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = lin.Location();
      gp_Dir dir     = lin.Direction();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.dirX    = dir.X();
      result.dirY    = dir.Y();
      result.dirZ    = dir.Z();
      return result;
    }

    gp_Circ circ;
    if (recog.IsCircle(tolerance, circ))
    {
      result.type    = OCCTCanonicalTypeCircle;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = circ.Location();
      gp_Dir dir     = circ.Axis().Direction();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.dirX    = dir.X();
      result.dirY    = dir.Y();
      result.dirZ    = dir.Z();
      result.param1  = circ.Radius();
      return result;
    }

    gp_Elips elips;
    if (recog.IsEllipse(tolerance, elips))
    {
      result.type    = OCCTCanonicalTypeEllipse;
      result.gap     = recog.GetGap();
      gp_Pnt loc     = elips.Location();
      gp_Dir dir     = elips.Axis().Direction();
      result.originX = loc.X();
      result.originY = loc.Y();
      result.originZ = loc.Z();
      result.dirX    = dir.X();
      result.dirY    = dir.Y();
      result.dirZ    = dir.Z();
      result.param1  = elips.MajorRadius();
      result.param2  = elips.MinorRadius();
      return result;
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - v0.93: ShapeFix_EdgeProjAux + BRepAlgo_FaceRestrictor
// MARK: - ShapeFix_EdgeProjAux (v0.93.0)

#include <ShapeFix_EdgeProjAux.hxx>

bool OCCTShapeFixEdgeProjAux(OCCTShapeRef shape,
                             int32_t      faceIndex,
                             int32_t      edgeIndex,
                             double       precision,
                             double*      outFirst,
                             double*      outLast)
{
  if (!shape)
    return false;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return false;

    // The edge index is into the face's own edge enumeration, read the same way.
    TopoDS_Edge edge = occtEdgeAt(face, edgeIndex);
    if (edge.IsNull())
      return false;

    Handle(ShapeFix_EdgeProjAux) aux = new ShapeFix_EdgeProjAux(face, edge);
    aux->Compute(precision);

    if (aux->IsFirstDone())
      *outFirst = aux->FirstParam();
    else
      *outFirst = 0;
    if (aux->IsLastDone())
      *outLast = aux->LastParam();
    else
      *outLast = 0;
    return aux->IsFirstDone() && aux->IsLastDone();
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - BRepAlgo_FaceRestrictor (v0.93.0)

#include <BRepAlgo_FaceRestrictor.hxx>

int32_t OCCTShapeFaceRestrictAlgo(OCCTShapeRef  shape,
                                  int32_t       faceIndex,
                                  OCCTShapeRef* outFaces,
                                  int32_t       maxFaces)
{
  if (!shape)
    return -1;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return -1;

    BRepAlgo_FaceRestrictor restrictor;
    restrictor.Init(face, false, true);

    TopExp_Explorer wireExp(face, TopAbs_WIRE);
    for (; wireExp.More(); wireExp.Next())
    {
      TopoDS_Wire w = TopoDS::Wire(wireExp.Current());
      restrictor.Add(w);
    }

    restrictor.Perform();
    if (!restrictor.IsDone())
      return -1;

    int count = 0;
    for (; restrictor.More() && count < maxFaces; restrictor.Next())
    {
      if (outFaces)
      {
        OCCTShape* result = new OCCTShape();
        result->shape     = restrictor.Current();
        outFaces[count]   = result;
      }
      count++;
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

// MARK: - v0.95: ShapeFix_IntersectionTool
// MARK: - ShapeFix_IntersectionTool (v0.95.0)

#include <ShapeFix_IntersectionTool.hxx>
#include <ShapeBuild_ReShape.hxx>

bool OCCTShapeFixIntersectingWires(OCCTShapeRef shape, int32_t faceIndex, double precision)
{
  if (!shape)
    return false;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return false;

    Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
    ShapeFix_IntersectionTool  tool(ctx, precision, 1.0);
    return tool.FixIntersectingWires(face);
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.99: ShapeFix_Wireframe Extensions
// MARK: - ShapeFix_Wireframe Extensions (v0.99.0)

OCCTShapeRef OCCTShapeFixWireGaps(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
    fixer->SetPrecision(tolerance);
    fixer->FixWireGaps();
    TopoDS_Shape result = fixer->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFixSmallEdges(OCCTShapeRef shape,
                                    double       tolerance,
                                    bool         dropSmall,
                                    double       limitAngle)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
    fixer->SetPrecision(tolerance);
    fixer->ModeDropSmallEdges() = dropSmall ? Standard_True : Standard_False;
    if (limitAngle >= 0.0)
      fixer->SetLimitAngle(limitAngle);
    fixer->FixSmallEdges();
    TopoDS_Shape result = fixer->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.100: ShapeAnalysis_FreeBounds simplified API
// --- ShapeAnalysis_FreeBounds simplified API ---

int32_t OCCTShapeFreeBoundsClosedCount(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_FreeBounds analyzer(shape->shape, tolerance);
    TopoDS_Compound          closed = analyzer.GetClosedWires();
    if (closed.IsNull())
      return 0;
    int32_t count = 0;
    for (TopExp_Explorer ex(closed, TopAbs_WIRE); ex.More(); ex.Next())
    {
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTShapeFreeBoundsClosed(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeAnalysis_FreeBounds analyzer(shape->shape, tolerance);
    TopoDS_Compound          closed = analyzer.GetClosedWires();
    if (closed.IsNull())
      return nullptr;
    return new OCCTShape(closed);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFreeBoundsOpen(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeAnalysis_FreeBounds analyzer(shape->shape, tolerance);
    TopoDS_Compound          open = analyzer.GetOpenWires();
    if (open.IsNull())
      return nullptr;
    return new OCCTShape(open);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.106: ShapeAnalysis_Wire + ShapeAnalysis_Edge
// MARK: - ShapeAnalysis_Wire (v0.106.0)

#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>
#include <BRep_Tool.hxx>

bool OCCTWireCheckOrder(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckOrder();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckConnected(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckConnected();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckSmall(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckSmall();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckDegenerated(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckDegenerated();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckClosed(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckSelfIntersection(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckSelfIntersection();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckGaps3d(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckGaps3d();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckGaps2d(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckGaps2d();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckEdgeCurves(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckEdgeCurves();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckLacking(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckLacking();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTWireEdgeCount(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return 0;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return 0;
    return saw.NbEdges();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTWireMinDistance3d(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return 0;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return 0;
    saw.CheckGaps3d();
    return saw.MinDistance3d();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTWireMaxDistance3d(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return 0;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return 0;
    saw.CheckGaps3d();
    return saw.MaxDistance3d();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTWireMinDistance2d(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return 0;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return 0;
    saw.CheckGaps2d();
    return saw.MinDistance2d();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTWireMaxDistance2d(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!wire || !face)
    return 0;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return 0;
    saw.CheckGaps2d();
    return saw.MaxDistance2d();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTWireCheckConnectedEdge(OCCTShapeRef wire,
                                OCCTShapeRef face,
                                double       prec,
                                int32_t      edgeIndex)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckConnected(edgeIndex);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckSmallEdge(OCCTShapeRef wire, OCCTShapeRef face, double prec, int32_t edgeIndex)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckSmall(edgeIndex);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckDegeneratedEdge(OCCTShapeRef wire,
                                  OCCTShapeRef face,
                                  double       prec,
                                  int32_t      edgeIndex)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckDegenerated(edgeIndex);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireCheckGap3dEdge(OCCTShapeRef wire, OCCTShapeRef face, double prec, int32_t edgeIndex)
{
  if (!wire || !face)
    return false;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
    if (!saw.IsReady())
      return false;
    return saw.CheckGap3d(edgeIndex);
  }
  catch (...)
  {
    return false;
  }
}

// #999: this took a `prec` and never called ShapeAnalysis_Wire at all. It ran a TopExp_Explorer
// and answered "does this face have any wire", which is true of every valid face, so it was
// neither the check its name promises nor a use of the precision it declared. It is now the real
// call, and takes the wire its siblings all take. CheckOuterBound consults no precision, so it
// declares none; see the header for the measurement.
// #1058: the return is tri-state, because `false` used to be both the verdict for a wire that IS
// the outer bound and the answer from every path that could not run the check. See the header for
// the encoding and for what the pcurve guard below is protecting against.
// #1073: added magnitude threshold against face UV scale and full pcurve coverage check.
int32_t OCCTWireCheckOuterBound(OCCTShapeRef wire, OCCTShapeRef face)
{
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
    return -1;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), Precision::Confusion());
    if (!saw.IsReady())
      return -1;
    TopoDS_Wire aBuilt = saw.WireData()->WireAPIMake();
    if (aBuilt.IsNull())
      return -1;
    TopoDS_Shape anEmpty = TopoDS::Face(face->shape).EmptyCopied();
    TopoDS_Face  aProbe  = TopoDS::Face(anEmpty);
    BRep_Builder aBuilder;
    aBuilder.Add(aProbe, aBuilt);

    // Count total edges and edges with pcurves on the face
    int totalEdges      = 0;
    int edgesWithPCurve = 0;
    for (TopExp_Explorer anIt(aProbe, TopAbs_EDGE); anIt.More(); anIt.Next())
    {
      totalEdges++;
      double aFirst, aLast;
      if (!BRep_Tool::CurveOnSurface(TopoDS::Edge(anIt.Current()), aProbe, aFirst, aLast).IsNull())
        edgesWithPCurve++;
    }
    // Refuse if not all edges have pcurves (partial pcurve set)
    if (totalEdges == 0 || edgesWithPCurve != totalEdges)
      return -1;

    // Compute signed area via TotCross2D
    occ::handle<ShapeExtend_WireData> sewd     = new ShapeExtend_WireData(aBuilt);
    double                            totcross = ShapeAnalysis::TotCross2D(sewd, aProbe);

    // Get face UV bounds for scale reference
    double umin, umax, vmin, vmax;
    ShapeAnalysis::GetFaceUVBounds(aProbe, umin, umax, vmin, vmax);
    double uRange = umax - umin;
    double vRange = vmax - vmin;
    double uvArea = uRange * vRange;

    // If UV area is degenerate, refuse
    if (uvArea <= 0.0)
      return -1;

    // Threshold: 1e-12 of UV area. The cancellation case measures ~1.8e-15
    // against a 100 unit^2 panel, so 1e-12 * 100 = 1e-10 comfortably separates.
    double threshold = 1e-12 * uvArea;
    if (std::abs(totcross) < threshold)
      return -1;

    // Use OCCT's CheckOuterBound for the actual verdict (handles orientation correctly)
    return saw.CheckOuterBound() ? 1 : 0;
  }
  catch (...)
  {
    return -1;
  }
}

// MARK: - ShapeAnalysis_Edge (v0.106.0)

#include <ShapeAnalysis_Edge.hxx>

bool OCCTEdgeHasCurve3dSA(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.HasCurve3d(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeIsClosed3dSA(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.IsClosed3d(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeHasPCurveSA(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.HasPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeIsSeamSA(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.IsSeam(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCheckSameParameter(OCCTShapeRef edge, double* maxdev)
{
  if (!edge)
  {
    *maxdev = 0;
    return false;
  }
  try
  {
    ShapeAnalysis_Edge sae;
    *maxdev = 0;
    return sae.CheckSameParameter(TopoDS::Edge(edge->shape), *maxdev);
  }
  catch (...)
  {
    *maxdev = 0;
    return false;
  }
}

bool OCCTEdgeCheckVerticesWithCurve3d(OCCTShapeRef edge, double prec)
{
  if (!edge)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.CheckVerticesWithCurve3d(TopoDS::Edge(edge->shape), prec);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCheckVerticesWithPCurve(OCCTShapeRef edge, OCCTShapeRef face, double prec)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.CheckVerticesWithPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), prec);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCheckCurve3dWithPCurve(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.CheckCurve3dWithPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return false;
  }
}

void OCCTEdgeFirstVertexSA(OCCTShapeRef edge, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!edge)
    return;
  try
  {
    ShapeAnalysis_Edge sae;
    TopoDS_Vertex      v = sae.FirstVertex(TopoDS::Edge(edge->shape));
    if (v.IsNull())
      return;
    gp_Pnt p = BRep_Tool::Pnt(v);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTEdgeLastVertexSA(OCCTShapeRef edge, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!edge)
    return;
  try
  {
    ShapeAnalysis_Edge sae;
    TopoDS_Vertex      v = sae.LastVertex(TopoDS::Edge(edge->shape));
    if (v.IsNull())
      return;
    gp_Pnt p = BRep_Tool::Pnt(v);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
  }
}

bool OCCTEdgeCheckVertexTolerance(OCCTShapeRef edge,
                                  OCCTShapeRef face,
                                  double*      toler1,
                                  double*      toler2)
{
  *toler1 = 0;
  *toler2 = 0;
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.CheckVertexTolerance(TopoDS::Edge(edge->shape),
                                    TopoDS::Face(face->shape),
                                    *toler1,
                                    *toler2);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCheckOverlapping(OCCTShapeRef edge1, OCCTShapeRef edge2, double* tolOverlap)
{
  *tolOverlap = 0;
  if (!edge1 || !edge2)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    return sae.CheckOverlapping(TopoDS::Edge(edge1->shape),
                                TopoDS::Edge(edge2->shape),
                                *tolOverlap,
                                0.0);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeBoundUV(OCCTShapeRef edge,
                     OCCTShapeRef face,
                     double*      uFirst,
                     double*      vFirst,
                     double*      uLast,
                     double*      vLast)
{
  *uFirst = 0;
  *vFirst = 0;
  *uLast  = 0;
  *vLast  = 0;
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    gp_Pnt2d           pFirst, pLast;
    bool ok = sae.BoundUV(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), pFirst, pLast);
    if (ok)
    {
      *uFirst = pFirst.X();
      *vFirst = pFirst.Y();
      *uLast  = pLast.X();
      *vLast  = pLast.Y();
    }
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetEndTangent2d(OCCTShapeRef edge,
                             OCCTShapeRef face,
                             bool         atEnd,
                             double*      px,
                             double*      py,
                             double*      tx,
                             double*      ty)
{
  *px = 0;
  *py = 0;
  *tx = 0;
  *ty = 0;
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    gp_Pnt2d           pos;
    gp_Vec2d           tang;
    bool               ok =
      sae.GetEndTangent2d(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), atEnd, pos, tang);
    if (ok)
    {
      *px = pos.X();
      *py = pos.Y();
      *tx = tang.X();
      *ty = tang.Y();
    }
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCheckPCurveRange(OCCTShapeRef edge, OCCTShapeRef face, double first, double last)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeAnalysis_Edge sae;
    // Check if the pcurve parameter range [first, last] is valid for the edge on the face
    // Get pcurve and check its range
    TopoDS_Edge          e = TopoDS::Edge(edge->shape);
    TopoDS_Face          f = TopoDS::Face(face->shape);
    double               cf, cl;
    Handle(Geom2d_Curve) pc = BRep_Tool::CurveOnSurface(e, f, cf, cl);
    if (pc.IsNull())
      return false;
    return (first >= cf - 1e-10 && last <= cl + 1e-10);
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.112: BRepCheck extended + tolerance helpers
// --- BRepCheck extended ---

int32_t OCCTCheckFaceStatus(OCCTShapeRef shape, OCCTShapeRef face)
{
  if (!shape || !face)
    return -1;
  try
  {
    BRepCheck_Analyzer       ana(shape->shape, Standard_True);
    Handle(BRepCheck_Result) res = ana.Result(face->shape);
    if (res.IsNull())
      return -1;
    const BRepCheck_ListOfStatus& st = res->Status();
    if (st.IsEmpty())
      return 0; // NoError
    return (int32_t)st.First();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTCheckEdgeStatus(OCCTShapeRef shape, OCCTShapeRef edge)
{
  if (!shape || !edge)
    return -1;
  try
  {
    BRepCheck_Analyzer       ana(shape->shape, Standard_True);
    Handle(BRepCheck_Result) res = ana.Result(edge->shape);
    if (res.IsNull())
      return -1;
    const BRepCheck_ListOfStatus& st = res->Status();
    if (st.IsEmpty())
      return 0;
    return (int32_t)st.First();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTCheckVertexStatus(OCCTShapeRef shape, OCCTShapeRef vertex)
{
  if (!shape || !vertex)
    return -1;
  try
  {
    BRepCheck_Analyzer       ana(shape->shape, Standard_True);
    Handle(BRepCheck_Result) res = ana.Result(vertex->shape);
    if (res.IsNull())
      return -1;
    const BRepCheck_ListOfStatus& st = res->Status();
    if (st.IsEmpty())
      return 0;
    return (int32_t)st.First();
  }
  catch (...)
  {
    return -1;
  }
}

double OCCTShapeMaxTolerance(OCCTShapeRef shape, int32_t type)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    TopAbs_ShapeEnum             se;
    switch (type)
    {
      case 0:
        se = TopAbs_VERTEX;
        break;
      case 1:
        se = TopAbs_EDGE;
        break;
      case 2:
        se = TopAbs_FACE;
        break;
      default:
        se = TopAbs_SHAPE;
        break;
    }
    return sat.Tolerance(shape->shape, 1, se); // 1 = max
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeMinTolerance(OCCTShapeRef shape, int32_t type)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    TopAbs_ShapeEnum             se;
    switch (type)
    {
      case 0:
        se = TopAbs_VERTEX;
        break;
      case 1:
        se = TopAbs_EDGE;
        break;
      case 2:
        se = TopAbs_FACE;
        break;
      default:
        se = TopAbs_SHAPE;
        break;
    }
    return sat.Tolerance(shape->shape, -1, se); // -1 = min
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeAvgTolerance(OCCTShapeRef shape, int32_t type)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    TopAbs_ShapeEnum             se;
    switch (type)
    {
      case 0:
        se = TopAbs_VERTEX;
        break;
      case 1:
        se = TopAbs_EDGE;
        break;
      case 2:
        se = TopAbs_FACE;
        break;
      default:
        se = TopAbs_SHAPE;
        break;
    }
    return sat.Tolerance(shape->shape, 0, se); // 0 = avg
  }
  catch (...)
  {
    return 0;
  }
}

// #833: ShapeAnalysis_ShapeTolerance::Tolerance's own `type` parameter already accepts a real
// TopAbs_ShapeEnum directly (ShapeAnalysis_ShapeTolerance.hxx documents VERTEX/EDGE/FACE/SHELL/
// SHAPE), so these three pass the caller's ordinal straight through instead of remapping it
// through the compressed 0/1/2 switch the three functions above use -- the same straight-cast
// convention OCCTBRepToolMaxTolerance (BRep_Tool::MaxTolerance) already uses, so a caller that
// standardizes on ShapeType/TopAbs_ShapeEnum ordinals gets the same answer from every tolerance
// entry point in this bridge.
static bool occtShapeToleranceOfTypeGuard(int32_t shapeType)
{
  return shapeType >= TopAbs_COMPOUND && shapeType <= TopAbs_SHAPE;
}

// Shared by OCCTShapeMaxToleranceOfType/MinToleranceOfType/AvgToleranceOfType below (PR #870
// aggregate review): the three differed only in the hardcoded `mode` literal (1/-1/0) passed to
// ShapeAnalysis_ShapeTolerance::Tolerance, otherwise triplicating the identical
// construct/guard/try-catch/call body, mirrors the `occtShapeToleranceOfTypeGuard` extraction
// just above for the same reason: a future change to this shared logic (tightening the exception
// handling, migrating off ShapeAnalysis_ShapeTolerance) now has one body to update instead of
// three near-identical copies that can silently drift apart.
static double occtShapeToleranceOfType(OCCTShapeRef shape, int32_t shapeType, int mode)
{
  if (!shape || !occtShapeToleranceOfTypeGuard(shapeType))
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    return sat.Tolerance(shape->shape, mode, (TopAbs_ShapeEnum)shapeType);
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeMaxToleranceOfType(OCCTShapeRef shape, int32_t shapeType)
{
  return occtShapeToleranceOfType(shape, shapeType, 1); // 1 = max
}

double OCCTShapeMinToleranceOfType(OCCTShapeRef shape, int32_t shapeType)
{
  return occtShapeToleranceOfType(shape, shapeType, -1); // -1 = min
}

double OCCTShapeAvgToleranceOfType(OCCTShapeRef shape, int32_t shapeType)
{
  return occtShapeToleranceOfType(shape, shapeType, 0); // 0 = avg
}

bool OCCTShapeFixTolerance(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return false;
  try
  {
    ShapeFix_ShapeTolerance sft;
    sft.SetTolerance(shape->shape, tolerance);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeLimitMaxTolerance(OCCTShapeRef shape, double maxTol)
{
  if (!shape)
    return false;
  try
  {
    ShapeFix_ShapeTolerance sft;
    bool                    limited = sft.LimitTolerance(shape->shape, 0.0, maxTol);
    return limited;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.113: ShapeFix_Wire + ShapeFix_Face individual fixes
// --- ShapeFix_Wire individual fixes ---

struct OCCTWireFixer
{
  Handle(ShapeFix_Wire) fixer;
};

OCCTWireFixerRef OCCTWireFixerCreate(OCCTShapeRef wire, OCCTShapeRef face, double precision)
{
  if (!wire || !face)
    return nullptr;
  try
  {
    auto ref   = new OCCTWireFixer();
    ref->fixer = new ShapeFix_Wire();
    ref->fixer->Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), precision);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTWireFixerRelease(OCCTWireFixerRef fixer)
{
  delete fixer;
}

bool OCCTWireFixerFixReorder(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixReorder();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixConnected(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixConnected();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixSmall(OCCTWireFixerRef fixer, double precSmall)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixSmall(false, precSmall);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixDegenerated(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixDegenerated();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixSelfIntersection(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixSelfIntersection();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixLacking(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixLacking();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixClosed(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixGaps3d(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixGaps3d();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixEdgeCurves(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixEdgeCurves();
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTWireFixerWire(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return nullptr;
  try
  {
    TopoDS_Wire w = fixer->fixer->Wire();
    if (w.IsNull())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = w;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeFix_Face individual fixes ---

struct OCCTFaceFixer
{
  Handle(ShapeFix_Face) fixer;
};

OCCTFaceFixerRef OCCTFaceFixerCreate(OCCTShapeRef face, double precision)
{
  if (!face)
    return nullptr;
  try
  {
    auto ref   = new OCCTFaceFixer();
    ref->fixer = new ShapeFix_Face(TopoDS::Face(face->shape));
    // #317: a null Context() makes ShapeFix_Face::FixPeriodicDegenerated() (invoked from
    // Perform() on a periodic conical single-wire boundary) SIGSEGV on an unguarded
    // Context()->Replace(...) at its last line. Give it a context up front.
    ref->fixer->SetContext(new ShapeBuild_ReShape);
    ref->fixer->SetPrecision(precision);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTFaceFixerRelease(OCCTFaceFixerRef fixer)
{
  delete fixer;
}

bool OCCTFaceFixerPerform(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->Perform();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixOrientation(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixOrientation();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixAddNaturalBound(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixAddNaturalBound();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixMissingSeam(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixMissingSeam();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixSmallAreaWire(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixSmallAreaWire(true);
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTFaceFixerFace(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return nullptr;
  try
  {
    TopoDS_Face f = fixer->fixer->Face();
    if (f.IsNull())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = f;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ShapeFix_Face control surface (#266 follow-up) ---

void OCCTFaceFixerSetMode(OCCTFaceFixerRef fixer, int32_t modeId, int32_t value)
{
  if (!fixer || fixer->fixer.IsNull())
    return;
  try
  {
    ShapeFix_Face& f = *fixer->fixer;
    switch (modeId)
    {
      case 0:
        f.FixWireMode() = value;
        break;
      case 1:
        f.FixOrientationMode() = value;
        break;
      case 2:
        f.FixAddNaturalBoundMode() = value;
        break;
      case 3:
        f.FixMissingSeamMode() = value;
        break;
      case 4:
        f.FixSmallAreaWireMode() = value;
        break;
      case 5:
        f.RemoveSmallAreaFaceMode() = value;
        break;
      case 6:
        f.FixIntersectingWiresMode() = value;
        break;
      case 7:
        f.FixLoopWiresMode() = value;
        break;
      case 8:
        f.FixSplitFaceMode() = value;
        break;
      case 9:
        f.AutoCorrectPrecisionMode() = value;
        break;
      case 10:
        f.FixPeriodicDegeneratedMode() = value;
        break;
      default:
        break;
    }
  }
  catch (...)
  {
  }
}

bool OCCTFaceFixerFixIntersectingWires(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixIntersectingWires();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixPeriodicDegenerated(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixPeriodicDegenerated();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixWiresTwoCoincEdges(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixWiresTwoCoincEdges();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceFixerFixLoopWire(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    NCollection_Sequence<TopoDS_Shape> resWires;
    return fixer->fixer->FixLoopWire(resWires);
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTFaceFixerResult(OCCTFaceFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return nullptr;
  try
  {
    TopoDS_Shape s = fixer->fixer->Result();
    if (s.IsNull())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = s;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTFaceFixerStatus(OCCTFaceFixerRef fixer, int32_t status)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->Status(static_cast<ShapeExtend_Status>(status));
  }
  catch (...)
  {
    return false;
  }
}

void OCCTFaceFixerSetMaxTolerance(OCCTFaceFixerRef fixer, double maxTolerance)
{
  if (!fixer || fixer->fixer.IsNull())
    return;
  try
  {
    fixer->fixer->SetMaxTolerance(maxTolerance);
  }
  catch (...)
  {
  }
}

void OCCTFaceFixerSetMinTolerance(OCCTFaceFixerRef fixer, double minTolerance)
{
  if (!fixer || fixer->fixer.IsNull())
    return;
  try
  {
    fixer->fixer->SetMinTolerance(minTolerance);
  }
  catch (...)
  {
  }
}

// MARK: - WireFixer extended (hoisted with struct)
// --- WireFixer extended ---

bool OCCTWireFixerFixGaps2d(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixGaps2d();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixSeam(OCCTWireFixerRef fixer, int32_t edgeIndex)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixSeam(edgeIndex);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixShifted(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixShifted();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixNotchedEdges(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixNotchedEdges();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireFixerFixTails(OCCTWireFixerRef fixer)
{
  if (!fixer || fixer->fixer.IsNull())
    return false;
  try
  {
    return fixer->fixer->FixTails();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTWireFixerSetMaxTailAngle(OCCTWireFixerRef fixer, double angle)
{
  if (!fixer || fixer->fixer.IsNull())
    return;
  try
  {
    fixer->fixer->SetMaxTailAngle(angle);
  }
  catch (...)
  {
  }
}

void OCCTWireFixerSetMaxTailWidth(OCCTWireFixerRef fixer, double width)
{
  if (!fixer || fixer->fixer.IsNull())
    return;
  try
  {
    fixer->fixer->SetMaxTailWidth(width);
  }
  catch (...)
  {
  }
}

// MARK: - v0.114: ShapeAnalysis_ShapeContents expanded + ShapeAnalysis_FreeBoundsProperties
// (handle-based)
// --- ShapeAnalysis_ShapeContents expanded ---

OCCTShapeContentsExtended OCCTShapeGetContentsExtended(OCCTShapeRef shape)
{
  OCCTShapeContentsExtended result = {};
  if (!shape)
    return result;
  try
  {
    ShapeAnalysis_ShapeContents sc;
    sc.Perform(shape->shape);
    result.nbSolids           = sc.NbSolids();
    result.nbShells           = sc.NbShells();
    result.nbFaces            = sc.NbFaces();
    result.nbWires            = sc.NbWires();
    result.nbEdges            = sc.NbEdges();
    result.nbVertices         = sc.NbVertices();
    result.nbFreeEdges        = sc.NbFreeEdges();
    result.nbFreeWires        = sc.NbFreeWires();
    result.nbFreeFaces        = sc.NbFreeFaces();
    result.nbSolidsWithVoids  = sc.NbSolidsWithVoids();
    result.nbBigSplines       = sc.NbBigSplines();
    result.nbC0Surfaces       = sc.NbC0Surfaces();
    result.nbC0Curves         = sc.NbC0Curves();
    result.nbOffsetSurf       = sc.NbOffsetSurf();
    result.nbIndirectSurf     = sc.NbIndirectSurf();
    result.nbOffsetCurves     = sc.NbOffsetCurves();
    result.nbTrimmedCurve2d   = sc.NbTrimmedCurve2d();
    result.nbTrimmedCurve3d   = sc.NbTrimmedCurve3d();
    result.nbBSplineSurf      = sc.NbBSplibeSurf();
    result.nbBezierSurf       = sc.NbBezierSurf();
    result.nbTrimSurf         = sc.NbTrimSurf();
    result.nbWireWithSeam     = sc.NbWireWitnSeam();
    result.nbWireWithSevSeams = sc.NbWireWithSevSeams();
    result.nbFaceWithSevWires = sc.NbFaceWithSevWires();
    result.nbNoPCurve         = sc.NbNoPCurve();
    result.nbSharedSolids     = sc.NbSharedSolids();
    result.nbSharedShells     = sc.NbSharedShells();
    result.nbSharedFaces      = sc.NbSharedFaces();
    result.nbSharedWires      = sc.NbSharedWires();
    result.nbSharedEdges      = sc.NbSharedEdges();
    result.nbSharedVertices   = sc.NbSharedVertices();
  }
  catch (...)
  {
  }
  return result;
}

// --- ShapeAnalysis_FreeBoundsProperties ---
//
// The one wrapping of this class since #504. See OCCTBridge.h for the contract; the two things
// that shape this code are both OCCT behaviours measured against the pinned kernel:
//
//   Perform() appends to myClosedFreeBounds/myOpenFreeBounds and never clears them, and Init()
//   does not clear them either; only the constructors allocate them. So a second Perform() on
//   one instance doubles every count, a third triples it. `performed` therefore latches, and
//   nothing here calls Perform() again.
//
//   Perform() itself returns DispatchBounds() | CheckNotches() | CheckContours(), and
//   CheckNotches() returns true unconditionally, so it is true even for a shape with no free
//   bounds at all, and even for one that was never loaded, contradicting its own documented
//   "False if fail or no free bounds are found". IsLoaded() is the real signal, so that is what
//   is checked here.

struct OCCTFreeBoundsProps
{
  ShapeAnalysis_FreeBoundsProperties fbp;
  bool                               performed;
};

// Run the analysis once. Returns whether results can be read.
static bool occtFreeBoundsPerformed(OCCTFreeBoundsPropsRef props)
{
  if (!props)
    return false;
  if (props->performed)
    return true;
  try
  {
    if (!props->fbp.IsLoaded())
      return false;
    props->fbp.Perform();
    props->performed = true;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// Resolve a 0-based index within one of the two sequences, range-checked here rather than left
// to NCollection_Sequence::Value's own throw: that check is compiled into this TU, so it does
// fire, but it costs an exception per out-of-range read and cannot distinguish "no such bound"
// from a genuine OCCT failure.
static Handle(ShapeAnalysis_FreeBoundData) occtFreeBound(OCCTFreeBoundsPropsRef props,
                                                         OCCTFreeBoundKind      kind,
                                                         int32_t                index)
{
  if (!occtFreeBoundsPerformed(props) || index < 0)
    return nullptr;
  const bool closed = (kind == OCCTFreeBoundClosed);
  try
  {
    if (index >= (closed ? props->fbp.NbClosedFreeBounds() : props->fbp.NbOpenFreeBounds()))
      return nullptr;
    return closed ? props->fbp.ClosedFreeBound(index + 1) : props->fbp.OpenFreeBound(index + 1);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTFreeBoundsPropsRef OCCTFreeBoundsPropsCreate(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    auto ref = new OCCTFreeBoundsProps();
    ref->fbp.Init(shape->shape, tolerance);
    ref->performed = false;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTFreeBoundsPropsRelease(OCCTFreeBoundsPropsRef props)
{
  delete props;
}

bool OCCTFreeBoundsPropsPerform(OCCTFreeBoundsPropsRef props)
{
  return occtFreeBoundsPerformed(props);
}

OCCTFreeBoundsResult OCCTFreeBoundsPropsCounts(OCCTFreeBoundsPropsRef props)
{
  OCCTFreeBoundsResult result = {};
  if (!occtFreeBoundsPerformed(props))
    return result;
  try
  {
    result.totalFreeBounds  = (int32_t)props->fbp.NbFreeBounds();
    result.closedFreeBounds = (int32_t)props->fbp.NbClosedFreeBounds();
    result.openFreeBounds   = (int32_t)props->fbp.NbOpenFreeBounds();
  }
  catch (...)
  {
    return OCCTFreeBoundsResult{};
  }
  return result;
}

bool OCCTFreeBoundsPropsInfo(OCCTFreeBoundsPropsRef props,
                             OCCTFreeBoundKind      kind,
                             int32_t                index,
                             OCCTFreeBoundInfo*     outInfo)
{
  Handle(ShapeAnalysis_FreeBoundData) fbd = occtFreeBound(props, kind, index);
  if (fbd.IsNull())
    return false;
  try
  {
    OCCTFreeBoundInfo info = {};
    info.area              = fbd->Area();
    info.perimeter         = fbd->Perimeter();
    info.ratio             = fbd->Ratio();
    info.width             = fbd->Width();
    info.notchCount        = (int32_t)fbd->NbNotches();
    *outInfo               = info;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTFreeBoundsPropsWire(OCCTFreeBoundsPropsRef props,
                                     OCCTFreeBoundKind      kind,
                                     int32_t                index)
{
  Handle(ShapeAnalysis_FreeBoundData) fbd = occtFreeBound(props, kind, index);
  if (fbd.IsNull())
    return nullptr;
  try
  {
    TopoDS_Wire wire = fbd->FreeBound();
    if (wire.IsNull())
      return nullptr;
    return new OCCTShape(wire);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.115: ShapeFix_Shape builder
// --- ShapeFix_Shape builder ---

struct OCCTShapeFixer
{
  Handle(ShapeFix_Shape) fixer;
};

OCCTShapeFixerRef OCCTShapeFixerCreate(OCCTShapeRef shape)
{
  // #1035: ShapeFix_Shape's constructor accepts a null shape and returns; Perform() is where it
  // dereferences, so the refusal has to be recorded here and read by every accessor below. The
  // declared return is _Nonnull, so a null wrapper is not available as the refusal: an empty
  // handle is, and it is what the seven accessors already test for.
  auto f = new OCCTShapeFixer();
  if (occtShapeIsPresent(shape))
    f->fixer = new ShapeFix_Shape(shape->shape);
  return (OCCTShapeFixerRef)f;
}

void OCCTShapeFixerRelease(OCCTShapeFixerRef ref)
{
  auto f = (OCCTShapeFixer*)ref;
  delete f;
}

void OCCTShapeFixerSetPrecision(OCCTShapeFixerRef ref, double precision)
{
  auto f = (OCCTShapeFixer*)ref;
  if (f && !f->fixer.IsNull())
    f->fixer->SetPrecision(precision);
}

void OCCTShapeFixerSetMaxTolerance(OCCTShapeFixerRef ref, double maxTol)
{
  auto f = (OCCTShapeFixer*)ref;
  if (f && !f->fixer.IsNull())
    f->fixer->SetMaxTolerance(maxTol);
}

void OCCTShapeFixerSetMinTolerance(OCCTShapeFixerRef ref, double minTol)
{
  auto f = (OCCTShapeFixer*)ref;
  if (f && !f->fixer.IsNull())
    f->fixer->SetMinTolerance(minTol);
}

bool OCCTShapeFixerPerform(OCCTShapeFixerRef ref)
{
  auto f = (OCCTShapeFixer*)ref;
  if (!f || f->fixer.IsNull())
    return false;
  try
  {
    return f->fixer->Perform();
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTShapeFixerShape(OCCTShapeFixerRef ref)
{
  auto f = (OCCTShapeFixer*)ref;
  if (!f || f->fixer.IsNull())
    return nullptr;
  try
  {
    TopoDS_Shape result = f->fixer->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape{result};
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTShapeFixerStatus(OCCTShapeFixerRef ref, int32_t statusType)
{
  auto f = (OCCTShapeFixer*)ref;
  if (!f || f->fixer.IsNull())
    return false;
  try
  {
    ShapeExtend_Status st;
    switch (statusType)
    {
      case 1:
        st = ShapeExtend_OK;
        break;
      case 2:
        st = ShapeExtend_DONE;
        break;
      case 3:
        st = ShapeExtend_FAIL;
        break;
      default:
        return false;
    }
    return f->fixer->Status(st);
  }
  catch (...)
  {
    return false;
  }
}

// #849: the full ShapeExtend_Status flag space, mirroring OCCTFaceFixerStatus's raw passthrough.
bool OCCTShapeFixerStatusFlag(OCCTShapeFixerRef ref, int32_t flag)
{
  auto f = (OCCTShapeFixer*)ref;
  if (!f || f->fixer.IsNull())
    return false;
  try
  {
    return f->fixer->Status(static_cast<ShapeExtend_Status>(flag));
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.118: Tolerance value/over-count/in-range + Boolean check single/pair
double OCCTShapeToleranceValue(OCCTShapeRef shape, int32_t mode, int32_t shapeType)
{
  try
  {
    auto*                        s = static_cast<OCCTShape*>(shape);
    ShapeAnalysis_ShapeTolerance sat;
    return sat.Tolerance(s->shape, mode, static_cast<TopAbs_ShapeEnum>(shapeType));
  }
  catch (...)
  {
    return 0.0;
  }
}

int32_t OCCTShapeToleranceOverCount(OCCTShapeRef shape, double value, int32_t shapeType)
{
  try
  {
    auto*                        s = static_cast<OCCTShape*>(shape);
    ShapeAnalysis_ShapeTolerance sat;
    auto seq = sat.OverTolerance(s->shape, value, static_cast<TopAbs_ShapeEnum>(shapeType));
    return seq.IsNull() ? 0 : (int32_t)seq->Length();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTShapeToleranceInRangeCount(OCCTShapeRef shape,
                                       double       valmin,
                                       double       valmax,
                                       int32_t      shapeType)
{
  try
  {
    auto*                        s = static_cast<OCCTShape*>(shape);
    ShapeAnalysis_ShapeTolerance sat;
    auto seq = sat.InTolerance(s->shape, valmin, valmax, static_cast<TopAbs_ShapeEnum>(shapeType));
    return seq.IsNull() ? 0 : (int32_t)seq->Length();
  }
  catch (...)
  {
    return 0;
  }
}

// === BRepAlgoAPI_Check ===
bool OCCTShapeBooleanCheckSingle(OCCTShapeRef shape, bool testSmallEdges, bool testSelfInterference)
{
  try
  {
    auto*             s = static_cast<OCCTShape*>(shape);
    BRepAlgoAPI_Check check(s->shape, testSmallEdges, testSelfInterference);
    return check.IsValid();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeBooleanCheckPair(OCCTShapeRef shape1,
                               OCCTShapeRef shape2,
                               int32_t      operation,
                               bool         testSmallEdges,
                               bool         testSelfInterference)
{
  try
  {
    auto*             s1 = static_cast<OCCTShape*>(shape1);
    auto*             s2 = static_cast<OCCTShape*>(shape2);
    BRepAlgoAPI_Check check(s1->shape,
                            s2->shape,
                            static_cast<BOPAlgo_Operation>(operation),
                            testSmallEdges,
                            testSelfInterference);
    return check.IsValid();
  }
  catch (...)
  {
    return false;
  }
}

// === BRepAlgoAPI_Defeaturing ===
#include <BRepAlgoAPI_Defeaturing.hxx>

// MARK: - v0.124: WireAnalyzer (ShapeAnalysis_Wire)
// --- WireAnalyzer (ShapeAnalysis_Wire) ---

#include <ShapeAnalysis_Wire.hxx>
#include <TopoDS.hxx>

struct OCCTWireAnalyzer
{
  Handle(ShapeAnalysis_Wire) analyzer;

  OCCTWireAnalyzer(const TopoDS_Wire& w, const TopoDS_Face& f, double prec)
  {
    analyzer = new ShapeAnalysis_Wire(w, f, prec);
  }
};

OCCTWireAnalyzerRef OCCTWireAnalyzerCreate(OCCTShapeRef wire, OCCTShapeRef face, double precision)
{
  if (!wire || !face)
    return nullptr;
  try
  {
    const TopoDS_Wire& w = TopoDS::Wire(wire->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    return new OCCTWireAnalyzer(w, f, precision);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTWireAnalyzerRelease(OCCTWireAnalyzerRef analyzer)
{
  delete analyzer;
}

bool OCCTWireAnalyzerPerform(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->Perform();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckOrder(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckOrder();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckConnected(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckConnected(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckSmall(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckSmall(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckDegenerated(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckDegenerated(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckGap3d(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckGap3d(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckGap2d(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckGap2d(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckSeam(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckSeam(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckLacking(OCCTWireAnalyzerRef analyzer, int32_t edgeNum)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckLacking(edgeNum);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckSelfIntersection(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckSelfIntersection();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerCheckClosed(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->CheckClosed();
  }
  catch (...)
  {
    return false;
  }
}

double OCCTWireAnalyzerMinDistance3d(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return -1.0;
  try
  {
    return analyzer->analyzer->MinDistance3d();
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTWireAnalyzerMaxDistance3d(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return -1.0;
  try
  {
    return analyzer->analyzer->MaxDistance3d();
  }
  catch (...)
  {
    return -1.0;
  }
}

int32_t OCCTWireAnalyzerNbEdges(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return 0;
  try
  {
    return analyzer->analyzer->NbEdges();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTWireAnalyzerIsLoaded(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->IsLoaded();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireAnalyzerIsReady(OCCTWireAnalyzerRef analyzer)
{
  if (!analyzer || analyzer->analyzer.IsNull())
    return false;
  try
  {
    return analyzer->analyzer->IsReady();
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.122: ShapeFix_Edge extended
// --- ShapeFix_Edge extended ---

bool OCCTShapeFixEdgeAddCurve3d(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    ShapeFix_Edge fixer;
    return fixer.FixAddCurve3d(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeFixEdgeAddPCurve(OCCTShapeRef edge, OCCTShapeRef face, bool isSeam)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeFix_Edge fixer;
    return fixer.FixAddPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), isSeam);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeFixEdgeRemoveCurve3d(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    ShapeFix_Edge fixer;
    return fixer.FixRemoveCurve3d(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeFixEdgeRemovePCurve(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeFix_Edge fixer;
    return fixer.FixRemovePCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeFixEdgeFixReversed2d(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || !face)
    return false;
  try
  {
    ShapeFix_Edge fixer;
    return fixer.FixReversed2d(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Validation

bool OCCTShapeIsValid(OCCTShapeRef shape)
{
  if (!shape)
    return false;
  try
  {
    BRepCheck_Analyzer analyzer(shape->shape);
    return analyzer.IsValid();
  }
  catch (...)
  {
    return false;
  }
}

// #1026, second class: this function touches no hazardous TopoDS_Shape member itself, so the gate's
// third walk cannot see it; ShapeFix_Shape's constructor dereferences the shape inside the kernel.
// Measured a SIGSEGV on Shape.nullified through Shape.healed().
OCCTShapeRef OCCTShapeHeal(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;
  try
  {
    // #263: ShapeFix_Shape heap-corrupts (uncatchable OS signal) when healing a solid built
    // from a self-intersecting wire, e.g. a prism extruded from a degenerate mesh-derived
    // outline. ShapeFix cannot repair a self-intersection anyway, so refuse such input.
    if (occtHasSelfIntersectingWire(shape->shape))
      return nullptr;
    Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
    fixer->Perform();
    return new OCCTShape(fixer->Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}
