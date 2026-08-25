//
//  OCCTBridge_Geom2d.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for the 2D geometry stack:
//
//  - Geom2d_* curve construction and conversion (line, circle, ellipse,
//    parabola, hyperbola, Bezier, BSpline, trimmed, offset)
//  - Geom2dAdaptor / Geom2dAPI / Geom2dConvert helpers
//  - Geom2dHatch (hatching) + HatchGen + Hatch_Hatcher
//  - Bisector_BisecCC / BisecPC (2D bisector curves)
//  - Geom2dGcc + GccAna (2D constraint solver)
//  - Geom2dGridEval (vectorized 2D curve sampling)
//  - gp_*2d primitives
//
//  Public C surface unchanged. No symbol changes: a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <Adaptor2d_Curve2d.hxx>
#include <Approx_Curve2d.hxx>
#include <BRepAdaptor_Curve2d.hxx>
#include <FairCurve_AnalysisCode.hxx>
#include <FairCurve_Batten.hxx>
#include <FairCurve_MinimalVariation.hxx>
#include <GccAna_Circ2d3Tan.hxx>
#include <Bisector_Inter.hxx>
#include <Bisector_PointOnBis.hxx>
#include <Bisector_PolyBis.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <Intf_InterferencePolygon2d.hxx>
#include <ShapeConstruct_Curve.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <GeomLib_Tool.hxx>
#include <GeomLib_Check2dBSplineCurve.hxx>
#include <ShapeUpgrade_SplitCurve2dContinuity.hxx>
#include <ShapeUpgrade_ConvertCurve2dToBezier.hxx>
#include <Extrema_LocateExtCC2d.hxx>
#include <Extrema_POnCurv2d.hxx>
#include <gce_MakeCirc2d.hxx>
#include <gce_MakeElips2d.hxx>
#include <gce_MakeHypr2d.hxx>
#include <gce_MakeLin2d.hxx>
#include <gce_MakeParab2d.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <Geom2dConvert.hxx>
#include <gp_GTrsf2d.hxx>
#include <gp_Mat2d.hxx>
#include <GccAna_Circ2d2TanRad.hxx>
#include <GccAna_Circ2dTanCen.hxx>
#include <GccAna_Lin2d2Tan.hxx>
#include <Intf_Polygon2d.hxx>
#include <BRepBuilderAPI_MakeEdge2d.hxx>
#include <GC_MakeLine2d.hxx>
#include <GccEnt_Position.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom2d_Direction.hxx>
#include <Geom2d_Point.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_VectorWithMagnitude.hxx>
#include <LProp_CIType.hxx>
#include <LProp_CurAndInf.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dGcc_Circ2d2TanRad.hxx>
#include <Geom2dGcc_Circ2d3Tan.hxx>
#include <Geom2dGcc_Circ2dTanCen.hxx>
#include <Geom2dGcc_Lin2d2Tan.hxx>
#include <Geom2dGcc_QualifiedCurve.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>

#include <Bnd_Box2d.hxx>
#include <BndLib_Add2dCurve.hxx>

#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <BRepMAT2d_LinkTopoBilo.hxx>
#include <Bisector_Bisec.hxx>
#include <MAT_Arc.hxx>
#include <MAT_BasicElt.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Node.hxx>
#include <MAT_Side.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>

#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// The conic dimension preconditions this file's factories share with Curve3D's
// (occtValidCircleRadius, occtValidEllipseRadii, occtValidHyperbolaRadii, occtValidParabolaFocal)
// live in OCCTBridge_Internal.h. #411 introduced a 2D-suffixed copy of the circle one here, which
// is how the 2D ellipse/hyperbola/parabola factories ended up skipped by both #411 and #399's
// otherwise-identical pass over the 3D side; #487 converged them.
//
// #553: the same predicate now covers the solver entry points too. A circle reaches this file's
// solvers as a centre and a radius, and there are three separate things a caller can mean by that
// radius, which had three different contracts:
//
//   1. a circle the solver is GIVEN            unchecked at 13 entry points
//   2. the radius of the circle it must FIND   checked at 3 entry points, unchecked at 4 siblings
//   3. a circle this file is asked to BUILD    checked at 6 entry points (#514), unchecked at 4
//
// Negative is not the gap: gp_Circ2d's constructor is constexpr in the header, so its
// Standard_ConstructionError_Raise_if does run in a bridge translation unit (the same finding as
// #514's, measured again for gp_Circ2d) and the existing catch already turns it into an empty
// result. GC_MakeCircle2d rejects a negative radius through gce_NegativeRadius, a status rather
// than a macro, so No_Exception does not void it either. The gap is exactly zero.
//
// Case 1 is the one the issue held open, because a zero-radius circle handed to a tangency solver
// is geometrically a point and several of these solvers have a documented answer for a point. The
// probe in Scripts/repro/553-gcc-zero-radius-circle ran every family against a zero-radius
// argument and against OCCT's own point overload of the same query. No family answers the point
// question:
//
//   GccAna_Circ2dBisec        4 solutions where the point overload gives 2, each duplicated; with
//                             both radii 0, two of the three solutions are hyperbolas of major
//                             radius 0, which occtValidHyperbolaRadii rejects on construction
//   GccAna_CircPnt2dBisec     2 hyperbolas of major radius 0; the point/point answer is a LINE,
//                             so the returned type is wrong, not merely duplicated
//   GccAna_CircLin2dBisec     the point overload's parabola, twice
//   GccAna_Lin2dTanPar/Per    the point overload's single line, twice
//   GccAna_Lin2d2Tan          the point overload's single line, twice
//   GccAna_Circ2d3Tan         3 circles: the point overload's 4 solutions, each twice.
//                             2 circles + a point: 2 distinct solutions padded to 4.
//                             1 circle + 2 points: 0 solutions, where the all-points overload
//                             finds the circumscribed circle - the answer is lost outright
//   Extrema_ExtPElC2d         0 extrema; the distance the point reading asks for is lost
//   Extrema_ExtElC2d          the right distance, twice
//   IntAna2d_AnaIntersection  the right point, with ParamOnSecond() NaN, which the bridge writes
//                             straight into the caller's param2
//
// Every one of those families already has a point entry point in this same file
// (OCCTGccAnaPnt2dBisec, OCCTGccAnaLinPnt2dBisec, OCCTGccAnaLin2dTanParPt,
// OCCTGccAnaLin2dTanPerPtLin, OCCTGccAnaCirc2d3TanPoints, OCCTGccAnaLin2d2TanPntPnt and the mixed
// circle/point overloads), so the decision costs the caller no query: asking about a point has a
// spelling, and a degenerate circle is not it. Guard, per family, on the same evidence.
//
// Case 2 was already decided, just not everywhere: OCCTGccCircle2d2TanRad, OCCTGccCircle2dTanPtRad
// and OCCTGccCircle2d2PtRad each spelled `radius <= 0` inline. A requested radius of 0 makes
// GccAna_Circ2d2TanRad and GccAna_Circ2dTanOnRad hand back solution circles of radius 0, which is
// the degenerate geometry #514 refused to return. All seven now share one predicate.
//
// Case 3 is #514's decision applied to the four sites it did not reach. One of them,
// OCCTCurve2DMakeCircleParallel, needs the offset checked as well as the radius: measured, a
// radius-5 circle offset by -5 yields radius 0 and by -6 yields radius 1, so GC_MakeCircle2d takes
// the absolute value rather than refusing an offset that passes through the centre.

// One nearest-point answer behind every 2D entry point that wants the nearest solution:
// OCCTCurve2DProjectPoint, OCCTCurve2DProjectPoint2D, OCCTPoint2DDistanceToCurve and
// OCCTCurve2DNearestParameter. They were four independent constructions of the same algorithm with
// four different failure-signalling conventions bolted on separately (#413 unified the first
// three, #500 the fourth). It also gives those that lacked one an explicit null-handle guard
// rather than relying on catch(...) to absorb the dereference.
//
// #615 makes that one construction the RIGHT one, the treatment #539/#580 gave the 3D side and
// never gave this one. Geom2dAPI_ProjectPointOnCurve reports extrema, not minima, so LowerDistance
// is not the nearest point and NbPoints() == 0 is not "no nearest point". Measured, on the 2D twin
// of the geometry #539 named: a half circle of radius 5 queried from (0, -6) reported the far side
// of the arc at distance 11 where the truth is 7.81, and a point on the circle but off the arc,
// (3, -4), reported 10 where the truth is 4.47; a segment trimmed to [3, 8] queried at (100, 0)
// reported no projection at all where the truth is its own end, 92 away. Every 2D spelling was
// wrong the same way, so they agreed with each other and with nothing else.
//
// See occtNearestPointOnCurve2dRange (OCCTBridge_Internal.h) for the candidate set, and for the one
// source the 3D helper has that this one cannot: ShapeAnalysis_Curve has no 2D projection.
//
// CONSEQUENCE, and it is the point rather than a side effect: this no longer returns false for a
// point with no perpendicular foot. A point beyond the end of a bounded curve is nearest to that
// end, and a circle's centre is equidistant from every point on it, so both now answer, with a
// real parameter and a true distance. Each caller keeps its own documented sentinel for the case
// that remains: no curve to answer about. None of them may report failure through the parameter,
// since 0 is a legitimate parameter on any curve whose domain includes it.
//
// OCCTCurve2DProjectPointAll is the multi-solution sibling: it needs every extremum rather than
// the nearest one, so it constructs its own and is not routed through here. It therefore still
// reports nothing where these four now answer, and that is correct: "the extrema" and "the
// nearest point" have been different questions since #539, and on a bounded curve queried from
// beyond its end the answer to the first one is that there are none.
static bool occtNearestProjectionOnCurve2d(OCCTCurve2DRef  curve,
                                           const gp_Pnt2d& point,
                                           gp_Pnt2d*       outNearest,
                                           double*         outParameter,
                                           double*         outDistance)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    return occtNearestPointOnCurve2dRange(curve->curve,
                                          point,
                                          curve->curve->FirstParameter(),
                                          curve->curve->LastParameter(),
                                          outNearest,
                                          outParameter,
                                          outDistance);
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Batch Curve2D Evaluation (v0.28.0)

#include <Geom2dGridEval_Curve.hxx>
#include <Geom2dGridEval.hxx>

// The canonical 2D-curve batch evaluators. Two later generations duplicated this job under
// other names (v0.110's OCCTCurve2DEvalBatchD0/D1, which looped Geom2d_Curve::EvalD0/EvalD1
// per point and was defined over in OCCTBridge_Curve3D.mm; v0.111's OCCTGridEvalCurve2dD0/D1,
// the same Geom2dGridEval_Curve calls as here); #486 removed both and pointed their Swift
// spellings at these two.

