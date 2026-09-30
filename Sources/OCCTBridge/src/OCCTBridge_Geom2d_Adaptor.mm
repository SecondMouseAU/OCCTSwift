//
//  OCCTBridge_Geom2d_Adaptor.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Geom2d.mm (#1380): BRepAdaptor_Curve2d, Geom2dAdaptor,
//  Geom2dLProp/LProp_AnalyticCurInf. Public C surface unchanged; every sibling file imports the
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
        // Deliberately NOT calling occtRecordCaughtException here (#1161). This one recovers: a
        // boundary curve this point cannot be projected onto is skipped and the minimum over the
        // others still stands, so recording it would report a failure for a call that did not
        // fail.
        continue;
      }
    }
    return (minDist < std::numeric_limits<double>::max()) ? minDist : 0.0;
  }
};

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

struct OCCTHatcher
{
  Hatch_Hatcher hatcher;

  OCCTHatcher(double tol)
      : hatcher(tol, false)
  {
  }
};

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
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return false;
  }
}

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
      // Ellipse curvature extrema at multiples of PI/2. LProp_MinCur/MaxCur classify by
      // radius of curvature, not curvature itself (LProp_CurAndInf.hxx:53-57):
      // At 0, PI: max curvature, min radius, major-axis vertices -> LProp_MinCur.
      // At PI/2, 3PI/2: min curvature, max radius, minor-axis vertices -> LProp_MaxCur.
      double PI2 = M_PI / 2.0;
      for (int k = 0; k < 4; k++)
      {
        double param = k * PI2;
        if (param >= first && param <= last)
        {
          bool isMin = (k == 0 || k == 2);
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
    occtRecordCaughtException(__func__);
    return 0;
  }
}

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
    occtRecordCaughtException(__func__);
  }
  return result;
}

int32_t OCCTCurve2DCurveType(OCCTCurve2DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 8; // OtherCurve
  try
  {
    Geom2dAdaptor_Curve ac(curve->curve);
    return (int32_t)ac.GetType();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 8; // OtherCurve
  }
}

int32_t OCCTCurve2DDrawAdaptive(OCCTCurve2DRef c,
                                double         angularDefl,
                                double         chordalDefl,
                                double*        outXY,
                                int32_t        maxPoints)
{
  if (!c || c->curve.IsNull() || !outXY || maxPoints <= 0)
    return 0;
  // #2861: see occtValidTangentialDeflection (OCCTBridge_Internal.h). The 2D twin of
  // OCCTCurve3DDrawAdaptive, with the same compiled-out precondition.
  if (!occtValidTangentialDeflection(angularDefl, chordalDefl))
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return 0;
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return -1.0;
  }
}

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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return 0;
  }
}

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
    occtRecordCaughtException(__func__);
    return -DBL_MAX;
  }
}
