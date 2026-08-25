//
//  OCCTBridge_AdvancedModeling.mm
//  OCCTSwift
//
//  Objective-C++ bridge implementations for the Advanced Modeling domain.
//  Split from OCCTBridge_Modeling.mm (#1071).
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFill.hxx>
#include <BRepLib.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TopExp.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <TopoDS_Solid.hxx>

// === Fillet Edges (uniform radius) ===

OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef   shape,
                                  const int32_t* edgeIndices,
                                  int32_t        edgeCount,
                                  double         radius,
                                  int32_t*       declinedEdgeIndices,
                                  int32_t*       outDeclinedCount)
{
  if (outDeclinedCount)
    *outDeclinedCount = 0;
  if (!occtValidFilletRadius(radius))
    return nullptr;

  return occtShapeFilletEdgeList(
    shape,
    edgeIndices,
    edgeCount,
    [radius](BRepFilletAPI_MakeFillet& fillet, const TopoDS_Edge& edge, int32_t) {
      fillet.Add(radius, edge);
      return true;
    },
    declinedEdgeIndices,
    outDeclinedCount);
}

// === Fillet Edges (variable radius) ===

// #639: same reporting contract as OCCTShapeFilletEdges above.
OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef   shape,
                                        const int32_t* edgeIndices,
                                        int32_t        edgeCount,
                                        double         startRadius,
                                        double         endRadius,
                                        int32_t*       declinedEdgeIndices,
                                        int32_t*       outDeclinedCount)
{
  if (outDeclinedCount)
    *outDeclinedCount = 0;
  if (!occtValidFilletRadius(startRadius) || !occtValidFilletRadius(endRadius))
    return nullptr;

  return occtShapeFilletEdgeList(
    shape,
    edgeIndices,
    edgeCount,
    [startRadius, endRadius](BRepFilletAPI_MakeFillet& fillet, const TopoDS_Edge& edge, int32_t) {
      // #612: this used to be Add(edge) followed by SetRadius(R1, R2, NbContours(), 1). Both
      // coordinates were wrong, a tangent-continuous edge extends an existing contour rather
      // than creating one, and the third argument is the edge's index *within* the contour, not
      // a constant 1, so every edge of a tangent chain landed on one slot and only the last
      // survived (measured 10273.238348 for two edges of a slot rim at 1 -> 4, exactly what
      // filleting the first alone produces, against 10297.711861 correct).
      //
      // OCCT ships the whole thing as one call: Add(R1, R2, E) is Add(E) plus the same
      // Contains(E, IinC) slot resolution plus SetRadius(R1, R2, IC, IinC). Verified equivalent
      // to resolving the slot by hand, identical to the digit on that rim for the pair
      // (10297.711860842), the straight side alone (10273.238347801) and the arc alone
      // (10276.405613964), and it declines an unfilletable edge by construction, which is the
      // skip the sibling entry points get from Add(Radius, E).
      fillet.Add(startRadius, endRadius, edge);
      return true;
    },
    declinedEdgeIndices,
    outDeclinedCount);
}

// === Draft Angle ===

