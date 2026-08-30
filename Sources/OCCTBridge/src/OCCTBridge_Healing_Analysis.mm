//
//  OCCTBridge_Healing_Analysis.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): ShapeAnalysis_* (Wire, Edge, Shell, WireOrder,
//  WireVertex, Geom, FreeBounds*, CanonicalRecognition), BRepCheck_* validators + Analyzer. Public
//  C surface unchanged; every sibling file imports the same headers this one does (the shared
//  preamble below). No symbol changes, pure file move -- see Scripts/repro/396-bridge-mm-split/ for
//  how.
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

bool OCCTWireCheckOrder(OCCTShapeRef wire, OCCTShapeRef face, double prec)
{
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
  if (!occtShapeIsType(wire, TopAbs_WIRE) || !occtShapeIsType(face, TopAbs_FACE))
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
// #1073: the pcurve guard now requires EVERY edge to carry a pcurve (not just some), and the
// returned area is tested against the face's UV bounds to reject cancellation to rounding.
// A partial pcurve set or a degenerate projection that cancels to ~1e-15 both produce a verdict
// whose sign is numerical noise, not geometry. Both are refused with -1.
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
    // Rebuild what CheckOuterBound hands to ShapeAnalysis::IsOuterBound and refuse if any edge
    // lacks a pcurve on the face: TotCross2D would then sign an area only the pcurved subset
    // contributed to. The sibling OCCTShapeUpgradeWireDivideOnFace has the same requirement.
    TopoDS_Wire aBuilt = saw.WireData()->WireAPIMake();
    if (aBuilt.IsNull())
      return -1;
    TopoDS_Shape anEmpty = TopoDS::Face(face->shape).EmptyCopied();
    TopoDS_Face  aProbe  = TopoDS::Face(anEmpty);
    BRep_Builder aBuilder;
    aBuilder.Add(aProbe, aBuilt);
    // Require EVERY edge to have a pcurve on the face.
    for (TopExp_Explorer anIt(aProbe, TopAbs_EDGE); anIt.More(); anIt.Next())
    {
      double aFirst, aLast;
      if (BRep_Tool::CurveOnSurface(TopoDS::Edge(anIt.Current()), aProbe, aFirst, aLast).IsNull())
        return -1;
    }
    // Compute the signed area and test its magnitude against the face UV bounds.
    // A wire whose projected area cancels to rounding (~1e-15) produces a verdict driven
    // by numerical noise, not geometry. The face UV bounds give a characteristic area scale.
    double umin = 0.0, umax = 0.0, vmin = 0.0, vmax = 0.0;
    ShapeAnalysis::GetFaceUVBounds(aProbe, umin, umax, vmin, vmax);
    double faceAreaScale = (umax - umin) * (vmax - vmin);
    // A WireData built the same way CheckOuterBound does internally.
    occ::handle<ShapeExtend_WireData> sewd     = new ShapeExtend_WireData(aBuilt);
    double                            totcross = ShapeAnalysis::TotCross2D(sewd, aProbe);
    // Reject areas whose magnitude is negligible relative to the face scale.
    // Threshold: 1e-12 of the face UV area. This is well below any legitimate
    // outer/inner wire distinction and well above rounding cancellation.
    if (faceAreaScale > 0.0 && std::abs(totcross) < faceAreaScale * 1e-12)
      return -1;
    return saw.CheckOuterBound() ? 1 : 0;
  }
  catch (...)
  {
    return -1;
  }
}

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
