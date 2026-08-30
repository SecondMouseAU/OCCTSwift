//
//  OCCTBridge_Healing_Fix.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): ShapeFix_* (Solid, Wire, Face, Edge, Wireframe,
//  IntersectionTool, EdgeProjAux, SplitTool, ComposeShell, EdgeConnect) -- the file's dominant
//  concern, default_bucket. Public C surface unchanged; every sibling file imports the same headers
//  this one does (the shared preamble below). No symbol changes, pure file move -- see
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

int32_t OCCTCheckFaceStatus(OCCTShapeRef shape, OCCTShapeRef face)
{
  if (!shape || !face)
    return -1;
  return occtBRepCheckSubShapeStatus(shape->shape, face->shape);
}

int32_t OCCTCheckEdgeStatus(OCCTShapeRef shape, OCCTShapeRef edge)
{
  if (!shape || !edge)
    return -1;
  return occtBRepCheckSubShapeStatus(shape->shape, edge->shape);
}

int32_t OCCTCheckVertexStatus(OCCTShapeRef shape, OCCTShapeRef vertex)
{
  if (!shape || !vertex)
    return -1;
  return occtBRepCheckSubShapeStatus(shape->shape, vertex->shape);
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

// === BRepAlgoAPI_Check ===
// #1297: converged with the older, now-removed OCCTShapeBooleanCheck (formerly
// OCCTBridge_Modeling.mm), which guarded its OCCTShapeRef argument(s) before dereferencing.
// Shape.isValidForBoolean / isValidForBoolean(with:) forward here now; the guard came along too.
bool OCCTShapeBooleanCheckSingle(OCCTShapeRef shape, bool testSmallEdges, bool testSelfInterference)
{
  if (!shape)
    return false;
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
  if (!shape1 || !shape2)
    return false;
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
