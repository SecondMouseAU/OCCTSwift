//
//  OCCTBridge_Healing_Upgrade.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): ShapeUpgrade_* (Divide*, SplitSurface*,
//  ConvertToBezier, FaceDivide/WireDivide), ShapeCustom_* (BSplineRestriction, ConvertToBSpline,
//  DirectFaces). Public C surface unchanged; every sibling file imports the same headers this one
//  does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

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

// Additional includes gathered from throughout the original file (#1380):
#include <BRepBuilderAPI_NurbsConvert.hxx>
#include <BRepBuilderAPI_FastSewing.hxx>
#include <ShapeUpgrade_RemoveInternalWires.hxx>
#include <ShapeFix_FixSmallFace.hxx>
#include <ShapeUpgrade_RemoveLocations.hxx>
#include <ShapeAnalysis_CheckSmallFace.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomConvert.hxx>
#include <BRepTools_PurgeLocations.hxx>
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
#include <BRepTools_Modifier.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Point.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <Geom2d_VectorWithMagnitude.hxx>
#include <Geom2d_Direction.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <LProp_CurAndInf.hxx>
#include <ShapeFix_Solid.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <Precision.hxx>
#include <TopoDS_Iterator.hxx>
#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Lin.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>
#include <ShapeFix_EdgeProjAux.hxx>
#include <ShapeFix_IntersectionTool.hxx>
#include <ShapeExtend_WireData.hxx>
#include <ShapeAnalysis_Edge.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

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

struct OCCTWireFixer
{
  Handle(ShapeFix_Wire) fixer;
};

struct OCCTFaceFixer
{
  Handle(ShapeFix_Face) fixer;
};

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

struct OCCTShapeFixer
{
  Handle(ShapeFix_Shape) fixer;
};

struct OCCTWireAnalyzer
{
  Handle(ShapeAnalysis_Wire) analyzer;

  OCCTWireAnalyzer(const TopoDS_Wire& w, const TopoDS_Face& f, double prec)
  {
    analyzer = new ShapeAnalysis_Wire(w, f, prec);
  }
};

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

OCCTShapeRef OCCTShapeDivideByNumber(OCCTShapeRef shape, int32_t nbU, int32_t nbV)
{
  if (!shape || nbU < 1 || nbV < 1)
    return nullptr;
  try
  {
    ShapeUpgrade_ShapeDivide divider(shape->shape);
    // Use FaceDivideArea with splitting-by-number mode. Two things are needed to make this
    // actually run rather than silently fail or silently ignore the caller's axis counts (#1491):
    //
    // 1. MaxArea() defaults to Precision::Infinite(), not the -1 sentinel
    //    ShapeUpgrade_FaceDivideArea::Perform() checks for ("if (myMaxArea == -1) { ... derive
    //    myMaxArea from myNbParts ... }"). Left at its default, Perform()'s very next line
    //    ("if ((anArea - myMaxArea) < Precision::Confusion()) return false;") is unconditionally
    //    true for any finite face area, so Perform() -- and therefore this whole function --
    //    failed outright for every input, every time, independent of nbU/nbV. Measured directly:
    //    a plain box through this exact call sequence with MaxArea() left unset returns false.
    // 2. SetNumbersUVSplits is what makes Compute() respect the caller's per-axis split counts
    //    once Perform() actually runs; without it, myUnbSplit/myVnbSplit stay at their own
    //    default sentinel (-1) and ShapeUpgrade_SplitSurfaceArea::Compute silently derives its
    //    own roughly-square split from NbParts() alone instead.
    Handle(ShapeUpgrade_FaceDivideArea) faceDivide = new ShapeUpgrade_FaceDivideArea();
    faceDivide->SetSplittingByNumber(true);
    faceDivide->NbParts() = nbU * nbV;
    faceDivide->MaxArea() = -1;
    faceDivide->SetNumbersUVSplits(nbU, nbV);
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

// OCCTShapeUpgradeFixSmallCurves / OCCTShapeUpgradeFixSmallBezierCurves removed (#1491): both were
// complete no-ops that unconditionally handed back the caller's own unmodified shape.
// ShapeUpgrade_FixSmallCurves/FixSmallBezierCurves have no standalone Perform()/Compute() at all;
// per their own headers they are internal helper "tool" classes meant only to be plugged into a
// driving class via SetFixSmallCurveTool. Investigated wiring ShapeFix_Wireframe in, since the
// removed comment above claimed that was the intended mechanism -- it was not: ShapeFix_Wireframe
// (ShapeUpgrade/../ShapeFix/ShapeFix_Wireframe.cxx) never references either class anywhere. The
// only two real OCCT callers are ShapeUpgrade_WireDivide (which constructs a default
// ShapeUpgrade_FixSmallCurves in its own constructor, but only reaches Approx() as a byproduct of
// an active 3D/2D curve *split* actually producing a too-small leftover segment, unreachable from a
// tolerance-only entry point with no splitting criterion to drive it) and
// ShapeUpgrade_ShapeConvertToBezier (which wires FixSmallBezierCurves into its own internal
// WireDivide automatically -- already exercised correctly by the existing OCCTShapeConvertToBezier
// / Shape.convertToBezier()). The one genuinely standalone "fix small edges" OCCT operation is a
// different class, ShapeFix_Wire::FixSmall via ShapeFix_Wireframe::FixSmallEdges(), already wrapped
// faithfully as OCCTShapeFixSmallEdges / Shape.fixSmallEdges(tolerance:dropSmall:limitAngle:). See
// the #1491 PR body for the full investigation.

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
