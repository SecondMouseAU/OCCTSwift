//
//  OCCTBridge_Spatial_GeometryUtils.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Spatial.mm (#1380): Ax3 utilities, Quaternion SLerp/NLerp, Trsf
//  interpolation/displacement, XY/XYZ utils, Polynomial-to-poles, gp_Pln/Lin distance/contains,
//  gp_Vec/gp_Dir extras, Precision. Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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

// MARK: - v0.116: Ax3 utilities + Quaternion SLerp/NLerp + Trsf interpolation + XY/XYZ utils +
// math_BracketedRoot/BracketMinimum/FRPR/FunctionAllRoots/GaussLeastSquare/NewtonFunctionRoot/Uzawa/EigenValues/KronrodIntegration/GaussMultipleIntegration/GaussSetIntegration/Poly*
// / Integ*
void OCCTAx3Create(double px,
                   double py,
                   double pz,
                   double nx,
                   double ny,
                   double nz,
                   double xDirX,
                   double xDirY,
                   double xDirZ,
                   bool* _Nonnull isDirect,
                   double* _Nonnull xDx,
                   double* _Nonnull xDy,
                   double* _Nonnull xDz,
                   double* _Nonnull yDx,
                   double* _Nonnull yDy,
                   double* _Nonnull yDz)
{
  try
  {
    gp_Ax3 ax3(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz), gp_Dir(xDirX, xDirY, xDirZ));
    *isDirect        = ax3.Direct();
    const gp_Dir& xd = ax3.XDirection();
    *xDx             = xd.X();
    *xDy             = xd.Y();
    *xDz             = xd.Z();
    const gp_Dir& yd = ax3.YDirection();
    *yDx             = yd.X();
    *yDy             = yd.Y();
    *yDz             = yd.Z();
  }
  catch (...)
  {
  }
}

