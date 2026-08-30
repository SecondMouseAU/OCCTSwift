//
//  OCCTBridge_Geom2d_Conversion.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Geom2d.mm (#1380): GC_Make*, gce_Make*, Geom2dConvert, Geom2dAPI,
//  ShapeUpgrade/ShapeCustom curve2d. Public C surface unchanged; every sibling file imports the
//  same headers this one does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

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
#include <Geom2dInt_GInter.hxx>
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

// Additional includes gathered from throughout the original file (#1380):
#include <Geom2dGridEval_Curve.hxx>
#include <Geom2dGridEval.hxx>
#include <Hatch_Hatcher.hxx>
#include <Geom2dHatch_Hatcher.hxx>
#include <Geom2dHatch_Intersector.hxx>
#include <HatchGen_Domain.hxx>
#include <Bisector_BisecCC.hxx>
#include <Bisector_BisecPC.hxx>
#include <MAT_SequenceOfArc.hxx>
#include <MAT_SequenceOfBasicElt.hxx>
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
#include <Bisector_BisecAna.hxx>
#include <GeomAbs_JoinType.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Hypr2d.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccEnt_QualifiedCirc.hxx>
#include <GccEnt.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <Convert_EllipseToBSplineCurve.hxx>
#include <Convert_HyperbolaToBSplineCurve.hxx>
#include <Convert_ParabolaToBSplineCurve.hxx>
#include <Convert_CylinderToBSplineSurface.hxx>
#include <Convert_ConeToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>
#include <Convert_CircleToBSplineCurve.hxx>
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
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <BRepLib_MakeEdge2d.hxx>
#include <IntAna2d_Conic.hxx>
#import <Geom2d_BezierCurve.hxx>
#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Geom2dEval_TBezierCurve.hxx>
#include <Geom2dEval_AHTBezierCurve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <GC_MakeSegment2d.hxx>
#include <GC_MakeArcOfCircle2d.hxx>
#include <GC_MakeArcOfEllipse2d.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <Geom2dAPI_ExtremaCurveCurve.hxx>
#include <Geom2dConvert_BSplineCurveToBezierCurve.hxx>
#include <gp_Trsf2d.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <GC_MakeArcOfHyperbola2d.hxx>
#include <GC_MakeArcOfParabola2d.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

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

struct OCCTPoint2D
{
  Handle(Geom2d_CartesianPoint) point;

  OCCTPoint2D(const Handle(Geom2d_CartesianPoint)& p)
      : point(p)
  {
  }
};

struct OCCTTransform2D
{
  Handle(Geom2d_Transformation) transform;

  OCCTTransform2D(const Handle(Geom2d_Transformation)& t)
      : transform(t)
  {
  }
};

struct OCCTAxisPlacement2D
{
  Handle(Geom2d_AxisPlacement) axis;

  OCCTAxisPlacement2D(const Handle(Geom2d_AxisPlacement)& a)
      : axis(a)
  {
  }
};

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

struct OCCTHatcher
{
  Hatch_Hatcher hatcher;

  OCCTHatcher(double tol)
      : hatcher(tol, false)
  {
  }
};

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
    const Geom2dInt_GInter&   alg = inter.Intersector();
    if (!alg.IsDone() || alg.IsEmpty())
      return 0;
    int32_t n = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < n; i++)
    {
      const IntRes2d_IntersectionPoint& pt = alg.Point(i + 1);
      out[i].x                             = pt.Value().X();
      out[i].y                             = pt.Value().Y();
      out[i].u1                            = pt.ParamOnFirst();
      out[i].u2                            = pt.ParamOnSecond();
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
    const Geom2dInt_GInter&   alg = inter.Intersector();
    if (!alg.IsDone() || alg.IsEmpty())
      return 0;
    int32_t n = std::min((int32_t)inter.NbPoints(), max);
    for (int32_t i = 0; i < n; i++)
    {
      const IntRes2d_IntersectionPoint& pt = alg.Point(i + 1);
      out[i].x                             = pt.Value().X();
      out[i].y                             = pt.Value().Y();
      out[i].u1                            = pt.ParamOnFirst();
      out[i].u2                            = pt.ParamOnSecond();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
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
