//
//  OCCTBridge_Geom2d_Bisector.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Geom2d.mm (#1380): Bisector_BisecAna/PointOnBis/Inter, BRepMAT2d (medial
//  axis transform). Public C surface unchanged; every sibling file imports the same headers this
//  one does (the shared preamble below). No symbol changes, pure file move -- see
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
    int written = 0;

    // First, add intersection points
    int pointCount = inter.NbPoints();
    for (int i = 1; i <= pointCount && written < maxPoints; ++i)
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

    // If no points but there are segments (coincident bisectors), add segment endpoints
    if (written == 0)
    {
      int segmentCount = inter.NbSegments();
      for (int i = 1; i <= segmentCount && written < maxPoints; ++i)
      {
        const IntRes2d_IntersectionSegment& seg = inter.Segment(i);

        // Add first point of segment if it exists
        if (seg.HasFirstPoint() && written < maxPoints)
        {
          const IntRes2d_IntersectionPoint& fp = seg.FirstPoint();
          if (outPoints)
          {
            outPoints[written].x             = fp.Value().X();
            outPoints[written].y             = fp.Value().Y();
            outPoints[written].paramOnFirst  = fp.ParamOnFirst();
            outPoints[written].paramOnSecond = fp.ParamOnSecond();
          }
          written++;
        }

        // Add last point of segment if it exists and is different from first
        if (seg.HasLastPoint() && written < maxPoints)
        {
          const IntRes2d_IntersectionPoint& lp = seg.LastPoint();
          // Check if last point is different from first point
          bool isDifferent = true;
          if (seg.HasFirstPoint())
          {
            const IntRes2d_IntersectionPoint& fp = seg.FirstPoint();
            isDifferent = (fabs(lp.Value().X() - fp.Value().X()) > 1e-12)
                          || (fabs(lp.Value().Y() - fp.Value().Y()) > 1e-12)
                          || (fabs(lp.ParamOnFirst() - fp.ParamOnFirst()) > 1e-12)
                          || (fabs(lp.ParamOnSecond() - fp.ParamOnSecond()) > 1e-12);
          }
          if (isDifferent)
          {
            if (outPoints)
            {
              outPoints[written].x             = lp.Value().X();
              outPoints[written].y             = lp.Value().Y();
              outPoints[written].paramOnFirst  = lp.ParamOnFirst();
              outPoints[written].paramOnSecond = lp.ParamOnSecond();
            }
            written++;
          }
        }
      }
    }

    return written;
  }
  catch (...)
  {
    return 0;
  }
}
