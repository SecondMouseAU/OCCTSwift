//
//  OCCTBridge_Spatial_MathSolvers.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Spatial.mm (#1380): math_* (FunctionRoot(s)/FunctionSetRoot, BFGS, Powell,
//  BrentMinimum, PSO, GlobOptMin, GaussSingleIntegration, NewtonFunctionSetRoot/Minimum,
//  TrigonometricFunctionRoots, Matrix, Gauss, SVD, DirectPolynomialRoots, Jacobi, Householder,
//  Crout), MathPoly_Laguerre -- default_bucket. Public C surface unchanged; every sibling file
//  imports the same headers this one does (the shared preamble below). No symbol changes, pure file
//  move -- see Scripts/repro/396-bridge-mm-split/ for how.
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

OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c)
{
  return occtSolvePolynomial(a, b, c);
}

OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d)
{
  return occtSolvePolynomial(a, b, c, d);
}

OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e)
{
  return occtSolvePolynomial(a, b, c, d, e);
}

bool OCCTAnalyzePointCloud(const double*           coords,
                           int32_t                 pointCount,
                           double                  tolerance,
                           OCCTPointCloudGeometry* outResult)
{
  if (!coords || pointCount < 1 || !outResult)
    return false;
  try
  {
    TColgp_Array1OfPnt pts(1, pointCount);
    for (int32_t i = 0; i < pointCount; i++)
    {
      pts.SetValue(i + 1, gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
    }

    GProp_PEquation eq(pts, tolerance);

    if (eq.IsPoint())
    {
      outResult->type   = 0;
      gp_Pnt pt         = eq.Point();
      outResult->pointX = pt.X();
      outResult->pointY = pt.Y();
      outResult->pointZ = pt.Z();
    }
    else if (eq.IsLinear())
    {
      outResult->type   = 1;
      gp_Lin lin        = eq.Line();
      gp_Pnt o          = lin.Location();
      gp_Dir d          = lin.Direction();
      outResult->pointX = o.X();
      outResult->pointY = o.Y();
      outResult->pointZ = o.Z();
      outResult->dirX   = d.X();
      outResult->dirY   = d.Y();
      outResult->dirZ   = d.Z();
    }
    else if (eq.IsPlanar())
    {
      outResult->type    = 2;
      gp_Pln pln         = eq.Plane();
      gp_Pnt o           = pln.Location();
      gp_Dir n           = pln.Axis().Direction();
      outResult->pointX  = o.X();
      outResult->pointY  = o.Y();
      outResult->pointZ  = o.Z();
      outResult->normalX = n.X();
      outResult->normalY = n.Y();
      outResult->normalZ = n.Z();
    }
    else
    {
      outResult->type = 3;
      // No specific geometry for space points
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTIntrvIntervalRelease(OCCTIntrvIntervalRef _Nonnull interval)
{
  delete interval;
}

OCCTIntrvBounds OCCTIntrvIntervalBounds(OCCTIntrvIntervalRef _Nonnull interval)
{
  OCCTIntrvBounds b;
  interval->interval.Bounds(b.start, b.tolStart, b.end, b.tolEnd);
  return b;
}

bool OCCTIntrvIntervalIsProbablyEmpty(OCCTIntrvIntervalRef _Nonnull interval)
{
  return interval->interval.IsProbablyEmpty();
}

int32_t OCCTIntrvIntervalPosition(OCCTIntrvIntervalRef _Nonnull interval,
                                  OCCTIntrvIntervalRef _Nonnull other)
{
  return (int32_t)interval->interval.Position(other->interval);
}

bool OCCTIntrvIntervalIsBefore(OCCTIntrvIntervalRef _Nonnull interval,
                               OCCTIntrvIntervalRef _Nonnull other)
{
  return interval->interval.IsBefore(other->interval);
}

bool OCCTIntrvIntervalIsAfter(OCCTIntrvIntervalRef _Nonnull interval,
                              OCCTIntrvIntervalRef _Nonnull other)
{
  return interval->interval.IsAfter(other->interval);
}

bool OCCTIntrvIntervalIsInside(OCCTIntrvIntervalRef _Nonnull interval,
                               OCCTIntrvIntervalRef _Nonnull other)
{
  return interval->interval.IsInside(other->interval);
}

bool OCCTIntrvIntervalIsEnclosing(OCCTIntrvIntervalRef _Nonnull interval,
                                  OCCTIntrvIntervalRef _Nonnull other)
{
  return interval->interval.IsEnclosing(other->interval);
}

bool OCCTIntrvIntervalIsSimilar(OCCTIntrvIntervalRef _Nonnull interval,
                                OCCTIntrvIntervalRef _Nonnull other)
{
  return interval->interval.IsSimilar(other->interval);
}

void OCCTIntrvIntervalSetStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol)
{
  interval->interval.SetStart(start, tol);
}

void OCCTIntrvIntervalSetEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol)
{
  interval->interval.SetEnd(end, tol);
}

void OCCTIntrvIntervalFuseAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol)
{
  interval->interval.FuseAtStart(start, tol);
}

void OCCTIntrvIntervalFuseAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol)
{
  interval->interval.FuseAtEnd(end, tol);
}

void OCCTIntrvIntervalCutAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol)
{
  interval->interval.CutAtStart(start, tol);
}

void OCCTIntrvIntervalCutAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol)
{
  interval->interval.CutAtEnd(end, tol);
}

void OCCTIntrvIntervalsRelease(OCCTIntrvIntervalsRef _Nonnull intervals)
{
  delete intervals;
}

int32_t OCCTIntrvIntervalsCount(OCCTIntrvIntervalsRef _Nonnull intervals)
{
  return (int32_t)intervals->intervals.NbIntervals();
}

OCCTRangeRef OCCTRangeCreateVoid()
{
  return new OCCTRange();
}

void OCCTRangeRelease(OCCTRangeRef range)
{
  delete range;
}

bool OCCTRangeIsVoid(OCCTRangeRef range)
{
  return range->range.IsVoid();
}

bool OCCTRangeGetBounds(OCCTRangeRef range, double* first, double* last)
{
  return range->range.GetBounds(*first, *last);
}

double OCCTRangeDelta(OCCTRangeRef range)
{
  return range->range.Delta();
}

bool OCCTRangeContains(OCCTRangeRef range, double value)
{
  return range->range.Contains(value);
}

void OCCTRangeAddValue(OCCTRangeRef range, double value)
{
  range->range.Add(value);
}

void OCCTRangeAddRange(OCCTRangeRef range, OCCTRangeRef other)
{
  range->range.Add(other->range);
}

void OCCTRangeCommon(OCCTRangeRef range, OCCTRangeRef other)
{
  range->range.Common(other->range);
}

void OCCTRangeEnlarge(OCCTRangeRef range, double delta)
{
  range->range.Enlarge(delta);
}

void OCCTRangeTrimFrom(OCCTRangeRef range, double lower)
{
  range->range.TrimFrom(lower);
}

void OCCTRangeTrimTo(OCCTRangeRef range, double upper)
{
  range->range.TrimTo(upper);
}

OCCTMathMatrixRef OCCTMathMatrixCreate(int32_t rows, int32_t cols, double initValue)
{
  return new OCCTMathMatrix(rows, cols, initValue);
}

void OCCTMathMatrixRelease(OCCTMathMatrixRef m)
{
  delete m;
}

int32_t OCCTMathMatrixRows(OCCTMathMatrixRef m)
{
  return m->mat.RowNumber();
}

int32_t OCCTMathMatrixCols(OCCTMathMatrixRef m)
{
  return m->mat.ColNumber();
}

double OCCTMathMatrixGetValue(OCCTMathMatrixRef m, int32_t row, int32_t col)
{
  return m->mat(row, col);
}

void OCCTMathMatrixSetValue(OCCTMathMatrixRef m, int32_t row, int32_t col, double value)
{
  m->mat(row, col) = value;
}

