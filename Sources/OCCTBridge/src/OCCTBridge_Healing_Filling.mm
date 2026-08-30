//
//  OCCTBridge_Healing_Filling.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): GeomPlate/BRepOffsetAPI_MakeFilling surface filling
//  (#430/#434). Public C surface unchanged; every sibling file imports the same headers this one
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
