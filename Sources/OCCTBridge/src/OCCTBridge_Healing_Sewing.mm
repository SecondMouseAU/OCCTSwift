//
//  OCCTBridge_Healing_Sewing.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): BRepBuilderAPI_Sewing, BRepTools_Substitution +
//  ShapeUpgrade_ShellSewing. Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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

OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_FastSewing sewer(tolerance);
    sewer.Add(shape->shape);
    sewer.Perform();
    TopoDS_Shape sewn = sewer.GetResult();
    if (sewn.IsNull())
      return nullptr;
    return new OCCTShape(sewn);
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
