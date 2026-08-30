//
//  OCCTBridge_Spatial_Intersection.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Spatial.mm (#1380): IntAna/IntAna_IntQuadQuad, Intrv_Interval(s),
//  Intf_Tool. Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_Spatial.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for spatial / numerical helpers:
//
//  - NCollection_KDTree spatial queries (nearest / k-NN / range / box)
//  - math_DirectPolynomialRoots (quadratic / cubic / quartic solvers)
//  - Bnd_OBB oriented bounding box helpers (when Topology delegates)
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <Intrv_Interval.hxx>
#include <Intrv_Intervals.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_KDTree.hxx>
#include <math_DirectPolynomialRoots.hxx>

#include <gp_Pnt.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Circ.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <Precision.hxx>
#include <Bnd_Sphere.hxx>
#include <BndLib.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <BndLib_AddSurface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <IntAna_QuadQuadGeo.hxx>
#include <Intf_Tool.hxx>
#include <gp_Ax3.hxx>
#include <gp_Quaternion.hxx>
#include <gp_QuaternionSLerp.hxx>
#include <gp_QuaternionNLerp.hxx>
#include <gp_TrsfNLerp.hxx>
#include <NCollection_Lerp.hxx>
#include <gp_XY.hxx>
#include <gp_XYZ.hxx>
#include <math_BracketedRoot.hxx>
#include <math_BracketMinimum.hxx>
#include <math_FRPR.hxx>
#include <math_FunctionAllRoots.hxx>
#include <math_GaussLeastSquare.hxx>
#include <math_NewtonFunctionRoot.hxx>
#include <math_Uzawa.hxx>
#include <math_EigenValuesSearcher.hxx>
#include <math_KronrodSingleIntegration.hxx>
#include <math_GaussMultipleIntegration.hxx>
#include <math_GaussSetIntegration.hxx>
#include <math_FunctionSample.hxx>
#include <math_IntegerVector.hxx>
#include <Convert_CompPolynomialToPoles.hxx>
#include <TopoDS.hxx>
#include <TopAbs.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <GProp_PEquation.hxx>

#include <algorithm>
#include <cmath>
#include <vector>

// MARK: - KD-Tree Spatial Queries (v0.28.0)

// Additional includes gathered from throughout the original file (#1380):
#include <Bnd_Range.hxx>
#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <math_Gauss.hxx>
#include <math_SVD.hxx>
#include <math_Jacobi.hxx>
#include <math_Householder.hxx>
#include <math_Crout.hxx>
#include <IntAna_IntConicQuad.hxx>
#include <IntAna_Int3Pln.hxx>
#include <IntAna_IntLinTorus.hxx>
#include <IntAna_Quadric.hxx>
#include <IntAna_IntQuadQuad.hxx>
#include <Bnd_Box.hxx>
#include <IntAna_Curve.hxx>
#include <math_TrigonometricFunctionRoots.hxx>
#include <math_FunctionWithDerivative.hxx>
#include <math_FunctionSetWithDerivatives.hxx>
#include <math_MultipleVarFunction.hxx>
#include <math_MultipleVarFunctionWithGradient.hxx>
#include <math_FunctionRoot.hxx>
#include <math_BissecNewton.hxx>
#include <math_FunctionSetRoot.hxx>
#include <math_BFGS.hxx>
#include <math_Powell.hxx>
#include <math_BrentMinimum.hxx>
#include <math_PSO.hxx>
#include <math_GlobOptMin.hxx>
#include <math_FunctionRoots.hxx>
#include <math_GaussSingleIntegration.hxx>
#include <math_NewtonFunctionSetRoot.hxx>
#include <GeomGridEval_Curve.hxx>
#include <Geom2dGridEval_Curve.hxx>
#include <GeomGridEval_Surface.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepLProp_SLProps.hxx>
#include <MathPoly_Laguerre.hxx>
#include <math_NewtonMinimum.hxx>
#include <math_MultipleVarFunctionWithHessian.hxx>
#include <MathPoly_Quadratic.hxx>
#include <MathPoly_Cubic.hxx>
#include <MathPoly_Quartic.hxx>
#include <MathInteg_Gauss.hxx>
#include <MathInteg_Kronrod.hxx>
#include <MathInteg_DoubleExp.hxx>
#include <UnitsMethods.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopExp.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

struct OCCTKDTree
{
  NCollection_KDTree<gp_Pnt, 3> tree;
  std::vector<gp_Pnt>           points;
};

