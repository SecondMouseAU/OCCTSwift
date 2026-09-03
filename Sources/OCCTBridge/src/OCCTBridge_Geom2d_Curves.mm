//
//  OCCTBridge_Geom2d_Curves.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Geom2d.mm (#1380): Geom2d_*
//  (Circle/Ellipse/Hyperbola/Parabola/Line/OffsetCurve/BSpline/Bezier),
//  Point2D/Transform2D/AxisPlacement2D/Vector2D -- default_bucket. Public C surface unchanged;
//  every sibling file imports the same headers this one does (the shared preamble below). No symbol
//  changes, pure file move -- see Scripts/repro/396-bridge-mm-split/ for how.
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
    // Do not gate on IsDone(): myDone is only ever set true by the constructor's trivial
    // early-exit branch (periodic curve, or fewer than 4 poles) or by FixTangentOnCurve(). Along
    // the real analysis branch (an ordinary non-periodic curve with 4+ poles), myDone is never
    // touched, even though myFixFirstTangent/myFixLastTangent are correctly computed there.
    // OCCT's own internal caller (TopOpeBRepTool_CurveTool.cxx) never checks IsDone() either,
    // it goes straight to NeedTangentFix, matching OCCTGeomLibFixBSpline2D below. #1457.
    GeomLib_Check2dBSplineCurve checker(bsp, tolerance, angularTol);
    bool                        f = false, l = false;
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
    return written;
  }
  catch (...)
  {
    return 0;
  }
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

void OCCTCurve2DRelease(OCCTCurve2DRef c)
{
  delete c;
}

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
      if (!joiner.Add(bsp, tolerance))
        return nullptr;
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
