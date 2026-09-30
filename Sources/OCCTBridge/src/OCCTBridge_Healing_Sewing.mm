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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return false;
  }
}