// #794: shared helper for polynomial solvers (Quadratic/Cubic/Quartic)
// Uses template parameter pack to handle different constructor arities
template <typename... Args>
static OCCTPolynomialRoots occtSolvePolynomial(Args... args)
{
  OCCTPolynomialRoots result;
  result.count    = 0;
  result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
  try
  {
    math_DirectPolynomialRoots solver(args...);
    if (!solver.IsDone())
      return result;
    result.count = std::min(solver.NbSolutions(), 4);
    for (int i = 0; i < result.count; i++)
    {
      result.roots[i] = solver.Value(i + 1);
    }
    std::sort(result.roots, result.roots + result.count);
  }
  catch (...)
  {
  }
  return result;
}

struct OCCTIntrvInterval
{
  Intrv_Interval interval;
};

struct OCCTIntrvIntervals
{
  Intrv_Intervals intervals;
};

struct OCCTRange
{
  Bnd_Range range;
};

struct OCCTMathMatrix
{
  math_Matrix mat;

  OCCTMathMatrix(int r, int c, double v)
      : mat(1, r, 1, c, v)
  {
  }
};

struct OCCTBndSphere
{
  Bnd_Sphere sphere;
};

static void fillBounds6(const Bnd_Box& box, double* bounds6)
{
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  bounds6[0] = x0;
  bounds6[1] = y0;
  bounds6[2] = z0;
  bounds6[3] = x1;
  bounds6[4] = y1;
  bounds6[5] = z1;
}

// C++ adapter: wraps a C callback into math_FunctionWithDerivative
class OCCTMathFuncAdapter : public math_FunctionWithDerivative
{
  OCCTMathFuncDerivCallback callback;
  void*                     ctx;

public:
  OCCTMathFuncAdapter(OCCTMathFuncDerivCallback cb, void* c)
      : callback(cb),
        ctx(c)
  {
  }

  bool Value(const double X, double& F) override
  {
    double d;
    return callback(X, &F, &d, ctx);
  }

  bool Derivative(const double X, double& D) override
  {
    double f;
    return callback(X, &f, &D, ctx);
  }

  bool Values(const double X, double& F, double& D) override { return callback(X, &F, &D, ctx); }
};

// C++ adapter: wraps C callbacks into math_FunctionSetWithDerivatives
class OCCTMathFuncSetAdapter : public math_FunctionSetWithDerivatives
{
  OCCTMathFuncSetCallback      valueCallback;
  OCCTMathFuncSetDerivCallback derivCallback;
  void*                        ctx;
  int                          nVars, nEqs;

public:
  OCCTMathFuncSetAdapter(int                          nv,
                         int                          ne,
                         OCCTMathFuncSetCallback      vcb,
                         OCCTMathFuncSetDerivCallback dcb,
                         void*                        c)
      : nVars(nv),
        nEqs(ne),
        valueCallback(vcb),
        derivCallback(dcb),
        ctx(c)
  {
  }

  int NbVariables() const override { return nVars; }

  int NbEquations() const override { return nEqs; }

  bool Value(const math_Vector& X, math_Vector& F) override
  {
    std::vector<double> x(nVars), f(nEqs);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = valueCallback(x.data(), nVars, f.data(), nEqs, ctx);
    for (int i = 0; i < nEqs; i++)
      F(i + 1) = f[i];
    return ok;
  }

  bool Derivatives(const math_Vector& X, math_Matrix& D) override
  {
    std::vector<double> x(nVars), jac(nVars * nEqs);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = derivCallback(x.data(), nVars, jac.data(), nEqs, ctx);
    for (int i = 0; i < nEqs; i++)
      for (int j = 0; j < nVars; j++)
        D(i + 1, j + 1) = jac[i * nVars + j];
    return ok;
  }

  bool Values(const math_Vector& X, math_Vector& F, math_Matrix& D) override
  {
    return Value(X, F) && Derivatives(X, D);
  }
};

// C++ adapter: wraps a C callback into math_MultipleVarFunction
class OCCTMathMultiVarAdapter : public math_MultipleVarFunction
{
  OCCTMathMultiVarCallback callback;
  void*                    ctx;
  int                      nVars;

public:
  OCCTMathMultiVarAdapter(int nv, OCCTMathMultiVarCallback cb, void* c)
      : nVars(nv),
        callback(cb),
        ctx(c)
  {
  }

  int NbVariables() const override { return nVars; }

  bool Value(const math_Vector& X, double& F) override
  {
    std::vector<double> x(nVars);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    return callback(x.data(), nVars, &F, ctx);
  }
};