double OCCTMathMatrixDeterminant(OCCTMathMatrixRef m)
{
  try
  {
    return m->mat.Determinant();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTMathMatrixInvert(OCCTMathMatrixRef m)
{
  try
  {
    m->mat.Invert();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTMathMatrixMultiplyScalar(OCCTMathMatrixRef m, double scalar)
{
  m->mat.Multiply(scalar);
}

void OCCTMathMatrixTranspose(OCCTMathMatrixRef m)
{
  m->mat.Transpose();
}

bool OCCTMathGaussSolve(const double* matrixData, int32_t n, const double* rhs, double* outSolution)
{
  try
  {
    math_Matrix A(1, n, 1, n, 0.0);
    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
        A(i + 1, j + 1) = matrixData[i * n + j];
    math_Gauss gauss(A);
    if (!gauss.IsDone())
      return false;
    math_Vector B(1, n, 0.0);
    for (int i = 0; i < n; i++)
      B(i + 1) = rhs[i];
    math_Vector X(1, n, 0.0);
    gauss.Solve(B, X);
    for (int i = 0; i < n; i++)
      outSolution[i] = X(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTMathGaussDeterminant(const double* matrixData, int32_t n)
{
  try
  {
    math_Matrix A(1, n, 1, n, 0.0);
    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
        A(i + 1, j + 1) = matrixData[i * n + j];
    math_Gauss gauss(A);
    if (!gauss.IsDone())
      return 0.0;
    return gauss.Determinant();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTMathSVDSolve(const double* matrixData,
                      int32_t       rows,
                      int32_t       cols,
                      const double* rhs,
                      double*       outSolution)
{
  try
  {
    math_Matrix A(1, rows, 1, cols, 0.0);
    for (int i = 0; i < rows; i++)
      for (int j = 0; j < cols; j++)
        A(i + 1, j + 1) = matrixData[i * cols + j];
    math_SVD svd(A);
    if (!svd.IsDone())
      return false;
    math_Vector B(1, rows, 0.0);
    for (int i = 0; i < rows; i++)
      B(i + 1) = rhs[i];
    math_Vector X(1, cols, 0.0);
    svd.Solve(B, X);
    for (int i = 0; i < cols; i++)
      outSolution[i] = X(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTMathPolynomialRoots(const double* coeffs, int32_t nCoeffs, double* outRoots)
{
  try
  {
    math_DirectPolynomialRoots* roots = nullptr;
    switch (nCoeffs)
    {
      case 2:
        roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1]);
        break;
      case 3:
        roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1], coeffs[2]);
        break;
      case 4:
        roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1], coeffs[2], coeffs[3]);
        break;
      case 5:
        roots =
          new math_DirectPolynomialRoots(coeffs[0], coeffs[1], coeffs[2], coeffs[3], coeffs[4]);
        break;
      default:
        return -1;
    }
    if (!roots->IsDone())
    {
      delete roots;
      return -1;
    }
    int n = roots->NbSolutions();
    for (int i = 0; i < n && i < 4; i++)
      outRoots[i] = roots->Value(i + 1);
    delete roots;
    return n;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTMathJacobiEigenvalues(const double* matrixData, int32_t n, double* outEigenvalues)
{
  try
  {
    math_Matrix A(1, n, 1, n, 0.0);
    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
        A(i + 1, j + 1) = matrixData[i * n + j];
    math_Jacobi jacobi(A);
    if (!jacobi.IsDone())
      return false;
    for (int i = 0; i < n; i++)
      outEigenvalues[i] = jacobi.Value(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathHouseholderSolve(const double* matrixData,
                              int32_t       rows,
                              int32_t       cols,
                              const double* rhs,
                              double*       outSolution)
{
  try
  {
    math_Matrix A(1, rows, 1, cols, 0.0);
    for (int i = 0; i < rows; i++)
      for (int j = 0; j < cols; j++)
        A(i + 1, j + 1) = matrixData[i * cols + j];
    math_Vector B(1, rows, 0.0);
    for (int i = 0; i < rows; i++)
      B(i + 1) = rhs[i];
    math_Householder hh(A, B);
    if (!hh.IsDone())
      return false;
    math_Vector sol(1, cols, 0.0);
    hh.Value(sol, 1);
    for (int i = 0; i < cols; i++)
      outSolution[i] = sol(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathCroutSolve(const double* matrixData, int32_t n, const double* rhs, double* outSolution)
{
  try
  {
    math_Matrix A(1, n, 1, n, 0.0);
    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
        A(i + 1, j + 1) = matrixData[i * n + j];
    math_Crout crout(A);
    if (!crout.IsDone())
      return false;
    math_Vector B(1, n, 0.0);
    for (int i = 0; i < n; i++)
      B(i + 1) = rhs[i];
    math_Vector X(1, n, 0.0);
    crout.Solve(B, X);
    for (int i = 0; i < n; i++)
      outSolution[i] = X(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTMathCroutDeterminant(const double* matrixData, int32_t n)
{
  try
  {
    math_Matrix A(1, n, 1, n, 0.0);
    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++)
        A(i + 1, j + 1) = matrixData[i * n + j];
    math_Crout crout(A);
    if (!crout.IsDone())
      return 0.0;
    return crout.Determinant();
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTPrecisionConfusion()
{
  return Precision::Confusion();
}

double OCCTPrecisionAngular()
{
  return Precision::Angular();
}

double OCCTPrecisionIntersection()
{
  return Precision::Intersection();
}

double OCCTPrecisionApproximation()
{
  return Precision::Approximation();
}

double OCCTPrecisionInfinite()
{
  return Precision::Infinite();
}

double OCCTPrecisionPConfusion()
{
  return Precision::PConfusion();
}

bool OCCTPrecisionIsInfinite(double value)
{
  return Precision::IsInfinite(value);
}

void OCCTBndSphereRelease(OCCTBndSphereRef sphere)
{
  delete sphere;
}

double OCCTBndSphereRadius(OCCTBndSphereRef sphere)
{
  return sphere->sphere.Radius();
}

void OCCTBndSphereCenter(OCCTBndSphereRef sphere, double* x, double* y, double* z)
{
  gp_XYZ c = sphere->sphere.Center();
  *x       = c.X();
  *y       = c.Y();
  *z       = c.Z();
}

double OCCTBndSphereDistance(OCCTBndSphereRef sphere, double x, double y, double z)
{
  return sphere->sphere.Distance(gp_XYZ(x, y, z));
}

bool OCCTBndSphereIsOut(OCCTBndSphereRef sphere, double x, double y, double z)
{
  double maxDist = 0;
  return sphere->sphere.IsOut(gp_XYZ(x, y, z), maxDist);
}

bool OCCTBndSphereIsOutSphere(OCCTBndSphereRef s1, OCCTBndSphereRef s2)
{
  return s1->sphere.IsOut(s2->sphere);
}

void OCCTBndSphereAdd(OCCTBndSphereRef sphere, OCCTBndSphereRef other)
{
  sphere->sphere.Add(other->sphere);
}

int32_t OCCTTrigRoots(double  A,
                      double  B,
                      double  C,
                      double  D,
                      double  E,
                      double  inf,
                      double  sup,
                      double* roots,
                      int32_t maxRoots)
{
  try
  {
    math_TrigonometricFunctionRoots solver(A, B, C, D, E, inf, sup);
    if (!solver.IsDone())
      return -1;
    int n     = solver.NbSolutions();
    int count = 0;
    for (int i = 1; i <= n && count < maxRoots; i++)
    {
      roots[count++] = solver.Value(i);
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTTrigRootsInfinite(double A, double B, double C, double D, double E, double inf, double sup)
{
  try
  {
    math_TrigonometricFunctionRoots solver(A, B, C, D, E, inf, sup);
    if (!solver.IsDone())
      return false;
    return solver.InfiniteRoots();
  }
  catch (...)
  {
    return false;
  }
}

double OCCTMathFunctionRoot(OCCTMathFuncDerivCallback callback,
                            void*                     context,
                            double                    guess,
                            double                    tolerance,
                            int32_t                   maxIter,
                            bool*                     isDone)
{
  *isDone = false;
  try
  {
    OCCTMathFuncAdapter func(callback, context);
    math_FunctionRoot   root(func, guess, tolerance, maxIter);
    *isDone = root.IsDone();
    return root.IsDone() ? root.Root() : 0.0;
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTMathFunctionRootBounded(OCCTMathFuncDerivCallback callback,
                                   void*                     context,
                                   double                    guess,
                                   double                    tolerance,
                                   double                    a,
                                   double                    b,
                                   int32_t                   maxIter,
                                   bool*                     isDone)
{
  *isDone = false;
  try
  {
    OCCTMathFuncAdapter func(callback, context);
    math_FunctionRoot   root(func, guess, tolerance, a, b, maxIter);
    *isDone = root.IsDone();
    return root.IsDone() ? root.Root() : 0.0;
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTMathBissecNewton(OCCTMathFuncDerivCallback callback,
                            void*                     context,
                            double                    a,
                            double                    b,
                            double                    tolerance,
                            int32_t                   maxIter,
                            bool*                     isDone)
{
  *isDone = false;
  try
  {
    OCCTMathFuncAdapter func(callback, context);
    math_BissecNewton   bn(tolerance);
    bn.Perform(func, a, b, maxIter);
    *isDone = bn.IsDone();
    return bn.IsDone() ? bn.Root() : 0.0;
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTMathFunctionSetRoot(int32_t                      nVars,
                             int32_t                      nEqs,
                             OCCTMathFuncSetCallback      valueCallback,
                             OCCTMathFuncSetDerivCallback derivCallback,
                             void*                        context,
                             const double*                startPoint,
                             double                       tolerance,
                             int32_t                      maxIter,
                             double*                      result)
{
  try
  {
    OCCTMathFuncSetAdapter sys(nVars, nEqs, valueCallback, derivCallback, context);
    math_Vector            start(1, nVars);
    math_Vector            tol(1, nVars, tolerance);
    for (int i = 0; i < nVars; i++)
      start(i + 1) = startPoint[i];
    math_FunctionSetRoot solver(sys, tol, maxIter);
    solver.Perform(sys, start);
    if (!solver.IsDone())
      return false;
    const math_Vector& sol = solver.Root();
    for (int i = 0; i < nVars; i++)
      result[i] = sol(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathBFGS(int32_t                      nVars,
                  OCCTMathMultiVarGradCallback callback,
                  void*                        context,
                  const double*                startPoint,
                  double                       tolerance,
                  int32_t                      maxIter,
                  double*                      result,
                  double*                      minimum)
{
  try
  {
    OCCTMathMultiVarGradAdapter func(nVars, callback, context);
    math_Vector                 start(1, nVars);
    for (int i = 0; i < nVars; i++)
      start(i + 1) = startPoint[i];
    math_BFGS bfgs(nVars, tolerance, maxIter, tolerance);
    bfgs.Perform(func, start);
    if (!bfgs.IsDone())
      return false;
    const math_Vector& loc = bfgs.Location();
    for (int i = 0; i < nVars; i++)
      result[i] = loc(i + 1);
    *minimum = bfgs.Minimum();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathPowell(int32_t                  nVars,
                    OCCTMathMultiVarCallback callback,
                    void*                    context,
                    const double*            startPoint,
                    double                   tolerance,
                    int32_t                  maxIter,
                    double*                  result,
                    double*                  minimum)
{
  try
  {
    OCCTMathMultiVarAdapter func(nVars, callback, context);
    math_Vector             start(1, nVars);
    for (int i = 0; i < nVars; i++)
      start(i + 1) = startPoint[i];
    math_Matrix dirs(1, nVars, 1, nVars, 0.0);
    for (int i = 1; i <= nVars; i++)
      dirs(i, i) = 1.0;
    math_Powell powell(func, tolerance, maxIter);
    powell.Perform(func, start, dirs);
    if (!powell.IsDone())
      return false;
    const math_Vector& loc = powell.Location();
    for (int i = 0; i < nVars; i++)
      result[i] = loc(i + 1);
    *minimum = powell.Minimum();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathBrentMinimum(OCCTMathFuncDerivCallback callback,
                          void*                     context,
                          double                    ax,
                          double                    bx,
                          double                    cx,
                          double                    tolerance,
                          int32_t                   maxIter,
                          double*                   location,
                          double*                   minimum)
{
  try
  {
    OCCTMathFuncAdapter func(callback, context);
    math_BrentMinimum   brent(tolerance, maxIter, tolerance);
    brent.Perform(func, ax, bx, cx);
    if (!brent.IsDone())
      return false;
    *location = brent.Location();
    *minimum  = brent.Minimum();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathPSO(int32_t                  nVars,
                 OCCTMathMultiVarCallback callback,
                 void*                    context,
                 const double*            lower,
                 const double*            upper,
                 const double*            steps,
                 int32_t                  nbParticles,
                 int32_t                  nbIter,
                 double*                  result,
                 double*                  minimum)
{
  try
  {
    OCCTMathMultiVarAdapter func(nVars, callback, context);
    math_Vector             lo(1, nVars), hi(1, nVars), st(1, nVars);
    for (int i = 0; i < nVars; i++)
    {
      lo(i + 1) = lower[i];
      hi(i + 1) = upper[i];
      st(i + 1) = steps[i];
    }
    math_PSO    pso(&func, lo, hi, st, nbParticles, nbIter);
    math_Vector res(1, nVars);
    double      val;
    pso.Perform(st, val, res);
    for (int i = 0; i < nVars; i++)
      result[i] = res(i + 1);
    *minimum = val;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathGlobOptMin(int32_t                  nVars,
                        OCCTMathMultiVarCallback callback,
                        void*                    context,
                        const double*            lower,
                        const double*            upper,
                        double*                  result,
                        double*                  minimum)
{
  try
  {
    OCCTMathMultiVarAdapter func(nVars, callback, context);
    math_Vector             lo(1, nVars), hi(1, nVars);
    for (int i = 0; i < nVars; i++)
    {
      lo(i + 1) = lower[i];
      hi(i + 1) = upper[i];
    }
    math_GlobOptMin gom(&func, lo, hi);
    gom.Perform();
    if (!gom.isDone() || gom.NbExtrema() == 0)
      return false;
    math_Vector sol(1, nVars);
    gom.Points(1, sol);
    for (int i = 0; i < nVars; i++)
      result[i] = sol(i + 1);
    *minimum = gom.GetF();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTMathFunctionRoots(OCCTMathFuncDerivCallback callback,
                              void*                     context,
                              double                    a,
                              double                    b,
                              int32_t                   nbSample,
                              double*                   roots,
                              int32_t                   maxRoots)
{
  try
  {
    OCCTMathFuncAdapter func(callback, context);
    math_FunctionRoots  fr(func, a, b, nbSample);
    if (!fr.IsDone())
      return 0;
    int32_t n = std::min((int32_t)fr.NbSolutions(), maxRoots);
    for (int32_t i = 0; i < n; i++)
      roots[i] = fr.Value(i + 1);
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTMathGaussIntegrate(OCCTMathSimpleFuncCallback callback,
                              void*                      context,
                              double                     lower,
                              double                     upper,
                              int32_t                    order)
{
  try
  {
    OCCTMathSimpleFuncAdapter   func(callback, context);
    math_GaussSingleIntegration gauss(func, lower, upper, order);
    if (!gauss.IsDone())
      return 0.0;
    return gauss.Value();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTMathNewtonFuncSetRoot(int32_t                      nVars,
                               int32_t                      nEqs,
                               OCCTMathFuncSetCallback      valCb,
                               OCCTMathFuncSetDerivCallback derivCb,
                               void*                        context,
                               const double*                start,
                               double                       tol,
                               int32_t                      maxIter,
                               double*                      result)
{
  try
  {
    OCCTMathFuncSetAdapter     sys(nVars, nEqs, valCb, derivCb, context);
    math_Vector                tolVec(1, nVars, tol);
    math_NewtonFunctionSetRoot solver(sys, tolVec, tol, maxIter);
    math_Vector                startVec(1, nVars);
    for (int i = 0; i < nVars; i++)
      startVec(i + 1) = start[i];
    solver.Perform(sys, startVec);
    if (!solver.IsDone())
      return false;
    const math_Vector& sol = solver.Root();
    for (int i = 0; i < nVars; i++)
      result[i] = sol(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTPolyLaguerreRoots(const double* coefficients,
                              int32_t       degree,
                              double*       roots,
                              int32_t       maxRoots)
{
  try
  {
    auto result = MathPoly::Laguerre(coefficients, degree);
    if (!result.IsDone())
      return 0;
    int32_t n = std::min((int32_t)result.NbRoots, maxRoots);
    for (int32_t i = 0; i < n; i++)
      roots[i] = result.Roots[i];
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTPolyLaguerreComplexRoots(const double* coefficients,
                                     int32_t       degree,
                                     double*       realParts,
                                     double*       imagParts,
                                     int32_t       maxRoots)
{
  try
  {
    auto result = MathPoly::Laguerre(coefficients, degree);
    if (!result.IsDone())
      return 0;
    int32_t n = std::min((int32_t)result.NbComplexRoots, maxRoots);
    for (int32_t i = 0; i < n; i++)
    {
      realParts[i] = result.ComplexRoots[i].real();
      imagParts[i] = result.ComplexRoots[i].imag();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTPolyQuinticRoots(double  a,
                             double  b,
                             double  c,
                             double  d,
                             double  e,
                             double  f,
                             double* roots,
                             int32_t maxRoots)
{
  try
  {
    auto result = MathPoly::Quintic(a, b, c, d, e, f);
    if (!result.IsDone())
      return 0;
    int32_t n = std::min((int32_t)result.NbRoots, maxRoots);
    for (int32_t i = 0; i < n; i++)
      roots[i] = result.Roots[i];
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTMathNewtonMinimum(int32_t                 nVars,
                           OCCTMathHessianCallback callback,
                           void*                   context,
                           const double*           startPoint,
                           double                  tolerance,
                           int32_t                 maxIter,
                           double*                 result,
                           double*                 minimum)
{
  try
  {
    OCCTMathHessianAdapter adapter(nVars, callback, context);
    math_NewtonMinimum     newton(adapter, tolerance, maxIter);
    math_Vector            start(1, nVars);
    for (int i = 0; i < nVars; i++)
      start(i + 1) = startPoint[i];
    newton.Perform(adapter, start);
    if (!newton.IsDone())
      return false;
    const math_Vector& loc = newton.Location();
    for (int i = 0; i < nVars; i++)
      result[i] = loc(i + 1);
    *minimum = newton.Minimum();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTIntfToolRef OCCTIntfToolCreate(void)
{
  return new OCCTIntfTool();
}

void OCCTIntfToolRelease(OCCTIntfToolRef tool)
{
  delete tool;
}

double OCCTIntfToolBeginParam(OCCTIntfToolRef tool, int32_t segIndex)
{
  if (!tool)
    return 0;
  try
  {
    return tool->tool.BeginParam(segIndex);
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTIntfToolEndParam(OCCTIntfToolRef tool, int32_t segIndex)
{
  if (!tool)
    return 0;
  try
  {
    return tool->tool.EndParam(segIndex);
  }
  catch (...)
  {
    return 0;
  }
}

// gp_XY / gp_XYZ
double OCCTXYModulus(double x, double y)
{
  return gp_XY(x, y).Modulus();
}

double OCCTXYCrossed(double x1, double y1, double x2, double y2)
{
  return gp_XY(x1, y1).Crossed(gp_XY(x2, y2));
}

double OCCTXYDot(double x1, double y1, double x2, double y2)
{
  return gp_XY(x1, y1).Dot(gp_XY(x2, y2));
}

bool OCCTXYNormalize(double x, double y, double* _Nonnull rx, double* _Nonnull ry)
{
  try
  {
    gp_XY v(x, y);
    gp_XY n = v.Normalized();
    *rx     = n.X();
    *ry     = n.Y();
    return true;
  }
  catch (...)
  {
    *rx = *ry = 0;
    return false;
  }
}

double OCCTMathBracketedRoot(OCCTMathFuncDerivCallback _Nonnull callback,
                             void* _Nullable context,
                             double  bound1,
                             double  bound2,
                             double  tolerance,
                             int32_t maxIter,
                             bool* _Nonnull isDone,
                             int32_t* _Nonnull nbIter)
{
  class Adapter : public math_FunctionWithDerivative
  {
    OCCTMathFuncDerivCallback cb;
    void*                     ctx;

  public:
    Adapter(OCCTMathFuncDerivCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override
    {
      double d;
      return cb(x, &f, &d, ctx);
    }

    bool Derivative(const double x, double& d) override
    {
      double f;
      return cb(x, &f, &d, ctx);
    }

    bool Values(const double x, double& f, double& d) override { return cb(x, &f, &d, ctx); }
  };

  try
  {
    Adapter            f(callback, context);
    math_BracketedRoot br(f, bound1, bound2, tolerance, maxIter);
    *isDone = br.IsDone();
    *nbIter = br.IsDone() ? br.NbIterations() : 0;
    return br.IsDone() ? br.Root() : 0;
  }
  catch (...)
  {
    *isDone = false;
    *nbIter = 0;
    return 0;
  }
}

bool OCCTMathBracketMinimum(OCCTMathSimpleFuncCallback _Nonnull callback,
                            void* _Nullable context,
                            double a,
                            double b,
                            double* _Nonnull ra,
                            double* _Nonnull rb,
                            double* _Nonnull rc,
                            double* _Nonnull fa,
                            double* _Nonnull fb,
                            double* _Nonnull fc)
{
  class Adapter : public math_Function
  {
    OCCTMathSimpleFuncCallback cb;
    void*                      ctx;

  public:
    Adapter(OCCTMathSimpleFuncCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override { return cb(x, &f, ctx); }
  };

  try
  {
    Adapter             f(callback, context);
    math_BracketMinimum bm(f, a, b);
    if (!bm.IsDone())
      return false;
    bm.Values(*ra, *rb, *rc);
    bm.FunctionValues(*fa, *fb, *fc);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMathFRPR(int32_t nVars,
                  OCCTMathMultiVarGradCallback _Nonnull callback,
                  void* _Nullable context,
                  const double* _Nonnull startPoint,
                  double  tolerance,
                  int32_t maxIter,
                  double* _Nonnull result,
                  double* _Nonnull minimum,
                  int32_t* _Nonnull nbIter)
{
  class Adapter : public math_MultipleVarFunctionWithGradient
  {
    OCCTMathMultiVarGradCallback cb;
    void*                        ctx;
    int                          n;

  public:
    Adapter(OCCTMathMultiVarGradCallback c, void* x, int nv)
        : cb(c),
          ctx(x),
          n(nv)
    {
    }

    int NbVariables() const override { return n; }

    bool Value(const math_Vector& X, double& F) override
    {
      std::vector<double> g(n);
      return cb(&X(1), n, &F, g.data(), ctx);
    }

    bool Gradient(const math_Vector& X, math_Vector& G) override
    {
      double              f;
      std::vector<double> g(n);
      bool                ok = cb(&X(1), n, &f, g.data(), ctx);
      for (int i = 0; i < n; i++)
        G(i + 1) = g[i];
      return ok;
    }

    bool Values(const math_Vector& X, double& F, math_Vector& G) override
    {
      std::vector<double> g(n);
      bool                ok = cb(&X(1), n, &F, g.data(), ctx);
      for (int i = 0; i < n; i++)
        G(i + 1) = g[i];
      return ok;
    }
  };

  try
  {
    Adapter     f(callback, context, nVars);
    math_FRPR   frpr(f, tolerance, maxIter);
    math_Vector start(1, nVars);
    for (int i = 0; i < nVars; i++)
      start(i + 1) = startPoint[i];
    frpr.Perform(f, start);
    if (!frpr.IsDone())
      return false;
    const math_Vector& loc = frpr.Location();
    for (int i = 0; i < nVars; i++)
      result[i] = loc(i + 1);
    *minimum = frpr.Minimum();
    *nbIter  = frpr.NbIterations();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTMathFunctionAllRoots(OCCTMathFuncDerivCallback _Nonnull callback,
                                 void* _Nullable context,
                                 double  a,
                                 double  b,
                                 int32_t nbSamples,
                                 double  epsX,
                                 double  epsF,
                                 double  epsNul,
                                 double* _Nonnull roots,
                                 int32_t maxRoots)
{
  class Adapter : public math_FunctionWithDerivative
  {
    OCCTMathFuncDerivCallback cb;
    void*                     ctx;

  public:
    Adapter(OCCTMathFuncDerivCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override
    {
      double d;
      return cb(x, &f, &d, ctx);
    }

    bool Derivative(const double x, double& d) override
    {
      double f;
      return cb(x, &f, &d, ctx);
    }

    bool Values(const double x, double& f, double& d) override { return cb(x, &f, &d, ctx); }
  };

  try
  {
    Adapter               f(callback, context);
    math_FunctionSample   sample(a, b, nbSamples);
    math_FunctionAllRoots allRoots(f, sample, epsX, epsF, epsNul);
    if (!allRoots.IsDone())
      return 0;
    int n     = allRoots.NbPoints();
    int count = std::min(n, (int)maxRoots);
    for (int i = 0; i < count; i++)
      roots[i] = allRoots.GetPoint(i + 1);
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTMathGaussLeastSquare(const double* _Nonnull matA,
                              int32_t nRows,
                              int32_t nCols,
                              const double* _Nonnull b,
                              double* _Nonnull x)
{
  try
  {
    math_Matrix A(1, nRows, 1, nCols);
    for (int i = 0; i < nRows; i++)
      for (int j = 0; j < nCols; j++)
        A(i + 1, j + 1) = matA[i * nCols + j];
    math_GaussLeastSquare gls(A);
    if (!gls.IsDone())
      return false;
    math_Vector bv(1, nRows);
    for (int i = 0; i < nRows; i++)
      bv(i + 1) = b[i];
    math_Vector xv(1, nCols);
    gls.Solve(bv, xv);
    for (int i = 0; i < nCols; i++)
      x[i] = xv(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTMathNewtonFunctionRoot(OCCTMathFuncDerivCallback _Nonnull callback,
                                  void* _Nullable context,
                                  double  guess,
                                  double  epsX,
                                  double  epsF,
                                  int32_t maxIter,
                                  bool* _Nonnull isDone,
                                  double* _Nonnull derivative,
                                  int32_t* _Nonnull nbIter)
{
  class Adapter : public math_FunctionWithDerivative
  {
    OCCTMathFuncDerivCallback cb;
    void*                     ctx;

  public:
    Adapter(OCCTMathFuncDerivCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override
    {
      double d;
      return cb(x, &f, &d, ctx);
    }

    bool Derivative(const double x, double& d) override
    {
      double f;
      return cb(x, &f, &d, ctx);
    }

    bool Values(const double x, double& f, double& d) override { return cb(x, &f, &d, ctx); }
  };

  try
  {
    Adapter                 f(callback, context);
    math_NewtonFunctionRoot nr(f, guess, epsX, epsF, maxIter);
    *isDone     = nr.IsDone();
    *derivative = nr.IsDone() ? nr.Derivative() : 0;
    *nbIter     = nr.IsDone() ? nr.NbIterations() : 0;
    return nr.IsDone() ? nr.Root() : 0;
  }
  catch (...)
  {
    *isDone     = false;
    *derivative = 0;
    *nbIter     = 0;
    return 0;
  }
}

double OCCTMathNewtonFunctionRootBounded(OCCTMathFuncDerivCallback _Nonnull callback,
                                         void* _Nullable context,
                                         double  guess,
                                         double  epsX,
                                         double  epsF,
                                         double  a,
                                         double  b,
                                         int32_t maxIter,
                                         bool* _Nonnull isDone)
{
  class Adapter : public math_FunctionWithDerivative
  {
    OCCTMathFuncDerivCallback cb;
    void*                     ctx;

  public:
    Adapter(OCCTMathFuncDerivCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override
    {
      double d;
      return cb(x, &f, &d, ctx);
    }

    bool Derivative(const double x, double& d) override
    {
      double f;
      return cb(x, &f, &d, ctx);
    }

    bool Values(const double x, double& f, double& d) override { return cb(x, &f, &d, ctx); }
  };

  try
  {
    Adapter                 f(callback, context);
    math_NewtonFunctionRoot nr(f, guess, epsX, epsF, a, b, maxIter);
    *isDone = nr.IsDone();
    return nr.IsDone() ? nr.Root() : 0;
  }
  catch (...)
  {
    *isDone = false;
    return 0;
  }
}

bool OCCTMathUzawa(const double* _Nonnull contData,
                   int32_t nConstraints,
                   int32_t nVars,
                   const double* _Nonnull secont,
                   const double* _Nonnull startPoint,
                   double  epsLix,
                   double  epsLic,
                   int32_t maxIter,
                   double* _Nonnull result,
                   int32_t* _Nonnull nbIter)
{
  try
  {
    math_Matrix Cont(1, nConstraints, 1, nVars);
    for (int i = 0; i < nConstraints; i++)
      for (int j = 0; j < nVars; j++)
        Cont(i + 1, j + 1) = contData[i * nVars + j];
    math_Vector Sec(1, nConstraints);
    for (int i = 0; i < nConstraints; i++)
      Sec(i + 1) = secont[i];
    math_Vector Start(1, nVars);
    for (int i = 0; i < nVars; i++)
      Start(i + 1) = startPoint[i];
    math_Uzawa uzawa(Cont, Sec, Start, epsLix, epsLic, maxIter);
    if (!uzawa.IsDone())
      return false;
    const math_Vector& v = uzawa.Value();
    for (int i = 0; i < nVars; i++)
      result[i] = v(i + 1);
    *nbIter = uzawa.NbIterations();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTMathEigenValues(const double* _Nonnull diagonal,
                            const double* _Nonnull subdiagonal,
                            int32_t n,
                            double* _Nonnull eigenvalues)
{
  try
  {
    NCollection_Array1<double> diag(1, n);
    NCollection_Array1<double> subdiag(1, n);
    for (int i = 0; i < n; i++)
    {
      diag(i + 1)    = diagonal[i];
      subdiag(i + 1) = subdiagonal[i];
    }
    math_EigenValuesSearcher evs(diag, subdiag);
    if (!evs.IsDone())
      return 0;
    int dim = evs.Dimension();
    for (int i = 0; i < dim; i++)
      eigenvalues[i] = evs.EigenValue(i + 1);
    return dim;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTMathEigenValuesAndVectors(const double* _Nonnull diagonal,
                                      const double* _Nonnull subdiagonal,
                                      int32_t n,
                                      double* _Nonnull eigenvalues,
                                      double* _Nonnull eigenvectors)
{
  try
  {
    NCollection_Array1<double> diag(1, n);
    NCollection_Array1<double> subdiag(1, n);
    for (int i = 0; i < n; i++)
    {
      diag(i + 1)    = diagonal[i];
      subdiag(i + 1) = subdiagonal[i];
    }
    math_EigenValuesSearcher evs(diag, subdiag);
    if (!evs.IsDone())
      return 0;
    int dim = evs.Dimension();
    for (int i = 0; i < dim; i++)
    {
      eigenvalues[i] = evs.EigenValue(i + 1);
      math_Vector ev = evs.EigenVector(i + 1);
      for (int j = 0; j < dim; j++)
        eigenvectors[i * dim + j] = ev(j + 1);
    }
    return dim;
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTMathKronrodIntegration(OCCTMathSimpleFuncCallback _Nonnull callback,
                                  void* _Nullable context,
                                  double  lower,
                                  double  upper,
                                  int32_t nbPoints,
                                  bool* _Nonnull isDone,
                                  double* _Nonnull errorReached)
{
  class Adapter : public math_Function
  {
    OCCTMathSimpleFuncCallback cb;
    void*                      ctx;

  public:
    Adapter(OCCTMathSimpleFuncCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override { return cb(x, &f, ctx); }
  };

  try
  {
    Adapter                       f(callback, context);
    math_KronrodSingleIntegration ksi(f, lower, upper, nbPoints);
    *isDone       = ksi.IsDone();
    *errorReached = ksi.IsDone() ? ksi.ErrorReached() : 0;
    return ksi.IsDone() ? ksi.Value() : 0;
  }
  catch (...)
  {
    *isDone       = false;
    *errorReached = 0;
    return 0;
  }
}

double OCCTMathKronrodIntegrationAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback,
                                          void* _Nullable context,
                                          double  lower,
                                          double  upper,
                                          int32_t nbPoints,
                                          double  tolerance,
                                          int32_t maxIter,
                                          bool* _Nonnull isDone,
                                          double* _Nonnull errorReached,
                                          int32_t* _Nonnull nbIterReached)
{
  class Adapter : public math_Function
  {
    OCCTMathSimpleFuncCallback cb;
    void*                      ctx;

  public:
    Adapter(OCCTMathSimpleFuncCallback c, void* x)
        : cb(c),
          ctx(x)
    {
    }

    bool Value(const double x, double& f) override { return cb(x, &f, ctx); }
  };

  try
  {
    Adapter                       f(callback, context);
    math_KronrodSingleIntegration ksi(f, lower, upper, nbPoints, tolerance, maxIter);
    *isDone        = ksi.IsDone();
    *errorReached  = ksi.IsDone() ? ksi.ErrorReached() : 0;
    *nbIterReached = ksi.IsDone() ? ksi.NbIterReached() : 0;
    return ksi.IsDone() ? ksi.Value() : 0;
  }
  catch (...)
  {
    *isDone        = false;
    *errorReached  = 0;
    *nbIterReached = 0;
    return 0;
  }
}

double OCCTMathGaussMultipleIntegration(OCCTMathMultiVarCallback _Nonnull callback,
                                        void* _Nullable context,
                                        int32_t nVars,
                                        const double* _Nonnull lower,
                                        const double* _Nonnull upper,
                                        const int32_t* _Nonnull order,
                                        bool* _Nonnull isDone)
{
  class Adapter : public math_MultipleVarFunction
  {
    OCCTMathMultiVarCallback cb;
    void*                    ctx;
    int                      n;

  public:
    Adapter(OCCTMathMultiVarCallback c, void* x, int nv)
        : cb(c),
          ctx(x),
          n(nv)
    {
    }

    int NbVariables() const override { return n; }

    bool Value(const math_Vector& X, double& F) override { return cb(&X(1), n, &F, ctx); }
  };

  try
  {
    Adapter            f(callback, context, nVars);
    math_Vector        lo(1, nVars), up(1, nVars);
    math_IntegerVector ord(1, nVars);
    for (int i = 0; i < nVars; i++)
    {
      lo(i + 1)  = lower[i];
      up(i + 1)  = upper[i];
      ord(i + 1) = order[i];
    }
    math_GaussMultipleIntegration gmi(f, lo, up, ord);
    *isDone = gmi.IsDone();
    return gmi.IsDone() ? gmi.Value() : 0;
  }
  catch (...)
  {
    *isDone = false;
    return 0;
  }
}

bool OCCTMathGaussSetIntegration(OCCTMathFuncSetCallback _Nonnull callback,
                                 void* _Nullable context,
                                 int32_t nVars,
                                 int32_t nEqs,
                                 const double* _Nonnull lower,
                                 const double* _Nonnull upper,
                                 const int32_t* _Nonnull order,
                                 double* _Nonnull result)
{
  class Adapter : public math_FunctionSet
  {
    OCCTMathFuncSetCallback cb;
    void*                   ctx;
    int                     nv, ne;

  public:
    Adapter(OCCTMathFuncSetCallback c, void* x, int v, int e)
        : cb(c),
          ctx(x),
          nv(v),
          ne(e)
    {
    }

    int NbVariables() const override { return nv; }

    int NbEquations() const override { return ne; }

    bool Value(const math_Vector& X, math_Vector& F) override
    {
      std::vector<double> vals(ne);
      bool                ok = cb(&X(1), nv, vals.data(), ne, ctx);
      for (int i = 0; i < ne; i++)
        F(i + 1) = vals[i];
      return ok;
    }
  };

  try
  {
    Adapter            f(callback, context, nVars, nEqs);
    math_Vector        lo(1, nVars), up(1, nVars);
    math_IntegerVector ord(1, nVars);
    for (int i = 0; i < nVars; i++)
    {
      lo(i + 1)  = lower[i];
      up(i + 1)  = upper[i];
      ord(i + 1) = order[i];
    }
    math_GaussSetIntegration gsi(f, lo, up, ord);
    if (!gsi.IsDone())
      return false;
    const math_Vector& v = gsi.Value();
    for (int i = 0; i < nEqs; i++)
      result[i] = v(i + 1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTMathPolyLinear(double a, double b, double* _Nonnull roots, int32_t maxRoots)
{
  try
  {
    auto result = MathPoly::Linear(a, b);
    if (!result.IsDone())
      return -1;
    int32_t n = (int32_t)result.NbRoots;
    for (int32_t i = 0; i < n && i < maxRoots; i++)
      roots[i] = result.Roots[i];
    return std::min(n, maxRoots);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTMathPolyQuadratic(double a,
                              double b,
                              double c,
                              double* _Nonnull roots,
                              int32_t maxRoots)
{
  try
  {
    auto result = MathPoly::Quadratic(a, b, c);
    if (!result.IsDone())
      return -1;
    int32_t n = (int32_t)result.NbRoots;
    for (int32_t i = 0; i < n && i < maxRoots; i++)
      roots[i] = result.Roots[i];
    return std::min(n, maxRoots);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTMathPolyCubic(double a,
                          double b,
                          double c,
                          double d,
                          double* _Nonnull roots,
                          int32_t maxRoots)
{
  try
  {
    auto result = MathPoly::Cubic(a, b, c, d);
    if (!result.IsDone())
      return -1;
    int32_t n = (int32_t)result.NbRoots;
    for (int32_t i = 0; i < n && i < maxRoots; i++)
      roots[i] = result.Roots[i];
    return std::min(n, maxRoots);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTMathPolyQuartic(double a,
                            double b,
                            double c,
                            double d,
                            double e,
                            double* _Nonnull roots,
                            int32_t maxRoots)
{
  try
  {
    auto result = MathPoly::Quartic(a, b, c, d, e);
    if (!result.IsDone())
      return -1;
    int32_t n = (int32_t)result.NbRoots;
    for (int32_t i = 0; i < n && i < maxRoots; i++)
      roots[i] = result.Roots[i];
    return std::min(n, maxRoots);
  }
  catch (...)
  {
    return -1;
  }
}

double OCCTMathIntegGauss(OCCTMathSimpleFuncCallback _Nonnull callback,
                          void* _Nullable context,
                          double  lower,
                          double  upper,
                          int32_t nbPoints,
                          bool* _Nonnull isDone,
                          double* _Nonnull error)
{
  try
  {
    MathIntegFuncAdapter f(callback, context);
    auto                 result = MathInteg::Gauss(f, lower, upper, nbPoints);
    *isDone                     = result.IsDone();
    *error                      = result.AbsoluteError ? *result.AbsoluteError : 0.0;
    return result.IsDone() && result.Value ? *result.Value : 0.0;
  }
  catch (...)
  {
    *isDone = false;
    *error  = 0.0;
    return 0.0;
  }
}

double OCCTMathIntegGaussAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback,
                                  void* _Nullable context,
                                  double  lower,
                                  double  upper,
                                  double  tolerance,
                                  int32_t maxIter,
                                  bool* _Nonnull isDone,
                                  double* _Nonnull error,
                                  int32_t* _Nonnull nbIter)
{
  try
  {
    MathIntegFuncAdapter   f(callback, context);
    MathUtils::IntegConfig config;
    config.Tolerance     = tolerance;
    config.MaxIterations = maxIter;
    auto result          = MathInteg::GaussAdaptive(f, lower, upper, config);
    *isDone              = result.IsDone();
    *error               = result.AbsoluteError ? *result.AbsoluteError : 0.0;
    *nbIter              = (int32_t)result.NbIterations;
    return result.IsDone() && result.Value ? *result.Value : 0.0;
  }
  catch (...)
  {
    *isDone = false;
    *error  = 0.0;
    *nbIter = 0;
    return 0.0;
  }
}

double OCCTMathIntegKronrod(OCCTMathSimpleFuncCallback _Nonnull callback,
                            void* _Nullable context,
                            double  lower,
                            double  upper,
                            int32_t nbGaussPoints,
                            bool* _Nonnull isDone,
                            double* _Nonnull error)
{
  try
  {
    MathIntegFuncAdapter f(callback, context);
    auto                 result = MathInteg::KronrodRule(f, lower, upper, nbGaussPoints);
    *isDone                     = result.IsDone();
    *error                      = result.AbsoluteError ? *result.AbsoluteError : 0.0;
    return result.IsDone() && result.Value ? *result.Value : 0.0;
  }
  catch (...)
  {
    *isDone = false;
    *error  = 0.0;
    return 0.0;
  }
}

double OCCTMathIntegKronrodAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback,
                                    void* _Nullable context,
                                    double  lower,
                                    double  upper,
                                    int32_t nbGaussPoints,
                                    double  tolerance,
                                    int32_t maxIter,
                                    bool* _Nonnull isDone,
                                    double* _Nonnull error,
                                    int32_t* _Nonnull nbIter)
{
  try
  {
    MathIntegFuncAdapter     f(callback, context);
    MathInteg::KronrodConfig config;
    config.NbGaussPoints = nbGaussPoints;
    config.Tolerance     = tolerance;
    config.MaxIterations = maxIter;
    config.Adaptive      = true;
    auto result          = MathInteg::Kronrod(f, lower, upper, config);
    *isDone              = result.IsDone();
    *error               = result.AbsoluteError ? *result.AbsoluteError : 0.0;
    *nbIter              = (int32_t)result.NbIterations;
    return result.IsDone() && result.Value ? *result.Value : 0.0;
  }
  catch (...)
  {
    *isDone = false;
    *error  = 0.0;
    *nbIter = 0;
    return 0.0;
  }
}

double OCCTMathIntegTanhSinh(OCCTMathSimpleFuncCallback _Nonnull callback,
                             void* _Nullable context,
                             double  lower,
                             double  upper,
                             double  tolerance,
                             int32_t maxLevels,
                             bool* _Nonnull isDone,
                             double* _Nonnull error,
                             int32_t* _Nonnull nbIter)
{
  try
  {
    MathIntegFuncAdapter       f(callback, context);
    MathInteg::DoubleExpConfig config;
    config.Tolerance = tolerance;
    config.NbLevels  = maxLevels;
    auto result      = MathInteg::TanhSinh(f, lower, upper, config);
    *isDone          = result.IsDone();
    *error           = result.AbsoluteError ? *result.AbsoluteError : 0.0;
    *nbIter          = (int32_t)result.NbIterations;
    return result.IsDone() && result.Value ? *result.Value : 0.0;
  }
  catch (...)
  {
    *isDone = false;
    *error  = 0.0;
    *nbIter = 0;
    return 0.0;
  }
}

// MARK: - v0.118: Polynomial→Poles + TrsfDisplacement/Transformation + gp_Pln/Lin distance/contains
bool OCCTConvertPolynomialToPoles(int32_t       dimension,
                                  int32_t       maxDegree,
                                  int32_t       degree,
                                  const double* coefficients,
                                  int32_t       coeffCount,
                                  double        polyStart,
                                  double        polyEnd,
                                  double        trueStart,
                                  double        trueEnd,
                                  double**      outPoles,
                                  int32_t*      outPoleCount,
                                  double**      outKnots,
                                  int32_t*      outKnotCount,
                                  int32_t*      outDegree)
{
  try
  {
    NCollection_Array1<double> coeff(1, coeffCount);
    for (int32_t i = 0; i < coeffCount; i++)
      coeff(i + 1) = coefficients[i];
    NCollection_Array1<double> polyIntervals(1, 2);
    polyIntervals(1) = polyStart;
    polyIntervals(2) = polyEnd;
    NCollection_Array1<double> trueIntervals(1, 2);
    trueIntervals(1) = trueStart;
    trueIntervals(2) = trueEnd;

    Convert_CompPolynomialToPoles converter(dimension,
                                            maxDegree,
                                            degree,
                                            coeff,
                                            polyIntervals,
                                            trueIntervals);
    if (!converter.IsDone())
      return false;

    int nbPoles   = converter.NbPoles();
    *outPoleCount = nbPoles;
    *outDegree    = converter.Degree();

    // Get poles (NCollection_Array2: [1..NbPoles][1..Dimension])
    const NCollection_Array2<double>& poles           = converter.Poles();
    int                               totalPoleValues = nbPoles * dimension;
    *outPoles = (double*)malloc(sizeof(double) * totalPoleValues);
    int idx   = 0;
    for (int i = poles.LowerRow(); i <= poles.UpperRow(); i++)
    {
      for (int j = poles.LowerCol(); j <= poles.UpperCol(); j++)
      {
        (*outPoles)[idx++] = poles(i, j);
      }
    }

    // Get knots
    const NCollection_Array1<double>& knots = converter.Knots();
    *outKnotCount                           = knots.Length();
    *outKnots                               = (double*)malloc(sizeof(double) * knots.Length());
    for (int i = 0; i < knots.Length(); i++)
      (*outKnots)[i] = knots(knots.Lower() + i);

    return true;
  }
  catch (...)
  {
    *outPoles     = nullptr;
    *outKnots     = nullptr;
    *outPoleCount = *outKnotCount = *outDegree = 0;
    return false;
  }
}

void OCCTTrsfTransformation(double  fromPx,
                            double  fromPy,
                            double  fromPz,
                            double  fromDx,
                            double  fromDy,
                            double  fromDz,
                            double  toPx,
                            double  toPy,
                            double  toPz,
                            double  toDx,
                            double  toDy,
                            double  toDz,
                            double* a11,
                            double* a12,
                            double* a13,
                            double* a14,
                            double* a21,
                            double* a22,
                            double* a23,
                            double* a24,
                            double* a31,
                            double* a32,
                            double* a33,
                            double* a34)
{
  try
  {
    gp_Ax3  from(gp_Pnt(fromPx, fromPy, fromPz), gp_Dir(fromDx, fromDy, fromDz));
    gp_Ax3  to(gp_Pnt(toPx, toPy, toPz), gp_Dir(toDx, toDy, toDz));
    gp_Trsf t;
    t.SetTransformation(from, to);
    *a11 = t.Value(1, 1);
    *a12 = t.Value(1, 2);
    *a13 = t.Value(1, 3);
    *a14 = t.Value(1, 4);
    *a21 = t.Value(2, 1);
    *a22 = t.Value(2, 2);
    *a23 = t.Value(2, 3);
    *a24 = t.Value(2, 4);
    *a31 = t.Value(3, 1);
    *a32 = t.Value(3, 2);
    *a33 = t.Value(3, 3);
    *a34 = t.Value(3, 4);
  }
  catch (...)
  {
    *a11 = 1;
    *a12 = 0;
    *a13 = 0;
    *a14 = 0;
    *a21 = 0;
    *a22 = 1;
    *a23 = 0;
    *a24 = 0;
    *a31 = 0;
    *a32 = 0;
    *a33 = 1;
    *a34 = 0;
  }
}

double OCCTPlaneDistanceToPoint(double ox,
                                double oy,
                                double oz,
                                double nx,
                                double ny,
                                double nz,
                                double px,
                                double py,
                                double pz)
{
  try
  {
    gp_Pln pln(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
    return pln.Distance(gp_Pnt(px, py, pz));
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTPlaneDistanceToLine(double ox,
                               double oy,
                               double oz,
                               double nx,
                               double ny,
                               double nz,
                               double lx,
                               double ly,
                               double lz,
                               double dx,
                               double dy,
                               double dz)
{
  try
  {
    gp_Pln pln(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
    gp_Lin lin(gp_Pnt(lx, ly, lz), gp_Dir(dx, dy, dz));
    return pln.Distance(lin);
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTPlaneContainsPoint(double ox,
                            double oy,
                            double oz,
                            double nx,
                            double ny,
                            double nz,
                            double px,
                            double py,
                            double pz,
                            double tolerance)
{
  try
  {
    gp_Pln pln(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
    return pln.Contains(gp_Pnt(px, py, pz), tolerance);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTLineDistanceToPoint(double lx,
                               double ly,
                               double lz,
                               double dx,
                               double dy,
                               double dz,
                               double px,
                               double py,
                               double pz)
{
  try
  {
    gp_Lin lin(gp_Pnt(lx, ly, lz), gp_Dir(dx, dy, dz));
    return lin.Distance(gp_Pnt(px, py, pz));
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTLineDistanceToLine(double l1x,
                              double l1y,
                              double l1z,
                              double d1x,
                              double d1y,
                              double d1z,
                              double l2x,
                              double l2y,
                              double l2z,
                              double d2x,
                              double d2y,
                              double d2z)
{
  try
  {
    gp_Lin lin1(gp_Pnt(l1x, l1y, l1z), gp_Dir(d1x, d1y, d1z));
    gp_Lin lin2(gp_Pnt(l2x, l2y, l2z), gp_Dir(d2x, d2y, d2z));
    return lin1.Distance(lin2);
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTLineContainsPoint(double lx,
                           double ly,
                           double lz,
                           double dx,
                           double dy,
                           double dz,
                           double px,
                           double py,
                           double pz,
                           double tolerance)
{
  try
  {
    gp_Lin lin(gp_Pnt(lx, ly, lz), gp_Dir(dx, dy, dz));
    return lin.Contains(gp_Pnt(px, py, pz), tolerance);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTVecCrossMagnitude(double v1x, double v1y, double v1z, double v2x, double v2y, double v2z)
{
  gp_Vec v1(v1x, v1y, v1z);
  gp_Vec v2(v2x, v2y, v2z);
  return v1.CrossMagnitude(v2);
}

double OCCTVecCrossSquareMagnitude(double v1x,
                                   double v1y,
                                   double v1z,
                                   double v2x,
                                   double v2y,
                                   double v2z)
{
  gp_Vec v1(v1x, v1y, v1z);
  gp_Vec v2(v2x, v2y, v2z);
  return v1.CrossSquareMagnitude(v2);
}

bool OCCTDirIsOpposite(double d1x,
                       double d1y,
                       double d1z,
                       double d2x,
                       double d2y,
                       double d2z,
                       double angularTolerance)
{
  try
  {
    gp_Dir d1(d1x, d1y, d1z);
    gp_Dir d2(d2x, d2y, d2z);
    return d1.IsOpposite(d2, angularTolerance);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDirIsNormal(double d1x,
                     double d1y,
                     double d1z,
                     double d2x,
                     double d2y,
                     double d2z,
                     double angularTolerance)
{
  try
  {
    gp_Dir d1(d1x, d1y, d1z);
    gp_Dir d2(d2x, d2y, d2z);
    return d1.IsNormal(d2, angularTolerance);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTShapeRaycast(OCCTShapeRef shape,
                         double       originX,
                         double       originY,
                         double       originZ,
                         double       dirX,
                         double       dirY,
                         double       dirZ,
                         double       tolerance,
                         OCCTRayHit*  outHits,
                         int32_t      maxHits)
{
  if (!shape || !outHits || maxHits <= 0)
    return -1;

  try
  {
    // Build face index map for looking up face indices
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

    // Create ray
    gp_Pnt origin(originX, originY, originZ);
    gp_Dir direction(dirX, dirY, dirZ);
    gp_Lin ray(origin, direction);

    // Perform intersection
    IntCurvesFace_ShapeIntersector intersector;
    intersector.Load(shape->shape, tolerance);
    intersector.Perform(ray, -1e10, 1e10); // Large range for ray

    int32_t hitCount = 0;
    int     nbPoints = intersector.NbPnt();

    for (int i = 1; i <= nbPoints && hitCount < maxHits; i++)
    {
      gp_Pnt pt    = intersector.Pnt(i);
      double param = intersector.WParameter(i);

      // Get face at this intersection
      TopoDS_Face hitFace   = intersector.Face(i);
      int         faceIndex = faceMap.FindIndex(hitFace) - 1; // Convert to 0-based

      // Get UV parameters
      double u = intersector.UParameter(i);
      double v = intersector.VParameter(i);

      // Get surface normal at intersection point.
      //
      // #529: this used to pass `tolerance` -- the caller's *intersection* tolerance, which
      // IntCurvesFace_ShapeIntersector::Load takes as a distance -- as the props Resolution,
      // which CSLib::Normal takes as a SINE tolerance on the angle between the two parametric
      // directions. A sine tolerance is dimensionless and saturates: measured on the pinned
      // kernel, raycast(tolerance: 1.0) reported every hit on a sphere as having no normal,
      // and at 5.0 a box's downward face came back pointing up, because the fallback below is
      // (0, 0, 1). The intersection tolerance now stops at Load, where it belongs.
      BRepAdaptor_Surface adaptor(hitFace);
      BRepLProp_SLProps   props = occtFaceLocalProps(adaptor, u, v, 1);

      OCCTRayHit& hit = outHits[hitCount];
      hit.point[0]    = pt.X();
      hit.point[1]    = pt.Y();
      hit.point[2]    = pt.Z();
      hit.distance    = param;
      hit.faceIndex   = faceIndex;
      hit.uv[0]       = u;
      hit.uv[1]       = v;

      // A hit on a genuinely singular point of a surface still has no normal, and the (0,0,1)
      // fallback is indistinguishable from a real upward normal, so say which one it is.
      if (props.IsNormalDefined())
      {
        gp_Dir normal = props.Normal();
        if (hitFace.Orientation() == TopAbs_REVERSED)
        {
          normal.Reverse();
        }
        hit.normal[0]     = normal.X();
        hit.normal[1]     = normal.Y();
        hit.normal[2]     = normal.Z();
        hit.normalDefined = true;
      }
      else
      {
        hit.normal[0]     = 0;
        hit.normal[1]     = 0;
        hit.normal[2]     = 1;
        hit.normalDefined = false;
      }

      hitCount++;
    }

    return hitCount;
  }
  catch (...)
  {
    return -1;
  }
}