OCCTShapeRef OCCTShapeDraft(OCCTShapeRef   shape,
                            const int32_t* faceIndices,
                            int32_t        faceCount,
                            double         dirX,
                            double         dirY,
                            double         dirZ,
                            double         angle,
                            double         planeX,
                            double         planeY,
                            double         planeZ,
                            double         planeNx,
                            double         planeNy,
                            double         planeNz)
{
  if (!shape || !faceIndices || faceCount <= 0)
    return nullptr;

  try
  {
    // Pull direction (typically vertical for mold release)
    gp_Dir pullDir(dirX, dirY, dirZ);

    // Neutral plane - where draft angle is measured from
    gp_Pnt planePoint(planeX, planeY, planeZ);
    gp_Dir planeNormal(planeNx, planeNy, planeNz);
    gp_Pln neutralPlane(planePoint, planeNormal);

    BRepOffsetAPI_DraftAngle draft(shape->shape);

    // #568: a face index naming no face of this shape rejects the whole draft. It used to be
    // skipped, and BRepOffsetAPI_DraftAngle reports IsDone() for a request it was handed no
    // faces for at all, so a draft naming only foreign faces returned the input shape,
    // undrafted, presented as a successful draft. See OCCTBridge_Internal.h.
    if (!occtUseSubShapesByIndex(shape->shape,
                                 TopAbs_FACE,
                                 faceIndices,
                                 faceCount,
                                 [&](const TopoDS_Shape& face, int32_t) {
                                   draft.Add(TopoDS::Face(face), pullDir, angle, neutralPlane);
                                 }))
      return nullptr;

    draft.Build();
    if (!draft.IsDone())
      return nullptr;

    return new OCCTShape(draft.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

// === Defeaturing ===

// The shared skeleton behind every defeaturing entry point, here and in OCCTBridge_Healing.mm.
// See OCCTBridge_Internal.h for what the four copies this replaced disagreed about, and for why
// the fuzzy-tolerance wrapper that used to be the fifth is gone rather than folded in. #497

OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef   shape,
                                     const int32_t* faceIndices,
                                     int32_t        faceCount)
{
  if (!shape)
    return nullptr;

  try
  {
    TopTools_ListOfShape facesToRemove;
    if (!occtDefeaturingFacesByIndex(shape->shape, faceIndices, faceCount, facesToRemove))
    {
      return nullptr;
    }

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

// === Pipe Shell (BRepOffsetAPI_MakePipeShell) ===

// Every Add()-based pipe shell in this bridge is one call to
// OCCTShapeCreatePipeShellMultiSection. The single-profile spellings that used to sit
// here (OCCTShapeCreatePipeShell, ...WithBinormal, ...WithAuxSpine, ...WithTransition)
// were that function with profileCount == 1 and some of its arguments nailed shut, and
// two of them disagreed with it about what a mode means (#503).

// Multi-section pipe shell (#180): one MakePipeShell, several Add() calls.
// Since #503 this is also the single-profile form, and the only Add()-based pipe shell.
OCCTShapeRef OCCTShapeCreatePipeShellMultiSection(OCCTWireRef        spine,
                                                  const OCCTWireRef* profiles,
                                                  int32_t            profileCount,
                                                  OCCTPipeMode       mode,
                                                  double             bnX,
                                                  double             bnY,
                                                  double             bnZ,
                                                  OCCTWireRef        auxSpine,
                                                  int32_t            transitionMode,
                                                  bool               withContact,
                                                  bool               withCorrection,
                                                  bool               solid)
{
  if (!spine || !profiles || profileCount < 1)
    return nullptr;

  try
  {
    BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

    if (!occtPipeShellSetMode(pipeShell, mode, bnX, bnY, bnZ, auxSpine))
      return nullptr;

    switch (transitionMode)
    {
      case 1:
        pipeShell.SetTransitionMode(BRepBuilderAPI_RightCorner);
        break;
      case 2:
        pipeShell.SetTransitionMode(BRepBuilderAPI_RoundCorner);
        break;
      default:
        pipeShell.SetTransitionMode(BRepBuilderAPI_Transformed);
        break;
    }

    // Add every profile (variable cross-section).
    for (int32_t i = 0; i < profileCount; ++i)
    {
      if (!profiles[i])
        return nullptr;
      pipeShell.Add(profiles[i]->wire,
                    withContact ? Standard_True : Standard_False,
                    withCorrection ? Standard_True : Standard_False);
    }

    return occtPipeShellFinish(pipeShell, solid);
  }
  catch (...)
  {
    return nullptr;
  }
}

// === Thread Cutter (analytic helicoid) ===

// Analytic helicoid thread cutter (#187): smooth ruled-face solid, no faceting/balloon.

OCCTShapeRef OCCTShapeBuildThreadCutter(double  ox,
                                        double  oy,
                                        double  oz,
                                        double  ax,
                                        double  ay,
                                        double  az,
                                        double  rx,
                                        double  ry,
                                        double  rz,
                                        double  pitch,
                                        double  turns,
                                        double  apexSign,
                                        double  helixRadius,
                                        double  cutDepth,
                                        double  outerHalf,
                                        double  apexHalf,
                                        double  bleed,
                                        double  phase,
                                        double  handed,
                                        int32_t nSections)
{
  if (pitch <= 0 || turns <= 0 || nSections < 2)
    return nullptr;
  try
  {
    const gp_Vec O(ox, oy, oz), A(ax, ay, az), R0(rx, ry, rz);
    const gp_Vec T0     = A.Crossed(R0);                     // tangential0 = axis x radial0
    const double outerR = helixRadius - apexSign * bleed;    // outer end bleeds past surface
    const double apexR  = helixRadius + apexSign * cutDepth; // apex = the deep cut
    const double cr[4]  = {outerR, apexR, apexR, outerR};
    const double cz[4]  = {-outerHalf,
                           -apexHalf,
                           apexHalf,
                           outerHalf}; // wide at surface, narrow at apex (#213)
    const int    N      = nSections;

    // Each V-corner traces a single-edge BSpline helix.
    TopoDS_Edge edges[4];
    for (int k = 0; k < 4; ++k)
    {
      Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, N + 1);
      for (int i = 0; i <= N; ++i)
      {
        const double fr     = (double)i / (double)N;
        const double theta  = handed * (phase + 2.0 * M_PI * turns * fr);
        const double zc     = pitch * turns * fr + cz[k];
        const gp_Vec radial = R0 * std::cos(theta) + T0 * std::sin(theta);
        const gp_Vec P      = O + A * zc + radial * cr[k];
        pts->SetValue(i + 1, gp_Pnt(P.X(), P.Y(), P.Z()));
      }
      GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
      interp.Perform();
      if (!interp.IsDone())
        return nullptr;
      edges[k] = BRepBuilderAPI_MakeEdge(interp.Curve());
      if (edges[k].IsNull())
        return nullptr;
    }

    // Ruled flank/crest/root faces between consecutive corner helices, + 2 V end caps.
    BRepBuilderAPI_Sewing sewer(1e-6);
    for (int k = 0; k < 4; ++k)
    {
      TopoDS_Face f = BRepFill::Face(edges[k], edges[(k + 1) % 4]);
      if (f.IsNull())
        return nullptr;
      sewer.Add(f);
    }
    for (int cap = 0; cap < 2; ++cap)
    {
      const double               fr     = (double)cap;
      const double               theta  = handed * (phase + 2.0 * M_PI * turns * fr);
      const double               zbase  = pitch * turns * fr;
      const gp_Vec               radial = R0 * std::cos(theta) + T0 * std::sin(theta);
      BRepBuilderAPI_MakePolygon poly;
      for (int k = 0; k < 4; ++k)
      {
        const gp_Vec P = O + A * (zbase + cz[k]) + radial * cr[k];
        poly.Add(gp_Pnt(P.X(), P.Y(), P.Z()));
      }
      poly.Close();
      BRepBuilderAPI_MakeFace mf(poly.Wire(), Standard_True);
      if (!mf.IsDone())
        return nullptr;
      sewer.Add(mf.Face());
    }
    sewer.Perform();
    TopoDS_Shape shell = sewer.SewedShape();
    if (shell.IsNull())
      return nullptr;
    // #443 audit: first shell only, but the faces sewn above are one closed helical
    // cutter by construction, so there is never a second. No caller-visible risk.
    TopExp_Explorer se(shell, TopAbs_SHELL);
    if (!se.More())
      return nullptr;
    TopoDS_Solid solid = BRepBuilderAPI_MakeSolid(TopoDS::Shell(se.Current())).Solid();
    // Orient outward so it is a proper positive-volume solid (the sewn shell can be
    // inside-out, which would make the boolean intersect instead of subtract).
    BRepLib::OrientClosedSolid(solid);
    return new OCCTShape(solid);
  }
  catch (...)
  {
    return nullptr;
  }
}

// === BSpline Surface ===

OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles,
                                           int32_t       uCount,
                                           int32_t       vCount,
                                           int32_t       uDegree,
                                           int32_t       vDegree)
{
  if (!poles || uCount < 2 || vCount < 2)
    return nullptr;
  if (uDegree < 1 || vDegree < 1)
    return nullptr;
  if (uCount < uDegree + 1 || vCount < vDegree + 1)
    return nullptr;

  try
  {
    // Create 2D array of control points (1-indexed for OCCT)
    TColgp_Array2OfPnt polesArray(1, uCount, 1, vCount);

    for (int32_t u = 0; u < uCount; u++)
    {
      for (int32_t v = 0; v < vCount; v++)
      {
        int32_t idx = (u * vCount + v) * 3;
        polesArray.SetValue(u + 1, v + 1, gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]));
      }
    }

    // Create uniform clamped knot vectors
    int32_t uKnotCount = uCount - uDegree + 1;
    int32_t vKnotCount = vCount - vDegree + 1;

    TColStd_Array1OfReal    uKnots(1, uKnotCount);
    TColStd_Array1OfReal    vKnots(1, vKnotCount);
    TColStd_Array1OfInteger uMults(1, uKnotCount);
    TColStd_Array1OfInteger vMults(1, vKnotCount);

    // Uniform knot values
    for (int32_t i = 1; i <= uKnotCount; i++)
    {
      uKnots.SetValue(i, (double)(i - 1) / (uKnotCount - 1));
      uMults.SetValue(i, (i == 1 || i == uKnotCount) ? uDegree + 1 : 1);
    }
    for (int32_t i = 1; i <= vKnotCount; i++)
    {
      vKnots.SetValue(i, (double)(i - 1) / (vKnotCount - 1));
      vMults.SetValue(i, (i == 1 || i == vKnotCount) ? vDegree + 1 : 1);
    }

    // Create B-spline surface
    Handle(Geom_BSplineSurface) surface =
      new Geom_BSplineSurface(polesArray, uKnots, vKnots, uMults, vMults, uDegree, vDegree);

    if (surface.IsNull())
      return nullptr;

    // Create face from surface
    BRepBuilderAPI_MakeFace faceMaker(surface, 1e-6);
    if (!faceMaker.IsDone())
      return nullptr;

    return new OCCTShape(faceMaker.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

// === Ruled Surface ===

OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2)
{
  if (!wire1 || !wire2)
    return nullptr;

  try
  {
    // Use BRepFill::Shell to create a ruled surface between two wires
    TopoDS_Shape result = BRepFill::Shell(wire1->wire, wire2->wire);

    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// === Shell with Open Faces ===

OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef   shape,
                                         double         thickness,
                                         const int32_t* openFaceIndices,
                                         int32_t        faceCount)
{
  if (!shape || !openFaceIndices || faceCount < 1)
    return nullptr;

  try
  {
    // #568: a face index naming no face of this shape rejects the whole call. It used to be
    // skipped, and the only thing that caught it was a `facesToRemove.IsEmpty()` check here --
    // which fires only when *every* index is unresolvable. A list mixing one real open face
    // with one foreign one shelled the solid with fewer openings than asked for and reported
    // success. That check is gone rather than kept: the helper refuses a count below 1 and
    // appends for every index it does resolve, so an empty list is now unreachable.
    // See OCCTBridge_Internal.h.
    TopTools_ListOfShape facesToRemove;
    if (!occtUseSubShapesByIndex(
          shape->shape,
          TopAbs_FACE,
          openFaceIndices,
          faceCount,
          [&](const TopoDS_Shape& face, int32_t) { facesToRemove.Append(face); }))
      return nullptr;

    // Create thick solid (shell) with open faces
    BRepOffsetAPI_MakeThickSolid thickSolid;
    thickSolid.MakeThickSolidByJoin(shape->shape, facesToRemove, thickness, 1e-6);

    if (!thickSolid.IsDone())
      return nullptr;

    return new OCCTShape(thickSolid.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}
