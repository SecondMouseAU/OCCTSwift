//
//  OCCTBridge_Geom2d_Extrema.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Geom2d.mm (#1380): Extrema_LocateExtCC2d, IntAna2d_Conic,
//  Intf_InterferencePolygon2d. Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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