void OCCTAx3CreateFromNormal(double px,
                             double py,
                             double pz,
                             double nx,
                             double ny,
                             double nz,
                             bool* _Nonnull isDirect,
                             double* _Nonnull xDx,
                             double* _Nonnull xDy,
                             double* _Nonnull xDz,
                             double* _Nonnull yDx,
                             double* _Nonnull yDy,
                             double* _Nonnull yDz)
{
  try
  {
    gp_Ax3 ax3(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
    *isDirect        = ax3.Direct();
    const gp_Dir& xd = ax3.XDirection();
    *xDx             = xd.X();
    *xDy             = xd.Y();
    *xDz             = xd.Z();
    const gp_Dir& yd = ax3.YDirection();
    *yDx             = yd.X();
    *yDy             = yd.Y();
    *yDz             = yd.Z();
  }
  catch (...)
  {
  }
}

double OCCTAx3Angle(double p1x,
                    double p1y,
                    double p1z,
                    double n1x,
                    double n1y,
                    double n1z,
                    double x1x,
                    double x1y,
                    double x1z,
                    double p2x,
                    double p2y,
                    double p2z,
                    double n2x,
                    double n2y,
                    double n2z,
                    double x2x,
                    double x2y,
                    double x2z)
{
  try
  {
    gp_Ax3 a1(gp_Pnt(p1x, p1y, p1z), gp_Dir(n1x, n1y, n1z), gp_Dir(x1x, x1y, x1z));
    gp_Ax3 a2(gp_Pnt(p2x, p2y, p2z), gp_Dir(n2x, n2y, n2z), gp_Dir(x2x, x2y, x2z));
    return a1.Angle(a2);
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTAx3IsCoplanar(double p1x,
                       double p1y,
                       double p1z,
                       double n1x,
                       double n1y,
                       double n1z,
                       double x1x,
                       double x1y,
                       double x1z,
                       double p2x,
                       double p2y,
                       double p2z,
                       double n2x,
                       double n2y,
                       double n2z,
                       double x2x,
                       double x2y,
                       double x2z,
                       double linearTol,
                       double angularTol)
{
  try
  {
    gp_Ax3 a1(gp_Pnt(p1x, p1y, p1z), gp_Dir(n1x, n1y, n1z), gp_Dir(x1x, x1y, x1z));
    gp_Ax3 a2(gp_Pnt(p2x, p2y, p2z), gp_Dir(n2x, n2y, n2z), gp_Dir(x2x, x2y, x2z));
    return a1.IsCoplanar(a2, linearTol, angularTol);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTAx3MirrorPoint(double px,
                        double py,
                        double pz,
                        double nx,
                        double ny,
                        double nz,
                        double xDx,
                        double xDy,
                        double xDz,
                        double mx,
                        double my,
                        double mz,
                        double* _Nonnull rpx,
                        double* _Nonnull rpy,
                        double* _Nonnull rpz,
                        double* _Nonnull rnx,
                        double* _Nonnull rny,
                        double* _Nonnull rnz,
                        double* _Nonnull rxDx,
                        double* _Nonnull rxDy,
                        double* _Nonnull rxDz)
{
  try
  {
    gp_Ax3 ax3(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz), gp_Dir(xDx, xDy, xDz));
    gp_Ax3 r = ax3.Mirrored(gp_Pnt(mx, my, mz));
    *rpx     = r.Location().X();
    *rpy     = r.Location().Y();
    *rpz     = r.Location().Z();
    *rnx     = r.Direction().X();
    *rny     = r.Direction().Y();
    *rnz     = r.Direction().Z();
    *rxDx    = r.XDirection().X();
    *rxDy    = r.XDirection().Y();
    *rxDz    = r.XDirection().Z();
  }
  catch (...)
  {
  }
}

void OCCTAx3Rotate(double px,
                   double py,
                   double pz,
                   double nx,
                   double ny,
                   double nz,
                   double xDx,
                   double xDy,
                   double xDz,
                   double axPx,
                   double axPy,
                   double axPz,
                   double axDx,
                   double axDy,
                   double axDz,
                   double angle,
                   double* _Nonnull rpx,
                   double* _Nonnull rpy,
                   double* _Nonnull rpz,
                   double* _Nonnull rnx,
                   double* _Nonnull rny,
                   double* _Nonnull rnz,
                   double* _Nonnull rxDx,
                   double* _Nonnull rxDy,
                   double* _Nonnull rxDz)
{
  try
  {
    gp_Ax3 ax3(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz), gp_Dir(xDx, xDy, xDz));
    gp_Ax3 r = ax3.Rotated(gp_Ax1(gp_Pnt(axPx, axPy, axPz), gp_Dir(axDx, axDy, axDz)), angle);
    *rpx     = r.Location().X();
    *rpy     = r.Location().Y();
    *rpz     = r.Location().Z();
    *rnx     = r.Direction().X();
    *rny     = r.Direction().Y();
    *rnz     = r.Direction().Z();
    *rxDx    = r.XDirection().X();
    *rxDy    = r.XDirection().Y();
    *rxDz    = r.XDirection().Z();
  }
  catch (...)
  {
  }
}

void OCCTAx3Translate(double px,
                      double py,
                      double pz,
                      double nx,
                      double ny,
                      double nz,
                      double xDx,
                      double xDy,
                      double xDz,
                      double vx,
                      double vy,
                      double vz,
                      double* _Nonnull rpx,
                      double* _Nonnull rpy,
                      double* _Nonnull rpz)
{
  try
  {
    gp_Ax3 ax3(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz), gp_Dir(xDx, xDy, xDz));
    gp_Ax3 r = ax3.Translated(gp_Vec(vx, vy, vz));
    *rpx     = r.Location().X();
    *rpy     = r.Location().Y();
    *rpz     = r.Location().Z();
  }
  catch (...)
  {
  }
}

// gp_GTrsf2d
void OCCTQuaternionSLerp(double x1,
                         double y1,
                         double z1,
                         double w1,
                         double x2,
                         double y2,
                         double z2,
                         double w2,
                         double t,
                         double* _Nonnull rx,
                         double* _Nonnull ry,
                         double* _Nonnull rz,
                         double* _Nonnull rw)
{
  gp_Quaternion q1(x1, y1, z1, w1), q2(x2, y2, z2, w2);
  gp_Quaternion r = gp_QuaternionSLerp::Interpolate(q1, q2, t);
  *rx             = r.X();
  *ry             = r.Y();
  *rz             = r.Z();
  *rw             = r.W();
}

void OCCTQuaternionNLerp(double x1,
                         double y1,
                         double z1,
                         double w1,
                         double x2,
                         double y2,
                         double z2,
                         double w2,
                         double t,
                         double* _Nonnull rx,
                         double* _Nonnull ry,
                         double* _Nonnull rz,
                         double* _Nonnull rw)
{
  gp_Quaternion q1(x1, y1, z1, w1), q2(x2, y2, z2, w2);
  gp_Quaternion r = gp_QuaternionNLerp::Interpolate(q1, q2, t);
  r.Normalize();
  *rx = r.X();
  *ry = r.Y();
  *rz = r.Z();
  *rw = r.W();
}

void OCCTTrsfInterpolate(double tx1,
                         double ty1,
                         double tz1,
                         double qx1,
                         double qy1,
                         double qz1,
                         double qw1,
                         double tx2,
                         double ty2,
                         double tz2,
                         double qx2,
                         double qy2,
                         double qz2,
                         double qw2,
                         double t,
                         double* _Nonnull rtx,
                         double* _Nonnull rty,
                         double* _Nonnull rtz,
                         double* _Nonnull rqx,
                         double* _Nonnull rqy,
                         double* _Nonnull rqz,
                         double* _Nonnull rqw)
{
  try
  {
    gp_Trsf t1, t2;
    t1.SetTranslation(gp_Vec(tx1, ty1, tz1));
    gp_Quaternion q1(qx1, qy1, qz1, qw1);
    gp_Mat        m1 = q1.GetMatrix();
    gp_Trsf       tr1;
    tr1.SetValues(m1(1, 1),
                  m1(1, 2),
                  m1(1, 3),
                  tx1,
                  m1(2, 1),
                  m1(2, 2),
                  m1(2, 3),
                  ty1,
                  m1(3, 1),
                  m1(3, 2),
                  m1(3, 3),
                  tz1);

    gp_Quaternion q2(qx2, qy2, qz2, qw2);
    gp_Mat        m2 = q2.GetMatrix();
    gp_Trsf       tr2;
    tr2.SetValues(m2(1, 1),
                  m2(1, 2),
                  m2(1, 3),
                  tx2,
                  m2(2, 1),
                  m2(2, 2),
                  m2(2, 3),
                  ty2,
                  m2(3, 1),
                  m2(3, 2),
                  m2(3, 3),
                  tz2);

    NCollection_Lerp<gp_Trsf> lerp(tr1, tr2);
    gp_Trsf                   result;
    lerp.Interpolate(t, result);
    gp_XYZ trans     = result.TranslationPart();
    *rtx             = trans.X();
    *rty             = trans.Y();
    *rtz             = trans.Z();
    gp_Quaternion rq = result.GetRotation();
    *rqx             = rq.X();
    *rqy             = rq.Y();
    *rqz             = rq.Z();
    *rqw             = rq.W();
  }
  catch (...)
  {
    *rtx = *rty = *rtz = 0;
    *rqx = *rqy = *rqz = 0;
    *rqw               = 1;
  }
}

double OCCTXYZModulus(double x, double y, double z)
{
  return gp_XYZ(x, y, z).Modulus();
}

void OCCTXYZCrossed(double x1,
                    double y1,
                    double z1,
                    double x2,
                    double y2,
                    double z2,
                    double* _Nonnull rx,
                    double* _Nonnull ry,
                    double* _Nonnull rz)
{
  gp_XYZ r = gp_XYZ(x1, y1, z1).Crossed(gp_XYZ(x2, y2, z2));
  *rx      = r.X();
  *ry      = r.Y();
  *rz      = r.Z();
}

double OCCTXYZDot(double x1, double y1, double z1, double x2, double y2, double z2)
{
  return gp_XYZ(x1, y1, z1).Dot(gp_XYZ(x2, y2, z2));
}

double OCCTXYZDotCross(double ax,
                       double ay,
                       double az,
                       double bx,
                       double by,
                       double bz,
                       double cx,
                       double cy,
                       double cz)
{
  return gp_XYZ(ax, ay, az).DotCross(gp_XYZ(bx, by, bz), gp_XYZ(cx, cy, cz));
}

bool OCCTXYZNormalize(double x,
                      double y,
                      double z,
                      double* _Nonnull rx,
                      double* _Nonnull ry,
                      double* _Nonnull rz)
{
  try
  {
    gp_XYZ v(x, y, z);
    gp_XYZ n = v.Normalized();
    *rx      = n.X();
    *ry      = n.Y();
    *rz      = n.Z();
    return true;
  }
  catch (...)
  {
    *rx = *ry = *rz = 0;
    return false;
  }
}

// === gp_Trsf extras ===
void OCCTTrsfDisplacement(double  fromPx,
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
    t.SetDisplacement(from, to);
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