// C++ adapter: wraps a C callback into math_MultipleVarFunctionWithGradient
class OCCTMathMultiVarGradAdapter : public math_MultipleVarFunctionWithGradient
{
  OCCTMathMultiVarGradCallback callback;
  void*                        ctx;
  int                          nVars;

public:
  OCCTMathMultiVarGradAdapter(int nv, OCCTMathMultiVarGradCallback cb, void* c)
      : nVars(nv),
        callback(cb),
        ctx(c)
  {
  }

  int NbVariables() const override { return nVars; }

  bool Value(const math_Vector& X, double& F) override
  {
    std::vector<double> x(nVars), g(nVars);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    return callback(x.data(), nVars, &F, g.data(), ctx);
  }

  bool Gradient(const math_Vector& X, math_Vector& G) override
  {
    std::vector<double> x(nVars), g(nVars);
    double              f;
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = callback(x.data(), nVars, &f, g.data(), ctx);
    for (int i = 0; i < nVars; i++)
      G(i + 1) = g[i];
    return ok;
  }

  bool Values(const math_Vector& X, double& F, math_Vector& G) override
  {
    std::vector<double> x(nVars), g(nVars);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = callback(x.data(), nVars, &F, g.data(), ctx);
    for (int i = 0; i < nVars; i++)
      G(i + 1) = g[i];
    return ok;
  }
};

// Simple math_Function adapter for GaussSingleIntegration
class OCCTMathSimpleFuncAdapter : public math_Function
{
  OCCTMathSimpleFuncCallback cb;
  void*                      ctx;

public:
  OCCTMathSimpleFuncAdapter(OCCTMathSimpleFuncCallback c, void* x)
      : cb(c),
        ctx(x)
  {
  }

  bool Value(const double X, double& F) override { return cb(X, &F, ctx); }
};

class OCCTMathHessianAdapter : public math_MultipleVarFunctionWithHessian
{
  OCCTMathHessianCallback callback;
  void*                   context;
  int                     nVars;

public:
  OCCTMathHessianAdapter(int n, OCCTMathHessianCallback cb, void* ctx)
      : nVars(n),
        callback(cb),
        context(ctx)
  {
  }

  int NbVariables() const override { return nVars; }

  bool Value(const math_Vector& X, double& F) override
  {
    std::vector<double> x(nVars), g(nVars), h(nVars * nVars);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    return callback(x.data(), nVars, &F, g.data(), h.data(), context);
  }

  bool Gradient(const math_Vector& X, math_Vector& G) override
  {
    std::vector<double> x(nVars), g(nVars), h(nVars * nVars);
    double              f;
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = callback(x.data(), nVars, &f, g.data(), h.data(), context);
    for (int i = 0; i < nVars; i++)
      G(i + 1) = g[i];
    return ok;
  }

  bool Values(const math_Vector& X, double& F, math_Vector& G) override
  {
    std::vector<double> x(nVars), g(nVars), h(nVars * nVars);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = callback(x.data(), nVars, &F, g.data(), h.data(), context);
    for (int i = 0; i < nVars; i++)
      G(i + 1) = g[i];
    return ok;
  }

  bool Values(const math_Vector& X, double& F, math_Vector& G, math_Matrix& H) override
  {
    std::vector<double> x(nVars), g(nVars), h(nVars * nVars);
    for (int i = 0; i < nVars; i++)
      x[i] = X(i + 1);
    bool ok = callback(x.data(), nVars, &F, g.data(), h.data(), context);
    for (int i = 0; i < nVars; i++)
      G(i + 1) = g[i];
    for (int i = 0; i < nVars; i++)
      for (int j = 0; j < nVars; j++)
        H(i + 1, j + 1) = h[i * nVars + j];
    return ok;
  }
};

struct OCCTIntfTool
{
  Intf_Tool tool;
  int       nbSeg;

  OCCTIntfTool()
      : nbSeg(0)
  {
  }
};

namespace
{
class MathIntegFuncAdapter
{
  OCCTMathSimpleFuncCallback cb;
  void*                      ctx;

public:
  MathIntegFuncAdapter(OCCTMathSimpleFuncCallback c, void* x)
      : cb(c),
        ctx(x)
  {
  }

  bool Value(double x, double& f) { return cb(x, &f, ctx); }
};
} // namespace