int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                const double*  params,
                                int32_t        paramCount,
                                double*        outXY)
{
  if (!curve || curve->curve.IsNull() || !params || !outXY || paramCount <= 0)
    return 0;
  try
  {
    Geom2dGridEval_Curve       evaluator(curve->curve);
    NCollection_Array1<double> paramArr = occtGridEvalParams(params, paramCount);

    NCollection_Array1<gp_Pnt2d> results = evaluator.EvaluateGrid(paramArr);
    // Defensive: bound the write by the caller's buffer as well as by what OCCT returned.
    // Every evaluator in the pinned kernel returns exactly theParams.Length() or an empty
    // array (empty only for a null curve or empty params, both rejected above), so neither
    // direction is reachable today. Taking the min covers both anyway: a shorter result must
    // not be read past its end, and a longer one must not be written past outXY's end.
    int32_t n = std::min(paramCount, static_cast<int32_t>(results.Size()));
    for (int32_t i = 0; i < n; i++)
    {
      const gp_Pnt2d& pt = results.Value(i + 1);
      outXY[i * 2]       = pt.X();
      outXY[i * 2 + 1]   = pt.Y();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DEvaluateGridD1(OCCTCurve2DRef curve,
                                  const double*  params,
                                  int32_t        paramCount,
                                  double*        outXY,
                                  double*        outDXDY)
{
  if (!curve || curve->curve.IsNull() || !params || !outXY || !outDXDY || paramCount <= 0)
    return 0;
  try
  {
    Geom2dGridEval_Curve       evaluator(curve->curve);
    NCollection_Array1<double> paramArr = occtGridEvalParams(params, paramCount);

    NCollection_Array1<Geom2dGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
    int32_t n = std::min(paramCount, static_cast<int32_t>(results.Size())); // see EvaluateGrid
    for (int32_t i = 0; i < n; i++)
    {
      const Geom2dGridEval::CurveD1& r = results.Value(i + 1);
      outXY[i * 2]                     = r.Point.X();
      outXY[i * 2 + 1]                 = r.Point.Y();
      outDXDY[i * 2]                   = r.D1.X();
      outDXDY[i * 2 + 1]               = r.D1.Y();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Hatch Patterns (v0.29.0)

#include <Hatch_Hatcher.hxx>

int32_t OCCTHatchLines(const double* boundaryXY,
                       int32_t       boundaryCount,
                       double        dirX,
                       double        dirY,
                       double        spacing,
                       double        offset,
                       double*       outSegments,
                       int32_t       maxSegments)
{
  if (!boundaryXY || boundaryCount < 3 || !outSegments || maxSegments <= 0 || spacing <= 0.0)
    return 0;
  try
  {
    double tolerance = 1.0e-7;
    // Use unoriented mode so intervals are always finite
    Hatch_Hatcher hatcher(tolerance, false);

    // Compute perpendicular direction for hatch lines
    double dirLen = std::sqrt(dirX * dirX + dirY * dirY);
    if (dirLen < 1.0e-12)
      return 0;
    double ndx = dirX / dirLen;
    double ndy = dirY / dirLen;
    // Perpendicular: rotate 90 degrees
    double perpX = -ndy;
    double perpY = ndx;

    // Compute bounding range along perpendicular direction
    double minDist = 1.0e30, maxDist = -1.0e30;
    for (int32_t i = 0; i < boundaryCount; i++)
    {
      double px   = boundaryXY[i * 2];
      double py   = boundaryXY[i * 2 + 1];
      double dist = px * perpX + py * perpY;
      if (dist < minDist)
        minDist = dist;
      if (dist > maxDist)
        maxDist = dist;
    }

    // Add hatch lines using direction + distance form
    gp_Dir2d hatchDir(ndx, ndy);
    double   startDist = std::floor((minDist - offset) / spacing) * spacing + offset;
    for (double dist = startDist; dist <= maxDist; dist += spacing)
    {
      hatcher.AddLine(hatchDir, dist);
    }

    // Trim hatch lines with boundary segments
    for (int32_t i = 0; i < boundaryCount; i++)
    {
      int32_t  j = (i + 1) % boundaryCount;
      gp_Pnt2d p1(boundaryXY[i * 2], boundaryXY[i * 2 + 1]);
      gp_Pnt2d p2(boundaryXY[j * 2], boundaryXY[j * 2 + 1]);
      hatcher.Trim(p1, p2);
    }

    // Extract hatch segments
    int32_t segCount = 0;
    for (int lineIdx = 1; lineIdx <= hatcher.NbLines(); lineIdx++)
    {
      for (int intIdx = 1; intIdx <= hatcher.NbIntervals(lineIdx); intIdx++)
      {
        if (segCount >= maxSegments)
          break;
        double startParam = hatcher.Start(lineIdx, intIdx);
        double endParam   = hatcher.End(lineIdx, intIdx);
        // Convert parameter back to point using the line equation
        const gp_Lin2d& line = hatcher.Line(lineIdx);
        gp_Pnt2d        pt1  = line.Location().Translated(gp_Vec2d(line.Direction()) * startParam);
        gp_Pnt2d        pt2  = line.Location().Translated(gp_Vec2d(line.Direction()) * endParam);
        outSegments[segCount * 4]     = pt1.X();
        outSegments[segCount * 4 + 1] = pt1.Y();
        outSegments[segCount * 4 + 2] = pt2.X();
        outSegments[segCount * 4 + 3] = pt2.Y();
        segCount++;
      }
    }
    return segCount;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Hatching

#include <Geom2dHatch_Hatcher.hxx>
#include <Geom2dHatch_Intersector.hxx>
#include <HatchGen_Domain.hxx>

int32_t OCCTCurve2DHatch(const OCCTCurve2DRef* boundaries,
                         int32_t               boundaryCount,
                         double                originX,
                         double                originY,
                         double                dirX,
                         double                dirY,
                         double                spacing,
                         double                tolerance,
                         double*               outXY,
                         int32_t               maxPoints)
{
  if (!boundaries || boundaryCount <= 0 || !outXY || maxPoints <= 0 || spacing <= 0)
    return 0;
  try
  {
    Geom2dHatch_Intersector intersector(tolerance, tolerance);
    Geom2dHatch_Hatcher     hatcher(intersector, tolerance, tolerance);

    // Add boundary elements
    for (int32_t i = 0; i < boundaryCount; i++)
    {
      if (!boundaries[i] || boundaries[i]->curve.IsNull())
        continue;
      Geom2dAdaptor_Curve adaptor(boundaries[i]->curve);
      hatcher.AddElement(adaptor, TopAbs_FORWARD);
    }

    // Compute bounding box for hatch range
    Bnd_Box2d box;
    for (int32_t i = 0; i < boundaryCount; i++)
    {
      if (!boundaries[i] || boundaries[i]->curve.IsNull())
        continue;
      BndLib_Add2dCurve::Add(boundaries[i]->curve, 0.0, box);
    }
    if (box.IsVoid())
      return 0;

    double xMin, yMin, xMax, yMax;
    box.Get(xMin, yMin, xMax, yMax);
    double diag = sqrt((xMax - xMin) * (xMax - xMin) + (yMax - yMin) * (yMax - yMin));
    if (diag < tolerance)
      return 0;

    gp_Dir2d dir(dirX, dirY);
    gp_Dir2d perp(-dirY, dirX);
    gp_Pnt2d origin(originX, originY);

    // Compute perpendicular extent
    double minPerp = 1e100, maxPerp = -1e100;
    double corners[4][2] = {{xMin, yMin}, {xMax, yMin}, {xMax, yMax}, {xMin, yMax}};
    for (int i = 0; i < 4; i++)
    {
      double dx   = corners[i][0] - originX;
      double dy   = corners[i][1] - originY;
      double proj = dx * perp.X() + dy * perp.Y();
      if (proj < minPerp)
        minPerp = proj;
      if (proj > maxPerp)
        maxPerp = proj;
    }

    // Add hatch lines
    int              nLines = (int)((maxPerp - minPerp) / spacing) + 2;
    std::vector<int> hatchIndices;
    for (int i = 0; i < nLines; i++)
    {
      double              offset = minPerp + i * spacing;
      gp_Pnt2d            p(originX + perp.X() * offset, originY + perp.Y() * offset);
      gp_Lin2d            line(p, dir);
      Geom2dAdaptor_Curve lineAdaptor(new Geom2d_Line(line));
      int                 idx = hatcher.AddHatching(lineAdaptor);
      hatchIndices.push_back(idx);
    }

    hatcher.Trim();
    hatcher.ComputeDomains();

    // Extract hatch segments
    int32_t pointIdx = 0;
    for (int idx : hatchIndices)
    {
      if (!hatcher.IsDone(idx))
        continue;
      int nDomains = hatcher.NbDomains(idx);
      for (int d = 1; d <= nDomains; d++)
      {
        HatchGen_Domain domain = hatcher.Domain(idx, d);
        if (!domain.HasFirstPoint() || !domain.HasSecondPoint())
          continue;
        double u1 = domain.FirstPoint().Parameter();
        double u2 = domain.SecondPoint().Parameter();
        // Get the hatch line curve
        const Geom2dAdaptor_Curve& hatchCurve = hatcher.HatchingCurve(idx);
        gp_Pnt2d                   p1         = hatchCurve.Value(u1);
        gp_Pnt2d                   p2         = hatchCurve.Value(u2);
        if (pointIdx + 4 > maxPoints * 2)
          break;
        outXY[pointIdx++] = p1.X();
        outXY[pointIdx++] = p1.Y();
        outXY[pointIdx++] = p2.X();
        outXY[pointIdx++] = p2.Y();
      }
    }
    return pointIdx / 4; // Each segment = 2 points = 4 doubles
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Bisector

#include <Bisector_BisecCC.hxx>
#include <Bisector_BisecPC.hxx>

OCCTCurve2DRef OCCTCurve2DBisectorCC(OCCTCurve2DRef c1,
                                     OCCTCurve2DRef c2,
                                     double         originX,
                                     double         originY,
                                     bool           side)
{
  if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Bisector_BisecCC) bisector = new Bisector_BisecCC();
    gp_Pnt2d                 origin(originX, originY);
    double                   s = side ? 1.0 : -1.0;
    bisector->Perform(c1->curve, c2->curve, s, s, origin);
    if (bisector->IsEmpty())
      return nullptr;
    // Return as Geom2d_Curve (Bisector_BisecCC inherits from Geom2d_Curve)
    Handle(Geom2d_Curve) result = bisector;
    return new OCCTCurve2D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #999: this took an originX/originY copied from OCCTCurve2DBisectorCC above, where the origin is
// real (Bisector_BisecCC::Perform takes one and this bridge passes it). Bisector_BisecPC::Perform
// is (Cu, P, Side, DistMax) and has no origin. DistMax is the parameter it does have, and it is
// live: measured on a point 4 above a line, DistMax 1 gives an empty bisector, and 10, 100, 500
// and 5000 give parameter ranges [-8, 8], [-28, 28], [-63.12, 63.12] and [-199.96, 199.96].
// See Scripts/repro/999-geom2d-curve3d-healing/parameterisation_and_bisector.mm.
OCCTCurve2DRef OCCTCurve2DBisectorPC(double         px,
                                     double         py,
                                     OCCTCurve2DRef curve,
                                     double         maxDistance,
                                     bool           side)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Bisector_BisecPC) bisector = new Bisector_BisecPC();
    gp_Pnt2d                 point(px, py);
    bisector->Perform(curve->curve, point, side ? 1.0 : -1.0, maxDistance);
    if (bisector->IsEmpty())
      return nullptr;
    Handle(Geom2d_Curve) result = bisector;
    return new OCCTCurve2D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - BRepMAT2d: Medial Axis Transform (v0.24.0)

#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <BRepMAT2d_LinkTopoBilo.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Arc.hxx>
#include <MAT_Node.hxx>
#include <MAT_BasicElt.hxx>
#include <MAT_SequenceOfArc.hxx>
#include <MAT_SequenceOfBasicElt.hxx>
#include <Bisector_Bisec.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2d_Curve.hxx>

struct OCCTMedialAxis
{
  BRepMAT2d_BisectingLocus locus;
  BRepMAT2d_Explorer       explorer;
  Handle(MAT_Graph)        graph;
  // Cached boundary curves for distance computation
  std::vector<Handle(Geom2d_Curve)> boundaryCurves;

  // Compute distance from a 2D point to the nearest boundary curve
  double distanceToBoundary(const gp_Pnt2d& pt) const
  {
    double minDist = std::numeric_limits<double>::max();
    for (const auto& curve : boundaryCurves)
    {
      if (curve.IsNull())
        continue;
      try
      {
        Geom2dAPI_ProjectPointOnCurve proj(pt, curve);
        if (proj.NbPoints() > 0)
        {
          double d = proj.LowerDistance();
          if (d < minDist)
            minDist = d;
        }
      }
      catch (...)
      {
        continue;
      }
    }
    return (minDist < std::numeric_limits<double>::max()) ? minDist : 0.0;
  }
};

// #443 audit: first face only. A medial axis is a property of one face, and the result type
// holds one graph, so widening this would mean a different return shape; documented on
// MedialAxis.init(of:) rather than changed. Measured: a two-face compound returns the same
// arcs as its first face alone.
// #999: this took a tolerance neither BRepMAT2d_Explorer::Perform nor
// BRepMAT2d_BisectingLocus::Compute accepts. Compute's real knobs are LineIndex, aSide, aJoinType
// and IsOpenResult, all left at the OCCT defaults spelled out in the call below.
OCCTMedialAxisRef OCCTMedialAxisCompute(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    // Extract the first face from the shape
    TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
    if (!faceExp.More())
      return nullptr;
    TopoDS_Face face = TopoDS::Face(faceExp.Current());

    auto ma = new OCCTMedialAxis();
    ma->explorer.Perform(face);

    ma->locus.Compute(ma->explorer, 1, MAT_Left, GeomAbs_Arc, Standard_False);
    if (!ma->locus.IsDone())
    {
      delete ma;
      return nullptr;
    }

    ma->graph = ma->locus.Graph();
    if (ma->graph.IsNull() || ma->graph->NumberOfArcs() == 0)
    {
      delete ma;
      return nullptr;
    }

    // Cache boundary curves for distance computation
    int numContours = ma->explorer.NumberOfContours();
    for (int c = 1; c <= numContours; c++)
    {
      ma->explorer.Init(c);
      while (ma->explorer.More())
      {
        Handle(Geom2d_Curve) curve = ma->explorer.Value();
        if (!curve.IsNull())
        {
          ma->boundaryCurves.push_back(curve);
        }
        ma->explorer.Next();
      }
    }

    return ma;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTMedialAxisRelease(OCCTMedialAxisRef ma)
{
  delete ma;
}

int32_t OCCTMedialAxisGetArcCount(OCCTMedialAxisRef ma)
{
  if (!ma || ma->graph.IsNull())
    return 0;
  return (int32_t)ma->graph->NumberOfArcs();
}

int32_t OCCTMedialAxisGetNodeCount(OCCTMedialAxisRef ma)
{
  if (!ma || ma->graph.IsNull())
    return 0;
  return (int32_t)ma->graph->NumberOfNodes();
}

bool OCCTMedialAxisGetNode(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisNode* outNode)
{
  if (!ma || !outNode || ma->graph.IsNull())
    return false;
  if (index < 1 || index > ma->graph->NumberOfNodes())
    return false;
  try
  {
    Handle(MAT_Node) node = ma->graph->Node(index);
    if (node.IsNull())
      return false;

    gp_Pnt2d pt    = ma->locus.GeomElt(node);
    outNode->index = index;
    outNode->x     = pt.X();
    outNode->y     = pt.Y();
    // Compute distance from node to nearest boundary curve
    outNode->distance     = ma->distanceToBoundary(pt);
    outNode->isPending    = node->PendingNode();
    outNode->isOnBoundary = node->OnBasicElt();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMedialAxisGetArc(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisArc* outArc)
{
  if (!ma || !outArc || ma->graph.IsNull())
    return false;
  if (index < 1 || index > ma->graph->NumberOfArcs())
    return false;
  try
  {
    Handle(MAT_Arc) arc = ma->graph->Arc(index);
    if (arc.IsNull())
      return false;

    outArc->index           = arc->Index();
    outArc->geomIndex       = arc->GeomIndex();
    outArc->firstNodeIndex  = arc->FirstNode()->Index();
    outArc->secondNodeIndex = arc->SecondNode()->Index();
    outArc->firstEltIndex   = arc->FirstElement()->Index();
    outArc->secondEltIndex  = arc->SecondElement()->Index();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTMedialAxisDrawArc(OCCTMedialAxisRef ma,
                              int32_t           arcIndex,
                              double*           outXY,
                              int32_t           maxPoints)
{
  if (!ma || !outXY || maxPoints < 2 || ma->graph.IsNull())
    return 0;
  if (arcIndex < 1 || arcIndex > ma->graph->NumberOfArcs())
    return 0;
  try
  {
    Handle(MAT_Arc) arc = ma->graph->Arc(arcIndex);
    if (arc.IsNull())
      return 0;

    Standard_Boolean            reverse = Standard_False;
    Bisector_Bisec              bisec   = ma->locus.GeomBis(arc, reverse);
    Handle(Geom2d_TrimmedCurve) trimmed = bisec.Value();
    if (trimmed.IsNull())
      return 0;

    double u0 = trimmed->FirstParameter();
    double u1 = trimmed->LastParameter();

    // Clamp infinite parameters
    if (Precision::IsNegativeInfinite(u0))
      u0 = -1000.0;
    if (Precision::IsPositiveInfinite(u1))
      u1 = 1000.0;

    // Get node positions as fallback endpoints
    gp_Pnt2d firstPt = ma->locus.GeomElt(arc->FirstNode());
    gp_Pnt2d lastPt  = ma->locus.GeomElt(arc->SecondNode());

    int32_t numPoints = maxPoints;
    for (int32_t i = 0; i < numPoints; i++)
    {
      double t = (numPoints > 1) ? (double)i / (numPoints - 1) : 0.0;
      double u = u0 + t * (u1 - u0);
      try
      {
        gp_Pnt2d pt;
        trimmed->D0(u, pt);
        outXY[i * 2 + 0] = pt.X();
        outXY[i * 2 + 1] = pt.Y();
      }
      catch (...)
      {
        // Fallback: interpolate between node positions
        double tx        = firstPt.X() + t * (lastPt.X() - firstPt.X());
        double ty        = firstPt.Y() + t * (lastPt.Y() - firstPt.Y());
        outXY[i * 2 + 0] = tx;
        outXY[i * 2 + 1] = ty;
      }
    }
    return numPoints;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTMedialAxisDrawAll(OCCTMedialAxisRef ma,
                              double*           outXY,
                              int32_t           maxPoints,
                              int32_t*          lineStarts,
                              int32_t*          lineLengths,
                              int32_t           maxLines)
{
  if (!ma || !outXY || !lineStarts || !lineLengths || ma->graph.IsNull())
    return 0;
  int32_t arcCount = (int32_t)ma->graph->NumberOfArcs();
  if (arcCount == 0)
    return 0;

  int32_t pointsPerArc = maxPoints / std::max(arcCount, (int32_t)1);
  if (pointsPerArc < 2)
    pointsPerArc = 2;

  int32_t totalPoints = 0;
  int32_t lineCount   = 0;

  for (int32_t i = 1; i <= arcCount && lineCount < maxLines; i++)
  {
    int32_t remaining = maxPoints - totalPoints;
    int32_t pts       = std::min(pointsPerArc, remaining);
    if (pts < 2)
      break;

    int32_t drawn = OCCTMedialAxisDrawArc(ma, i, outXY + totalPoints * 2, pts);
    if (drawn > 0)
    {
      lineStarts[lineCount]  = totalPoints;
      lineLengths[lineCount] = drawn;
      lineCount++;
      totalPoints += drawn;
    }
  }
  return totalPoints;
}

double OCCTMedialAxisDistanceOnArc(OCCTMedialAxisRef ma, int32_t arcIndex, double t)
{
  if (!ma || ma->graph.IsNull())
    return -1.0;
  if (arcIndex < 1 || arcIndex > ma->graph->NumberOfArcs())
    return -1.0;
  try
  {
    Handle(MAT_Arc) arc = ma->graph->Arc(arcIndex);
    if (arc.IsNull())
      return -1.0;

    // Compute boundary distances at both endpoints
    gp_Pnt2d pt1 = ma->locus.GeomElt(arc->FirstNode());
    gp_Pnt2d pt2 = ma->locus.GeomElt(arc->SecondNode());
    double   d1  = ma->distanceToBoundary(pt1);
    double   d2  = ma->distanceToBoundary(pt2);

    // Linear interpolation between node distances
    t = std::max(0.0, std::min(1.0, t));
    return d1 + t * (d2 - d1);
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTMedialAxisMinThickness(OCCTMedialAxisRef ma)
{
  if (!ma || ma->graph.IsNull())
    return -1.0;
  try
  {
    double  minDist   = std::numeric_limits<double>::max();
    int32_t nodeCount = (int32_t)ma->graph->NumberOfNodes();
    for (int32_t i = 1; i <= nodeCount; i++)
    {
      Handle(MAT_Node) node = ma->graph->Node(i);
      if (!node.IsNull() && !node->Infinite())
      {
        gp_Pnt2d pt = ma->locus.GeomElt(node);
        double   d  = ma->distanceToBoundary(pt);
        if (d > 0 && d < minDist)
          minDist = d;
      }
    }
    return (minDist < std::numeric_limits<double>::max()) ? minDist : -1.0;
  }
  catch (...)
  {
    return -1.0;
  }
}

int32_t OCCTMedialAxisGetBasicEltCount(OCCTMedialAxisRef ma)
{
  if (!ma || ma->graph.IsNull())
    return 0;
  return (int32_t)ma->graph->NumberOfBasicElts();
}

// MARK: - GC_MakeLine2d (v0.51)
// --- GC_MakeLine2d ---

OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineThroughPoints(double p1x,
                                                          double p1y,
                                                          double p2x,
                                                          double p2y)
{
  try
  {
    GC_MakeLine2d ml(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y));
    if (!ml.IsDone())
      return nullptr;
    auto* curve  = new OCCTCurve2D();
    curve->curve = ml.Value();
    return curve;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineParallel(double px,
                                                     double py,
                                                     double dx,
                                                     double dy,
                                                     double distance)
{
  try
  {
    gp_Lin2d      lin(gp_Pnt2d(px, py), gp_Dir2d(dx, dy));
    GC_MakeLine2d ml(lin, distance);
    if (!ml.IsDone())
      return nullptr;
    auto* curve  = new OCCTCurve2D();
    curve->curve = ml.Value();
    return curve;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ShapeCustom_Curve2d (v0.52)
// --- ShapeCustom_Curve2d ---

bool OCCTCurve2DIsLinear(OCCTCurve2DRef curve2D, double tolerance, double* deviation)
{
  if (!curve2D || !deviation)
    return false;
  try
  {
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(curve2D->curve);
    if (bsp.IsNull())
      return false;
    TColgp_Array1OfPnt2d poles(1, bsp->NbPoles());
    for (int i = 1; i <= bsp->NbPoles(); i++)
    {
      poles(i) = bsp->Pole(i);
    }
    return ShapeCustom_Curve2d::IsLinear(poles, tolerance, *deviation);
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve2DRef _Nullable OCCTCurve2DConvertToLine(OCCTCurve2DRef curve2D,
                                                  double         first,
                                                  double         last,
                                                  double         tolerance,
                                                  double*        newFirst,
                                                  double*        newLast,
                                                  double*        deviation)
{
  if (!curve2D || curve2D->curve.IsNull() || !newFirst || !newLast || !deviation)
    return nullptr;
  try
  {
    Handle(Geom2d_Line) line = ShapeCustom_Curve2d::ConvertToLine2d(curve2D->curve,
                                                                    first,
                                                                    last,
                                                                    tolerance,
                                                                    *newFirst,
                                                                    *newLast,
                                                                    *deviation);
    if (line.IsNull())
      return nullptr;
    auto* result  = new OCCTCurve2D();
    result->curve = line;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTCurve2DSimplifyBSpline(OCCTCurve2DRef curve2D, double tolerance)
{
  if (!curve2D)
    return false;
  try
  {
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(curve2D->curve);
    if (bsp.IsNull())
      return false;
    return ShapeCustom_Curve2d::SimplifyBSpline2d(bsp, tolerance);
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Approx_Curve2d (v0.52)
// --- Approx_Curve2d ---

OCCTCurve2DRef _Nullable OCCTApproxCurve2d(OCCTCurve2DRef curve2D,
                                           double         first,
                                           double         last,
                                           double         tolU,
                                           double         tolV,
                                           int32_t        maxDegree,
                                           int32_t        maxSegments)
{
  if (!curve2D || curve2D->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Adaptor2d_Curve2d) adaptor = new Geom2dAdaptor_Curve(curve2D->curve, first, last);
    Approx_Curve2d approx(adaptor, first, last, tolU, tolV, GeomAbs_C2, maxDegree, maxSegments);
    if (!approx.IsDone() || !approx.HasResult())
      return nullptr;
    Handle(Geom2d_BSplineCurve) bsp = approx.Curve();
    if (bsp.IsNull())
      return nullptr;
    auto* result  = new OCCTCurve2D();
    result->curve = bsp;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Gcc Constraint Solver (v0.16)
// MARK: - Gcc Constraint Solver

static GccEnt_Position toGccPosition(int32_t q)
{
  switch (q)
  {
    case 1:
      return GccEnt_enclosing;
    case 2:
      return GccEnt_enclosed;
    case 3:
      return GccEnt_outside;
    default:
      return GccEnt_unqualified;
  }
}

// #556: no guard here by design. The return type has no null-safe value to fall back to, so the
// precondition lives in the callers: every one of them rejects a null pointer and a null handle
// before calling. Keep that true when adding a caller: Geom2dAdaptor_Curve::load() dereferences.
static Geom2dGcc_QualifiedCurve makeQualifiedCurve(OCCTCurve2DRef c, int32_t q)
{
  Geom2dAdaptor_Curve adaptor(c->curve);
  return Geom2dGcc_QualifiedCurve(adaptor, toGccPosition(q));
}

int32_t OCCTGccCircle2d3Tan(OCCTCurve2DRef         c1,
                            int32_t                q1,
                            OCCTCurve2DRef         c2,
                            int32_t                q2,
                            OCCTCurve2DRef         c3,
                            int32_t                q3,
                            double                 tolerance,
                            OCCTGccCircleSolution* out,
                            int32_t                max)
{
  if (!c1 || !c2 || !c3 || !out || max <= 0)
    return 0;
  if (c1->curve.IsNull() || c2->curve.IsNull() || c3->curve.IsNull())
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
    Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
    Geom2dGcc_QualifiedCurve qc3 = makeQualifiedCurve(c3, q3);
    Geom2dGcc_Circ2d3Tan     solver(qc1, qc2, qc3, tolerance, 0, 0, 0);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ = solver.ThisSolution(i + 1);
      out[i].cx      = circ.Location().X();
      out[i].cy      = circ.Location().Y();
      out[i].radius  = circ.Radius();
      GccEnt_Position qq1, qq2, qq3;
      solver.WhichQualifier(i + 1, qq1, qq2, qq3);
      out[i].qualifier = (int32_t)qq1;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccCircle2d2TanPt(OCCTCurve2DRef         c1,
                              int32_t                q1,
                              OCCTCurve2DRef         c2,
                              int32_t                q2,
                              double                 px,
                              double                 py,
                              double                 tolerance,
                              OCCTGccCircleSolution* out,
                              int32_t                max)
{
  if (!c1 || !c2 || !out || max <= 0)
    return 0;
  if (c1->curve.IsNull() || c2->curve.IsNull())
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve      qc1   = makeQualifiedCurve(c1, q1);
    Geom2dGcc_QualifiedCurve      qc2   = makeQualifiedCurve(c2, q2);
    Handle(Geom2d_CartesianPoint) point = new Geom2d_CartesianPoint(px, py);
    Geom2dGcc_Circ2d3Tan          solver(qc1, qc2, point, tolerance, 0, 0);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ   = solver.ThisSolution(i + 1);
      out[i].cx        = circ.Location().X();
      out[i].cy        = circ.Location().Y();
      out[i].radius    = circ.Radius();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccCircle2dTanCen(OCCTCurve2DRef         curve,
                              int32_t                qualifier,
                              double                 cx,
                              double                 cy,
                              double                 tolerance,
                              OCCTGccCircleSolution* out,
                              int32_t                max)
{
  if (!curve || curve->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve      qc     = makeQualifiedCurve(curve, qualifier);
    Handle(Geom2d_CartesianPoint) center = new Geom2d_CartesianPoint(cx, cy);
    Geom2dGcc_Circ2dTanCen        solver(qc, center, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ   = solver.ThisSolution(i + 1);
      out[i].cx        = circ.Location().X();
      out[i].cy        = circ.Location().Y();
      out[i].radius    = circ.Radius();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccCircle2d2TanRad(OCCTCurve2DRef         c1,
                               int32_t                q1,
                               OCCTCurve2DRef         c2,
                               int32_t                q2,
                               double                 radius,
                               double                 tolerance,
                               OCCTGccCircleSolution* out,
                               int32_t                max)
{
  if (!c1 || !c2 || !out || max <= 0)
    return 0;
  if (c1->curve.IsNull() || c2->curve.IsNull())
    return 0;
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
    Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
    Geom2dGcc_Circ2d2TanRad  solver(qc1, qc2, radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ   = solver.ThisSolution(i + 1);
      out[i].cx        = circ.Location().X();
      out[i].cy        = circ.Location().Y();
      out[i].radius    = circ.Radius();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccCircle2dTanPtRad(OCCTCurve2DRef         curve,
                                int32_t                qualifier,
                                double                 px,
                                double                 py,
                                double                 radius,
                                double                 tolerance,
                                OCCTGccCircleSolution* out,
                                int32_t                max)
{
  if (!curve || curve->curve.IsNull() || !out || max <= 0)
    return 0;
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve      qc    = makeQualifiedCurve(curve, qualifier);
    Handle(Geom2d_CartesianPoint) point = new Geom2d_CartesianPoint(px, py);
    Geom2dGcc_Circ2d2TanRad       solver(qc, point, radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ   = solver.ThisSolution(i + 1);
      out[i].cx        = circ.Location().X();
      out[i].cy        = circ.Location().Y();
      out[i].radius    = circ.Radius();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccCircle2d2PtRad(double                 p1x,
                              double                 p1y,
                              double                 p2x,
                              double                 p2y,
                              double                 radius,
                              double                 tolerance,
                              OCCTGccCircleSolution* out,
                              int32_t                max)
{
  if (!out || max <= 0 || !occtValidCircleRadius(radius))
    return 0;
  try
  {
    Handle(Geom2d_CartesianPoint) pt1 = new Geom2d_CartesianPoint(p1x, p1y);
    Handle(Geom2d_CartesianPoint) pt2 = new Geom2d_CartesianPoint(p2x, p2y);
    Geom2dGcc_Circ2d2TanRad       solver(pt1, pt2, radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ   = solver.ThisSolution(i + 1);
      out[i].cx        = circ.Location().X();
      out[i].cy        = circ.Location().Y();
      out[i].radius    = circ.Radius();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccCircle2d3Pt(double                 p1x,
                           double                 p1y,
                           double                 p2x,
                           double                 p2y,
                           double                 p3x,
                           double                 p3y,
                           double                 tolerance,
                           OCCTGccCircleSolution* out,
                           int32_t                max)
{
  if (!out || max <= 0)
    return 0;
  try
  {
    Handle(Geom2d_CartesianPoint) pt1 = new Geom2d_CartesianPoint(p1x, p1y);
    Handle(Geom2d_CartesianPoint) pt2 = new Geom2d_CartesianPoint(p2x, p2y);
    Handle(Geom2d_CartesianPoint) pt3 = new Geom2d_CartesianPoint(p3x, p3y);
    Geom2dGcc_Circ2d3Tan          solver(pt1, pt2, pt3, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Circ2d circ   = solver.ThisSolution(i + 1);
      out[i].cx        = circ.Location().X();
      out[i].cy        = circ.Location().Y();
      out[i].radius    = circ.Radius();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// Gcc Line Construction

int32_t OCCTGccLine2d2Tan(OCCTCurve2DRef       c1,
                          int32_t              q1,
                          OCCTCurve2DRef       c2,
                          int32_t              q2,
                          double               tolerance,
                          OCCTGccLineSolution* out,
                          int32_t              max)
{
  if (!c1 || !c2 || !out || max <= 0)
    return 0;
  if (c1->curve.IsNull() || c2->curve.IsNull())
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
    Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
    Geom2dGcc_Lin2d2Tan      solver(qc1, qc2, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Lin2d lin     = solver.ThisSolution(i + 1);
      out[i].px        = lin.Location().X();
      out[i].py        = lin.Location().Y();
      out[i].dx        = lin.Direction().X();
      out[i].dy        = lin.Direction().Y();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccLine2dTanPt(OCCTCurve2DRef       curve,
                           int32_t              qualifier,
                           double               px,
                           double               py,
                           double               tolerance,
                           OCCTGccLineSolution* out,
                           int32_t              max)
{
  if (!curve || curve->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    Geom2dGcc_QualifiedCurve qc = makeQualifiedCurve(curve, qualifier);
    gp_Pnt2d                 point(px, py);
    Geom2dGcc_Lin2d2Tan      solver(qc, point, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t n = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Lin2d lin     = solver.ThisSolution(i + 1);
      out[i].px        = lin.Location().X();
      out[i].py        = lin.Location().Y();
      out[i].dx        = lin.Direction().X();
      out[i].dy        = lin.Direction().Y();
      out[i].qualifier = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - 2D Geometry Completions: GccAna / Geom2dGcc / IntAna2d / Extrema 2D / GeomLProp /
// Bisector_BisecAna (v0.53) MARK: - v0.53.0: 2D Geometry Completions
// ============================================================================

#include <GccAna_Pnt2dBisec.hxx>
#include <GccAna_Lin2dBisec.hxx>
#include <GccAna_LinPnt2dBisec.hxx>
#include <GccAna_Circ2dBisec.hxx>
#include <GccAna_CircLin2dBisec.hxx>
#include <GccAna_CircPnt2dBisec.hxx>
#include <GccAna_Lin2dTanPar.hxx>
#include <GccAna_Lin2dTanPer.hxx>
#include <GccAna_Lin2dTanObl.hxx>
#include <GccAna_Circ2d2TanOn.hxx>
#include <GccAna_Circ2dTanOnRad.hxx>
#include <GccInt_Bisec.hxx>
#include <GccInt_IType.hxx>
#include <GccInt_BCirc.hxx>
#include <GccInt_BLine.hxx>
#include <GccInt_BElips.hxx>
#include <GccInt_BHyper.hxx>
#include <GccInt_BParab.hxx>
#include <Geom2dGcc_Circ2d2TanOn.hxx>
#include <Geom2dGcc_Circ2dTanOnRad.hxx>
#include <Geom2dGcc_Lin2dTanObl.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <Extrema_ExtElC2d.hxx>
#include <Extrema_ExtPElC2d.hxx>
#include <Extrema_ExtCC2d.hxx>
#include <Extrema_POnCurv2d.hxx>
#include <Bisector_BisecAna.hxx>
#include <GeomAbs_JoinType.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Hypr2d.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccEnt_QualifiedCirc.hxx>

// Helper to extract bisector solution from GccInt_Bisec
static void extractBisecSolution(const Handle(GccInt_Bisec)& bisec, OCCTBisecSolution* out)
{
  GccInt_IType type = bisec->ArcType();
  switch (type)
  {
    case GccInt_Lin: {
      gp_Lin2d lin = bisec->Line();
      out->type    = OCCTBisecTypeLine;
      out->px      = lin.Location().X();
      out->py      = lin.Location().Y();
      out->dx      = lin.Direction().X();
      out->dy      = lin.Direction().Y();
      out->radius  = 0;
      break;
    }
    case GccInt_Cir: {
      gp_Circ2d circ = bisec->Circle();
      out->type      = OCCTBisecTypeCircle;
      out->px        = circ.Location().X();
      out->py        = circ.Location().Y();
      out->dx        = 0;
      out->dy        = 0;
      out->radius    = circ.Radius();
      break;
    }
    case GccInt_Ell: {
      gp_Elips2d ell = bisec->Ellipse();
      out->type      = OCCTBisecTypeEllipse;
      out->px        = ell.Location().X();
      out->py        = ell.Location().Y();
      out->dx        = ell.MajorRadius();
      out->dy        = ell.MinorRadius();
      out->radius    = 0;
      break;
    }
    case GccInt_Hpr: {
      gp_Hypr2d hyp = bisec->Hyperbola();
      out->type     = OCCTBisecTypeHyperbola;
      out->px       = hyp.Location().X();
      out->py       = hyp.Location().Y();
      out->dx       = hyp.MajorRadius();
      out->dy       = hyp.MinorRadius();
      out->radius   = 0;
      break;
    }
    case GccInt_Par: {
      gp_Parab2d par = bisec->Parabola();
      out->type      = OCCTBisecTypeParabola;
      out->px        = par.Location().X();
      out->py        = par.Location().Y();
      out->dx        = par.Focal();
      out->dy        = 0;
      out->radius    = 0;
      break;
    }
    default: {
      out->type   = OCCTBisecTypePoint;
      out->px     = 0;
      out->py     = 0;
      out->dx     = 0;
      out->dy     = 0;
      out->radius = 0;
      break;
    }
  }
}

// --- GccAna_Pnt2dBisec ---
bool OCCTGccAnaPnt2dBisec(double  p1x,
                          double  p1y,
                          double  p2x,
                          double  p2y,
                          double* outPx,
                          double* outPy,
                          double* outDx,
                          double* outDy)
{
  try
  {
    GccAna_Pnt2dBisec bisec(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y));
    if (!bisec.HasSolution())
      return false;
    gp_Lin2d line = bisec.ThisSolution();
    *outPx        = line.Location().X();
    *outPy        = line.Location().Y();
    *outDx        = line.Direction().X();
    *outDy        = line.Direction().Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// --- GccAna_Lin2dBisec ---
int32_t OCCTGccAnaLin2dBisec(double               l1px,
                             double               l1py,
                             double               l1dx,
                             double               l1dy,
                             double               l2px,
                             double               l2py,
                             double               l2dx,
                             double               l2dy,
                             OCCTGccLineSolution* out,
                             int32_t              max)
{
  try
  {
    gp_Lin2d          l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d          l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    GccAna_Lin2dBisec bisec(l1, l2);
    if (!bisec.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol     = bisec.ThisSolution(i + 1);
      out[i].px        = sol.Location().X();
      out[i].py        = sol.Location().Y();
      out[i].dx        = sol.Direction().X();
      out[i].dy        = sol.Direction().Y();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_LinPnt2dBisec ---
bool OCCTGccAnaLinPnt2dBisec(double             lpx,
                             double             lpy,
                             double             ldx,
                             double             ldy,
                             double             px,
                             double             py,
                             OCCTBisecSolution* out)
{
  try
  {
    gp_Lin2d             line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccAna_LinPnt2dBisec bisec(line, gp_Pnt2d(px, py));
    if (!bisec.IsDone())
      return false;
    Handle(GccInt_Bisec) sol = bisec.ThisSolution();
    extractBisecSolution(sol, out);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// --- GccAna_Circ2dBisec ---
int32_t OCCTGccAnaCirc2dBisec(double             c1x,
                              double             c1y,
                              double             c1r,
                              double             c2x,
                              double             c2y,
                              double             c2r,
                              OCCTBisecSolution* out,
                              int32_t            max)
{
  if (!occtValidCircleRadius(c1r) || !occtValidCircleRadius(c2r))
    return 0;
  try
  {
    gp_Circ2d          circ1(gp_Ax22d(gp_Pnt2d(c1x, c1y), gp_Dir2d(1, 0)), c1r);
    gp_Circ2d          circ2(gp_Ax22d(gp_Pnt2d(c2x, c2y), gp_Dir2d(1, 0)), c2r);
    GccAna_Circ2dBisec bisec(circ1, circ2);
    if (!bisec.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      Handle(GccInt_Bisec) sol = bisec.ThisSolution(i + 1);
      extractBisecSolution(sol, &out[i]);
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_CircLin2dBisec ---
int32_t OCCTGccAnaCircLin2dBisec(double             cx,
                                 double             cy,
                                 double             cr,
                                 double             lpx,
                                 double             lpy,
                                 double             ldx,
                                 double             ldy,
                                 OCCTBisecSolution* out,
                                 int32_t            max)
{
  if (!occtValidCircleRadius(cr))
    return 0;
  try
  {
    gp_Circ2d             circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    gp_Lin2d              line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccAna_CircLin2dBisec bisec(circ, line);
    if (!bisec.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      Handle(GccInt_Bisec) sol = bisec.ThisSolution(i + 1);
      extractBisecSolution(sol, &out[i]);
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_CircPnt2dBisec ---
int32_t OCCTGccAnaCircPnt2dBisec(double             cx,
                                 double             cy,
                                 double             cr,
                                 double             px,
                                 double             py,
                                 OCCTBisecSolution* out,
                                 int32_t            max)
{
  if (!occtValidCircleRadius(cr))
    return 0;
  try
  {
    gp_Circ2d             circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    GccAna_CircPnt2dBisec bisec(circ, gp_Pnt2d(px, py));
    if (!bisec.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      Handle(GccInt_Bisec) sol = bisec.ThisSolution(i + 1);
      extractBisecSolution(sol, &out[i]);
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Lin2dTanPar (point version) ---
int32_t OCCTGccAnaLin2dTanParPt(double               px,
                                double               py,
                                double               lpx,
                                double               lpy,
                                double               ldx,
                                double               ldy,
                                OCCTGccLineSolution* out,
                                int32_t              max)
{
  try
  {
    gp_Pnt2d           pt(px, py);
    gp_Lin2d           ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccAna_Lin2dTanPar solver(pt, ref);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol     = solver.ThisSolution(i + 1);
      out[i].px        = sol.Location().X();
      out[i].py        = sol.Location().Y();
      out[i].dx        = sol.Direction().X();
      out[i].dy        = sol.Direction().Y();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Lin2dTanPar (circle version) ---
int32_t OCCTGccAnaLin2dTanParCirc(double               cx,
                                  double               cy,
                                  double               cr,
                                  int32_t              qualifier,
                                  double               lpx,
                                  double               lpy,
                                  double               ldx,
                                  double               ldy,
                                  OCCTGccLineSolution* out,
                                  int32_t              max)
{
  if (!occtValidCircleRadius(cr))
    return 0;
  try
  {
    gp_Circ2d            circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    gp_Lin2d             ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccEnt_QualifiedCirc qc(circ, toGccPosition(qualifier));
    GccAna_Lin2dTanPar   solver(qc, ref);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol = solver.ThisSolution(i + 1);
      out[i].px    = sol.Location().X();
      out[i].py    = sol.Location().Y();
      out[i].dx    = sol.Direction().X();
      out[i].dy    = sol.Direction().Y();
      GccEnt_Position pos;
      solver.WhichQualifier(i + 1, pos);
      out[i].qualifier = (int32_t)pos;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Lin2dTanPer (point + line version) ---
int32_t OCCTGccAnaLin2dTanPerPtLin(double               px,
                                   double               py,
                                   double               lpx,
                                   double               lpy,
                                   double               ldx,
                                   double               ldy,
                                   OCCTGccLineSolution* out,
                                   int32_t              max)
{
  try
  {
    gp_Pnt2d           pt(px, py);
    gp_Lin2d           ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccAna_Lin2dTanPer solver(pt, ref);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol     = solver.ThisSolution(i + 1);
      out[i].px        = sol.Location().X();
      out[i].py        = sol.Location().Y();
      out[i].dx        = sol.Direction().X();
      out[i].dy        = sol.Direction().Y();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Lin2dTanPer (circle + line version) ---
int32_t OCCTGccAnaLin2dTanPerCircLin(double               cx,
                                     double               cy,
                                     double               cr,
                                     int32_t              qualifier,
                                     double               lpx,
                                     double               lpy,
                                     double               ldx,
                                     double               ldy,
                                     OCCTGccLineSolution* out,
                                     int32_t              max)
{
  if (!occtValidCircleRadius(cr))
    return 0;
  try
  {
    gp_Circ2d            circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    gp_Lin2d             ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccEnt_QualifiedCirc qc(circ, toGccPosition(qualifier));
    GccAna_Lin2dTanPer   solver(qc, ref);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol = solver.ThisSolution(i + 1);
      out[i].px    = sol.Location().X();
      out[i].py    = sol.Location().Y();
      out[i].dx    = sol.Direction().X();
      out[i].dy    = sol.Direction().Y();
      GccEnt_Position pos;
      solver.WhichQualifier(i + 1, pos);
      out[i].qualifier = (int32_t)pos;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Lin2dTanObl (point version) ---
int32_t OCCTGccAnaLin2dTanOblPt(double               px,
                                double               py,
                                double               lpx,
                                double               lpy,
                                double               ldx,
                                double               ldy,
                                double               angle,
                                OCCTGccLineSolution* out,
                                int32_t              max)
{
  try
  {
    gp_Pnt2d           pt(px, py);
    gp_Lin2d           ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccAna_Lin2dTanObl solver(pt, ref, angle);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol     = solver.ThisSolution(i + 1);
      out[i].px        = sol.Location().X();
      out[i].py        = sol.Location().Y();
      out[i].dx        = sol.Direction().X();
      out[i].dy        = sol.Direction().Y();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- Geom2dGcc_Lin2dTanObl ---
int32_t OCCTGeom2dGccLin2dTanObl(OCCTCurve2DRef       curve,
                                 int32_t              qualifier,
                                 double               lpx,
                                 double               lpy,
                                 double               ldx,
                                 double               ldy,
                                 double               tolerance,
                                 double               angle,
                                 OCCTGccLineSolution* out,
                                 int32_t              max)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    Geom2dAdaptor_Curve      adaptor(curve->curve);
    Geom2dGcc_QualifiedCurve qc(adaptor, toGccPosition(qualifier));
    gp_Lin2d                 ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    Geom2dGcc_Lin2dTanObl    solver(qc, ref, tolerance, angle);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Lin2d sol = solver.ThisSolution(i + 1);
      out[i].px    = sol.Location().X();
      out[i].py    = sol.Location().Y();
      out[i].dx    = sol.Direction().X();
      out[i].dy    = sol.Direction().Y();
      GccEnt_Position pos;
      solver.WhichQualifier(i + 1, pos);
      out[i].qualifier = (int32_t)pos;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Circ2d2TanOn (2 qualified lines, center on line) ---
int32_t OCCTGccAnaCirc2d2TanOnLinLin(double                 l1px,
                                     double                 l1py,
                                     double                 l1dx,
                                     double                 l1dy,
                                     int32_t                q1,
                                     double                 l2px,
                                     double                 l2py,
                                     double                 l2dx,
                                     double                 l2dy,
                                     int32_t                q2,
                                     double                 onPx,
                                     double                 onPy,
                                     double                 onDx,
                                     double                 onDy,
                                     double                 tolerance,
                                     OCCTGccCircleSolution* out,
                                     int32_t                max)
{
  try
  {
    gp_Lin2d            l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d            l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    gp_Lin2d            onLine(gp_Pnt2d(onPx, onPy), gp_Dir2d(onDx, onDy));
    GccEnt_QualifiedLin ql1(l1, toGccPosition(q1));
    GccEnt_QualifiedLin ql2(l2, toGccPosition(q2));
    GccAna_Circ2d2TanOn solver(ql1, ql2, onLine, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Circ2d sol    = solver.ThisSolution(i + 1);
      out[i].cx        = sol.Location().X();
      out[i].cy        = sol.Location().Y();
      out[i].radius    = sol.Radius();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- GccAna_Circ2dTanOnRad (qualified line, center on line, given radius) ---
int32_t OCCTGccAnaCirc2dTanOnRadLin(double                 lpx,
                                    double                 lpy,
                                    double                 ldx,
                                    double                 ldy,
                                    int32_t                qualifier,
                                    double                 onPx,
                                    double                 onPy,
                                    double                 onDx,
                                    double                 onDy,
                                    double                 radius,
                                    double                 tolerance,
                                    OCCTGccCircleSolution* out,
                                    int32_t                max)
{
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    gp_Lin2d              l1(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    gp_Lin2d              onLine(gp_Pnt2d(onPx, onPy), gp_Dir2d(onDx, onDy));
    GccEnt_QualifiedLin   ql1(l1, toGccPosition(qualifier));
    GccAna_Circ2dTanOnRad solver(ql1, onLine, radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Circ2d sol    = solver.ThisSolution(i + 1);
      out[i].cx        = sol.Location().X();
      out[i].cy        = sol.Location().Y();
      out[i].radius    = sol.Radius();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- Geom2dGcc_Circ2d2TanOn ---
int32_t OCCTGeom2dGccCirc2d2TanOn(OCCTCurve2DRef         c1,
                                  int32_t                q1,
                                  OCCTCurve2DRef         c2,
                                  int32_t                q2,
                                  OCCTCurve2DRef         onCurve,
                                  double                 tolerance,
                                  double                 initParam1,
                                  double                 initParam2,
                                  double                 initParamOn,
                                  OCCTGccCircleSolution* out,
                                  int32_t                max)
{
  if (!c1 || !c2 || !onCurve)
    return 0;
  if (c1->curve.IsNull() || c2->curve.IsNull() || onCurve->curve.IsNull())
    return 0;
  try
  {
    Geom2dAdaptor_Curve      ac1(c1->curve), ac2(c2->curve), aon(onCurve->curve);
    Geom2dGcc_QualifiedCurve qc1(ac1, toGccPosition(q1));
    Geom2dGcc_QualifiedCurve qc2(ac2, toGccPosition(q2));
    Geom2dGcc_Circ2d2TanOn   solver(qc1, qc2, aon, tolerance, initParam1, initParam2, initParamOn);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Circ2d sol    = solver.ThisSolution(i + 1);
      out[i].cx        = sol.Location().X();
      out[i].cy        = sol.Location().Y();
      out[i].radius    = sol.Radius();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- Geom2dGcc_Circ2dTanOnRad ---
int32_t OCCTGeom2dGccCirc2dTanOnRad(OCCTCurve2DRef         curve,
                                    int32_t                qualifier,
                                    OCCTCurve2DRef         onCurve,
                                    double                 radius,
                                    double                 tolerance,
                                    OCCTGccCircleSolution* out,
                                    int32_t                max)
{
  if (!curve || !onCurve || curve->curve.IsNull() || onCurve->curve.IsNull())
    return 0;
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    Geom2dAdaptor_Curve      ac(curve->curve), aon(onCurve->curve);
    Geom2dGcc_QualifiedCurve qc(ac, toGccPosition(qualifier));
    Geom2dGcc_Circ2dTanOnRad solver(qc, aon, radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Circ2d sol    = solver.ThisSolution(i + 1);
      out[i].cx        = sol.Location().X();
      out[i].cy        = sol.Location().Y();
      out[i].radius    = sol.Radius();
      out[i].qualifier = 0;
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- IntAna2d_AnaIntersection: Line-Line ---
int32_t OCCTIntAna2dLinLin(double             l1px,
                           double             l1py,
                           double             l1dx,
                           double             l1dy,
                           double             l2px,
                           double             l2py,
                           double             l2dx,
                           double             l2dy,
                           OCCTIntAna2dPoint* out,
                           int32_t            max)
{
  try
  {
    gp_Lin2d                 l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d                 l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    IntAna2d_AnaIntersection inter(l1, l2);
    if (!inter.IsDone() || inter.IsEmpty())
      return 0;
    int32_t nb = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      const IntAna2d_IntPoint& pt = inter.Point(i + 1);
      out[i].x                    = pt.Value().X();
      out[i].y                    = pt.Value().Y();
      out[i].param1               = pt.ParamOnFirst();
      out[i].param2               = pt.ParamOnSecond();
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- IntAna2d_AnaIntersection: Line-Circle ---
int32_t OCCTIntAna2dLinCirc(double             lpx,
                            double             lpy,
                            double             ldx,
                            double             ldy,
                            double             cx,
                            double             cy,
                            double             cr,
                            OCCTIntAna2dPoint* out,
                            int32_t            max)
{
  if (!occtValidCircleRadius(cr))
    return 0;
  try
  {
    gp_Lin2d                 line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    gp_Circ2d                circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    IntAna2d_AnaIntersection inter(line, circ);
    if (!inter.IsDone() || inter.IsEmpty())
      return 0;
    int32_t nb = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      const IntAna2d_IntPoint& pt = inter.Point(i + 1);
      out[i].x                    = pt.Value().X();
      out[i].y                    = pt.Value().Y();
      out[i].param1               = pt.ParamOnFirst();
      out[i].param2               = pt.ParamOnSecond();
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- IntAna2d_AnaIntersection: Circle-Circle ---
int32_t OCCTIntAna2dCircCirc(double             c1x,
                             double             c1y,
                             double             c1r,
                             double             c2x,
                             double             c2y,
                             double             c2r,
                             OCCTIntAna2dPoint* out,
                             int32_t            max)
{
  if (!occtValidCircleRadius(c1r) || !occtValidCircleRadius(c2r))
    return 0;
  try
  {
    gp_Circ2d                circ1(gp_Ax22d(gp_Pnt2d(c1x, c1y), gp_Dir2d(1, 0)), c1r);
    gp_Circ2d                circ2(gp_Ax22d(gp_Pnt2d(c2x, c2y), gp_Dir2d(1, 0)), c2r);
    IntAna2d_AnaIntersection inter(circ1, circ2);
    if (!inter.IsDone() || inter.IsEmpty())
      return 0;
    int32_t nb = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      const IntAna2d_IntPoint& pt = inter.Point(i + 1);
      out[i].x                    = pt.Value().X();
      out[i].y                    = pt.Value().Y();
      out[i].param1               = pt.ParamOnFirst();
      out[i].param2               = pt.ParamOnSecond();
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

// --- Extrema_ExtElC2d: Line-Line ---
int32_t OCCTExtremaExtElC2dLinLin(double               l1px,
                                  double               l1py,
                                  double               l1dx,
                                  double               l1dy,
                                  double               l2px,
                                  double               l2py,
                                  double               l2dx,
                                  double               l2dy,
                                  double               tolerance,
                                  bool*                outIsParallel,
                                  OCCTExtrema2dResult* out,
                                  int32_t              max)
{
  try
  {
    gp_Lin2d         l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d         l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    Extrema_ExtElC2d ext(l1, l2, tolerance);
    if (!ext.IsDone())
      return -1;
    *outIsParallel = ext.IsParallel();
    if (ext.IsParallel())
    {
      if (max >= 1)
      {
        out[0].squareDistance = ext.SquareDistance(1);
        out[0].param1         = 0;
        out[0].param2         = 0;
        out[0].p1x            = l1px;
        out[0].p1y            = l1py;
        out[0].p2x            = l2px;
        out[0].p2y            = l2py;
        return 1;
      }
      return 0;
    }
    int32_t nb = std::min((int32_t)ext.NbExt(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      out[i].squareDistance = ext.SquareDistance(i + 1);
      Extrema_POnCurv2d p1, p2;
      ext.Points(i + 1, p1, p2);
      out[i].param1 = p1.Parameter();
      out[i].param2 = p2.Parameter();
      out[i].p1x    = p1.Value().X();
      out[i].p1y    = p1.Value().Y();
      out[i].p2x    = p2.Value().X();
      out[i].p2y    = p2.Value().Y();
    }
    return nb;
  }
  catch (...)
  {
    return -1;
  }
}

// --- Extrema_ExtElC2d: Line-Circle ---
int32_t OCCTExtremaExtElC2dLinCirc(double               lpx,
                                   double               lpy,
                                   double               ldx,
                                   double               ldy,
                                   double               cx,
                                   double               cy,
                                   double               cr,
                                   double               tolerance,
                                   OCCTExtrema2dResult* out,
                                   int32_t              max)
{
  if (!occtValidCircleRadius(cr))
    return -1;
  try
  {
    gp_Lin2d         line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    gp_Circ2d        circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    Extrema_ExtElC2d ext(line, circ, tolerance);
    if (!ext.IsDone())
      return -1;
    int32_t nb = std::min((int32_t)ext.NbExt(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      out[i].squareDistance = ext.SquareDistance(i + 1);
      Extrema_POnCurv2d p1, p2;
      ext.Points(i + 1, p1, p2);
      out[i].param1 = p1.Parameter();
      out[i].param2 = p2.Parameter();
      out[i].p1x    = p1.Value().X();
      out[i].p1y    = p1.Value().Y();
      out[i].p2x    = p2.Value().X();
      out[i].p2y    = p2.Value().Y();
    }
    return nb;
  }
  catch (...)
  {
    return -1;
  }
}

// --- Extrema_ExtPElC2d: Point-Circle ---
int32_t OCCTExtremaExtPElC2dCirc(double               px,
                                 double               py,
                                 double               cx,
                                 double               cy,
                                 double               cr,
                                 double               tolerance,
                                 OCCTExtrema2dResult* out,
                                 int32_t              max)
{
  if (!occtValidCircleRadius(cr))
    return -1;
  try
  {
    gp_Pnt2d          pt(px, py);
    gp_Circ2d         circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    Extrema_ExtPElC2d ext(pt, circ, tolerance, 0, 2 * M_PI);
    if (!ext.IsDone())
      return -1;
    int32_t nb = std::min((int32_t)ext.NbExt(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      out[i].squareDistance = ext.SquareDistance(i + 1);
      Extrema_POnCurv2d pc  = ext.Point(i + 1);
      out[i].param1         = 0;
      out[i].param2         = pc.Parameter();
      out[i].p1x            = px;
      out[i].p1y            = py;
      out[i].p2x            = pc.Value().X();
      out[i].p2y            = pc.Value().Y();
    }
    return nb;
  }
  catch (...)
  {
    return -1;
  }
}

// --- Extrema_ExtPElC2d: Point-Line ---
int32_t OCCTExtremaExtPElC2dLin(double               px,
                                double               py,
                                double               lpx,
                                double               lpy,
                                double               ldx,
                                double               ldy,
                                double               tolerance,
                                OCCTExtrema2dResult* out,
                                int32_t              max)
{
  try
  {
    gp_Pnt2d pt(px, py);
    gp_Lin2d line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    // The 2D sibling of the Extrema_ExtPElC sites in OCCTBridge_Curve3D.mm (#1020). A line is
    // unbounded and Uinf/Usup post-filter an answer Extrema has already computed, so a finite
    // bound can only discard a correct result. RealFirst()/RealLast() admits every
    // representable parameter, matching OCCT's own unbounded-conic call sites.
    Extrema_ExtPElC2d ext(pt, line, tolerance, RealFirst(), RealLast());
    if (!ext.IsDone())
      return -1;
    int32_t nb = std::min((int32_t)ext.NbExt(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      out[i].squareDistance = ext.SquareDistance(i + 1);
      Extrema_POnCurv2d pc  = ext.Point(i + 1);
      out[i].param1         = 0;
      out[i].param2         = pc.Parameter();
      out[i].p1x            = px;
      out[i].p1y            = py;
      out[i].p2x            = pc.Value().X();
      out[i].p2y            = pc.Value().Y();
    }
    return nb;
  }
  catch (...)
  {
    return -1;
  }
}

// --- Extrema_ExtCC2d ---
int32_t OCCTExtremaExtCC2d(OCCTCurve2DRef       c1,
                           double               first1,
                           double               last1,
                           OCCTCurve2DRef       c2,
                           double               first2,
                           double               last2,
                           OCCTExtrema2dResult* out,
                           int32_t              max)
{
  if (!c1 || !c2 || c1->curve.IsNull() || c2->curve.IsNull())
    return -1;
  try
  {
    Geom2dAdaptor_Curve ac1(c1->curve, first1, last1);
    Geom2dAdaptor_Curve ac2(c2->curve, first2, last2);
    Extrema_ExtCC2d     ext(ac1, ac2);
    if (!ext.IsDone())
      return -1;
    int32_t nb = std::min((int32_t)ext.NbExt(), max);
    for (int32_t i = 0; i < nb; i++)
    {
      out[i].squareDistance = ext.SquareDistance(i + 1);
      Extrema_POnCurv2d p1, p2;
      ext.Points(i + 1, p1, p2);
      out[i].param1 = p1.Parameter();
      out[i].param2 = p2.Parameter();
      out[i].p1x    = p1.Value().X();
      out[i].p1y    = p1.Value().Y();
      out[i].p2x    = p2.Value().X();
      out[i].p2y    = p2.Value().Y();
    }
    return nb;
  }
  catch (...)
  {
    return -1;
  }
}

// --- Bisector_BisecAna ---
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurveCurve(OCCTCurve2DRef curve1,
                                                        OCCTCurve2DRef curve2,
                                                        double         px,
                                                        double         py,
                                                        double         v1x,
                                                        double         v1y,
                                                        double         v2x,
                                                        double         v2y,
                                                        double         sense,
                                                        double         tolerance)
{
  if (!curve1 || !curve2 || curve1->curve.IsNull() || curve2->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Bisector_BisecAna) bisec = new Bisector_BisecAna();
    bisec->Perform(curve1->curve,
                   curve2->curve,
                   gp_Pnt2d(px, py),
                   gp_Vec2d(v1x, v1y),
                   gp_Vec2d(v2x, v2y),
                   sense,
                   GeomAbs_Arc,
                   tolerance);
    Handle(Geom2d_Curve) result = bisec->Geom2dCurve();
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve2D();
    ref->curve = result;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurvePoint(OCCTCurve2DRef curve,
                                                        double         ptx,
                                                        double         pty,
                                                        double         px,
                                                        double         py,
                                                        double         v1x,
                                                        double         v1y,
                                                        double         v2x,
                                                        double         v2y,
                                                        double         sense,
                                                        double         tolerance)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Point)      geomPt = new Geom2d_CartesianPoint(gp_Pnt2d(ptx, pty));
    Handle(Bisector_BisecAna) bisec  = new Bisector_BisecAna();
    bisec->Perform(curve->curve,
                   geomPt,
                   gp_Pnt2d(px, py),
                   gp_Vec2d(v1x, v1y),
                   gp_Vec2d(v2x, v2y),
                   sense,
                   tolerance);
    Handle(Geom2d_Curve) result = bisec->Geom2dCurve();
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve2D();
    ref->curve = result;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaPointPoint(double pt1x,
                                                        double pt1y,
                                                        double pt2x,
                                                        double pt2y,
                                                        double px,
                                                        double py,
                                                        double v1x,
                                                        double v1y,
                                                        double v2x,
                                                        double v2y,
                                                        double sense,
                                                        double tolerance)
{
  try
  {
    Handle(Geom2d_Point)      p1    = new Geom2d_CartesianPoint(gp_Pnt2d(pt1x, pt1y));
    Handle(Geom2d_Point)      p2    = new Geom2d_CartesianPoint(gp_Pnt2d(pt2x, pt2y));
    Handle(Bisector_BisecAna) bisec = new Bisector_BisecAna();
    bisec
      ->Perform(p1, p2, gp_Pnt2d(px, py), gp_Vec2d(v1x, v1y), gp_Vec2d(v2x, v2y), sense, tolerance);
    Handle(Geom2d_Curve) result = bisec->Geom2dCurve();
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve2D();
    ref->curve = result;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - BRepAdaptor_Curve2d Edge PCurves (v0.61)
// MARK: - BRepAdaptor_Curve2d (v0.61.0)

// #1026: both refuse a null shape the way they already refused a wrong-typed one, leaving the out
// parameters untouched. occtShapeIsType (OCCTBridge_Internal.h) is the pointer test and the
// null-shape test in one, and TopoDS_Shape::ShapeType() needs the second: it is an unguarded
// myTShape dereference, so a null shape was a SIGSEGV rather than a refusal.
bool OCCTEdgePCurveParams(OCCTShapeRef edge, OCCTShapeRef face, double* outFirst, double* outLast)
{
  if (!occtShapeIsType(edge, TopAbs_EDGE) || !occtShapeIsType(face, TopAbs_FACE) || !outFirst
      || !outLast)
    return false;
  try
  {
    TopoDS_Edge         e = TopoDS::Edge(edge->shape);
    TopoDS_Face         f = TopoDS::Face(face->shape);
    BRepAdaptor_Curve2d adaptor(e, f);
    *outFirst = adaptor.FirstParameter();
    *outLast  = adaptor.LastParameter();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgePCurveValue(OCCTShapeRef edge, OCCTShapeRef face, double t, double* outU, double* outV)
{
  if (!occtShapeIsType(edge, TopAbs_EDGE) || !occtShapeIsType(face, TopAbs_FACE) || !outU || !outV)
    return false;
  try
  {
    TopoDS_Edge         e = TopoDS::Edge(edge->shape);
    TopoDS_Face         f = TopoDS::Face(face->shape);
    BRepAdaptor_Curve2d adaptor(e, f);
    gp_Pnt2d            pt = adaptor.Value(t);
    *outU                  = pt.X();
    *outV                  = pt.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - BRepBuilderAPI_MakeEdge2d (v0.62)
// --- BRepBuilderAPI_MakeEdge2d ---

OCCTShapeRef _Nullable OCCTMakeEdge2dFromPoints(double x1, double y1, double x2, double y2)
{
  try
  {
    BRepBuilderAPI_MakeEdge2d me(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2));
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTMakeEdge2dFromCircle(double cx,
                                                double cy,
                                                double dx,
                                                double dy,
                                                double radius,
                                                double p1,
                                                double p2)
{
  if (!occtValidCircleRadius(radius))
    return nullptr;
  try
  {
    gp_Circ2d                 circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy)), radius);
    BRepBuilderAPI_MakeEdge2d me(circ, p1, p2);
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTMakeEdge2dFromLine(double ox,
                                              double oy,
                                              double dx,
                                              double dy,
                                              double p1,
                                              double p2)
{
  try
  {
    Handle(Geom2d_Line)       line = new Geom2d_Line(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy));
    BRepBuilderAPI_MakeEdge2d me(line, p1, p2);
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Geom2d Point2D (v0.64)
// --- Point2D (Geom2d_CartesianPoint) ---

struct OCCTPoint2D
{
  Handle(Geom2d_CartesianPoint) point;

  OCCTPoint2D(const Handle(Geom2d_CartesianPoint)& p)
      : point(p)
  {
  }
};

OCCTPoint2DRef _Nullable OCCTPoint2DCreate(double x, double y)
{
  try
  {
    return new OCCTPoint2D(new Geom2d_CartesianPoint(x, y));
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTPoint2DRelease(OCCTPoint2DRef _Nonnull ref)
{
  delete ref;
}

double OCCTPoint2DGetX(OCCTPoint2DRef _Nonnull ref)
{
  return ref->point->X();
}

double OCCTPoint2DGetY(OCCTPoint2DRef _Nonnull ref)
{
  return ref->point->Y();
}

void OCCTPoint2DSetCoords(OCCTPoint2DRef _Nonnull ref, double x, double y)
{
  ref->point->SetCoord(x, y);
}

double OCCTPoint2DDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other)
{
  return ref->point->Distance(other->point);
}

double OCCTPoint2DSquareDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other)
{
  return ref->point->SquareDistance(other->point);
}

OCCTPoint2DRef _Nullable OCCTPoint2DTranslated(OCCTPoint2DRef _Nonnull ref, double dx, double dy)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetTranslation(gp_Vec2d(dx, dy));
    Handle(Geom2d_Geometry)       g = ref->point->Transformed(trsf);
    Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
    if (p.IsNull())
      return nullptr;
    return new OCCTPoint2D(p);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPoint2DRef _Nullable OCCTPoint2DRotated(OCCTPoint2DRef _Nonnull ref,
                                            double cx,
                                            double cy,
                                            double angle)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetRotation(gp_Pnt2d(cx, cy), angle);
    Handle(Geom2d_Geometry)       g = ref->point->Transformed(trsf);
    Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
    if (p.IsNull())
      return nullptr;
    return new OCCTPoint2D(p);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPoint2DRef _Nullable OCCTPoint2DScaled(OCCTPoint2DRef _Nonnull ref,
                                           double cx,
                                           double cy,
                                           double factor)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetScale(gp_Pnt2d(cx, cy), factor);
    Handle(Geom2d_Geometry)       g = ref->point->Transformed(trsf);
    Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
    if (p.IsNull())
      return nullptr;
    return new OCCTPoint2D(p);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPoint2DRef _Nullable OCCTPoint2DMirroredPoint(OCCTPoint2DRef _Nonnull ref, double px, double py)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetMirror(gp_Pnt2d(px, py));
    Handle(Geom2d_Geometry)       g = ref->point->Transformed(trsf);
    Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
    if (p.IsNull())
      return nullptr;
    return new OCCTPoint2D(p);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPoint2DRef _Nullable OCCTPoint2DMirroredAxis(OCCTPoint2DRef _Nonnull ref,
                                                 double ox,
                                                 double oy,
                                                 double dx,
                                                 double dy)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetMirror(gp_Ax2d(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)));
    Handle(Geom2d_Geometry)       g = ref->point->Transformed(trsf);
    Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
    if (p.IsNull())
      return nullptr;
    return new OCCTPoint2D(p);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Failure contract: returns a negative distance. Swift's Point2D.distance(to:) maps that to
// .infinity rather than passing the sentinel through as if it were a real distance (#413).
double OCCTPoint2DDistanceToCurve(OCCTPoint2DRef _Nonnull ref, OCCTCurve2DRef _Nonnull curve)
{
  if (!ref)
    return -1.0;
  double distance = -1.0;
  if (!occtNearestProjectionOnCurve2d(curve, ref->point->Pnt2d(), nullptr, nullptr, &distance))
  {
    return -1.0;
  }
  return distance;
}

OCCTPoint2DRef _Nullable OCCTPoint2DTransformed(OCCTPoint2DRef _Nonnull ref,
                                                OCCTTransform2DRef _Nonnull trsf);

// MARK: - Geom2d Transform2D (v0.64)
// --- Transform2D (Geom2d_Transformation) ---

struct OCCTTransform2D
{
  Handle(Geom2d_Transformation) transform;

  OCCTTransform2D(const Handle(Geom2d_Transformation)& t)
      : transform(t)
  {
  }
};

OCCTTransform2DRef _Nullable OCCTTransform2DCreateIdentity(void)
{
  try
  {
    return new OCCTTransform2D(new Geom2d_Transformation());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTTransform2DRelease(OCCTTransform2DRef _Nonnull ref)
{
  delete ref;
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateTranslation(double dx, double dy)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetTranslation(gp_Vec2d(dx, dy));
    return new OCCTTransform2D(new Geom2d_Transformation(trsf));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateRotation(double cx, double cy, double angle)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetRotation(gp_Pnt2d(cx, cy), angle);
    return new OCCTTransform2D(new Geom2d_Transformation(trsf));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateScale(double cx, double cy, double factor)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetScale(gp_Pnt2d(cx, cy), factor);
    return new OCCTTransform2D(new Geom2d_Transformation(trsf));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorPoint(double px, double py)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetMirror(gp_Pnt2d(px, py));
    return new OCCTTransform2D(new Geom2d_Transformation(trsf));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorAxis(double ox,
                                                             double oy,
                                                             double dx,
                                                             double dy)
{
  try
  {
    gp_Trsf2d trsf;
    trsf.SetMirror(gp_Ax2d(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)));
    return new OCCTTransform2D(new Geom2d_Transformation(trsf));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DInverted(OCCTTransform2DRef _Nonnull ref)
{
  try
  {
    Handle(Geom2d_Transformation) inv =
      Handle(Geom2d_Transformation)::DownCast(ref->transform->Inverted());
    if (inv.IsNull())
      return nullptr;
    return new OCCTTransform2D(inv);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DComposed(OCCTTransform2DRef _Nonnull ref,
                                                     OCCTTransform2DRef _Nonnull other)
{
  try
  {
    Handle(Geom2d_Transformation) composed =
      Handle(Geom2d_Transformation)::DownCast(ref->transform->Multiplied(other->transform));
    if (composed.IsNull())
      return nullptr;
    return new OCCTTransform2D(composed);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTTransform2DRef _Nullable OCCTTransform2DPowered(OCCTTransform2DRef _Nonnull ref, int32_t n)
{
  try
  {
    Handle(Geom2d_Transformation) powered =
      Handle(Geom2d_Transformation)::DownCast(ref->transform->Powered(n));
    if (powered.IsNull())
      return nullptr;
    return new OCCTTransform2D(powered);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTTransform2DApply(OCCTTransform2DRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y)
{
  try
  {
    ref->transform->Trsf2d().Transforms(*x, *y);
  }
  catch (...)
  {
  }
}

double OCCTTransform2DScaleFactor(OCCTTransform2DRef _Nonnull ref)
{
  return ref->transform->ScaleFactor();
}

bool OCCTTransform2DIsNegative(OCCTTransform2DRef _Nonnull ref)
{
  return ref->transform->IsNegative();
}

void OCCTTransform2DGetValues(OCCTTransform2DRef _Nonnull ref,
                              double* _Nonnull a11,
                              double* _Nonnull a12,
                              double* _Nonnull a13,
                              double* _Nonnull a21,
                              double* _Nonnull a22,
                              double* _Nonnull a23)
{
  try
  {
    *a11 = ref->transform->Value(1, 1);
    *a12 = ref->transform->Value(1, 2);
    *a13 = ref->transform->Value(1, 3);
    *a21 = ref->transform->Value(2, 1);
    *a22 = ref->transform->Value(2, 2);
    *a23 = ref->transform->Value(2, 3);
  }
  catch (...)
  {
  }
}

OCCTCurve2DRef _Nullable OCCTTransform2DApplyToCurve(OCCTTransform2DRef _Nonnull ref,
                                                     OCCTCurve2DRef _Nonnull curve)
{
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(curve->curve->Copy());
    if (copy.IsNull())
      return nullptr;
    copy->Transform(ref->transform->Trsf2d());
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Now implement the forward-declared Point2D + Transform2D function
OCCTPoint2DRef _Nullable OCCTPoint2DTransformed(OCCTPoint2DRef _Nonnull ref,
                                                OCCTTransform2DRef _Nonnull trsf)
{
  try
  {
    Handle(Geom2d_Geometry)       g = ref->point->Transformed(trsf->transform->Trsf2d());
    Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
    if (p.IsNull())
      return nullptr;
    return new OCCTPoint2D(p);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Geom2d AxisPlacement2D (v0.64)
// --- AxisPlacement2D (Geom2d_AxisPlacement) ---

struct OCCTAxisPlacement2D
{
  Handle(Geom2d_AxisPlacement) axis;

  OCCTAxisPlacement2D(const Handle(Geom2d_AxisPlacement)& a)
      : axis(a)
  {
  }
};

OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DCreate(double ox,
                                                           double oy,
                                                           double dx,
                                                           double dy)
{
  try
  {
    return new OCCTAxisPlacement2D(new Geom2d_AxisPlacement(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)));
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTAxisPlacement2DRelease(OCCTAxisPlacement2DRef _Nonnull ref)
{
  delete ref;
}

void OCCTAxisPlacement2DGetOrigin(OCCTAxisPlacement2DRef _Nonnull ref,
                                  double* _Nonnull x,
                                  double* _Nonnull y)
{
  gp_Pnt2d loc = ref->axis->Location();
  *x           = loc.X();
  *y           = loc.Y();
}

void OCCTAxisPlacement2DGetDirection(OCCTAxisPlacement2DRef _Nonnull ref,
                                     double* _Nonnull x,
                                     double* _Nonnull y)
{
  gp_Dir2d dir = ref->axis->Direction();
  *x           = dir.X();
  *y           = dir.Y();
}

OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DReversed(OCCTAxisPlacement2DRef _Nonnull ref)
{
  try
  {
    Handle(Geom2d_AxisPlacement) copy = Handle(Geom2d_AxisPlacement)::DownCast(ref->axis->Copy());
    if (copy.IsNull())
      return nullptr;
    copy->Reverse();
    return new OCCTAxisPlacement2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTAxisPlacement2DAngle(OCCTAxisPlacement2DRef _Nonnull ref,
                                OCCTAxisPlacement2DRef _Nonnull other)
{
  return ref->axis->Angle(other->axis);
}

// MARK: - Vector2D / Direction2D Utilities (v0.64)
// --- Vector2D utilities ---

double OCCTVector2DAngle(double ax, double ay, double bx, double by)
{
  try
  {
    gp_Vec2d a(ax, ay), b(bx, by);
    return a.Angle(b);
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTVector2DCross(double ax, double ay, double bx, double by)
{
  return ax * by - ay * bx;
}

double OCCTVector2DDot(double ax, double ay, double bx, double by)
{
  return ax * bx + ay * by;
}

double OCCTVector2DMagnitude(double x, double y)
{
  return sqrt(x * x + y * y);
}

void OCCTVector2DNormalize(double* _Nonnull x, double* _Nonnull y)
{
  double mag = sqrt((*x) * (*x) + (*y) * (*y));
  if (mag > 1e-15)
  {
    *x /= mag;
    *y /= mag;
  }
}

// --- Direction2D utilities ---

void OCCTDirection2DNormalize(double* _Nonnull x, double* _Nonnull y)
{
  try
  {
    gp_Dir2d d(*x, *y);
    *x = d.X();
    *y = d.Y();
  }
  catch (...)
  {
  }
}

double OCCTDirection2DAngle(double ax, double ay, double bx, double by)
{
  try
  {
    gp_Dir2d a(ax, ay), b(bx, by);
    return a.Angle(b);
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTDirection2DCross(double ax, double ay, double bx, double by)
{
  try
  {
    gp_Dir2d a(ax, ay), b(bx, by);
    return a.Crossed(b);
  }
  catch (...)
  {
    return 0.0;
  }
}

// MARK: - LProp_AnalyticCurInf (v0.64)

int32_t OCCTLPropAnalyticCurInf(int32_t curveType,
                                double  first,
                                double  last,
                                double* _Nonnull outParams,
                                int32_t* _Nonnull outTypes,
                                int32_t maxResults)
{
  try
  {
    // Inline implementation matching OCCT LProp_AnalyticCurInf::Perform.
    // Only ellipses have curvature extrema among analytic curves.
    // Line: zero curvature, Circle: constant curvature, Parabola/Hyperbola: monotonic curvature.
    LProp_CurAndInf   result;
    GeomAbs_CurveType ct = (GeomAbs_CurveType)curveType;
    if (ct == GeomAbs_Ellipse)
    {
      // Ellipse curvature extrema at multiples of PI/2
      // At 0, PI: max curvature (min radius vertex on minor axis)
      // At PI/2, 3PI/2: min curvature (max radius vertex on major axis)
      double PI2 = M_PI / 2.0;
      for (int k = 0; k < 4; k++)
      {
        double param = k * PI2;
        if (param >= first && param <= last)
        {
          bool isMin = (k == 1 || k == 3);
          result.AddExtCur(param, isMin);
        }
      }
    }
    // All other analytic curve types: no curvature extrema to report.
    int32_t count = std::min((int32_t)result.NbPoints(), maxResults);
    for (int32_t i = 0; i < count; i++)
    {
      outParams[i]   = result.Parameter(i + 1);
      LProp_CIType t = result.Type(i + 1);
      switch (t)
      {
        case LProp_Inflection:
          outTypes[i] = 0;
          break;
        case LProp_MinCur:
          outTypes[i] = 1;
          break;
        case LProp_MaxCur:
          outTypes[i] = 2;
          break;
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Curve2D ↔ Point2D Integration (v0.64)
// --- Curve2D ↔ Point2D integration ---

OCCTPoint2DRef _Nullable OCCTCurve2DPointAt(OCCTCurve2DRef _Nonnull curve, double t)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    gp_Pnt2d pt;
    curve->curve->D0(t, pt);
    return new OCCTPoint2D(new Geom2d_CartesianPoint(pt));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTCurve2DSegmentFromPoints(OCCTPoint2DRef _Nonnull p1,
                                                      OCCTPoint2DRef _Nonnull p2)
{
  try
  {
    Handle(Geom2d_Line) line =
      new Geom2d_Line(p1->point->Pnt2d(),
                      gp_Dir2d(p2->point->X() - p1->point->X(), p2->point->Y() - p1->point->Y()));
    double                      dist = p1->point->Pnt2d().Distance(p2->point->Pnt2d());
    Handle(Geom2d_TrimmedCurve) seg  = new Geom2d_TrimmedCurve(line, 0.0, dist);
    return new OCCTCurve2D(seg);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Failure contract: *outDistance < 0, and NaN returned. The parameter cannot carry the failure
// signal: 0 is a legitimate result (projecting a segment's own start point onto it returns
// exactly 0), which is what the old "returns 0 on failure" contract conflated (#413).
double OCCTCurve2DProjectPoint2D(OCCTCurve2DRef _Nonnull curve,
                                 OCCTPoint2DRef _Nonnull point,
                                 double* _Nonnull outDistance)
{
  if (!point)
  {
    *outDistance = -1.0;
    return std::numeric_limits<double>::quiet_NaN();
  }
  double parameter = 0.0;
  if (!occtNearestProjectionOnCurve2d(curve,
                                      point->point->Pnt2d(),
                                      nullptr,
                                      &parameter,
                                      outDistance))
  {
    *outDistance = -1.0;
    return std::numeric_limits<double>::quiet_NaN();
  }
  return parameter;
}

// MARK: - FairCurve Batten / MinimalVariation (v0.67)
// --- FairCurve_Batten ---

OCCTCurve2DRef _Nullable OCCTFairCurveBatten(double  p1x,
                                             double  p1y,
                                             double  p2x,
                                             double  p2y,
                                             double  height,
                                             double  slope,
                                             double  angle1,
                                             double  angle2,
                                             int32_t constraintOrder1,
                                             int32_t constraintOrder2,
                                             bool    freeSliding,
                                             int32_t* _Nonnull outCode)
{
  try
  {
    gp_Pnt2d         P1(p1x, p1y);
    gp_Pnt2d         P2(p2x, p2y);
    FairCurve_Batten batten(P1, P2, height, slope);
    batten.SetAngle1(angle1);
    batten.SetAngle2(angle2);
    batten.SetConstraintOrder1(constraintOrder1);
    batten.SetConstraintOrder2(constraintOrder2);
    batten.SetFreeSliding(freeSliding);

    FairCurve_AnalysisCode code;
    bool                   ok = batten.Compute(code, 50, 1.0e-3);
    *outCode                  = (int32_t)code;
    if (!ok)
      return nullptr;

    Handle(Geom2d_BSplineCurve) bspline = batten.Curve();
    if (bspline.IsNull())
      return nullptr;

    // Convert to Geom2d_Curve handle
    Handle(Geom2d_Curve) curve = bspline;
    auto                 ref   = new OCCTCurve2D();
    ref->curve                 = curve;
    return ref;
  }
  catch (...)
  {
    *outCode = -1;
    return nullptr;
  }
}

// --- FairCurve_MinimalVariation ---

OCCTCurve2DRef _Nullable OCCTFairCurveMinimalVariation(double  p1x,
                                                       double  p1y,
                                                       double  p2x,
                                                       double  p2y,
                                                       double  height,
                                                       double  slope,
                                                       double  angle1,
                                                       double  angle2,
                                                       int32_t constraintOrder1,
                                                       int32_t constraintOrder2,
                                                       bool    freeSliding,
                                                       double  physicalRatio,
                                                       double  curvature1,
                                                       double  curvature2,
                                                       int32_t* _Nonnull outCode)
{
  try
  {
    gp_Pnt2d                   P1(p1x, p1y);
    gp_Pnt2d                   P2(p2x, p2y);
    FairCurve_MinimalVariation mv(P1, P2, height, slope, physicalRatio);
    mv.SetAngle1(angle1);
    mv.SetAngle2(angle2);
    mv.SetConstraintOrder1(constraintOrder1);
    mv.SetConstraintOrder2(constraintOrder2);
    mv.SetFreeSliding(freeSliding);
    if (constraintOrder1 >= 2)
      mv.SetCurvature1(curvature1);
    if (constraintOrder2 >= 2)
      mv.SetCurvature2(curvature2);

    FairCurve_AnalysisCode code;
    bool                   ok = mv.Compute(code, 50, 1.0e-3);
    *outCode                  = (int32_t)code;
    if (!ok)
      return nullptr;

    Handle(Geom2d_BSplineCurve) bspline = mv.Curve();
    if (bspline.IsNull())
      return nullptr;

    Handle(Geom2d_Curve) curve = bspline;
    auto                 ref   = new OCCTCurve2D();
    ref->curve                 = curve;
    return ref;
  }
  catch (...)
  {
    *outCode = -1;
    return nullptr;
  }
}

// MARK: - GccAna_Circ2d3Tan + variants (v0.68)
// --- GccAna_Circ2d3Tan ---

static void extractCircSolutions(const GccAna_Circ2d3Tan& solver,
                                 OCCTCircle2DSolution*    outSolutions,
                                 int32_t                  maxSolutions,
                                 int32_t*                 count)
{
  if (!solver.IsDone())
  {
    *count = 0;
    return;
  }
  int nb = std::min((int)maxSolutions, solver.NbSolutions());
  for (int i = 0; i < nb; i++)
  {
    gp_Circ2d sol           = solver.ThisSolution(i + 1);
    outSolutions[i].centerX = sol.Location().X();
    outSolutions[i].centerY = sol.Location().Y();
    outSolutions[i].radius  = sol.Radius();
  }
  *count = (int32_t)nb;
}

int32_t OCCTGccAnaCirc2d3TanPoints(double                p1x,
                                   double                p1y,
                                   double                p2x,
                                   double                p2y,
                                   double                p3x,
                                   double                p3y,
                                   double                tolerance,
                                   OCCTCircle2DSolution* outSolutions,
                                   int32_t               maxSolutions)
{
  try
  {
    GccAna_Circ2d3Tan solver(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y), gp_Pnt2d(p3x, p3y), tolerance);
    int32_t           count = 0;
    extractCircSolutions(solver, outSolutions, maxSolutions, &count);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccAnaCirc2d3TanLines(double                l1px,
                                  double                l1py,
                                  double                l1dx,
                                  double                l1dy,
                                  double                l2px,
                                  double                l2py,
                                  double                l2dx,
                                  double                l2dy,
                                  double                l3px,
                                  double                l3py,
                                  double                l3dx,
                                  double                l3dy,
                                  double                tolerance,
                                  OCCTCircle2DSolution* outSolutions,
                                  int32_t               maxSolutions)
{
  try
  {
    gp_Lin2d          lin1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d          lin2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    gp_Lin2d          lin3(gp_Pnt2d(l3px, l3py), gp_Dir2d(l3dx, l3dy));
    GccAna_Circ2d3Tan solver(GccEnt_QualifiedLin(lin1, GccEnt_unqualified),
                             GccEnt_QualifiedLin(lin2, GccEnt_unqualified),
                             GccEnt_QualifiedLin(lin3, GccEnt_unqualified),
                             tolerance);
    int32_t           count = 0;
    extractCircSolutions(solver, outSolutions, maxSolutions, &count);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccAnaCirc2d3TanCircles(double                c1x,
                                    double                c1y,
                                    double                c1r,
                                    double                c2x,
                                    double                c2y,
                                    double                c2r,
                                    double                c3x,
                                    double                c3y,
                                    double                c3r,
                                    double                tolerance,
                                    OCCTCircle2DSolution* outSolutions,
                                    int32_t               maxSolutions)
{
  if (!occtValidCircleRadius(c1r) || !occtValidCircleRadius(c2r) || !occtValidCircleRadius(c3r))
    return 0;
  try
  {
    gp_Circ2d         circ1(gp_Ax2d(gp_Pnt2d(c1x, c1y), gp_Dir2d(1, 0)), c1r);
    gp_Circ2d         circ2(gp_Ax2d(gp_Pnt2d(c2x, c2y), gp_Dir2d(1, 0)), c2r);
    gp_Circ2d         circ3(gp_Ax2d(gp_Pnt2d(c3x, c3y), gp_Dir2d(1, 0)), c3r);
    GccAna_Circ2d3Tan solver(GccEnt_QualifiedCirc(circ1, GccEnt_unqualified),
                             GccEnt_QualifiedCirc(circ2, GccEnt_unqualified),
                             GccEnt_QualifiedCirc(circ3, GccEnt_unqualified),
                             tolerance);
    int32_t           count = 0;
    extractCircSolutions(solver, outSolutions, maxSolutions, &count);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccAnaCirc2d2CirclesPoint(double                c1x,
                                      double                c1y,
                                      double                c1r,
                                      double                c2x,
                                      double                c2y,
                                      double                c2r,
                                      double                px,
                                      double                py,
                                      double                tolerance,
                                      OCCTCircle2DSolution* outSolutions,
                                      int32_t               maxSolutions)
{
  if (!occtValidCircleRadius(c1r) || !occtValidCircleRadius(c2r))
    return 0;
  try
  {
    gp_Circ2d         circ1(gp_Ax2d(gp_Pnt2d(c1x, c1y), gp_Dir2d(1, 0)), c1r);
    gp_Circ2d         circ2(gp_Ax2d(gp_Pnt2d(c2x, c2y), gp_Dir2d(1, 0)), c2r);
    GccAna_Circ2d3Tan solver(GccEnt_QualifiedCirc(circ1, GccEnt_unqualified),
                             GccEnt_QualifiedCirc(circ2, GccEnt_unqualified),
                             gp_Pnt2d(px, py),
                             tolerance);
    int32_t           count = 0;
    extractCircSolutions(solver, outSolutions, maxSolutions, &count);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccAnaCirc2dCircle2Points(double                cx,
                                      double                cy,
                                      double                cr,
                                      double                p1x,
                                      double                p1y,
                                      double                p2x,
                                      double                p2y,
                                      double                tolerance,
                                      OCCTCircle2DSolution* outSolutions,
                                      int32_t               maxSolutions)
{
  if (!occtValidCircleRadius(cr))
    return 0;
  try
  {
    gp_Circ2d         circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
    GccAna_Circ2d3Tan solver(GccEnt_QualifiedCirc(circ, GccEnt_unqualified),
                             gp_Pnt2d(p1x, p1y),
                             gp_Pnt2d(p2x, p2y),
                             tolerance);
    int32_t           count = 0;
    extractCircSolutions(solver, outSolutions, maxSolutions, &count);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGccAnaCirc2d2LinesPoint(double                l1px,
                                    double                l1py,
                                    double                l1dx,
                                    double                l1dy,
                                    double                l2px,
                                    double                l2py,
                                    double                l2dx,
                                    double                l2dy,
                                    double                px,
                                    double                py,
                                    double                tolerance,
                                    OCCTCircle2DSolution* outSolutions,
                                    int32_t               maxSolutions)
{
  try
  {
    gp_Lin2d          lin1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d          lin2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    GccAna_Circ2d3Tan solver(GccEnt_QualifiedLin(lin1, GccEnt_unqualified),
                             GccEnt_QualifiedLin(lin2, GccEnt_unqualified),
                             gp_Pnt2d(px, py),
                             tolerance);
    int32_t           count = 0;
    extractCircSolutions(solver, outSolutions, maxSolutions, &count);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Intf_InterferencePolygon2d (v0.68)
// --- Intf_InterferencePolygon2d ---

// Concrete adapter for Intf_Polygon2d (abstract base)
class OCCTSimplePolygon2d : public Intf_Polygon2d
{
public:
  OCCTSimplePolygon2d(const double* coords, int32_t count)
  {
    for (int32_t i = 0; i < count; i++)
    {
      myPoints.push_back(gp_Pnt2d(coords[i * 2], coords[i * 2 + 1]));
    }
    for (const auto& p : myPoints)
    {
      myBox.Add(p);
    }
  }

  Standard_Real DeflectionOverEstimation() const override { return 0.0; }

  Standard_Integer NbSegments() const override { return (Standard_Integer)myPoints.size() - 1; }

  void Segment(const Standard_Integer theIndex, gp_Pnt2d& theBegin, gp_Pnt2d& theEnd) const override
  {
    theBegin = myPoints[theIndex - 1];
    theEnd   = myPoints[theIndex];
  }

private:
  std::vector<gp_Pnt2d> myPoints;
};

int32_t OCCTIntfInterferencePolygon2d(const double*    poly1,
                                      int32_t          count1,
                                      const double*    poly2,
                                      int32_t          count2,
                                      OCCTIntfPoint2D* outPoints,
                                      int32_t          maxPoints)
{
  try
  {
    OCCTSimplePolygon2d        sp1(poly1, count1);
    OCCTSimplePolygon2d        sp2(poly2, count2);
    Intf_InterferencePolygon2d intf(sp1, sp2);

    int nb = std::min((int)maxPoints, intf.NbSectionPoints());
    for (int i = 0; i < nb; i++)
    {
      gp_Pnt2d pt    = intf.Pnt2dValue(i + 1);
      outPoints[i].x = pt.X();
      outPoints[i].y = pt.Y();
    }
    return (int32_t)nb;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTIntfSelfInterferencePolygon2d(const double*    poly,
                                          int32_t          count,
                                          OCCTIntfPoint2D* outPoints,
                                          int32_t          maxPoints)
{
  try
  {
    OCCTSimplePolygon2d        sp(poly, count);
    Intf_InterferencePolygon2d intf(sp);

    int nb = std::min((int)maxPoints, intf.NbSectionPoints());
    for (int i = 0; i < nb; i++)
    {
      gp_Pnt2d pt    = intf.Pnt2dValue(i + 1);
      outPoints[i].x = pt.X();
      outPoints[i].y = pt.Y();
    }
    return (int32_t)nb;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeConstruct Curve2D Convert + Adjust (v0.76)
OCCTCurve2DRef _Nullable OCCTShapeConstructConvertToBSpline2D(OCCTCurve2DRef _Nonnull curve,
                                                              double first,
                                                              double last,
                                                              double precision)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    ShapeConstruct_Curve        scc;
    Handle(Geom2d_BSplineCurve) bsp = scc.ConvertToBSpline(curve->curve, first, last, precision);
    if (bsp.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve2D();
    ref->curve = bsp;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTShapeConstructAdjustCurve2D(OCCTCurve2DRef _Nonnull curve,
                                     double p1x,
                                     double p1y,
                                     double p2x,
                                     double p2y)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    ShapeConstruct_Curve scc;
    return scc.AdjustCurve2d(curve->curve, gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y));
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Bisector_PointOnBis + Bisector_Inter (v0.76)

// OCCTBisectorPointOnBisCreate lived here: it echoed its 6 double parameters into a plain C
// struct and never touched Bisector_PointOnBis itself, so isInfinite (this struct's one bool
// field) was always the literal false the constructor had no parameter to override. No Swift
// call site (BisectorPoint, the Swift struct it built for, had no public initializer either, so
// nothing outside this bridge could construct one). Found by census-unmeasured-values.py's
// sub-kind 3 (#771), which flags a bool struct field assigned literal false somewhere and literal
// true nowhere; the field's fate turned out to be dead code around it, not a stuck gate on a live
// path. Removed by #771.

// --- Bisector_Inter ---

int OCCTBisectorInterPointPoint(double                         ax,
                                double                         ay,
                                double                         bx,
                                double                         by,
                                double                         cx,
                                double                         cy,
                                double                         dx,
                                double                         dy,
                                OCCTBisectorIntersectionPoint* outPoints,
                                int                            maxPoints)
{
  try
  {
    // Build bisector 1: between points A and B
    Bisector_Bisec                b1;
    Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
    Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
    gp_Pnt2d                      midAB((ax + bx) / 2, (ay + by) / 2);
    gp_Vec2d                      vAB(bx - ax, by - ay);
    gp_Vec2d                      perpAB(-vAB.Y(), vAB.X());
    gp_Vec2d                      v1 = perpAB;
    v1.Normalize();
    gp_Vec2d v2 = perpAB.Reversed();
    v2.Normalize();
    b1.Perform(pA, pB, midAB, v1, v2, 1.0, 1e-6);
    if (b1.Value().IsNull())
      return 0;

    // Build bisector 2: between points C and D
    Bisector_Bisec                b2;
    Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(cx, cy));
    Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(dx, dy));
    gp_Pnt2d                      midCD((cx + dx) / 2, (cy + dy) / 2);
    gp_Vec2d                      vCD(dx - cx, dy - cy);
    gp_Vec2d                      perpCD(-vCD.Y(), vCD.X());
    gp_Vec2d                      v3 = perpCD;
    v3.Normalize();
    gp_Vec2d v4 = perpCD.Reversed();
    v4.Normalize();
    b2.Perform(pC, pD, midCD, v3, v4, 1.0, 1e-6);
    if (b2.Value().IsNull())
      return 0;

    // Search each bisector over its own parameter range rather than a fixed window. Bisector_Bisec
    // hands back a half-line trimmed to [0, Precision::Infinite()], so the [-100, 100] carried here
    // until #1050 spent half its width off the curve and capped the live half at 100, silently
    // dropping any meeting point past it. Bisector_Inter::Perform clips the domain against the
    // basis curve's own continuity intervals regardless, so passing the curve's range leaves the
    // extent of the search to OCCT instead of narrowing it here. An unbounded IntRes2d_Domain() is
    // not the way to spell that: Perform reads FirstTolerance()/LastTolerance(), which raise
    // Standard_DomainError when the domain has no bounds, and the catch below would turn that into
    // the same empty result the fixed window produced.
    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    const double                       f1 = c1->FirstParameter();
    const double                       l1 = c1->LastParameter();
    const double                       f2 = c2->FirstParameter();
    const double                       l2 = c2->LastParameter();
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(f1)), f1, 1e-6, gp_Pnt2d(c1->Value(l1)), l1, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(f2)), f2, 1e-6, gp_Pnt2d(c2->Value(l2)), l2, 1e-6);

    Bisector_Inter inter;
    inter.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);

    if (!inter.IsDone())
      return 0;
    int count   = inter.NbPoints();
    int written = 0;
    for (int i = 1; i <= count && written < maxPoints; ++i)
    {
      const IntRes2d_IntersectionPoint& ip = inter.Point(i);
      if (outPoints)
      {
        outPoints[written].x             = ip.Value().X();
        outPoints[written].y             = ip.Value().Y();
        outPoints[written].paramOnFirst  = ip.ParamOnFirst();
        outPoints[written].paramOnSecond = ip.ParamOnSecond();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GeomLib_Tool Param2D (v0.77)
bool OCCTGeomLibToolParameter2D(OCCTCurve2DRef _Nonnull curveRef,
                                double px,
                                double py,
                                double maxDist,
                                double* _Nonnull outParam)
{
  try
  {
    auto&  curve = reinterpret_cast<OCCTCurve2D*>(curveRef)->curve;
    double param = 0;
    bool   ok    = GeomLib_Tool::Parameter(curve, gp_Pnt2d(px, py), maxDist, param);
    if (ok)
      *outParam = param;
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - GeomLib_Check + Fix BSpline 2D (v0.77)
bool OCCTGeomLibCheckBSpline2D(OCCTCurve2DRef _Nonnull curveRef,
                               double tolerance,
                               double angularTol,
                               bool* _Nonnull needFixFirst,
                               bool* _Nonnull needFixLast)
{
  try
  {
    auto&                       curve = reinterpret_cast<OCCTCurve2D*>(curveRef)->curve;
    Handle(Geom2d_BSplineCurve) bsp   = Handle(Geom2d_BSplineCurve)::DownCast(curve);
    if (bsp.IsNull())
      return false;
    GeomLib_Check2dBSplineCurve checker(bsp, tolerance, angularTol);
    if (!checker.IsDone())
      return false;
    bool f = false, l = false;
    checker.NeedTangentFix(f, l);
    *needFixFirst = f;
    *needFixLast  = l;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve2DRef _Nullable OCCTGeomLibFixBSpline2D(OCCTCurve2DRef _Nonnull curveRef,
                                                 double tolerance,
                                                 double angularTol,
                                                 bool   fixFirst,
                                                 bool   fixLast)
{
  try
  {
    auto&                       curve = reinterpret_cast<OCCTCurve2D*>(curveRef)->curve;
    Handle(Geom2d_BSplineCurve) bsp   = Handle(Geom2d_BSplineCurve)::DownCast(curve);
    if (bsp.IsNull())
      return nullptr;
    GeomLib_Check2dBSplineCurve checker(bsp, tolerance, angularTol);
    Handle(Geom2d_BSplineCurve) fixed = checker.FixedTangent(fixFirst, fixLast);
    if (fixed.IsNull())
      return nullptr;
    return reinterpret_cast<OCCTCurve2DRef>(new OCCTCurve2D{fixed});
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - GccAna Circ2d2TanRad / TanCen / Lin2d2Tan (v0.77)
// MARK: - GccAna_Circ2d2TanRad

#include <GccAna_Circ2d2TanRad.hxx>
#include <GccAna_Circ2dTanCen.hxx>
#include <GccAna_Lin2d2Tan.hxx>
#include <GccEnt.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccEnt_QualifiedCirc.hxx>

int OCCTGccAnaCirc2d2TanRadLineLin(double l1px,
                                   double l1py,
                                   double l1dx,
                                   double l1dy,
                                   double l2px,
                                   double l2py,
                                   double l2dx,
                                   double l2dy,
                                   double radius,
                                   double tolerance,
                                   OCCTCircle2DSolution* _Nullable outSolutions,
                                   int maxSolutions)
{
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    gp_Lin2d             l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
    gp_Lin2d             l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
    GccEnt_QualifiedLin  ql1(l1, GccEnt_unqualified);
    GccEnt_QualifiedLin  ql2(l2, GccEnt_unqualified);
    GccAna_Circ2d2TanRad solver(ql1, ql2, radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int n       = solver.NbSolutions();
    int written = 0;
    for (int i = 1; i <= n && written < maxSolutions; i++)
    {
      gp_Circ2d circ = solver.ThisSolution(i);
      if (outSolutions)
      {
        outSolutions[written].centerX = circ.Location().X();
        outSolutions[written].centerY = circ.Location().Y();
        outSolutions[written].radius  = circ.Radius();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTGccAnaCirc2d2TanRadPntPnt(double p1x,
                                  double p1y,
                                  double p2x,
                                  double p2y,
                                  double radius,
                                  double tolerance,
                                  OCCTCircle2DSolution* _Nullable outSolutions,
                                  int maxSolutions)
{
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    GccAna_Circ2d2TanRad solver(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y), radius, tolerance);
    if (!solver.IsDone())
      return 0;
    int n       = solver.NbSolutions();
    int written = 0;
    for (int i = 1; i <= n && written < maxSolutions; i++)
    {
      gp_Circ2d circ = solver.ThisSolution(i);
      if (outSolutions)
      {
        outSolutions[written].centerX = circ.Location().X();
        outSolutions[written].centerY = circ.Location().Y();
        outSolutions[written].radius  = circ.Radius();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GccAna_Circ2dTanCen

int OCCTGccAnaCirc2dTanCenPntPnt(double px,
                                 double py,
                                 double cx,
                                 double cy,
                                 OCCTCircle2DSolution* _Nullable outSolutions,
                                 int maxSolutions)
{
  try
  {
    GccAna_Circ2dTanCen solver(gp_Pnt2d(px, py), gp_Pnt2d(cx, cy));
    if (!solver.IsDone())
      return 0;
    int n       = solver.NbSolutions();
    int written = 0;
    for (int i = 1; i <= n && written < maxSolutions; i++)
    {
      gp_Circ2d circ = solver.ThisSolution(i);
      if (outSolutions)
      {
        outSolutions[written].centerX = circ.Location().X();
        outSolutions[written].centerY = circ.Location().Y();
        outSolutions[written].radius  = circ.Radius();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTGccAnaCirc2dTanCenLinPnt(double lpx,
                                 double lpy,
                                 double ldx,
                                 double ldy,
                                 double cx,
                                 double cy,
                                 OCCTCircle2DSolution* _Nullable outSolutions,
                                 int maxSolutions)
{
  try
  {
    gp_Lin2d            line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    GccAna_Circ2dTanCen solver(line, gp_Pnt2d(cx, cy));
    if (!solver.IsDone())
      return 0;
    int n       = solver.NbSolutions();
    int written = 0;
    for (int i = 1; i <= n && written < maxSolutions; i++)
    {
      gp_Circ2d circ = solver.ThisSolution(i);
      if (outSolutions)
      {
        outSolutions[written].centerX = circ.Location().X();
        outSolutions[written].centerY = circ.Location().Y();
        outSolutions[written].radius  = circ.Radius();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GccAna_Lin2d2Tan

int OCCTGccAnaLin2d2TanPntPnt(double p1x,
                              double p1y,
                              double p2x,
                              double p2y,
                              double tolerance,
                              OCCTLine2DSolution* _Nullable outSolutions,
                              int maxSolutions)
{
  try
  {
    GccAna_Lin2d2Tan solver(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y), tolerance);
    if (!solver.IsDone())
      return 0;
    int n       = solver.NbSolutions();
    int written = 0;
    for (int i = 1; i <= n && written < maxSolutions; i++)
    {
      gp_Lin2d lin = solver.ThisSolution(i);
      if (outSolutions)
      {
        outSolutions[written].originX = lin.Location().X();
        outSolutions[written].originY = lin.Location().Y();
        outSolutions[written].dirX    = lin.Direction().X();
        outSolutions[written].dirY    = lin.Direction().Y();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTGccAnaLin2d2TanCircPnt(double cx,
                               double cy,
                               double radius,
                               double px,
                               double py,
                               double tolerance,
                               OCCTLine2DSolution* _Nullable outSolutions,
                               int maxSolutions)
{
  if (!occtValidCircleRadius(radius))
    return 0;
  try
  {
    gp_Circ2d            circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), radius);
    GccEnt_QualifiedCirc qc(circ, GccEnt_unqualified);
    GccAna_Lin2d2Tan     solver(qc, gp_Pnt2d(px, py), tolerance);
    if (!solver.IsDone())
      return 0;
    int n       = solver.NbSolutions();
    int written = 0;
    for (int i = 1; i <= n && written < maxSolutions; i++)
    {
      gp_Lin2d lin = solver.ThisSolution(i);
      if (outSolutions)
      {
        outSolutions[written].originX = lin.Location().X();
        outSolutions[written].originY = lin.Location().Y();
        outSolutions[written].dirX    = lin.Direction().X();
        outSolutions[written].dirY    = lin.Direction().Y();
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeUpgrade_SplitCurve2dContinuity (v0.77)
// MARK: - ShapeUpgrade_SplitCurve2dContinuity

int OCCTSplitCurve2dContinuity(OCCTCurve2DRef _Nonnull curveRef,
                               int    criterion,
                               double tolerance,
                               OCCTCurve2DRef _Nullable* _Nullable outCurves,
                               int maxCurves)
{
  try
  {
    auto* wrapper = reinterpret_cast<OCCTCurve2D*>(curveRef);
    if (!wrapper || wrapper->curve.IsNull())
      return 0;
    auto&                                       curve = wrapper->curve;
    Handle(ShapeUpgrade_SplitCurve2dContinuity) splitter =
      new ShapeUpgrade_SplitCurve2dContinuity();
    splitter->Init(curve);
    splitter->SetCriterion(occtGeomAbsFromParametricContinuity(criterion));
    splitter->SetTolerance(tolerance);
    splitter->Perform(true);
    auto curves = splitter->GetCurves();
    if (curves.IsNull())
      return 0;
    int n       = curves->Length();
    int written = 0;
    for (int i = curves->Lower(); i <= curves->Upper() && written < maxCurves; i++)
    {
      Handle(Geom2d_Curve) c = curves->Value(i);
      if (!c.IsNull() && outCurves)
      {
        outCurves[written] = reinterpret_cast<OCCTCurve2DRef>(new OCCTCurve2D{c});
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - ShapeUpgrade_ConvertCurve2dToBezier (v0.77)
// MARK: - ShapeUpgrade_ConvertCurve2dToBezier

int OCCTConvertCurve2dToBezier(OCCTCurve2DRef _Nonnull curveRef,
                               OCCTCurve2DRef _Nullable* _Nullable outCurves,
                               int maxCurves)
{
  try
  {
    auto* wrapper = reinterpret_cast<OCCTCurve2D*>(curveRef);
    if (!wrapper || wrapper->curve.IsNull())
      return 0;
    auto&                                       curve = wrapper->curve;
    Handle(ShapeUpgrade_ConvertCurve2dToBezier) converter =
      new ShapeUpgrade_ConvertCurve2dToBezier();
    converter->Init(curve);
    converter->Perform(true);
    auto curves = converter->GetCurves();
    if (curves.IsNull())
      return 0;
    int written = 0;
    for (int i = curves->Lower(); i <= curves->Upper() && written < maxCurves; i++)
    {
      Handle(Geom2d_Curve) c = curves->Value(i);
      if (!c.IsNull() && outCurves)
      {
        outCurves[written] = reinterpret_cast<OCCTCurve2DRef>(new OCCTCurve2D{c});
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Geom2dConvert_ApproxArcsSegments (v0.78)
// MARK: - Geom2dConvert_ApproxArcsSegments

int OCCTGeom2dConvertApproxArcsSegments(OCCTCurve2DRef _Nonnull curveRef,
                                        double tolerance,
                                        double angleTolerance,
                                        OCCTCurve2DRef _Nullable* _Nullable outCurves,
                                        int maxCurves)
{
  try
  {
    auto&                            curve = reinterpret_cast<OCCTCurve2D*>(curveRef)->curve;
    Geom2dAdaptor_Curve              adaptor(curve);
    Geom2dConvert_ApproxArcsSegments approx(adaptor, tolerance, angleTolerance);
    const NCollection_Sequence<Handle(Geom2d_Curve)>& result  = approx.GetResult();
    int                                               count   = result.Length();
    int                                               written = 0;
    for (int i = 1; i <= count && written < maxCurves; i++)
    {
      Handle(Geom2d_Curve) c = result.Value(i);
      if (!c.IsNull() && outCurves)
      {
        outCurves[written] = reinterpret_cast<OCCTCurve2DRef>(new OCCTCurve2D{c});
      }
      written++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Extrema_LocateExtCC2d (v0.80)
// --- Extrema_LocateExtCC2d ---

OCCTExtremaLocateExtCC2dResult OCCTExtremaLocateExtCC2d(OCCTCurve2DRef curve1,
                                                        double         u1First,
                                                        double         u1Last,
                                                        OCCTCurve2DRef curve2,
                                                        double         u2First,
                                                        double         u2Last,
                                                        double         seedU,
                                                        double         seedV)
{
  OCCTExtremaLocateExtCC2dResult result = {};
  try
  {
    auto*                       c1  = (OCCTCurve2D*)curve1;
    auto*                       c2  = (OCCTCurve2D*)curve2;
    Handle(Geom2dAdaptor_Curve) ac1 = new Geom2dAdaptor_Curve(c1->curve, u1First, u1Last);
    Handle(Geom2dAdaptor_Curve) ac2 = new Geom2dAdaptor_Curve(c2->curve, u2First, u2Last);
    Extrema_LocateExtCC2d       ext(*ac1, *ac2, seedU, seedV);
    result.isDone = ext.IsDone();
    if (result.isDone)
    {
      result.squareDistance = ext.SquareDistance();
      Extrema_POnCurv2d p1, p2;
      ext.Point(p1, p2);
      result.x1     = p1.Value().X();
      result.y1     = p1.Value().Y();
      result.param1 = p1.Parameter();
      result.x2     = p2.Value().X();
      result.y2     = p2.Value().Y();
      result.param2 = p2.Parameter();
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - gce_Make Circ2d / Lin2d / Elips2d / Hypr2d / Parab2d (v0.80)
OCCTCurve2DRef _Nullable OCCTGceMakeCirc2dFromCenterRadius(double cx, double cy, double radius)
{
  try
  {
    if (!occtValidCircleRadius(radius))
      return nullptr;
    gce_MakeCirc2d mc(gp_Pnt2d(cx, cy), radius);
    if (!mc.IsDone())
      return nullptr;
    Handle(Geom2d_Circle) circ = new Geom2d_Circle(mc.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{circ};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTGceMakeCirc2dFrom3Points(double p1x,
                                                      double p1y,
                                                      double p2x,
                                                      double p2y,
                                                      double p3x,
                                                      double p3y)
{
  try
  {
    gce_MakeCirc2d mc(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y), gp_Pnt2d(p3x, p3y));
    if (!mc.IsDone())
      return nullptr;
    Handle(Geom2d_Circle) circ = new Geom2d_Circle(mc.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{circ};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTGceMakeLin2dFrom2Points(double p1x, double p1y, double p2x, double p2y)
{
  try
  {
    gce_MakeLin2d ml(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y));
    if (!ml.IsDone())
      return nullptr;
    Handle(Geom2d_Line) line = new Geom2d_Line(ml.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{line};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTGceMakeLin2dFromEquation(double a, double b, double c)
{
  try
  {
    gce_MakeLin2d ml(a, b, c);
    if (!ml.IsDone())
      return nullptr;
    Handle(Geom2d_Line) line = new Geom2d_Line(ml.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{line};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTGceMakeElips2d(double cx,
                                            double cy,
                                            double dirX,
                                            double dirY,
                                            double majorRadius,
                                            double minorRadius)
{
  try
  {
    if (!occtValidEllipseRadii(majorRadius, minorRadius))
      return nullptr;
    gce_MakeElips2d me(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dirX, dirY)), majorRadius, minorRadius);
    if (!me.IsDone())
      return nullptr;
    Handle(Geom2d_Ellipse) elips = new Geom2d_Ellipse(me.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{elips};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTGceMakeHypr2d(double cx,
                                           double cy,
                                           double dirX,
                                           double dirY,
                                           double majorRadius,
                                           double minorRadius)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorRadius, minorRadius))
      return nullptr;
    gce_MakeHypr2d mh(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dirX, dirY)),
                      majorRadius,
                      minorRadius,
                      true);
    if (!mh.IsDone())
      return nullptr;
    Handle(Geom2d_Hyperbola) hypr = new Geom2d_Hyperbola(mh.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{hypr};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef _Nullable OCCTGceMakeParab2d(double cx,
                                            double cy,
                                            double dirX,
                                            double dirY,
                                            double focal)
{
  try
  {
    if (!occtValidParabolaFocal(focal))
      return nullptr;
    gce_MakeParab2d mp(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dirX, dirY)), focal);
    if (!mp.IsDone())
      return nullptr;
    Handle(Geom2d_Parabola) parab = new Geom2d_Parabola(mp.Value());
    return (OCCTCurve2DRef) new OCCTCurve2D{parab};
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.93: Geom2dAPI_Interpolate + PointsToBSpline
// MARK: - Geom2dAPI_Interpolate (v0.93.0)

#include <Geom2dAPI_Interpolate.hxx>

OCCTCurve2DRef OCCTCurve2DInterpolate2D(const double* xs,
                                        const double* ys,
                                        int32_t       count,
                                        bool          periodic,
                                        double        tolerance)
{
  if (!xs || !ys || count < 2)
    return nullptr;
  try
  {
    Handle(NCollection_HArray1<gp_Pnt2d>) pts = new NCollection_HArray1<gp_Pnt2d>(1, count);
    for (int i = 0; i < count; i++)
    {
      pts->SetValue(i + 1, gp_Pnt2d(xs[i], ys[i]));
    }
    Geom2dAPI_Interpolate interp(pts, periodic, tolerance);
    interp.Perform();
    if (!interp.IsDone())
      return nullptr;
    Handle(Geom2d_BSplineCurve) curve = interp.Curve();
    if (curve.IsNull())
      return nullptr;
    OCCTCurve2D* result = new OCCTCurve2D();
    result->curve       = curve;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Geom2dAPI_PointsToBSpline (v0.93.0)

#include <Geom2dAPI_PointsToBSpline.hxx>

OCCTCurve2DRef OCCTCurve2DApproximate2D(const double* xs, const double* ys, int32_t count)
{
  if (!xs || !ys || count < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt2d pts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts.SetValue(i + 1, gp_Pnt2d(xs[i], ys[i]));
    }
    Geom2dAPI_PointsToBSpline approx(pts);
    if (!approx.IsDone())
      return nullptr;
    Handle(Geom2d_BSplineCurve) curve = approx.Curve();
    if (curve.IsNull())
      return nullptr;
    OCCTCurve2D* result = new OCCTCurve2D();
    result->curve       = curve;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.95: Convert_Ellipse/Hyperbola/Parabola → BSpline 2D
// MARK: - Convert conic/surface helpers (v0.95.0)

#include <Convert_EllipseToBSplineCurve.hxx>
#include <Convert_HyperbolaToBSplineCurve.hxx>
#include <Convert_ParabolaToBSplineCurve.hxx>
#include <Convert_CylinderToBSplineSurface.hxx>
#include <Convert_ConeToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>

// Helper: build Geom2d_BSplineCurve from Convert_ConicToBSplineCurve result
// #801: use batch accessors (Poles/Weights/Knots/Multiplicities) instead of deprecated
// per-index accessors (Pole/Weight/Knot/Multiplicity) on Convert_ConicToBSplineCurve.
static OCCTCurve2DRef buildCurve2DFromConic(const Convert_ConicToBSplineCurve& conv)
{
  int                     np = conv.NbPoles(), nk = conv.NbKnots(), deg = conv.Degree();
  TColgp_Array1OfPnt2d    poles(1, np);
  TColStd_Array1OfReal    weights(1, np), knots(1, nk);
  TColStd_Array1OfInteger mults(1, nk);
  // Batch copy: batch accessors return NCollection_Array1 by const reference
  const TColgp_Array1OfPnt2d&    convPoles   = conv.Poles();
  const TColStd_Array1OfReal&    convWeights = conv.Weights();
  const TColStd_Array1OfReal&    convKnots   = conv.Knots();
  const TColStd_Array1OfInteger& convMults   = conv.Multiplicities();
  for (int i = 1; i <= np; i++)
  {
    poles(i)   = convPoles.Value(i);
    weights(i) = convWeights.Value(i);
  }
  for (int i = 1; i <= nk; i++)
  {
    knots(i) = convKnots.Value(i);
    mults(i) = convMults.Value(i);
  }
  Handle(Geom2d_BSplineCurve) bsc = new Geom2d_BSplineCurve(poles, weights, knots, mults, deg);
  if (bsc.IsNull())
    return nullptr;
  OCCTCurve2D* result = new OCCTCurve2D();
  result->curve       = bsc;
  return result;
}

OCCTCurve2DRef OCCTConvertEllipseToBSpline2D(double cx,
                                             double cy,
                                             double majorRadius,
                                             double minorRadius,
                                             double u1,
                                             double u2)
{
  if (!occtValidEllipseRadii(majorRadius, minorRadius))
    return nullptr;
  try
  {
    gp_Elips2d                    e(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0), gp_Dir2d(0, 1)),
                                    majorRadius,
                                    minorRadius);
    Convert_EllipseToBSplineCurve conv(e, u1, u2);
    return buildCurve2DFromConic(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTConvertHyperbolaToBSpline2D(double cx,
                                               double cy,
                                               double majorRadius,
                                               double minorRadius,
                                               double u1,
                                               double u2)
{
  if (!occtValidHyperbolaRadii(majorRadius, minorRadius))
    return nullptr;
  try
  {
    gp_Hypr2d                       h(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0), gp_Dir2d(0, 1)),
                                      majorRadius,
                                      minorRadius);
    Convert_HyperbolaToBSplineCurve conv(h, u1, u2);
    return buildCurve2DFromConic(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTConvertParabolaToBSpline2D(double cx,
                                              double cy,
                                              double focal,
                                              double u1,
                                              double u2)
{
  // Measured (#514): focal 0 does not fail here, it produces a 3-pole degree-2 BSpline whose
  // poles are NaN, so everything downstream of it evaluates to NaN.
  if (!occtValidParabolaFocal(focal))
    return nullptr;
  try
  {
    gp_Parab2d p(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), focal);
    Convert_ParabolaToBSplineCurve conv(p, u1, u2);
    return buildCurve2DFromConic(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Convert_CircleToBSplineCurve 2D (v0.94)
// MARK: - Convert_CircleToBSplineCurve (v0.94.0)

#include <Convert_CircleToBSplineCurve.hxx>

OCCTCurve2DRef OCCTConvertCircleToBSpline2D(double cx,
                                            double cy,
                                            double radius,
                                            double u1,
                                            double u2)
{
  if (!occtValidCircleRadius(radius))
    return nullptr;
  try
  {
    gp_Circ2d circle(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), radius);
    // Convert_CircleToBSplineCurve is a Convert_ConicToBSplineCurve subclass (#791), so it can
    // share the same array-building helper its Ellipse/Hyperbola/Parabola siblings already use.
    Convert_CircleToBSplineCurve conv(circle, u1, u2);
    return buildCurve2DFromConic(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.105: GC_MakeCircle2d/Ellipse2d/Hyperbola2d/Parabola2d,
// Geom2dConvert_CompCurveToBSplineCurve, Geom2dConvert_BSplineCurveKnotSplitting MARK: -
// GC_MakeCircle2d (v0.105.0)

#include <GC_MakeCircle2d.hxx>
#include <GC_MakeEllipse2d.hxx>
#include <GC_MakeHyperbola2d.hxx>
#include <GC_MakeParabola2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Circ2d.hxx>

OCCTCurve2DRef OCCTCurve2DMakeCircleCenterRadius(double cx, double cy, double radius)
{
  if (!occtValidCircleRadius(radius))
    return nullptr;
  try
  {
    GC_MakeCircle2d mc(gp_Pnt2d(cx, cy), radius);
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeCircle3Points(double x1,
                                            double y1,
                                            double x2,
                                            double y2,
                                            double x3,
                                            double y3)
{
  try
  {
    GC_MakeCircle2d mc(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2), gp_Pnt2d(x3, y3));
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeCircleCenterPoint(double cx, double cy, double px, double py)
{
  try
  {
    GC_MakeCircle2d mc(gp_Pnt2d(cx, cy), gp_Pnt2d(px, py));
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeCircleParallel(double cx,
                                             double cy,
                                             double dx,
                                             double dy,
                                             double radius,
                                             double dist)
{
  // The offset is checked as well as the radius. GC_MakeCircle2d takes the absolute value of
  // radius + dist rather than refusing an offset that reaches or passes the centre: measured
  // (#553), radius 5 offset by -5 gives radius 0 and by -6 gives radius 1, a circle inside the
  // base rather than the one the caller asked for.
  if (!occtValidCircleRadius(radius) || !occtValidCircleRadius(radius + dist))
    return nullptr;
  try
  {
    gp_Circ2d       circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy)), radius);
    GC_MakeCircle2d mc(circ, dist);
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeCircleAxis(double cx, double cy, double dx, double dy, double radius)
{
  if (!occtValidCircleRadius(radius))
    return nullptr;
  try
  {
    gp_Ax2d         ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    GC_MakeCircle2d mc(ax, radius);
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - GC_MakeEllipse2d (v0.105.0)

OCCTCurve2DRef OCCTCurve2DMakeEllipse(double cx,
                                      double cy,
                                      double dx,
                                      double dy,
                                      double major,
                                      double minor)
{
  try
  {
    gp_Ax2d          ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    GC_MakeEllipse2d me(ax, major, minor);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = me.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeEllipse3Points(double x1,
                                             double y1,
                                             double x2,
                                             double y2,
                                             double x3,
                                             double y3)
{
  try
  {
    GC_MakeEllipse2d me(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2), gp_Pnt2d(x3, y3));
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = me.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeEllipseAxis22d(double cx,
                                             double cy,
                                             double xdx,
                                             double xdy,
                                             double ydx,
                                             double ydy,
                                             double major,
                                             double minor)
{
  try
  {
    gp_Ax22d         ax(gp_Pnt2d(cx, cy), gp_Dir2d(xdx, xdy), gp_Dir2d(ydx, ydy));
    GC_MakeEllipse2d me(ax, major, minor);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = me.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - GC_MakeHyperbola2d (v0.105.0)

OCCTCurve2DRef OCCTCurve2DMakeHyperbola(double cx,
                                        double cy,
                                        double dx,
                                        double dy,
                                        double major,
                                        double minor)
{
  try
  {
    gp_Ax2d            ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    GC_MakeHyperbola2d mh(ax, major, minor);
    if (!mh.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mh.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeHyperbola3Points(double x1,
                                               double y1,
                                               double x2,
                                               double y2,
                                               double x3,
                                               double y3)
{
  try
  {
    GC_MakeHyperbola2d mh(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2), gp_Pnt2d(x3, y3));
    if (!mh.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mh.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - GC_MakeParabola2d (v0.105.0)

OCCTCurve2DRef OCCTCurve2DMakeParabola(double cx, double cy, double dx, double dy, double focal)
{
  try
  {
    gp_Ax2d           ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    GC_MakeParabola2d mp(ax, focal, true);
    if (!mp.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mp.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMakeParabolaDirectrixFocus(double dx,
                                                     double dy,
                                                     double ddx,
                                                     double ddy,
                                                     double fx,
                                                     double fy)
{
  try
  {
    gp_Ax2d           directrix(gp_Pnt2d(dx, dy), gp_Dir2d(ddx, ddy));
    GC_MakeParabola2d mp(directrix, gp_Pnt2d(fx, fy));
    if (!mp.IsDone())
      return nullptr;
    auto result   = new OCCTCurve2D();
    result->curve = mp.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Geom2dConvert_CompCurveToBSplineCurve (v0.105.0)

#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>

OCCTCurve2DRef OCCTConcatenateCurves2D(OCCTCurve2DRef* curves, int32_t count, double tolerance)
{
  if (!curves || count <= 0)
    return nullptr;
  try
  {
    if (!curves[0] || curves[0]->curve.IsNull())
      return nullptr;
    Handle(Geom2d_BoundedCurve) first = Handle(Geom2d_BoundedCurve)::DownCast(curves[0]->curve);
    if (first.IsNull())
    {
      double f = curves[0]->curve->FirstParameter();
      double l = curves[0]->curve->LastParameter();
      first    = new Geom2d_TrimmedCurve(curves[0]->curve, f, l);
    }
    Geom2dConvert_CompCurveToBSplineCurve comp(first);
    for (int32_t i = 1; i < count; i++)
    {
      if (!curves[i] || curves[i]->curve.IsNull())
        return nullptr;
      Handle(Geom2d_BoundedCurve) bc = Handle(Geom2d_BoundedCurve)::DownCast(curves[i]->curve);
      if (bc.IsNull())
      {
        double f = curves[i]->curve->FirstParameter();
        double l = curves[i]->curve->LastParameter();
        bc       = new Geom2d_TrimmedCurve(curves[i]->curve, f, l);
      }
      if (!comp.Add(bc, tolerance))
        return nullptr;
    }
    Handle(Geom2d_BSplineCurve) result = comp.BSplineCurve();
    if (result.IsNull())
      return nullptr;
    auto r   = new OCCTCurve2D();
    r->curve = result;
    return r;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #562: OCCTBSplineCurve2dKnotSplits and OCCTBSplineCurve2dKnotSplitValues stood here, a second
// wrap of Geom2dConvert_BSplineCurveKnotSplitting added three releases after
// OCCTCurve2DSplitAtDiscontinuities (further down this file) already wrapped it. Deleted; that
// one returns the same indices, and now reports the true count when truncated, which is the one
// respect in which these were the stronger pair rather than the weaker.

// MARK: - v0.106: BRepLib_MakeEdge2d extensions + Curve2D continuity
// MARK: - BRepLib_MakeEdge2d extensions (v0.106.0)

#include <BRepLib_MakeEdge2d.hxx>
#include <gp_Elips2d.hxx>

// BRepLib_MakeEdge2d reports IsDone() for a degenerate conic rather than refusing it: measured
// (#514), a zero-radius ellipse yields a zero-length edge with both vertices at the centre, and a
// zero minor radius yields a segment doubled back along the major axis. Neither is an edge the
// caller asked for, so the dimensions are checked before OCCT sees them.
OCCTShapeRef OCCTMakeEdge2dFullCircle(double cx, double cy, double dx, double dy, double radius)
{
  if (!occtValidCircleRadius(radius))
    return nullptr;
  try
  {
    gp_Ax2d            ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    gp_Circ2d          circ(ax, radius);
    BRepLib_MakeEdge2d me(circ);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = me.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdge2dEllipse(double cx,
                                   double cy,
                                   double dx,
                                   double dy,
                                   double major,
                                   double minor)
{
  if (!occtValidEllipseRadii(major, minor))
    return nullptr;
  try
  {
    gp_Ax2d            ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    gp_Elips2d         elips(ax, major, minor);
    BRepLib_MakeEdge2d me(elips);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = me.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdge2dEllipseArc(double cx,
                                      double cy,
                                      double dx,
                                      double dy,
                                      double major,
                                      double minor,
                                      double u1,
                                      double u2)
{
  if (!occtValidEllipseRadii(major, minor))
    return nullptr;
  try
  {
    gp_Ax2d            ax(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy));
    gp_Elips2d         elips(ax, major, minor);
    BRepLib_MakeEdge2d me(elips, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = me.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdge2dCurve(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    BRepLib_MakeEdge2d me(curve->curve);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = me.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdge2dCurveRange(OCCTCurve2DRef curve, double u1, double u2)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    BRepLib_MakeEdge2d me(curve->curve, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = me.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Curve2D continuity (v0.106.0)

int32_t OCCTCurve2DGetContinuity(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    return static_cast<int32_t>(curve->curve->Continuity());
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - v0.107: Geom2d_BSplineCurve Methods + Hatch_Hatcher
// MARK: - Geom2d_BSplineCurve Methods (v0.107.0)

int32_t OCCTCurve2DBSplineKnotCount(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  return bs->NbKnots();
}

int32_t OCCTCurve2DBSplinePoleCount(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  return bs->NbPoles();
}

int32_t OCCTCurve2DBSplineDegree(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  return bs->Degree();
}

bool OCCTCurve2DBSplineIsRational(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  return bs->IsRational();
}

void OCCTCurve2DBSplineGetPole(OCCTCurve2DRef curve, int32_t index, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve || curve->curve.IsNull())
    return;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return;
  gp_Pnt2d p = bs->Pole(index);
  *x         = p.X();
  *y         = p.Y();
}

bool OCCTCurve2DBSplineSetPole(OCCTCurve2DRef curve, int32_t index, double x, double y)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return false;
  try
  {
    bs->SetPole(index, gp_Pnt2d(x, y));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineSetWeight(OCCTCurve2DRef curve, int32_t index, double weight)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return false;
  try
  {
    bs->SetWeight(index, weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineInsertKnot(OCCTCurve2DRef curve, double u, int32_t mult, double tol)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->InsertKnot(u, mult, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineRemoveKnot(OCCTCurve2DRef curve, int32_t index, int32_t mult, double tol)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbKnots())
    return false;
  try
  {
    return bs->RemoveKnot(index, mult, tol);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineSegment(OCCTCurve2DRef curve, double u1, double u2)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->Segment(u1, u2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineIncreaseDegree(OCCTCurve2DRef curve, int32_t degree)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseDegree(degree);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DBSplineResolution(OCCTCurve2DRef curve, double tolerance)
{
  if (!curve || curve->curve.IsNull())
    return 0.0;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0.0;
  double uTol = 0;
  bs->Resolution(tolerance, uTol);
  return uTol;
}

// MARK: - Hatch_Hatcher (v0.107.0)

struct OCCTHatcher
{
  Hatch_Hatcher hatcher;

  OCCTHatcher(double tol)
      : hatcher(tol, false)
  {
  }
};

OCCTHatcherRef OCCTHatcherCreate(double tolerance)
{
  try
  {
    return new OCCTHatcher(tolerance);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTHatcherRelease(OCCTHatcherRef hatcher)
{
  delete hatcher;
}

void OCCTHatcherAddXLine(OCCTHatcherRef hatcher, double x)
{
  if (!hatcher)
    return;
  try
  {
    hatcher->hatcher.AddXLine(x);
  }
  catch (...)
  {
  }
}

void OCCTHatcherAddYLine(OCCTHatcherRef hatcher, double y)
{
  if (!hatcher)
    return;
  try
  {
    hatcher->hatcher.AddYLine(y);
  }
  catch (...)
  {
  }
}

void OCCTHatcherTrim(OCCTHatcherRef hatcher, double x1, double y1, double x2, double y2)
{
  if (!hatcher)
    return;
  try
  {
    hatcher->hatcher.Trim(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2));
  }
  catch (...)
  {
  }
}

int32_t OCCTHatcherNbLines(OCCTHatcherRef hatcher)
{
  if (!hatcher)
    return 0;
  try
  {
    return hatcher->hatcher.NbLines();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTHatcherNbIntervals(OCCTHatcherRef hatcher, int32_t lineIndex)
{
  if (!hatcher)
    return 0;
  try
  {
    return hatcher->hatcher.NbIntervals(lineIndex);
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - v0.108: Geom2d_Circle/Ellipse/Hyperbola/Parabola/Line/OffsetCurve Methods
// MARK: - Geom2d_Circle Methods (v0.108.0)

double OCCTCurve2DCircleRadius(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Circle) c = Handle(Geom2d_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return 0;
    return c->Radius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve2DCircleSetRadius(OCCTCurve2DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_Circle) c = Handle(Geom2d_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return false;
    c->SetRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DCircleEccentricity(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Circle) c = Handle(Geom2d_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return 0;
    return c->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DCircleCenter(OCCTCurve2DRef curve, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Circle) c = Handle(Geom2d_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return;
    gp_Pnt2d ctr = c->Circ2d().Location();
    *x           = ctr.X();
    *y           = ctr.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DCircleXAxis(OCCTCurve2DRef curve, double* px, double* py, double* dx, double* dy)
{
  *px = 0;
  *py = 0;
  *dx = 0;
  *dy = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Circle) c = Handle(Geom2d_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return;
    gp_Ax2d ax = c->XAxis();
    *px        = ax.Location().X();
    *py        = ax.Location().Y();
    *dx        = ax.Direction().X();
    *dy        = ax.Direction().Y();
  }
  catch (...)
  {
  }
}

// MARK: - Geom2d_Ellipse Methods (v0.108.0)

double OCCTCurve2DEllipseMajorRadius(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->MajorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DEllipseMinorRadius(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->MinorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve2DEllipseSetMajorRadius(OCCTCurve2DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return false;
    e->SetMajorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DEllipseSetMinorRadius(OCCTCurve2DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return false;
    e->SetMinorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DEllipseEccentricity(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DEllipseFocal(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->Focal();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DEllipseFocus1(OCCTCurve2DRef curve, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Ellipse) e = Handle(Geom2d_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return;
    gp_Pnt2d f = e->Focus1();
    *x         = f.X();
    *y         = f.Y();
  }
  catch (...)
  {
  }
}

// MARK: - Geom2d_Hyperbola Methods (v0.108.0)

double OCCTCurve2DHyperbolaMajorRadius(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Hyperbola) h = Handle(Geom2d_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->MajorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DHyperbolaMinorRadius(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Hyperbola) h = Handle(Geom2d_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->MinorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DHyperbolaEccentricity(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Hyperbola) h = Handle(Geom2d_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DHyperbolaFocal(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Hyperbola) h = Handle(Geom2d_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->Focal();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DHyperbolaFocus1(OCCTCurve2DRef curve, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Hyperbola) h = Handle(Geom2d_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return;
    gp_Pnt2d f = h->Focus1();
    *x         = f.X();
    *y         = f.Y();
  }
  catch (...)
  {
  }
}

// MARK: - Geom2d_Parabola Methods (v0.108.0)

double OCCTCurve2DParabolaFocal(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Parabola) p = Handle(Geom2d_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return 0;
    return p->Focal();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve2DParabolaSetFocal(OCCTCurve2DRef curve, double focal)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_Parabola) p = Handle(Geom2d_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return false;
    p->SetFocal(focal);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve2DParabolaFocus(OCCTCurve2DRef curve, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Parabola) p = Handle(Geom2d_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return;
    gp_Pnt2d f = p->Focus();
    *x         = f.X();
    *y         = f.Y();
  }
  catch (...)
  {
  }
}

double OCCTCurve2DParabolaEccentricity(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Parabola) p = Handle(Geom2d_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return 0;
    return p->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DParabolaParameter(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Parabola) p = Handle(Geom2d_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return 0;
    return p->Parameter();
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Geom2d_Line Methods (v0.108.0)

void OCCTCurve2DLineDirection(OCCTCurve2DRef curve, double* dx, double* dy)
{
  *dx = 0;
  *dy = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Line) l = Handle(Geom2d_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Dir2d d = l->Direction();
    *dx        = d.X();
    *dy        = d.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DLineLocation(OCCTCurve2DRef curve, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Line) l = Handle(Geom2d_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Pnt2d loc = l->Location();
    *x           = loc.X();
    *y           = loc.Y();
  }
  catch (...)
  {
  }
}

bool OCCTCurve2DLineSetDirection(OCCTCurve2DRef curve, double dx, double dy)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_Line) l = Handle(Geom2d_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return false;
    l->SetDirection(gp_Dir2d(dx, dy));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DLineSetLocation(OCCTCurve2DRef curve, double x, double y)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_Line) l = Handle(Geom2d_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return false;
    l->SetLocation(gp_Pnt2d(x, y));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DLineDistance(OCCTCurve2DRef curve, double px, double py)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_Line) l = Handle(Geom2d_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return 0;
    return l->Distance(gp_Pnt2d(px, py));
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DLineLin2d(OCCTCurve2DRef curve, double* px, double* py, double* dx, double* dy)
{
  *px = 0;
  *py = 0;
  *dx = 0;
  *dy = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom2d_Line) l = Handle(Geom2d_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Lin2d gl = l->Lin2d();
    *px         = gl.Location().X();
    *py         = gl.Location().Y();
    *dx         = gl.Direction().X();
    *dy         = gl.Direction().Y();
  }
  catch (...)
  {
  }
}

// MARK: - Geom2d_OffsetCurve Methods (v0.108.0)

double OCCTCurve2DOffsetValue(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom2d_OffsetCurve) oc = Handle(Geom2d_OffsetCurve)::DownCast(curve->curve);
    if (oc.IsNull())
      return 0;
    return oc->Offset();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve2DOffsetSetValue(OCCTCurve2DRef curve, double offset)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom2d_OffsetCurve) oc = Handle(Geom2d_OffsetCurve)::DownCast(curve->curve);
    if (oc.IsNull())
      return false;
    oc->SetOffsetValue(offset);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve2DRef OCCTCurve2DOffsetBasisCurve(OCCTCurve2DRef curve)
{
  if (!curve)
    return nullptr;
  try
  {
    Handle(Geom2d_OffsetCurve) oc = Handle(Geom2d_OffsetCurve)::DownCast(curve->curve);
    if (oc.IsNull())
      return nullptr;
    Handle(Geom2d_Curve) basis = oc->BasisCurve();
    if (basis.IsNull())
      return nullptr;
    return new OCCTCurve2D(basis);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.109-v0.111: IntAna2d_Conic + Curve2D Extras + Curve2D Evaluation + GridEval
// MARK: - IntAna2d_Conic (v0.109.0)

#include <IntAna2d_Conic.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>

// The three OCCTConic2dFrom* entry points share one failure encoding: the six coefficients are
// zeroed and false returned. Zeroing alone could not carry it: 0 = 0 holds at every point of the
// plane, so an all-zero result reads as a conic rather than as no answer, and a degenerate ellipse
// produced exactly that (#514).
static bool occtConic2dCoefficients(const IntAna2d_Conic& conic, double* coeffs)
{
  double A, B, C, D, E, F;
  conic.Coefficients(A, B, C, D, E, F);
  coeffs[0] = A;
  coeffs[1] = B;
  coeffs[2] = C;
  coeffs[3] = D;
  coeffs[4] = E;
  coeffs[5] = F;
  return true;
}

static bool occtConic2dFailed(double* coeffs)
{
  for (int i = 0; i < 6; i++)
    coeffs[i] = 0;
  return false;
}

bool OCCTConic2dFromCircle(double  cx,
                           double  cy,
                           double  dx,
                           double  dy,
                           double  radius,
                           double* coeffs)
{
  if (!occtValidCircleRadius(radius))
    return occtConic2dFailed(coeffs);
  try
  {
    gp_Circ2d circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy)), radius);
    return occtConic2dCoefficients(IntAna2d_Conic(circ), coeffs);
  }
  catch (...)
  {
    return occtConic2dFailed(coeffs);
  }
}

bool OCCTConic2dFromLine(double px, double py, double dx, double dy, double* coeffs)
{
  try
  {
    gp_Lin2d line(gp_Pnt2d(px, py), gp_Dir2d(dx, dy));
    return occtConic2dCoefficients(IntAna2d_Conic(line), coeffs);
  }
  catch (...)
  {
    return occtConic2dFailed(coeffs);
  }
}

bool OCCTConic2dFromEllipse(double  cx,
                            double  cy,
                            double  dx,
                            double  dy,
                            double  majorRadius,
                            double  minorRadius,
                            double* coeffs)
{
  if (!occtValidEllipseRadii(majorRadius, minorRadius))
    return occtConic2dFailed(coeffs);
  try
  {
    gp_Elips2d elips(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy)), majorRadius, minorRadius);
    return occtConic2dCoefficients(IntAna2d_Conic(elips), coeffs);
  }
  catch (...)
  {
    return occtConic2dFailed(coeffs);
  }
}

int32_t OCCTConic2dLineCircleIntersect(double  lpx,
                                       double  lpy,
                                       double  ldx,
                                       double  ldy,
                                       double  cx,
                                       double  cy,
                                       double  cdx,
                                       double  cdy,
                                       double  radius,
                                       double* xs,
                                       double* ys,
                                       int32_t max)
{
  // Same circle contract as OCCTConic2dFromCircle above: intersecting against a radius-0 circle
  // is a point-on-line test, not an intersection, and asking it here would be the one place in
  // this block that still accepted a degenerate circle.
  if (!occtValidCircleRadius(radius))
    return -1;
  try
  {
    gp_Lin2d                 line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
    gp_Circ2d                circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(cdx, cdy)), radius);
    IntAna2d_AnaIntersection inter(line, IntAna2d_Conic(circ));
    if (!inter.IsDone())
      return -1;
    int n     = inter.NbPoints();
    int count = 0;
    for (int i = 1; i <= n && count < max; i++)
    {
      const IntAna2d_IntPoint& pt = inter.Point(i);
      xs[count]                   = pt.Value().X();
      ys[count]                   = pt.Value().Y();
      count++;
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

// MARK: - Curve2D Extras (v0.109.0)

bool OCCTCurve2DReverse(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false; // #478
  try
  {
    curve->curve->Reverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve2DRef OCCTCurve2DCopy(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr; // #478
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(curve->curve->Copy());
    if (copy.IsNull())
      return nullptr;
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Delegates to OCCTCurve2DGetContinuity: same Continuity() call, one encoding (#485).
int32_t OCCTCurve2DContinuity(OCCTCurve2DRef curve)
{
  return OCCTCurve2DGetContinuity(curve);
}

// MARK: - Curve2D Evaluation (v0.110.0)

void OCCTCurve2DEvalD0(OCCTCurve2DRef curve, double u, double* x, double* y)
{
  *x = 0;
  *y = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    gp_Pnt2d p = curve->curve->EvalD0(u);
    *x         = p.X();
    *y         = p.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DEvalD1(OCCTCurve2DRef curve,
                       double         u,
                       double*        px,
                       double*        py,
                       double*        d1x,
                       double*        d1y)
{
  *px  = 0;
  *py  = 0;
  *d1x = 0;
  *d1y = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    Geom2d_Curve::ResD1 r = curve->curve->EvalD1(u);
    *px                   = r.Point.X();
    *py                   = r.Point.Y();
    *d1x                  = r.D1.X();
    *d1y                  = r.D1.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DEvalD2(OCCTCurve2DRef curve,
                       double         u,
                       double*        px,
                       double*        py,
                       double*        d1x,
                       double*        d1y,
                       double*        d2x,
                       double*        d2y)
{
  *px  = 0;
  *py  = 0;
  *d1x = 0;
  *d1y = 0;
  *d2x = 0;
  *d2y = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    Geom2d_Curve::ResD2 r = curve->curve->EvalD2(u);
    *px                   = r.Point.X();
    *py                   = r.Point.Y();
    *d1x                  = r.D1.X();
    *d1y                  = r.D1.Y();
    *d2x                  = r.D2.X();
    *d2y                  = r.D2.Y();
  }
  catch (...)
  {
  }
}

// MARK: - Geom2dGridEval_Curve (v0.111.0)
//
// #486: OCCTGridEvalCurve2dD0/D1 lived here, the same Geom2dGridEval_Curve::EvaluateGrid /
// EvaluateGridD1 calls as OCCTCurve2DEvaluateGrid/D1 above, only writing per-axis planes
// instead of interleaved pairs. Removed; Curve2D.gridEvalD0/D1 now forward to the v0.28.0 pair.

// MARK: - v0.112: Curve2D extras
// --- Curve2D extras ---

int32_t OCCTCurve2DCurveType(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 7;
  try
  {
    Geom2dAdaptor_Curve ac(curve->curve);
    return (int32_t)ac.GetType();
  }
  catch (...)
  {
    return 7;
  }
}

// Failure contract: returns false, leaving *outParameter untouched. This replaces
// OCCTCurve2DParameterAtPoint, which reported "no projection" as curve->FirstParameter(): a real
// parameter in the curve's own domain, indistinguishable from a genuine result, and right or
// maximally wrong depending only on which end the point fell off (#500).
bool OCCTCurve2DNearestParameter(OCCTCurve2DRef _Nonnull curve,
                                 double x,
                                 double y,
                                 double* _Nonnull outParameter)
{
  return occtNearestProjectionOnCurve2d(curve, gp_Pnt2d(x, y), nullptr, outParameter, nullptr);
}

// MARK: - v0.114: Curve2D isBounded + DN + type-name

bool OCCTCurve2DIsBounded(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    Handle(Geom2d_BoundedCurve) bc = Handle(Geom2d_BoundedCurve)::DownCast(curve->curve);
    return !bc.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve2DDN(OCCTCurve2DRef curve, double u, int32_t n, double* x, double* y)
{
  if (!curve || curve->curve.IsNull())
  {
    *x = *y = 0;
    return;
  }
  try
  {
    gp_Vec2d v = curve->curve->DN(u, n);
    *x         = v.X();
    *y         = v.Y();
  }
  catch (...)
  {
    *x = *y = 0;
  }
}

const char* OCCTCurve2DTypeName(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    return curve->curve->DynamicType()->Name();
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.115: 2D interpolate / PointsToBSpline / SplitAtContinuity / Trimmed / Length
// (re-routed from Curve3D) Exactly OCCTCurve2DInterpolateWithTangents with tolerance pinned to the
// OCCT default. It used to be a second, independent Geom2dAPI_Interpolate call site with the
// tolerance hardcoded and no way to reach it. Forwarding keeps the C ABI while leaving one
// implementation (#410). Callers that need a different tolerance should call
// OCCTCurve2DInterpolateWithTangents directly.
OCCTCurve2DRef OCCTInterpolate2DWithTangents(const double* points,
                                             int32_t       count,
                                             double        t1x,
                                             double        t1y,
                                             double        t2x,
                                             double        t2y)
{
  return OCCTCurve2DInterpolateWithTangents(points, count, t1x, t1y, t2x, t2y, 1e-6);
}

// Exactly OCCTCurve2DInterpolate with the periodicity flag pinned. It used to be a second,
// independent Geom2dAPI_Interpolate call site, which had already drifted: it rejected count < 3
// where the general entry point rejects only count < 2, so the same 2-point input reached OCCT
// through one and not the other. Forwarding keeps the C ABI while leaving one implementation
// (#412). Callers that need a tolerance other than the default should call
// OCCTCurve2DInterpolate directly with closed = true.
OCCTCurve2DRef OCCTInterpolate2DPeriodic(const double* points, int32_t count)
{
  return OCCTCurve2DInterpolate(points, count, true, 1e-6);
}

// --- Geom2dAPI_PointsToBSpline expansion ---
// (the 2D half of the header's "PointsToBSpline expansion" section; the 3D and surface
// halves live in OCCTBridge_Curve3D.mm and OCCTBridge_Surface.mm)

OCCTCurve2DRef OCCTPoints2DToBSplineWithParams(const double* points,
                                               int32_t       count,
                                               int32_t       degMin,
                                               int32_t       degMax,
                                               int32_t       continuity,
                                               double        tol)
{
  if (!points || count < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt2d pts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts.SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
    }
    Geom2dAPI_PointsToBSpline approx(pts,
                                     degMin,
                                     degMax,
                                     occtGeomAbsFromParametricContinuity(continuity),
                                     tol);
    if (approx.IsDone())
    {
      return (OCCTCurve2DRef) new OCCTCurve2D{approx.Curve()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTCurve2DSplitAtContinuity(OCCTCurve2DRef  curve,
                                     int32_t         continuity,
                                     double          tol,
                                     OCCTCurve2DRef* outSegments,
                                     int32_t         maxSegments)
{
  if (!curve || curve->curve.IsNull() || !outSegments || maxSegments < 1)
    return 0;
  try
  {
    Handle(Geom2d_BSplineCurve) bsp = Geom2dConvert::CurveToBSplineCurve(curve->curve);
    if (bsp.IsNull())
      return 0;

    if (continuity <= 1)
    {
      Handle(NCollection_HArray1<Handle(Geom2d_BSplineCurve)>) arr;
      Geom2dConvert::C0BSplineToArrayOfC1BSplineCurve(bsp, arr, tol);
      if (arr.IsNull())
        return 0;
      int n = std::min((int)arr->Length(), (int)maxSegments);
      for (int i = 0; i < n; i++)
      {
        outSegments[i] = (OCCTCurve2DRef) new OCCTCurve2D{arr->Value(arr->Lower() + i)};
      }
      return n;
    }
    else
    {
      outSegments[0] = (OCCTCurve2DRef) new OCCTCurve2D{bsp};
      return 1;
    }
  }
  catch (...)
  {
    return 0;
  }
}

OCCTCurve2DRef OCCTCurve2DTrimmed(OCCTCurve2DRef curve, double u1, double u2)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_TrimmedCurve) trimmed = new Geom2d_TrimmedCurve(curve->curve, u1, u2);
    return (OCCTCurve2DRef) new OCCTCurve2D{trimmed};
  }
  catch (...)
  {
    return nullptr;
  }
}

// OCCTCurve2DLength lived here: GCPnts_AbscissaPoint::Length over a pre-bounded
// Geom2dAdaptor_Curve(curve, u1, u2), which raises on a reversed range (so the catch reported a
// reversed range as -1.0) and extrapolates past a multi-span curve's knots instead of clamping to
// its domain. Removed by #549, which is what #506 did to the 3D spelling of the same call;
// Curve2D.arcLength(from:to:) now routes through OCCTCurve2DGetLengthBetween, which does neither.
// OCCTCurve2DGetLengthBetween (below) carries this PR's (#548) non-finite-bound rejection via
// occtValidParameterRange, so the guard #602 originally added here now lives on the surviving
// spelling instead of being re-added to the removed one. Its winding/domain-confinement fix (#600)
// is on the same surviving spelling, see OCCTCurve2DGetLengthBetween below.

// MARK: - v0.116: gp_GTrsf2d + gp_Mat2d
void OCCTGTrsf2dAffinity(double axPx,
                         double axPy,
                         double axDx,
                         double axDy,
                         double ratio,
                         double* _Nonnull mat,
                         double* _Nonnull tx,
                         double* _Nonnull ty)
{
  gp_GTrsf2d gt;
  gt.SetAffinity(gp_Ax2d(gp_Pnt2d(axPx, axPy), gp_Dir2d(axDx, axDy)), ratio);
  const gp_Mat2d& m = gt.VectorialPart();
  mat[0]            = m.Value(1, 1);
  mat[1]            = m.Value(1, 2);
  mat[2]            = m.Value(2, 1);
  mat[3]            = m.Value(2, 2);
  *tx               = gt.TranslationPart().X();
  *ty               = gt.TranslationPart().Y();
}

void OCCTGTrsf2dMultiply(const double* _Nonnull matA,
                         double txA,
                         double tyA,
                         const double* _Nonnull matB,
                         double txB,
                         double tyB,
                         double* _Nonnull matR,
                         double* _Nonnull txR,
                         double* _Nonnull tyR)
{
  gp_GTrsf2d a, b;
  gp_Mat2d   ma;
  ma.SetValue(1, 1, matA[0]);
  ma.SetValue(1, 2, matA[1]);
  ma.SetValue(2, 1, matA[2]);
  ma.SetValue(2, 2, matA[3]);
  a.SetVectorialPart(ma);
  a.SetTranslationPart(gp_XY(txA, tyA));
  gp_Mat2d mb;
  mb.SetValue(1, 1, matB[0]);
  mb.SetValue(1, 2, matB[1]);
  mb.SetValue(2, 1, matB[2]);
  mb.SetValue(2, 2, matB[3]);
  b.SetVectorialPart(mb);
  b.SetTranslationPart(gp_XY(txB, tyB));
  gp_GTrsf2d      r  = a.Multiplied(b);
  const gp_Mat2d& mr = r.VectorialPart();
  matR[0]            = mr.Value(1, 1);
  matR[1]            = mr.Value(1, 2);
  matR[2]            = mr.Value(2, 1);
  matR[3]            = mr.Value(2, 2);
  *txR               = r.TranslationPart().X();
  *tyR               = r.TranslationPart().Y();
}

bool OCCTGTrsf2dInvert(const double* _Nonnull mat,
                       double tx,
                       double ty,
                       double* _Nonnull matR,
                       double* _Nonnull txR,
                       double* _Nonnull tyR)
{
  try
  {
    gp_GTrsf2d gt;
    gp_Mat2d   m;
    m.SetValue(1, 1, mat[0]);
    m.SetValue(1, 2, mat[1]);
    m.SetValue(2, 1, mat[2]);
    m.SetValue(2, 2, mat[3]);
    gt.SetVectorialPart(m);
    gt.SetTranslationPart(gp_XY(tx, ty));
    gp_GTrsf2d      inv = gt.Inverted();
    const gp_Mat2d& mr  = inv.VectorialPart();
    matR[0]             = mr.Value(1, 1);
    matR[1]             = mr.Value(1, 2);
    matR[2]             = mr.Value(2, 1);
    matR[3]             = mr.Value(2, 2);
    *txR                = inv.TranslationPart().X();
    *tyR                = inv.TranslationPart().Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGTrsf2dTransformPoint(const double* _Nonnull mat,
                               double tx,
                               double ty,
                               double px,
                               double py,
                               double* _Nonnull rx,
                               double* _Nonnull ry)
{
  gp_GTrsf2d gt;
  gp_Mat2d   m;
  m.SetValue(1, 1, mat[0]);
  m.SetValue(1, 2, mat[1]);
  m.SetValue(2, 1, mat[2]);
  m.SetValue(2, 2, mat[3]);
  gt.SetVectorialPart(m);
  gt.SetTranslationPart(gp_XY(tx, ty));
  gp_XY pt(px, py);
  gp_XY result = gt.Transformed(pt);
  *rx          = result.X();
  *ry          = result.Y();
}

// gp_Mat2d

void OCCTMat2dIdentity(double* _Nonnull mat)
{
  gp_Mat2d m;
  m.SetIdentity();
  mat[0] = m.Value(1, 1);
  mat[1] = m.Value(1, 2);
  mat[2] = m.Value(2, 1);
  mat[3] = m.Value(2, 2);
}

void OCCTMat2dRotation(double angle, double* _Nonnull mat)
{
  gp_Mat2d m;
  m.SetRotation(angle);
  mat[0] = m.Value(1, 1);
  mat[1] = m.Value(1, 2);
  mat[2] = m.Value(2, 1);
  mat[3] = m.Value(2, 2);
}

void OCCTMat2dScale(double s, double* _Nonnull mat)
{
  gp_Mat2d m;
  m.SetScale(s);
  mat[0] = m.Value(1, 1);
  mat[1] = m.Value(1, 2);
  mat[2] = m.Value(2, 1);
  mat[3] = m.Value(2, 2);
}

double OCCTMat2dDeterminant(const double* _Nonnull mat)
{
  gp_Mat2d m;
  m.SetValue(1, 1, mat[0]);
  m.SetValue(1, 2, mat[1]);
  m.SetValue(2, 1, mat[2]);
  m.SetValue(2, 2, mat[3]);
  return m.Determinant();
}

bool OCCTMat2dInvert(const double* _Nonnull mat, double* _Nonnull result)
{
  try
  {
    gp_Mat2d m;
    m.SetValue(1, 1, mat[0]);
    m.SetValue(1, 2, mat[1]);
    m.SetValue(2, 1, mat[2]);
    m.SetValue(2, 2, mat[3]);
    gp_Mat2d inv = m.Inverted();
    result[0]    = inv.Value(1, 1);
    result[1]    = inv.Value(1, 2);
    result[2]    = inv.Value(2, 1);
    result[3]    = inv.Value(2, 2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTMat2dMultiply(const double* _Nonnull matA,
                       const double* _Nonnull matB,
                       double* _Nonnull result)
{
  gp_Mat2d a, b;
  a.SetValue(1, 1, matA[0]);
  a.SetValue(1, 2, matA[1]);
  a.SetValue(2, 1, matA[2]);
  a.SetValue(2, 2, matA[3]);
  b.SetValue(1, 1, matB[0]);
  b.SetValue(1, 2, matB[1]);
  b.SetValue(2, 1, matB[2]);
  b.SetValue(2, 2, matB[3]);
  gp_Mat2d r = a.Multiplied(b);
  result[0]  = r.Value(1, 1);
  result[1]  = r.Value(1, 2);
  result[2]  = r.Value(2, 1);
  result[3]  = r.Value(2, 2);
}

void OCCTMat2dTranspose(const double* _Nonnull mat, double* _Nonnull result)
{
  gp_Mat2d m;
  m.SetValue(1, 1, mat[0]);
  m.SetValue(1, 2, mat[1]);
  m.SetValue(2, 1, mat[2]);
  m.SetValue(2, 2, mat[3]);
  gp_Mat2d t = m.Transposed();
  result[0]  = t.Value(1, 1);
  result[1]  = t.Value(1, 2);
  result[2]  = t.Value(2, 1);
  result[3]  = t.Value(2, 2);
}

// Quaternion interpolation

// MARK: - v0.118: Curve2D Bezier + BSpline extras
// --- Curve2D Bezier ---

void OCCTCurve2DBezierGetPole(OCCTCurve2DRef curve, int32_t index, double* x, double* y)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
    {
      *x = *y = 0;
      return;
    }
    gp_Pnt2d p = bezier->Pole(index);
    *x         = p.X();
    *y         = p.Y();
  }
  catch (...)
  {
    *x = *y = 0;
  }
}

bool OCCTCurve2DBezierSetPole(OCCTCurve2DRef curve, int32_t index, double x, double y)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
      return false;
    bezier->SetPole(index, gp_Pnt2d(x, y));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBezierSetWeight(OCCTCurve2DRef curve, int32_t index, double weight)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
      return false;
    bezier->SetWeight(index, weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCurve2DBezierDegree(OCCTCurve2DRef curve)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
      return -1;
    return (int32_t)bezier->Degree();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTCurve2DBezierPoleCount(OCCTCurve2DRef curve)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
      return 0;
    return (int32_t)bezier->NbPoles();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve2DBezierIsRational(OCCTCurve2DRef curve)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
      return false;
    return bezier->IsRational();
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DBezierResolution(OCCTCurve2DRef curve, double tolerance)
{
  try
  {
    auto* c      = static_cast<OCCTCurve2D*>(curve);
    auto  bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);
    if (bezier.IsNull())
      return 0;
    double utol = 0;
    bezier->Resolution(tolerance, utol);
    return utol;
  }
  catch (...)
  {
    return 0;
  }
}

// --- Curve2D BSpline extras ---

bool OCCTCurve2DBSplineSetPeriodic(OCCTCurve2DRef curve, bool periodic)
{
  try
  {
    auto* c   = static_cast<OCCTCurve2D*>(curve);
    auto  bsp = occ::handle<Geom2d_BSplineCurve>::DownCast(c->curve);
    if (bsp.IsNull())
      return false;
    if (periodic)
      bsp->SetPeriodic();
    else
      bsp->SetNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DBSplineGetWeight(OCCTCurve2DRef curve, int32_t index)
{
  try
  {
    auto* c   = static_cast<OCCTCurve2D*>(curve);
    auto  bsp = occ::handle<Geom2d_BSplineCurve>::DownCast(c->curve);
    if (bsp.IsNull())
      return 0;
    return bsp->Weight(index);
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DBSplineGetWeights(OCCTCurve2DRef curve, double* weights)
{
  try
  {
    auto* c   = static_cast<OCCTCurve2D*>(curve);
    auto  bsp = occ::handle<Geom2d_BSplineCurve>::DownCast(c->curve);
    if (bsp.IsNull())
      return;
    NCollection_Array1<double> w(1, bsp->NbPoles());
    bsp->Weights(w);
    for (int i = 1; i <= bsp->NbPoles(); i++)
    {
      weights[i - 1] = w(i);
    }
  }
  catch (...)
  {
  }
}

// MARK: - v0.120: Curve2D continuity + BezierMaxDegree + BSplineMaxDegree
// --- Curve2D continuity queries ---

bool OCCTCurve2DIsCN(OCCTCurve2DRef _Nonnull curve, int32_t n)
{
  try
  {
    auto c = *(occ::handle<Geom2d_Curve>*)curve;
    if (c.IsNull())
      return false;
    return c->IsCN(n);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve2DReversedParameter(OCCTCurve2DRef _Nonnull curve, double u)
{
  try
  {
    auto c = *(occ::handle<Geom2d_Curve>*)curve;
    if (c.IsNull())
      return u;
    return c->ReversedParameter(u);
  }
  catch (...)
  {
    return u;
  }
}

int32_t OCCTCurve2DBezierMaxDegree(void)
{
  return Geom2d_BezierCurve::MaxDegree();
}

int32_t OCCTCurve2DBSplineMaxDegree(void)
{
  return Geom2d_BSplineCurve::MaxDegree();
}

// MARK: - v0.121: BSplineCurve 2D completions
// --- BSplineCurve 2D completions ---

bool OCCTCurve2DBSplineSetNotPeriodic(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineSetOrigin(OCCTCurve2DRef curve, int32_t index)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetOrigin(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineIncreaseMultiplicity(OCCTCurve2DRef curve, int32_t index, int32_t mult)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseMultiplicity(index, mult);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineIncrementMultiplicity(OCCTCurve2DRef curve,
                                             int32_t        index1,
                                             int32_t        index2,
                                             int32_t        step)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncrementMultiplicity(index1, index2, step);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineSetKnots(OCCTCurve2DRef curve, const double* knots, int32_t count)
{
  if (!curve || curve->curve.IsNull() || !knots || count <= 0)
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || count != bs->NbKnots())
    return false;
  try
  {
    TColStd_Array1OfReal kArr(1, count);
    for (int32_t i = 0; i < count; i++)
    {
      kArr.SetValue(i + 1, knots[i]);
    }
    bs->SetKnots(kArr);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineReverse(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->Reverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineMovePointAndTangent(OCCTCurve2DRef curve,
                                           double         u,
                                           double         px,
                                           double         py,
                                           double         tx,
                                           double         ty,
                                           double         tolerance,
                                           int32_t        startIndex,
                                           int32_t        endIndex)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom2d_BSplineCurve) bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    Standard_Integer errorStatus = 0;
    bs->MovePointAndTangent(u,
                            gp_Pnt2d(px, py),
                            gp_Vec2d(tx, ty),
                            tolerance,
                            startIndex,
                            endIndex,
                            errorStatus);
    return (errorStatus == 0);
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.125: Geom2d_BSplineCurve completions
// --- Geom2d_BSplineCurve completions ---

void OCCTCurve2DBSplineLocalD0(OCCTCurve2DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        x,
                               double*        y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P;
    bs->LocalD0(u, fromK1, toK2, P);
    *x = P.X();
    *y = P.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineLocalD1(OCCTCurve2DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        v1x,
                               double*        v1y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P;
    gp_Vec2d V1;
    bs->LocalD1(u, fromK1, toK2, P, V1);
    *px  = P.X();
    *py  = P.Y();
    *v1x = V1.X();
    *v1y = V1.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineLocalD2(OCCTCurve2DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        v1x,
                               double*        v1y,
                               double*        v2x,
                               double*        v2y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P;
    gp_Vec2d V1, V2;
    bs->LocalD2(u, fromK1, toK2, P, V1, V2);
    *px  = P.X();
    *py  = P.Y();
    *v1x = V1.X();
    *v1y = V1.Y();
    *v2x = V2.X();
    *v2y = V2.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineLocalD3(OCCTCurve2DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        v1x,
                               double*        v1y,
                               double*        v2x,
                               double*        v2y,
                               double*        v3x,
                               double*        v3y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P;
    gp_Vec2d V1, V2, V3;
    bs->LocalD3(u, fromK1, toK2, P, V1, V2, V3);
    *px  = P.X();
    *py  = P.Y();
    *v1x = V1.X();
    *v1y = V1.Y();
    *v2x = V2.X();
    *v2y = V2.Y();
    *v3x = V3.X();
    *v3y = V3.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineLocalDN(OCCTCurve2DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               int32_t        n,
                               double*        vx,
                               double*        vy)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Vec2d V = bs->LocalDN(u, fromK1, toK2, n);
    *vx        = V.X();
    *vy        = V.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineLocalValue(OCCTCurve2DRef curve,
                                  double         u,
                                  int32_t        fromK1,
                                  int32_t        toK2,
                                  double*        x,
                                  double*        y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P = bs->LocalValue(u, fromK1, toK2);
    *x         = P.X();
    *y         = P.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineLocateU(OCCTCurve2DRef curve,
                               double         u,
                               double         paramTol,
                               int32_t*       i1,
                               int32_t*       i2)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    int I1 = 0, I2 = 0;
    bs->LocateU(u, paramTol, I1, I2);
    *i1 = I1;
    *i2 = I2;
  }
  catch (...)
  {
  }
}

int32_t OCCTCurve2DBSplineFirstUKnotIndex(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  try
  {
    return bs->FirstUKnotIndex();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DBSplineLastUKnotIndex(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  try
  {
    return bs->LastUKnotIndex();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve2DBSplineKnot(OCCTCurve2DRef curve, int32_t index)
{
  if (!curve)
    return 0.0;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0.0;
  try
  {
    return bs->Knot(index);
  }
  catch (...)
  {
    return 0.0;
  }
}

int32_t OCCTCurve2DBSplineKnotDistribution(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->KnotDistribution();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DBSplineMultiplicity(OCCTCurve2DRef curve, int32_t index)
{
  if (!curve)
    return 0;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  try
  {
    return bs->Multiplicity(index);
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DBSplineGetMultiplicities(OCCTCurve2DRef curve, int32_t* mults)
{
  if (!curve || !mults)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    const auto& m = bs->Multiplicities();
    for (int i = m.Lower(); i <= m.Upper(); i++)
    {
      mults[i - m.Lower()] = m(i);
    }
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineStartPoint(OCCTCurve2DRef curve, double* x, double* y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P = bs->StartPoint();
    *x         = P.X();
    *y         = P.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineEndPoint(OCCTCurve2DRef curve, double* x, double* y)
{
  if (!curve)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt2d P = bs->EndPoint();
    *x         = P.X();
    *y         = P.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBSplineGetPoles(OCCTCurve2DRef curve, double* poles)
{
  if (!curve || !poles)
    return;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  try
  {
    const auto& p   = bs->Poles();
    int         idx = 0;
    for (int i = p.Lower(); i <= p.Upper(); i++)
    {
      poles[idx++] = p(i).X();
      poles[idx++] = p(i).Y();
    }
  }
  catch (...)
  {
  }
}

bool OCCTCurve2DBSplineIsClosed(OCCTCurve2DRef curve)
{
  if (!curve)
    return false;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    return bs->IsClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBSplineIsPeriodic(OCCTCurve2DRef curve)
{
  if (!curve)
    return false;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    return bs->IsPeriodic();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCurve2DBSplineContinuity(OCCTCurve2DRef curve)
{
  if (!curve)
    return 0;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->Continuity();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve2DBSplineIsCN(OCCTCurve2DRef curve, int32_t n)
{
  if (!curve)
    return false;
  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    return bs->IsCN(n);
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.126: Geom2d_BezierCurve completions + v0.128: Curve2D Transform + v0.130: Geom2dEval
// Curves + v0.131: Geom2dEval_TBezier/AHTBezier
// --- Geom2d_BezierCurve completions ---

#import <Geom2d_BezierCurve.hxx>

bool OCCTCurve2DBezierInsertPoleAfter(OCCTCurve2DRef curve, int32_t index, double x, double y)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->InsertPoleAfter(index, gp_Pnt2d(x, y));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBezierRemovePole(OCCTCurve2DRef curve, int32_t index)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->RemovePole(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBezierSegment(OCCTCurve2DRef curve, double u1, double u2)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Segment(u1, u2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DBezierIncreaseDegree(OCCTCurve2DRef curve, int32_t degree)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Increase(degree);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve2DBezierStartPoint(OCCTCurve2DRef curve, double* x, double* y)
{
  if (!curve)
    return;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return;
  try
  {
    gp_Pnt2d p = bz->StartPoint();
    *x         = p.X();
    *y         = p.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBezierEndPoint(OCCTCurve2DRef curve, double* x, double* y)
{
  if (!curve)
    return;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return;
  try
  {
    gp_Pnt2d p = bz->EndPoint();
    *x         = p.X();
    *y         = p.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DBezierGetPoles(OCCTCurve2DRef curve, double* poles)
{
  if (!curve || !poles)
    return;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return;
  try
  {
    int n = bz->NbPoles();
    for (int i = 1; i <= n; i++)
    {
      gp_Pnt2d p             = bz->Pole(i);
      poles[(i - 1) * 2]     = p.X();
      poles[(i - 1) * 2 + 1] = p.Y();
    }
  }
  catch (...)
  {
  }
}

bool OCCTCurve2DBezierReverse(OCCTCurve2DRef curve)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Reverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// === #478: one gp_Trsf2d builder behind both Curve2D transform families ===
//
// Curve2D has the same two-family shape as Curve3D (#416) and Surface (#488): an in-place
// mutating dispatcher (OCCTCurve2DTransform, taking a transformType selector) and an immutable
// OCCTCurve2DTranslate/Rotate/Scale/MirrorAxis/MirrorPoint family that returns a transformed
// copy. Both build the same five transformations; each family built them its own way, so the
// two could drift, and had already drifted on the null guard below. They share this builder now,
// mirroring occtBuildTrsf3D, which the two 3D families share from OCCTBridge_Internal.h (#995).
//
// The scale case is the only one whose construction changes. The dispatcher used to compose it
// by hand as SetScaleFactor(S) + SetTranslationPart(C * (1 - S)); gp_Trsf2d::SetScale(C, S) is
// what the immutable family reached through Geom2d_Geometry::Scale, and what occtBuildTrsf3D uses.
// Verified equivalent before switching, over factors {2.5, 0.25, 1, -1, -3, 0, 1e-9, 1e9} x three
// centres including (1e6, 1e-6): identical ScaleFactor(), identical TranslationPart(), identical
// transformed coordinates, to the bit. The two disagree only on the internal gp_TrsfForm tag at
// S = 1 (gp_Scale vs gp_Identity) and S = -1 (gp_Scale vs gp_PntMirror), which is a dispatch hint,
// not a result: transforming a real BSpline curve through both gives identical poles.
static bool buildTrsf2D(gp_Trsf2d& trsf, int32_t type, double p1, double p2, double p3, double p4)
{
  switch (type)
  {
    case 0: // translation (dx, dy)
      trsf.SetTranslation(gp_Vec2d(p1, p2));
      return true;
    case 1: // rotation (cx, cy, angle)
      trsf.SetRotation(gp_Pnt2d(p1, p2), p3);
      return true;
    case 2: // scale (cx, cy, factor)
      trsf.SetScale(gp_Pnt2d(p1, p2), p3);
      return true;
    case 3: // mirror point (px, py)
      trsf.SetMirror(gp_Pnt2d(p1, p2));
      return true;
    case 4: // mirror axis (ox, oy, dx, dy)
      trsf.SetMirror(gp_Ax2d(gp_Pnt2d(p1, p2), gp_Dir2d(p3, p4)));
      return true;
    default:
      return false;
  }
}

// #999: this declared a p5 that buildTrsf2D never reads and no gp_Trsf2d setter it reaches takes.
// Every Swift call site passed a literal 0 for it.
bool OCCTCurve2DTransform(OCCTCurve2DRef curve,
                          int32_t        transformType,
                          double         p1,
                          double         p2,
                          double         p3,
                          double         p4)
{
  // #478: the handle as well as the wrapper. Geom2d_Curve::Transform is a kernel virtual, so
  // its Standard_NullObject precondition is compiled out of this No_Exception build and a null
  // handle is a raw dereference; the enclosing catch cannot intercept the resulting signal.
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    gp_Trsf2d trsf;
    if (!buildTrsf2D(trsf, transformType, p1, p2, p3, p4))
      return false;
    curve->curve->Transform(trsf);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// --- Geom2dEval Curves ---

#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Geom2dEval_TBezierCurve.hxx>
#include <Geom2dEval_AHTBezierCurve.hxx>

void OCCTGeom2dEvalArchimedeanSpiralD0(double  initialRadius,
                                       double  growthRate,
                                       double  u,
                                       double* px,
                                       double* py)
{
  gp_Ax2d                           ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_ArchimedeanSpiralCurve sp(ax, initialRadius, growthRate);
  gp_Pnt2d                          p = sp.EvalD0(u);
  *px                                 = p.X();
  *py                                 = p.Y();
}

void OCCTGeom2dEvalArchimedeanSpiralD1(double  initialRadius,
                                       double  growthRate,
                                       double  u,
                                       double* px,
                                       double* py,
                                       double* vx,
                                       double* vy)
{
  gp_Ax2d                           ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_ArchimedeanSpiralCurve sp(ax, initialRadius, growthRate);
  auto                              res = sp.EvalD1(u);
  *px                                   = res.Point.X();
  *py                                   = res.Point.Y();
  *vx                                   = res.D1.X();
  *vy                                   = res.D1.Y();
}

void OCCTGeom2dEvalLogSpiralD0(double  scale,
                               double  growthExponent,
                               double  u,
                               double* px,
                               double* py)
{
  gp_Ax2d                           ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_LogarithmicSpiralCurve sp(ax, scale, growthExponent);
  gp_Pnt2d                          p = sp.EvalD0(u);
  *px                                 = p.X();
  *py                                 = p.Y();
}

void OCCTGeom2dEvalLogSpiralD1(double  scale,
                               double  growthExponent,
                               double  u,
                               double* px,
                               double* py,
                               double* vx,
                               double* vy)
{
  gp_Ax2d                           ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_LogarithmicSpiralCurve sp(ax, scale, growthExponent);
  auto                              res = sp.EvalD1(u);
  *px                                   = res.Point.X();
  *py                                   = res.Point.Y();
  *vx                                   = res.D1.X();
  *vy                                   = res.D1.Y();
}

void OCCTGeom2dEvalCircleInvoluteD0(double radius, double u, double* px, double* py)
{
  gp_Ax2d                        ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_CircleInvoluteCurve inv(ax, radius);
  gp_Pnt2d                       p = inv.EvalD0(u);
  *px                              = p.X();
  *py                              = p.Y();
}

void OCCTGeom2dEvalCircleInvoluteD1(double  radius,
                                    double  u,
                                    double* px,
                                    double* py,
                                    double* vx,
                                    double* vy)
{
  gp_Ax2d                        ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_CircleInvoluteCurve inv(ax, radius);
  auto                           res = inv.EvalD1(u);
  *px                                = res.Point.X();
  *py                                = res.Point.Y();
  *vx                                = res.D1.X();
  *vy                                = res.D1.Y();
}

OCCTCurve2DRef OCCTGeom2dEvalCircleInvoluteCurveCreate(double originX,
                                                       double originY,
                                                       double dirX,
                                                       double dirY,
                                                       double radius)
{
  if (radius <= 0.0)
    return nullptr;
  double dirLen = std::sqrt(dirX * dirX + dirY * dirY);
  if (dirLen < 1.0e-12)
    return nullptr;
  try
  {
    gp_Ax2d ax(gp_Pnt2d(originX, originY), gp_Dir2d(dirX / dirLen, dirY / dirLen));
    auto    inv = new Geom2dEval_CircleInvoluteCurve(ax, radius);
    occ::handle<Geom2d_Curve> hCurve(inv);
    auto                      ref = new OCCTCurve2D();
    ref->curve                    = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTGeom2dEvalCircleInvoluteD0WithPlacement(double  originX,
                                                 double  originY,
                                                 double  dirX,
                                                 double  dirY,
                                                 double  radius,
                                                 double  u,
                                                 double* px,
                                                 double* py)
{
  if (!px || !py)
    return;
  if (radius <= 0.0)
  {
    *px = 0.0;
    *py = 0.0;
    return;
  }
  double dirLen = std::sqrt(dirX * dirX + dirY * dirY);
  if (dirLen < 1.0e-12)
  {
    *px = 0.0;
    *py = 0.0;
    return;
  }
  gp_Ax2d ax(gp_Pnt2d(originX, originY), gp_Dir2d(dirX / dirLen, dirY / dirLen));
  Geom2dEval_CircleInvoluteCurve inv(ax, radius);
  gp_Pnt2d                       p = inv.EvalD0(u);
  *px                              = p.X();
  *py                              = p.Y();
}

void OCCTGeom2dEvalCircleInvoluteD1WithPlacement(double  originX,
                                                 double  originY,
                                                 double  dirX,
                                                 double  dirY,
                                                 double  radius,
                                                 double  u,
                                                 double* px,
                                                 double* py,
                                                 double* vx,
                                                 double* vy)
{
  if (!px || !py || !vx || !vy)
    return;
  if (radius <= 0.0)
  {
    *px = 0.0;
    *py = 0.0;
    *vx = 0.0;
    *vy = 0.0;
    return;
  }
  double dirLen = std::sqrt(dirX * dirX + dirY * dirY);
  if (dirLen < 1.0e-12)
  {
    *px = 0.0;
    *py = 0.0;
    *vx = 0.0;
    *vy = 0.0;
    return;
  }
  gp_Ax2d ax(gp_Pnt2d(originX, originY), gp_Dir2d(dirX / dirLen, dirY / dirLen));
  Geom2dEval_CircleInvoluteCurve inv(ax, radius);
  auto                           res = inv.EvalD1(u);
  *px                                = res.Point.X();
  *py                                = res.Point.Y();
  *vx                                = res.D1.X();
  *vy                                = res.D1.Y();
}

void OCCTGeom2dEvalSineWaveD0(double  amplitude,
                              double  omega,
                              double  phase,
                              double  u,
                              double* px,
                              double* py)
{
  gp_Ax2d                  ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_SineWaveCurve sw(ax, amplitude, omega, phase);
  gp_Pnt2d                 p = sw.EvalD0(u);
  *px                        = p.X();
  *py                        = p.Y();
}

void OCCTGeom2dEvalSineWaveD1(double  amplitude,
                              double  omega,
                              double  phase,
                              double  u,
                              double* px,
                              double* py,
                              double* vx,
                              double* vy)
{
  gp_Ax2d                  ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Geom2dEval_SineWaveCurve sw(ax, amplitude, omega, phase);
  auto                     res = sw.EvalD1(u);
  *px                          = res.Point.X();
  *py                          = res.Point.Y();
  *vx                          = res.D1.X();
  *vy                          = res.D1.Y();
}

// --- Geom2dEval_TBezierCurve ---

OCCTCurve2DRef OCCTGeom2dEvalTBezierCurveCreate(const double* poles, int32_t count, double alpha)
{
  if (!poles || count < 3 || count % 2 == 0)
    return nullptr;
  try
  {
    NCollection_Array1<gp_Pnt2d> pts(1, count);
    for (int i = 0; i < count; i++)
      pts(i + 1) = gp_Pnt2d(poles[i * 2], poles[i * 2 + 1]);
    auto                      tc = new Geom2dEval_TBezierCurve(pts, alpha);
    occ::handle<Geom2d_Curve> hCurve(tc);
    auto                      ref = new OCCTCurve2D();
    ref->curve                    = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- Geom2dEval_AHTBezierCurve ---

OCCTCurve2DRef OCCTGeom2dEvalAHTBezierCurveCreate(const double* poles,
                                                  int32_t       count,
                                                  int32_t       algDegree,
                                                  double        alpha,
                                                  double        beta)
{
  if (!poles || count < 1)
    return nullptr;
  try
  {
    NCollection_Array1<gp_Pnt2d> pts(1, count);
    for (int i = 0; i < count; i++)
      pts(i + 1) = gp_Pnt2d(poles[i * 2], poles[i * 2 + 1]);
    auto                      ac = new Geom2dEval_AHTBezierCurve(pts, algDegree, alpha, beta);
    occ::handle<Geom2d_Curve> hCurve(ac);
    auto                      ref = new OCCTCurve2D();
    ref->curve                    = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// end of v0.131.0 implementations
// MARK: - 2D Curve (Geom2d), v0.16.0

#include <Geom2d_Curve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <GC_MakeSegment2d.hxx>
#include <GC_MakeCircle2d.hxx>
#include <GC_MakeArcOfCircle2d.hxx>
#include <GC_MakeEllipse2d.hxx>
#include <GC_MakeArcOfEllipse2d.hxx>
#include <GC_MakeParabola2d.hxx>
#include <GC_MakeHyperbola2d.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <Geom2dAPI_ExtremaCurveCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_BSplineCurveToBezierCurve.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Trsf2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Hypr2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColStd_HArray1OfReal.hxx>

void OCCTCurve2DRelease(OCCTCurve2DRef c)
{
  delete c;
}

// Properties

void OCCTCurve2DGetDomain(OCCTCurve2DRef c, double* first, double* last)
{
  if (!c || c->curve.IsNull() || !first || !last)
    return;
  *first = c->curve->FirstParameter();
  *last  = c->curve->LastParameter();
}

bool OCCTCurve2DIsClosed(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return false;
  return c->curve->IsClosed() == Standard_True;
}

bool OCCTCurve2DIsPeriodic(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return false;
  return c->curve->IsPeriodic() == Standard_True;
}

double OCCTCurve2DGetPeriod(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return 0.0;
  if (!c->curve->IsPeriodic())
    return 0.0;
  return c->curve->Period();
}

// Evaluation

void OCCTCurve2DGetPoint(OCCTCurve2DRef c, double u, double* x, double* y)
{
  if (!c || c->curve.IsNull() || !x || !y)
    return;
  gp_Pnt2d p = c->curve->Value(u);
  *x         = p.X();
  *y         = p.Y();
}

void OCCTCurve2DD1(OCCTCurve2DRef c, double u, double* px, double* py, double* vx, double* vy)
{
  if (!c || c->curve.IsNull() || !px || !py || !vx || !vy)
    return;
  try
  {
    gp_Pnt2d p;
    gp_Vec2d v;
    c->curve->D1(u, p, v);
    *px = p.X();
    *py = p.Y();
    *vx = v.X();
    *vy = v.Y();
  }
  catch (...)
  {
  }
}

void OCCTCurve2DD2(OCCTCurve2DRef c,
                   double         u,
                   double*        px,
                   double*        py,
                   double*        v1x,
                   double*        v1y,
                   double*        v2x,
                   double*        v2y)
{
  if (!c || c->curve.IsNull() || !px || !py || !v1x || !v1y || !v2x || !v2y)
    return;
  try
  {
    gp_Pnt2d p;
    gp_Vec2d v1, v2;
    c->curve->D2(u, p, v1, v2);
    *px  = p.X();
    *py  = p.Y();
    *v1x = v1.X();
    *v1y = v1.Y();
    *v2x = v2.X();
    *v2y = v2.Y();
  }
  catch (...)
  {
  }
}

// Primitives

OCCTCurve2DRef OCCTCurve2DCreateLine(double px, double py, double dx, double dy)
{
  try
  {
    gp_Pnt2d            p(px, py);
    gp_Dir2d            d(dx, dy);
    Handle(Geom2d_Line) line = new Geom2d_Line(p, d);
    return new OCCTCurve2D(line);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateSegment(double p1x, double p1y, double p2x, double p2y)
{
  try
  {
    gp_Pnt2d         p1(p1x, p1y);
    gp_Pnt2d         p2(p2x, p2y);
    GC_MakeSegment2d maker(p1, p2);
    if (maker.Status() != gce_Done)
      return nullptr;
    return new OCCTCurve2D(maker.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateCircle(double cx, double cy, double radius)
{
  try
  {
    if (!occtValidCircleRadius(radius))
      return nullptr;
    gp_Pnt2d              center(cx, cy);
    gp_Ax2d               axis(center, gp_Dir2d(1, 0));
    Handle(Geom2d_Circle) circle = new Geom2d_Circle(axis, radius);
    return new OCCTCurve2D(circle);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateArcOfCircle(double cx,
                                            double cy,
                                            double radius,
                                            double startAngle,
                                            double endAngle)
{
  try
  {
    if (!occtValidCircleRadius(radius))
      return nullptr;
    gp_Pnt2d                    center(cx, cy);
    gp_Ax2d                     axis(center, gp_Dir2d(1, 0));
    Handle(Geom2d_Circle)       circle = new Geom2d_Circle(axis, radius);
    Handle(Geom2d_TrimmedCurve) arc    = new Geom2d_TrimmedCurve(circle, startAngle, endAngle);
    return new OCCTCurve2D(arc);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateArcThrough(double p1x,
                                           double p1y,
                                           double p2x,
                                           double p2y,
                                           double p3x,
                                           double p3y)
{
  try
  {
    gp_Pnt2d             p1(p1x, p1y);
    gp_Pnt2d             p2(p2x, p2y);
    gp_Pnt2d             p3(p3x, p3y);
    GC_MakeArcOfCircle2d maker(p1, p2, p3);
    if (maker.Status() != gce_Done)
      return nullptr;
    return new OCCTCurve2D(maker.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateEllipse(double cx,
                                        double cy,
                                        double majorR,
                                        double minorR,
                                        double rotation)
{
  try
  {
    if (!occtValidEllipseRadii(majorR, minorR))
      return nullptr;
    gp_Pnt2d               center(cx, cy);
    gp_Dir2d               majorDir(cos(rotation), sin(rotation));
    gp_Ax22d               axes(center, majorDir);
    Handle(Geom2d_Ellipse) ellipse = new Geom2d_Ellipse(axes, majorR, minorR);
    return new OCCTCurve2D(ellipse);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateArcOfEllipse(double cx,
                                             double cy,
                                             double majorR,
                                             double minorR,
                                             double rotation,
                                             double startAngle,
                                             double endAngle)
{
  try
  {
    if (!occtValidEllipseRadii(majorR, minorR))
      return nullptr;
    gp_Pnt2d                    center(cx, cy);
    gp_Dir2d                    majorDir(cos(rotation), sin(rotation));
    gp_Ax22d                    axes(center, majorDir);
    Handle(Geom2d_Ellipse)      ellipse = new Geom2d_Ellipse(axes, majorR, minorR);
    Handle(Geom2d_TrimmedCurve) arc     = new Geom2d_TrimmedCurve(ellipse, startAngle, endAngle);
    return new OCCTCurve2D(arc);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateParabola(double fx, double fy, double dx, double dy, double focal)
{
  try
  {
    if (!occtValidParabolaFocal(focal))
      return nullptr;
    gp_Pnt2d                mirrorP(fx - dx * focal, fy - dy * focal);
    gp_Dir2d                dir(dx, dy);
    gp_Ax2d                 axis(mirrorP, dir);
    Handle(Geom2d_Parabola) parab = new Geom2d_Parabola(axis, focal);
    return new OCCTCurve2D(parab);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateHyperbola(double cx,
                                          double cy,
                                          double majorR,
                                          double minorR,
                                          double rotation)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorR, minorR))
      return nullptr;
    gp_Pnt2d                 center(cx, cy);
    gp_Dir2d                 majorDir(cos(rotation), sin(rotation));
    gp_Ax22d                 axes(center, majorDir);
    Handle(Geom2d_Hyperbola) hyp = new Geom2d_Hyperbola(axes, majorR, minorR);
    return new OCCTCurve2D(hyp);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Draw (discretization)

int32_t OCCTCurve2DDrawAdaptive(OCCTCurve2DRef c,
                                double         angularDefl,
                                double         chordalDefl,
                                double*        outXY,
                                int32_t        maxPoints)
{
  if (!c || c->curve.IsNull() || !outXY || maxPoints <= 0)
    return 0;
  try
  {
    Geom2dAdaptor_Curve         adaptor(c->curve);
    GCPnts_TangentialDeflection sampler(adaptor, angularDefl, chordalDefl);
    int32_t                     n = std::min((int32_t)sampler.NbPoints(), maxPoints);
    for (int32_t i = 0; i < n; i++)
    {
      double   u       = sampler.Parameter(i + 1);
      gp_Pnt2d p       = adaptor.Value(u);
      outXY[i * 2]     = p.X();
      outXY[i * 2 + 1] = p.Y();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DDrawUniform(OCCTCurve2DRef c, int32_t pointCount, double* outXY)
{
  // outXY holds pointCount pairs, which is not what the sampler is bounded by. See
  // occtSamplerKept/occtSamplerIndex in OCCTBridge_Internal.h (#501).
  if (!c || c->curve.IsNull() || !outXY || !occtValidSampleCount(pointCount))
    return 0;
  try
  {
    Geom2dAdaptor_Curve    adaptor(c->curve);
    GCPnts_UniformAbscissa sampler(adaptor, pointCount);
    if (!sampler.IsDone())
      return 0;
    int32_t total = sampler.NbPoints();
    int32_t n     = occtSamplerKept(total, pointCount);
    for (int32_t i = 0; i < n; i++)
    {
      double   u       = sampler.Parameter(occtSamplerIndex(i, n, total));
      gp_Pnt2d p       = adaptor.Value(u);
      outXY[i * 2]     = p.X();
      outXY[i * 2 + 1] = p.Y();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DDrawDeflection(OCCTCurve2DRef c,
                                  double         deflection,
                                  double*        outXY,
                                  int32_t        maxPoints)
{
  if (!c || c->curve.IsNull() || !outXY || maxPoints <= 0)
    return 0;
  try
  {
    Geom2dAdaptor_Curve      adaptor(c->curve);
    GCPnts_UniformDeflection sampler(adaptor, deflection);
    if (!sampler.IsDone())
      return 0;
    int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
    for (int32_t i = 0; i < n; i++)
    {
      double   u       = sampler.Parameter(i + 1);
      gp_Pnt2d p       = adaptor.Value(u);
      outXY[i * 2]     = p.X();
      outXY[i * 2 + 1] = p.Y();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// BSpline & Bezier

OCCTCurve2DRef OCCTCurve2DCreateBSpline(const double*  poles,
                                        int32_t        poleCount,
                                        const double*  weights,
                                        const double*  knots,
                                        int32_t        knotCount,
                                        const int32_t* multiplicities,
                                        int32_t        degree)
{
  if (!poles || poleCount < 2 || !knots || knotCount < 2 || degree < 1)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt2d polesArr(1, poleCount);
    for (int i = 0; i < poleCount; i++)
    {
      polesArr.SetValue(i + 1, gp_Pnt2d(poles[i * 2], poles[i * 2 + 1]));
    }

    TColStd_Array1OfReal weightsArr(1, poleCount);
    for (int i = 0; i < poleCount; i++)
    {
      weightsArr.SetValue(i + 1, weights ? weights[i] : 1.0);
    }

    TColStd_Array1OfReal knotsArr(1, knotCount);
    for (int i = 0; i < knotCount; i++)
    {
      knotsArr.SetValue(i + 1, knots[i]);
    }

    TColStd_Array1OfInteger multsArr(1, knotCount);
    for (int i = 0; i < knotCount; i++)
    {
      multsArr.SetValue(i + 1, multiplicities ? multiplicities[i] : 1);
    }

    Handle(Geom2d_BSplineCurve) bsp =
      new Geom2d_BSplineCurve(polesArr, weightsArr, knotsArr, multsArr, degree);
    return new OCCTCurve2D(bsp);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateBezier(const double* poles,
                                       int32_t       poleCount,
                                       const double* weights)
{
  if (!poles || poleCount < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt2d polesArr(1, poleCount);
    for (int i = 0; i < poleCount; i++)
    {
      polesArr.SetValue(i + 1, gp_Pnt2d(poles[i * 2], poles[i * 2 + 1]));
    }

    Handle(Geom2d_BezierCurve) bez;
    if (weights)
    {
      TColStd_Array1OfReal weightsArr(1, poleCount);
      for (int i = 0; i < poleCount; i++)
      {
        weightsArr.SetValue(i + 1, weights[i]);
      }
      bez = new Geom2d_BezierCurve(polesArr, weightsArr);
    }
    else
    {
      bez = new Geom2d_BezierCurve(polesArr);
    }
    return new OCCTCurve2D(bez);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Interpolation & Fitting

OCCTCurve2DRef OCCTCurve2DInterpolate(const double* points,
                                      int32_t       count,
                                      bool          closed,
                                      double        tolerance)
{
  if (!points || count < 2)
    return nullptr;
  try
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, count);
    for (int i = 0; i < count; i++)
    {
      pts->SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
    }
    Geom2dAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);
    interp.Perform();
    if (!interp.IsDone())
      return nullptr;
    return new OCCTCurve2D(interp.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DInterpolateWithTangents(const double* points,
                                                  int32_t       count,
                                                  double        stx,
                                                  double        sty,
                                                  double        etx,
                                                  double        ety,
                                                  double        tolerance)
{
  if (!points || count < 2)
    return nullptr;
  try
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, count);
    for (int i = 0; i < count; i++)
    {
      pts->SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
    }
    Geom2dAPI_Interpolate interp(pts, Standard_False, tolerance);
    gp_Vec2d              startTan(stx, sty);
    gp_Vec2d              endTan(etx, ety);
    interp.Load(startTan, endTan);
    interp.Perform();
    if (!interp.IsDone())
      return nullptr;
    return new OCCTCurve2D(interp.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DFitPoints(const double* points,
                                    int32_t       count,
                                    int32_t       minDeg,
                                    int32_t       maxDeg,
                                    double        tolerance)
{
  if (!points || count < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt2d pts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts.SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
    }
    Geom2dAPI_PointsToBSpline fitter(pts, minDeg, maxDeg, GeomAbs_C2, tolerance);
    if (!fitter.IsDone())
      return nullptr;
    return new OCCTCurve2D(fitter.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}

// BSpline queries

int32_t OCCTCurve2DGetPoleCount(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return 0;
  Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
  if (bsp.IsNull())
  {
    Handle(Geom2d_BezierCurve) bez = Handle(Geom2d_BezierCurve)::DownCast(c->curve);
    if (bez.IsNull())
      return 0;
    return bez->NbPoles();
  }
  return bsp->NbPoles();
}

int32_t OCCTCurve2DGetPoles(OCCTCurve2DRef c, double* outXY)
{
  if (!c || c->curve.IsNull() || !outXY)
    return 0;
  Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
  if (!bsp.IsNull())
  {
    int n = bsp->NbPoles();
    for (int i = 1; i <= n; i++)
    {
      gp_Pnt2d p             = bsp->Pole(i);
      outXY[(i - 1) * 2]     = p.X();
      outXY[(i - 1) * 2 + 1] = p.Y();
    }
    return n;
  }
  Handle(Geom2d_BezierCurve) bez = Handle(Geom2d_BezierCurve)::DownCast(c->curve);
  if (!bez.IsNull())
  {
    int n = bez->NbPoles();
    for (int i = 1; i <= n; i++)
    {
      gp_Pnt2d p             = bez->Pole(i);
      outXY[(i - 1) * 2]     = p.X();
      outXY[(i - 1) * 2 + 1] = p.Y();
    }
    return n;
  }
  return 0;
}

int32_t OCCTCurve2DGetDegree(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return -1;
  Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
  if (!bsp.IsNull())
    return bsp->Degree();
  Handle(Geom2d_BezierCurve) bez = Handle(Geom2d_BezierCurve)::DownCast(c->curve);
  if (!bez.IsNull())
    return bez->Degree();
  return -1;
}

// Operations

OCCTCurve2DRef OCCTCurve2DTrim(OCCTCurve2DRef c, double u1, double u2)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_TrimmedCurve) trimmed = new Geom2d_TrimmedCurve(c->curve, u1, u2);
    return new OCCTCurve2D(trimmed);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DOffset(OCCTCurve2DRef c, double distance)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_OffsetCurve) oc = new Geom2d_OffsetCurve(c->curve, distance);
    return new OCCTCurve2D(oc);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DReversed(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Curve) rev = Handle(Geom2d_Curve)::DownCast(c->curve->Reversed());
    return new OCCTCurve2D(rev);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #478: the five immutable transforms share buildTrsf2D with the in-place
// OCCTCurve2DTransform dispatcher (defined above) rather than each building its own
// transformation, so the two families cannot drift apart on the transform math.

OCCTCurve2DRef OCCTCurve2DTranslate(OCCTCurve2DRef c, double dx, double dy)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
    gp_Trsf2d            trsf;
    if (!buildTrsf2D(trsf, 0, dx, dy, 0, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DRotate(OCCTCurve2DRef c, double cx, double cy, double angle)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
    gp_Trsf2d            trsf;
    if (!buildTrsf2D(trsf, 1, cx, cy, angle, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DScale(OCCTCurve2DRef c, double cx, double cy, double factor)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
    gp_Trsf2d            trsf;
    if (!buildTrsf2D(trsf, 2, cx, cy, factor, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMirrorAxis(OCCTCurve2DRef c, double px, double py, double dx, double dy)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
    gp_Trsf2d            trsf;
    if (!buildTrsf2D(trsf, 4, px, py, dx, dy))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DMirrorPoint(OCCTCurve2DRef c, double px, double py)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
    gp_Trsf2d            trsf;
    if (!buildTrsf2D(trsf, 3, px, py, 0, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTCurve2D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Same subdivided measurement as the 3D sibling (occtAdaptorArcLength, OCCTBridge_Internal.h): the
// GCPnts_AbscissaPoint::length template is shared between Adaptor3d_Curve and Adaptor2d_Curve2d,
// so a 2D ellipse measured exactly the same 0.337% long. #603.
double OCCTCurve2DGetLength(OCCTCurve2DRef c)
{
  if (!c || c->curve.IsNull())
    return -1.0;
  try
  {
    Geom2dAdaptor_Curve adaptor(c->curve);
    return occtAdaptorArcLength(adaptor, adaptor.FirstParameter(), adaptor.LastParameter());
  }
  catch (...)
  {
    return -1.0;
  }
}

// Same non-finite-bound rejection as the 3D sibling: Geom2dAdaptor_Curve reaches the very same
// GCPnts_AbscissaPoint::length template, so a 2D BSpline measured 0 (NaN upper) or its whole
// length (NaN lower) too. See occtValidParameterRange (OCCTBridge_Internal.h). #548.
// Same shared measurement too, so 2D and 3D agree on an out-of-domain range. #600.
double OCCTCurve2DGetLengthBetween(OCCTCurve2DRef c, double u1, double u2)
{
  if (!c || c->curve.IsNull())
    return -1.0;
  if (!occtValidParameterRange(u1, u2))
    return -1.0;
  try
  {
    Geom2dAdaptor_Curve adaptor(c->curve);
    return occtAdaptorLengthBetween(adaptor, u1, u2);
  }
  catch (...)
  {
    return -1.0;
  }
}

// Intersection

int32_t OCCTCurve2DIntersect(OCCTCurve2DRef           c1,
                             OCCTCurve2DRef           c2,
                             double                   tolerance,
                             OCCTCurve2DIntersection* out,
                             int32_t                  max)
{
  if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    Geom2dAPI_InterCurveCurve inter(c1->curve, c2->curve, tolerance);
    int32_t                   n = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt2d p = inter.Point(i + 1);
      out[i].x   = p.X();
      out[i].y   = p.Y();
      // Parameters not directly available from this API for all intersection types
      out[i].u1 = 0;
      out[i].u2 = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DSelfIntersect(OCCTCurve2DRef           c,
                                 double                   tolerance,
                                 OCCTCurve2DIntersection* out,
                                 int32_t                  max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    Geom2dAPI_InterCurveCurve inter(c->curve, tolerance);
    int32_t                   n = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt2d p = inter.Point(i + 1);
      out[i].x   = p.X();
      out[i].y   = p.Y();
      out[i].u1  = 0;
      out[i].u2  = 0;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// Projection

// Failure contract: distance < 0. The point/parameter fields are left zeroed and must not be
// read when it is negative.
OCCTCurve2DProjection OCCTCurve2DProjectPoint(OCCTCurve2DRef c, double px, double py)
{
  OCCTCurve2DProjection result = {0, 0, 0, -1};
  gp_Pnt2d              nearest;
  if (!occtNearestProjectionOnCurve2d(c,
                                      gp_Pnt2d(px, py),
                                      &nearest,
                                      &result.parameter,
                                      &result.distance))
  {
    return result;
  }
  result.x = nearest.X();
  result.y = nearest.Y();
  return result;
}

int32_t OCCTCurve2DProjectPointAll(OCCTCurve2DRef         c,
                                   double                 px,
                                   double                 py,
                                   OCCTCurve2DProjection* out,
                                   int32_t                max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    gp_Pnt2d                      point(px, py);
    Geom2dAPI_ProjectPointOnCurve proj(point, c->curve);
    int32_t                       n = std::min((int32_t)proj.NbPoints(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt2d p       = proj.Point(i + 1);
      out[i].x         = p.X();
      out[i].y         = p.Y();
      out[i].parameter = proj.Parameter(i + 1);
      out[i].distance  = proj.Distance(i + 1);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// Extrema

OCCTCurve2DExtrema OCCTCurve2DMinDistance(OCCTCurve2DRef c1, OCCTCurve2DRef c2)
{
  OCCTCurve2DExtrema result = {0, 0, 0, 0, 0, 0, -1};
  if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull())
    return result;
  try
  {
    double u1min = c1->curve->FirstParameter();
    double u1max = c1->curve->LastParameter();
    double u2min = c2->curve->FirstParameter();
    double u2max = c2->curve->LastParameter();
    // Clamp infinite parameters for extrema computation
    if (u1min < -1e10)
      u1min = -1e10;
    if (u1max > 1e10)
      u1max = 1e10;
    if (u2min < -1e10)
      u2min = -1e10;
    if (u2max > 1e10)
      u2max = 1e10;
    Geom2dAPI_ExtremaCurveCurve ext(c1->curve, c2->curve, u1min, u1max, u2min, u2max);
    if (ext.NbExtrema() == 0)
      return result;
    gp_Pnt2d p1, p2;
    ext.NearestPoints(p1, p2);
    result.p1x = p1.X();
    result.p1y = p1.Y();
    result.p2x = p2.X();
    result.p2y = p2.Y();
    double u1, u2;
    ext.LowerDistanceParameters(u1, u2);
    result.u1       = u1;
    result.u2       = u2;
    result.distance = ext.LowerDistance();
    return result;
  }
  catch (...)
  {
    return result;
  }
}

int32_t OCCTCurve2DAllExtrema(OCCTCurve2DRef      c1,
                              OCCTCurve2DRef      c2,
                              OCCTCurve2DExtrema* out,
                              int32_t             max)
{
  if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    double u1min = c1->curve->FirstParameter();
    double u1max = c1->curve->LastParameter();
    double u2min = c2->curve->FirstParameter();
    double u2max = c2->curve->LastParameter();
    if (u1min < -1e10)
      u1min = -1e10;
    if (u1max > 1e10)
      u1max = 1e10;
    if (u2min < -1e10)
      u2min = -1e10;
    if (u2max > 1e10)
      u2max = 1e10;
    Geom2dAPI_ExtremaCurveCurve ext(c1->curve, c2->curve, u1min, u1max, u2min, u2max);
    int32_t                     n = std::min((int32_t)ext.NbExtrema(), max);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt2d p1, p2;
      ext.Points(i + 1, p1, p2);
      out[i].p1x = p1.X();
      out[i].p1y = p1.Y();
      out[i].p2x = p2.X();
      out[i].p2y = p2.Y();
      double u1, u2;
      ext.Parameters(i + 1, u1, u2);
      out[i].u1       = u1;
      out[i].u2       = u2;
      out[i].distance = ext.Distance(i + 1);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// Conversion

// #999: this took a tolerance Geom2dConvert::CurveToBSplineCurve does not have. Its one parameter
// is the Convert_ParameterisationType, and it is live: measured on a full circle of radius 5, the
// eight types give degree 2/2/2/6/4/7 and 6/8/6/12/7 poles, and Polynomial is the only
// non-rational and the only inexact one (6.5e-06 relative radial error against ~1e-16). Two of
// them, TgtThetaOver2_1 and _2, throw for a full circle: their own documentation caps the opening
// angle at 0.9999*pi and 1.9999*pi. Every type throws for an unbounded curve.
// See Scripts/repro/999-geom2d-curve3d-healing/parameterisation_and_bisector.mm.
OCCTCurve2DRef OCCTCurve2DToBSpline(OCCTCurve2DRef c, OCCTParameterisationType parameterisation)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom2d_BSplineCurve) bsp =
      Geom2dConvert::CurveToBSplineCurve(c->curve, (Convert_ParameterisationType)parameterisation);
    if (bsp.IsNull())
      return nullptr;
    return new OCCTCurve2D(bsp);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTCurve2DBSplineToBeziers(OCCTCurve2DRef c, OCCTCurve2DRef* out, int32_t max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
    if (bsp.IsNull())
      return 0;
    Geom2dConvert_BSplineCurveToBezierCurve converter(bsp);
    int32_t                                 n = std::min((int32_t)converter.NbArcs(), max);
    for (int32_t i = 0; i < n; i++)
    {
      Handle(Geom2d_BezierCurve) arc = converter.Arc(i + 1);
      out[i]                         = new OCCTCurve2D(arc);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve2DFreeArray(OCCTCurve2DRef* curves, int32_t count)
{
  if (!curves)
    return;
  for (int32_t i = 0; i < count; i++)
  {
    delete curves[i];
  }
}

OCCTCurve2DRef OCCTCurve2DJoinToBSpline(const OCCTCurve2DRef* curves,
                                        int32_t               count,
                                        double                tolerance)
{
  if (!curves || count <= 0)
    return nullptr;
  try
  {
    Geom2dConvert_CompCurveToBSplineCurve joiner;
    for (int32_t i = 0; i < count; i++)
    {
      if (!curves[i] || curves[i]->curve.IsNull())
        continue;
      Handle(Geom2d_BSplineCurve) bsp = Geom2dConvert::CurveToBSplineCurve(curves[i]->curve);
      if (bsp.IsNull())
        continue;
      joiner.Add(bsp, tolerance);
    }
    Handle(Geom2d_BSplineCurve) result = joiner.BSplineCurve();
    if (result.IsNull())
      return nullptr;
    return new OCCTCurve2D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Local Properties (Geom2dLProp)

#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <LProp_CurAndInf.hxx>
#include <LProp_CIType.hxx>
#include <Bnd_Box2d.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <GC_MakeArcOfHyperbola2d.hxx>
#include <GC_MakeArcOfParabola2d.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2dGcc_Circ2d3Tan.hxx>
#include <Geom2dGcc_Circ2d2TanRad.hxx>
#include <Geom2dGcc_Circ2dTanCen.hxx>
#include <Geom2dGcc_Lin2d2Tan.hxx>
#include <Geom2dGcc_QualifiedCurve.hxx>
#include <GccEnt_Position.hxx>

// #595: reports whether there is a curvature rather than spelling its absence 0, which is also a
// straight 2D curve's real answer. Matches OCCTCurve3DGetCurvature, here as in #494.
bool OCCTCurve2DGetCurvature(OCCTCurve2DRef c, double u, double* curvature)
{
  *curvature = 0.0;
  if (!c || c->curve.IsNull())
    return false;
  try
  {
    GeomLProp_CLProps2d props = occtCurve2dLocalProps(c->curve, u, 2);
    // Curvature() is only meaningful once the tangent is established. It does raise otherwise,
    // but through LProp_NotDefined_Raise_if, which compiles out under No_Exception, defined
    // for the OCCT build, not for this one. Matches OCCTCurve3DGetCurvature (#494).
    if (!props.IsTangentDefined())
      return false;
    *curvature = props.Curvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DGetNormal(OCCTCurve2DRef c, double u, double* nx, double* ny)
{
  if (!c || c->curve.IsNull() || !nx || !ny)
    return false;
  try
  {
    GeomLProp_CLProps2d props = occtCurve2dLocalProps(c->curve, u, 2);
    if (!props.IsTangentDefined())
      return false;
    // Rejects a cusp's RealLast() curvature as well as a straight stretch's zero (#494).
    if (!occtCurveCurvatureIsInvertible(props.Curvature()))
      return false;
    gp_Dir2d n;
    props.Normal(n);
    *nx = n.X();
    *ny = n.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DGetTangentDir(OCCTCurve2DRef c, double u, double* tx, double* ty)
{
  if (!c || c->curve.IsNull() || !tx || !ty)
    return false;
  try
  {
    GeomLProp_CLProps2d props = occtCurve2dLocalProps(c->curve, u, 1);
    if (!props.IsTangentDefined())
      return false;
    gp_Dir2d t;
    props.Tangent(t);
    *tx = t.X();
    *ty = t.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve2DGetCenterOfCurvature(OCCTCurve2DRef c, double u, double* cx, double* cy)
{
  if (!c || c->curve.IsNull() || !cx || !cy)
    return false;
  try
  {
    GeomLProp_CLProps2d props = occtCurve2dLocalProps(c->curve, u, 2);
    if (!props.IsTangentDefined())
      return false;
    // Rejects a cusp's RealLast() curvature, which used to reach CentreOfCurvature (#494).
    if (!occtCurveCurvatureIsInvertible(props.Curvature()))
      return false;
    gp_Pnt2d center;
    props.CentreOfCurvature(center);
    *cx = center.X();
    *cy = center.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCurve2DGetInflectionPoints(OCCTCurve2DRef c, double* outParams, int32_t max)
{
  if (!c || c->curve.IsNull() || !outParams || max <= 0)
    return 0;
  try
  {
    GeomLProp_CurAndInf2d analyzer;
    analyzer.PerformInf(c->curve);
    if (!analyzer.IsDone())
      return 0;
    int32_t n = 0;
    for (int i = 1; i <= analyzer.NbPoints() && n < max; i++)
    {
      if (analyzer.Type(i) == LProp_Inflection)
      {
        outParams[n++] = analyzer.Parameter(i);
      }
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DGetCurvatureExtrema(OCCTCurve2DRef c, OCCTCurve2DCurvePoint* out, int32_t max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    GeomLProp_CurAndInf2d analyzer;
    analyzer.PerformCurExt(c->curve);
    if (!analyzer.IsDone())
      return 0;
    int32_t n = 0;
    for (int i = 1; i <= analyzer.NbPoints() && n < max; i++)
    {
      out[n].parameter = analyzer.Parameter(i);
      LProp_CIType t   = analyzer.Type(i);
      out[n].type      = (t == LProp_MinCur) ? 1 : (t == LProp_MaxCur) ? 2 : 0;
      n++;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DGetAllSpecialPoints(OCCTCurve2DRef c, OCCTCurve2DCurvePoint* out, int32_t max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    GeomLProp_CurAndInf2d analyzer;
    analyzer.Perform(c->curve);
    if (!analyzer.IsDone())
      return 0;
    int32_t n = std::min((int32_t)analyzer.NbPoints(), max);
    for (int i = 0; i < n; i++)
    {
      out[i].parameter = analyzer.Parameter(i + 1);
      LProp_CIType t   = analyzer.Type(i + 1);
      out[i].type      = (t == LProp_Inflection) ? 0 : (t == LProp_MinCur) ? 1 : 2;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// Bounding Box

bool OCCTCurve2DGetBoundingBox(OCCTCurve2DRef c,
                               double*        xMin,
                               double*        yMin,
                               double*        xMax,
                               double*        yMax)
{
  if (!c || c->curve.IsNull() || !xMin || !yMin || !xMax || !yMax)
    return false;
  try
  {
    Bnd_Box2d box;
    BndLib_Add2dCurve::Add(c->curve, 0.0, box);
    if (box.IsVoid())
      return false;
    box.Get(*xMin, *yMin, *xMax, *yMax);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// Additional Arc Types

OCCTCurve2DRef OCCTCurve2DCreateArcOfHyperbola(double cx,
                                               double cy,
                                               double majorR,
                                               double minorR,
                                               double rotation,
                                               double startAngle,
                                               double endAngle)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorR, minorR))
      return nullptr;
    gp_Pnt2d                    center(cx, cy);
    gp_Dir2d                    majorDir(cos(rotation), sin(rotation));
    gp_Ax22d                    axes(center, majorDir);
    Handle(Geom2d_Hyperbola)    hyp = new Geom2d_Hyperbola(axes, majorR, minorR);
    Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(hyp, startAngle, endAngle);
    return new OCCTCurve2D(arc);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTCurve2DCreateArcOfParabola(double fx,
                                              double fy,
                                              double dx,
                                              double dy,
                                              double focal,
                                              double startParam,
                                              double endParam)
{
  try
  {
    if (!occtValidParabolaFocal(focal))
      return nullptr;
    gp_Pnt2d                    mirrorP(fx - dx * focal, fy - dy * focal);
    gp_Dir2d                    dir(dx, dy);
    gp_Ax2d                     axis(mirrorP, dir);
    Handle(Geom2d_Parabola)     parab = new Geom2d_Parabola(axis, focal);
    Handle(Geom2d_TrimmedCurve) arc   = new Geom2d_TrimmedCurve(parab, startParam, endParam);
    return new OCCTCurve2D(arc);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Conversion Extras

OCCTCurve2DRef OCCTCurve2DApproximate(OCCTCurve2DRef c,
                                      double         tolerance,
                                      int32_t        continuity,
                                      int32_t        maxSegments,
                                      int32_t        maxDegree)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Geom2dConvert_ApproxCurve approx(c->curve,
                                     tolerance,
                                     occtGeomAbsFromParametricContinuity(continuity),
                                     maxSegments,
                                     maxDegree);
    if (!approx.HasResult())
      return nullptr;
    Handle(Geom2d_BSplineCurve) result = approx.Curve();
    if (result.IsNull())
      return nullptr;
    return new OCCTCurve2D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #562: reports the TRUE split count even when `max` truncated the write, so the Swift caller can
// retry at the size it was just told, the #481 contract shared by every other member of this
// family. It used to return the written count, which capped it silently at its caller's 256-entry
// first pass and was indistinguishable from a curve with exactly 256 splits.
int32_t OCCTCurve2DSplitAtDiscontinuities(OCCTCurve2DRef c,
                                          int32_t        continuity,
                                          int32_t*       outKnotIndices,
                                          int32_t        max)
{
  if (!c || c->curve.IsNull() || !outKnotIndices || max <= 0)
    return 0;
  try
  {
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
    if (bsp.IsNull())
      return 0;
    Geom2dConvert_BSplineCurveKnotSplitting splitter(bsp, continuity);
    return occtWriteKnotSplits<int32_t>(
      splitter.NbSplits(),
      [&](int32_t i) { return (int32_t)splitter.SplitValue(i); },
      outKnotIndices,
      max);
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve2DToArcsAndSegments(OCCTCurve2DRef  c,
                                     double          tolerance,
                                     double          angleTol,
                                     OCCTCurve2DRef* out,
                                     int32_t         max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    // Approximate with arcs/segments using adaptor
    Geom2dAdaptor_Curve              adaptor(c->curve);
    Geom2dConvert_ApproxArcsSegments converter(adaptor, tolerance, angleTol);
    const auto&                      result = converter.GetResult();
    int32_t                          n      = std::min((int32_t)result.Size(), max);
    for (int32_t i = 0; i < n; i++)
    {
      out[i] = new OCCTCurve2D(result.Value(i + 1));
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Issue #37: Parameter at Arc Length

// Shared with the 3D spelling so both stay consistent with the length they invert. #603.
double OCCTCurve2DParameterAtLength(OCCTCurve2DRef c, double arcLength, double fromParam)
{
  if (!c || c->curve.IsNull())
    return -DBL_MAX;
  try
  {
    Geom2dAdaptor_Curve adaptor(c->curve);
    double              parameter = 0;
    if (!occtAdaptorParameterAtLength(adaptor, arcLength, fromParam, parameter))
      return -DBL_MAX;
    return parameter;
  }
  catch (...)
  {
    return -DBL_MAX;
  }
}

// MARK: - Issue #38: Interpolate with Interior Tangent Constraints

OCCTCurve2DRef OCCTCurve2DInterpolateWithInteriorTangents(const double* points,
                                                          int32_t       count,
                                                          const double* tangents,
                                                          const bool*   tangentFlags,
                                                          bool          closed,
                                                          double        tolerance)
{
  if (!points || !tangents || !tangentFlags || count < 2)
    return nullptr;
  try
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, count);
    for (int i = 0; i < count; i++)
    {
      pts->SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
    }
    Geom2dAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);

    // Build tangent array and flags array
    NCollection_Array1<gp_Vec2d>      tanVecs(1, count);
    Handle(NCollection_HArray1<bool>) tanFlags = new NCollection_HArray1<bool>(1, count);
    bool                              anyFlag  = false;
    for (int i = 0; i < count; i++)
    {
      tanVecs.SetValue(i + 1, gp_Vec2d(tangents[i * 2], tangents[i * 2 + 1]));
      tanFlags->SetValue(i + 1, tangentFlags[i]);
      if (tangentFlags[i])
        anyFlag = true;
    }
    if (anyFlag)
    {
      interp.Load(tanVecs, tanFlags);
    }
    interp.Perform();
    if (!interp.IsDone())
      return nullptr;
    return new OCCTCurve2D(interp.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}
