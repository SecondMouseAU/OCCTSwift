//
//  OCCTBridge_Healing_Misc.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): ShapeBuild_*, ShapeExtend_Explorer, NURBS conversion,
//  BRepLib_ValidateEdge, BRepAlgo_FaceRestrictor. Public C surface unchanged; every sibling file
//  imports the same headers this one does (the shared preamble below). No symbol changes, pure file
//  move -- see Scripts/repro/396-bridge-mm-split/ for how.
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

void OCCTEdgeSetSameParameter(OCCTEdgeRef edge, bool sameParameter)
{
  if (!occtShapeIsPresent(edge))
    return;
  try
  {
    BRep_Builder().SameParameter(edge->edge, sameParameter);
  }
  catch (...)
  {
  }
}

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

OCCTValidateEdgeResult OCCTValidateEdge(OCCTEdgeRef _Nonnull edge,
                                        OCCTFaceRef _Nonnull face,
                                        double tolerance)
{
  OCCTValidateEdgeResult result = {};
  if (!occtShapeIsPresent(edge) || !occtShapeIsPresent(face))
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

    // theSameParameter is the edge's own OCCT-tracked SameParameter state, not a mode flag the
    // caller picks: BRepLib_ValidateEdge::processApprox() uses it to decide whether the naive
    // same-t point comparison is valid, and every real OCCT caller (BRepCheck_Edge,
    // ShapeAnalysis_Edge::CheckSameParameter) passes the edge's real flag (#1461).
    BRepLib_ValidateEdge validator(curve3d, curveOnSurf, BRep_Tool::SameParameter(e));
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
    bool                       done = tool.FixIntersectingWires(face);
    // FixIntersectingWires records its substitutions on ctx (and, on success, reassigns its
    // by-reference `face` parameter to a brand-new TopoDS_Face) but never mutates shape->shape
    // itself -- ctx->Apply() is what actually rebuilds the shape from the accumulated
    // Replace() map. Without this, the function always reported `true` with no observable
    // change (#1461).
    if (done)
      shape->shape = ctx->Apply(shape->shape);
    return done;
  }
  catch (...)
  {
    return false;
  }
}