OCCTIntrvIntervalRef _Nonnull OCCTIntrvIntervalCreate(double start,
                                                      double end,
                                                      float  tolStart,
                                                      float  tolEnd)
{
  auto* ref     = new OCCTIntrvInterval();
  ref->interval = Intrv_Interval(start, tolStart, end, tolEnd);
  return ref;
}

OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreate(double start, double end)
{
  auto* ref      = new OCCTIntrvIntervals();
  ref->intervals = Intrv_Intervals(Intrv_Interval(start, end));
  return ref;
}

OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreateEmpty(void)
{
  auto* ref      = new OCCTIntrvIntervals();
  ref->intervals = Intrv_Intervals();
  return ref;
}

OCCTIntrvBounds OCCTIntrvIntervalsValue(OCCTIntrvIntervalsRef _Nonnull intervals, int32_t index)
{
  OCCTIntrvBounds b = {0, 0, 0, 0};
  try
  {
    const Intrv_Interval& iv = intervals->intervals.Value(index);
    iv.Bounds(b.start, b.tolStart, b.end, b.tolEnd);
  }
  catch (...)
  {
  }
  return b;
}

void OCCTIntrvIntervalsUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end)
{
  intervals->intervals.Unite(Intrv_Interval(start, end));
}

void OCCTIntrvIntervalsSubtract(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end)
{
  intervals->intervals.Subtract(Intrv_Interval(start, end));
}

void OCCTIntrvIntervalsIntersect(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end)
{
  intervals->intervals.Intersect(Intrv_Interval(start, end));
}

void OCCTIntrvIntervalsXUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end)
{
  intervals->intervals.XUnite(Intrv_Interval(start, end));
}

OCCTIntConicQuadResult OCCTIntAnaLineQuad(double lox,
                                          double loy,
                                          double loz,
                                          double ldx,
                                          double ldy,
                                          double ldz,
                                          double pox,
                                          double poy,
                                          double poz,
                                          double pnx,
                                          double pny,
                                          double pnz)
{
  OCCTIntConicQuadResult r = {};
  try
  {
    gp_Lin              line(gp_Pnt(lox, loy, loz), gp_Dir(ldx, ldy, ldz));
    gp_Pln              plane(gp_Pnt(pox, poy, poz), gp_Dir(pnx, pny, pnz));
    IntAna_IntConicQuad inter(line, plane, Precision::Angular());
    if (!inter.IsDone())
      return r;
    r.isParallel  = inter.IsParallel();
    r.isInQuadric = inter.IsInQuadric();
    r.count       = inter.NbPoints();
    for (int i = 0; i < r.count && i < 4; i++)
    {
      gp_Pnt p            = inter.Point(i + 1);
      r.points[i * 3]     = p.X();
      r.points[i * 3 + 1] = p.Y();
      r.points[i * 3 + 2] = p.Z();
      r.params[i]         = inter.ParamOnConic(i + 1);
    }
  }
  catch (...)
  {
  }
  return r;
}

OCCTIntConicQuadResult OCCTIntAnaLineSphere(double lox,
                                            double loy,
                                            double loz,
                                            double ldx,
                                            double ldy,
                                            double ldz,
                                            double sx,
                                            double sy,
                                            double sz,
                                            double snx,
                                            double sny,
                                            double snz,
                                            double radius)
{
  OCCTIntConicQuadResult r = {};
  try
  {
    gp_Lin         line(gp_Pnt(lox, loy, loz), gp_Dir(ldx, ldy, ldz));
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sx, sy, sz), gp_Dir(snx, sny, snz)), radius));
    IntAna_IntConicQuad inter(line, quad);
    if (!inter.IsDone())
      return r;
    r.isParallel = inter.IsParallel();
    r.count      = inter.NbPoints();
    for (int i = 0; i < r.count && i < 4; i++)
    {
      gp_Pnt p            = inter.Point(i + 1);
      r.points[i * 3]     = p.X();
      r.points[i * 3 + 1] = p.Y();
      r.points[i * 3 + 2] = p.Z();
      r.params[i]         = inter.ParamOnConic(i + 1);
    }
  }
  catch (...)
  {
  }
  return r;
}

OCCTQuadQuadGeoResult OCCTIntAnaPlanePlane(double p1ox,
                                           double p1oy,
                                           double p1oz,
                                           double p1nx,
                                           double p1ny,
                                           double p1nz,
                                           double p2ox,
                                           double p2oy,
                                           double p2oz,
                                           double p2nx,
                                           double p2ny,
                                           double p2nz)
{
  OCCTQuadQuadGeoResult r = {};
  try
  {
    gp_Pln             pl1(gp_Pnt(p1ox, p1oy, p1oz), gp_Dir(p1nx, p1ny, p1nz));
    gp_Pln             pl2(gp_Pnt(p2ox, p2oy, p2oz), gp_Dir(p2nx, p2ny, p2nz));
    IntAna_QuadQuadGeo inter(pl1, pl2, Precision::Angular(), Precision::Confusion());
    if (!inter.IsDone())
      return r;
    r.solutionCount = inter.NbSolutions();
    r.resultType    = (int32_t)inter.TypeInter();
    for (int i = 0; i < r.solutionCount && i < 4; i++)
    {
      try
      {
        gp_Lin line        = inter.Line(i + 1);
        gp_Pnt o           = line.Location();
        gp_Dir d           = line.Direction();
        r.lines[i * 6]     = o.X();
        r.lines[i * 6 + 1] = o.Y();
        r.lines[i * 6 + 2] = o.Z();
        r.lines[i * 6 + 3] = d.X();
        r.lines[i * 6 + 4] = d.Y();
        r.lines[i * 6 + 5] = d.Z();
      }
      catch (...)
      {
      }
    }
  }
  catch (...)
  {
  }
  return r;
}

OCCTQuadQuadGeoResult OCCTIntAnaPlaneSphere(double pox,
                                            double poy,
                                            double poz,
                                            double pnx,
                                            double pny,
                                            double pnz,
                                            double sx,
                                            double sy,
                                            double sz,
                                            double snx,
                                            double sny,
                                            double snz,
                                            double radius)
{
  OCCTQuadQuadGeoResult r = {};
  try
  {
    gp_Pln             plane(gp_Pnt(pox, poy, poz), gp_Dir(pnx, pny, pnz));
    gp_Sphere          sphere(gp_Ax3(gp_Pnt(sx, sy, sz), gp_Dir(snx, sny, snz)), radius);
    IntAna_QuadQuadGeo inter(plane, sphere);
    if (!inter.IsDone())
      return r;
    r.solutionCount = inter.NbSolutions();
    r.resultType    = (int32_t)inter.TypeInter();
    for (int i = 0; i < r.solutionCount && i < 4; i++)
    {
      try
      {
        gp_Pnt p            = inter.Point(i + 1);
        r.points[i * 3]     = p.X();
        r.points[i * 3 + 1] = p.Y();
        r.points[i * 3 + 2] = p.Z();
      }
      catch (...)
      {
      }
    }
  }
  catch (...)
  {
  }
  return r;
}

bool OCCTIntAna3Planes(double  p1ox,
                       double  p1oy,
                       double  p1oz,
                       double  p1nx,
                       double  p1ny,
                       double  p1nz,
                       double  p2ox,
                       double  p2oy,
                       double  p2oz,
                       double  p2nx,
                       double  p2ny,
                       double  p2nz,
                       double  p3ox,
                       double  p3oy,
                       double  p3oz,
                       double  p3nx,
                       double  p3ny,
                       double  p3nz,
                       double* outX,
                       double* outY,
                       double* outZ)
{
  try
  {
    IntAna_Int3Pln inter(gp_Pln(gp_Pnt(p1ox, p1oy, p1oz), gp_Dir(p1nx, p1ny, p1nz)),
                         gp_Pln(gp_Pnt(p2ox, p2oy, p2oz), gp_Dir(p2nx, p2ny, p2nz)),
                         gp_Pln(gp_Pnt(p3ox, p3oy, p3oz), gp_Dir(p3nx, p3ny, p3nz)));
    if (!inter.IsDone() || inter.IsEmpty())
      return false;
    gp_Pnt p = inter.Value();
    *outX    = p.X();
    *outY    = p.Y();
    *outZ    = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTIntAnaLineTorus(double  lox,
                            double  loy,
                            double  loz,
                            double  ldx,
                            double  ldy,
                            double  ldz,
                            double  tox,
                            double  toy,
                            double  toz,
                            double  tnx,
                            double  tny,
                            double  tnz,
                            double  majorRadius,
                            double  minorRadius,
                            double* outPoints)
{
  try
  {
    gp_Lin   line(gp_Pnt(lox, loy, loz), gp_Dir(ldx, ldy, ldz));
    gp_Torus torus(gp_Ax3(gp_Pnt(tox, toy, toz), gp_Dir(tnx, tny, tnz)), majorRadius, minorRadius);
    IntAna_IntLinTorus inter(line, torus);
    if (!inter.IsDone())
      return 0;
    int n = inter.NbPoints();
    for (int i = 0; i < n && i < 4; i++)
    {
      gp_Pnt p             = inter.Value(i + 1);
      outPoints[i * 3]     = p.X();
      outPoints[i * 3 + 1] = p.Y();
      outPoints[i * 3 + 2] = p.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTIntAnaCylinderSphere(double cylRadius,
                                 double sphCx,
                                 double sphCy,
                                 double sphCz,
                                 double sphRadius,
                                 double tol)
{
  try
  {
    gp_Cylinder    cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), cylRadius);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0, 0, 1)), sphRadius));
    IntAna_IntQuadQuad iqq(cyl, quad, tol);
    if (!iqq.IsDone())
      return -1;
    if (iqq.IdenticalElements())
      return -2;
    return (int32_t)iqq.NbCurve();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTIntAnaCylinderSphereIdentical(double cylRadius,
                                       double sphCx,
                                       double sphCy,
                                       double sphCz,
                                       double sphRadius,
                                       double tol)
{
  try
  {
    gp_Cylinder    cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), cylRadius);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0, 0, 1)), sphRadius));
    IntAna_IntQuadQuad iqq(cyl, quad, tol);
    return iqq.IsDone() && iqq.IdenticalElements();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTIntAnaConeSphere(double semiAngle,
                             double refRadius,
                             double sphCx,
                             double sphCy,
                             double sphCz,
                             double sphRadius,
                             double tol)
{
  try
  {
    gp_Cone        cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), semiAngle, refRadius);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0, 0, 1)), sphRadius));
    IntAna_IntQuadQuad iqq(cone, quad, tol);
    if (!iqq.IsDone())
      return -1;
    if (iqq.IdenticalElements())
      return -2;
    return (int32_t)iqq.NbCurve();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTIntAnaConeSpherePoints(double  semiAngle,
                                   double  refRadius,
                                   double  sphCx,
                                   double  sphCy,
                                   double  sphCz,
                                   double  sphRadius,
                                   double  tol,
                                   int32_t curveIndex,
                                   int32_t nbSamples,
                                   double* xs,
                                   double* ys,
                                   double* zs)
{
  try
  {
    gp_Cone        cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), semiAngle, refRadius);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0, 0, 1)), sphRadius));
    IntAna_IntQuadQuad iqq(cone, quad, tol);
    if (!iqq.IsDone() || curveIndex < 1 || curveIndex > (int32_t)iqq.NbCurve())
      return 0;
    IntAna_Curve curve = iqq.Curve(curveIndex);
    double       first, last;
    curve.Domain(first, last);
    int32_t actual = nbSamples;
    for (int32_t i = 0; i < actual; i++)
    {
      double t = first + (last - first) * i / (actual - 1);
      gp_Pnt p = curve.Value(t);
      xs[i]    = p.X();
      ys[i]    = p.Y();
      zs[i]    = p.Z();
    }
    return actual;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTIntAnaConeSphereIsOpen(double  semiAngle,
                                double  refRadius,
                                double  sphCx,
                                double  sphCy,
                                double  sphCz,
                                double  sphRadius,
                                double  tol,
                                int32_t curveIndex)
{
  try
  {
    gp_Cone        cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), semiAngle, refRadius);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0, 0, 1)), sphRadius));
    IntAna_IntQuadQuad iqq(cone, quad, tol);
    if (!iqq.IsDone() || curveIndex < 1 || curveIndex > (int32_t)iqq.NbCurve())
      return true;
    IntAna_Curve curve = iqq.Curve(curveIndex);
    return curve.IsOpen();
  }
  catch (...)
  {
    return true;
  }
}

void OCCTIntAnaConeSphereGetDomain(double  semiAngle,
                                   double  refRadius,
                                   double  sphCx,
                                   double  sphCy,
                                   double  sphCz,
                                   double  sphRadius,
                                   double  tol,
                                   int32_t curveIndex,
                                   double* first,
                                   double* last)
{
  *first = 0;
  *last  = 0;
  try
  {
    gp_Cone        cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), semiAngle, refRadius);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0, 0, 1)), sphRadius));
    IntAna_IntQuadQuad iqq(cone, quad, tol);
    if (!iqq.IsDone() || curveIndex < 1 || curveIndex > (int32_t)iqq.NbCurve())
      return;
    IntAna_Curve curve = iqq.Curve(curveIndex);
    curve.Domain(*first, *last);
  }
  catch (...)
  {
  }
}
