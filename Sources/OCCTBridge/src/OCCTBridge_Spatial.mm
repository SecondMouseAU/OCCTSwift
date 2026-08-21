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
//  Public C surface unchanged. No symbol changes — pure file move.
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

#include <NCollection_KDTree.hxx>

struct OCCTKDTree
{
  NCollection_KDTree<gp_Pnt, 3> tree;
  std::vector<gp_Pnt>           points;
};

OCCTKDTreeRef OCCTKDTreeBuild(const double* coords, int32_t count)
{
  if (!coords || count <= 0)
    return nullptr;
  try
  {
    auto* kd = new OCCTKDTree();
    kd->points.resize(count);
    for (int32_t i = 0; i < count; i++)
    {
      kd->points[i] = gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]);
    }
    kd->tree.Build(kd->points.data(), (size_t)count);
    return kd;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTKDTreeRelease(OCCTKDTreeRef tree)
{
  delete tree;
}

int32_t OCCTKDTreeNearestPoint(OCCTKDTreeRef tree,
                               double        qx,
                               double        qy,
                               double        qz,
                               double*       outDistance)
{
  if (!tree || tree->tree.IsEmpty())
    return -1;
  try
  {
    gp_Pnt query(qx, qy, qz);
    double sqDist = 0;
    size_t idx    = tree->tree.NearestPoint(query, sqDist);
    if (outDistance)
      *outDistance = std::sqrt(sqDist);
    return (int32_t)(idx - 1); // OCCT uses 1-based → convert to 0-based
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTKDTreeKNearest(OCCTKDTreeRef tree,
                           double        qx,
                           double        qy,
                           double        qz,
                           int32_t       k,
                           int32_t*      outIndices,
                           double*       outSqDistances)
{
  if (!tree || !outIndices || k <= 0 || tree->tree.IsEmpty())
    return 0;
  try
  {
    gp_Pnt                     query(qx, qy, qz);
    NCollection_Array1<size_t> indices(1, k);
    NCollection_Array1<double> distances(1, k);
    size_t found = tree->tree.KNearestPoints(query, (size_t)k, indices, distances);

    int32_t n = (int32_t)found;
    for (int32_t i = 0; i < n; i++)
    {
      outIndices[i] = (int32_t)(indices.Value(i + 1) - 1); // 1-based → 0-based
    }
    if (outSqDistances)
    {
      for (int32_t i = 0; i < n; i++)
      {
        outSqDistances[i] = distances.Value(i + 1);
      }
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTKDTreeRangeSearch(OCCTKDTreeRef tree,
                              double        qx,
                              double        qy,
                              double        qz,
                              double        radius,
                              int32_t*      outIndices,
                              int32_t       maxResults)
{
  if (!tree || !outIndices || maxResults <= 0 || tree->tree.IsEmpty())
    return 0;
  try
  {
    gp_Pnt query(qx, qy, qz);
    auto   results = tree->tree.RangeSearch(query, radius);

    int32_t n = std::min((int32_t)results.Size(), maxResults);
    for (int32_t i = 0; i < n; i++)
    {
      outIndices[i] = (int32_t)(results[i] - 1); // 1-based → 0-based
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTKDTreeBoxSearch(OCCTKDTreeRef tree,
                            double        minX,
                            double        minY,
                            double        minZ,
                            double        maxX,
                            double        maxY,
                            double        maxZ,
                            int32_t*      outIndices,
                            int32_t       maxResults)
{
  if (!tree || !outIndices || maxResults <= 0 || tree->tree.IsEmpty())
    return 0;
  try
  {
    gp_Pnt minPt(minX, minY, minZ);
    gp_Pnt maxPt(maxX, maxY, maxZ);
    auto   results = tree->tree.BoxSearch(minPt, maxPt);

    int32_t n = std::min((int32_t)results.Size(), maxResults);
    for (int32_t i = 0; i < n; i++)
    {
      outIndices[i] = (int32_t)(results[i] - 1); // 1-based → 0-based
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Polynomial Solvers (v0.29.0)

#include <math_DirectPolynomialRoots.hxx>
#include <algorithm>

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

// MARK: - Intrv_Interval (v0.73)
// --- Intrv_Interval ---

struct OCCTIntrvInterval
{
  Intrv_Interval interval;
};

OCCTIntrvIntervalRef _Nonnull OCCTIntrvIntervalCreate(double start,
                                                      double end,
                                                      float  tolStart,
                                                      float  tolEnd)
{
  auto* ref     = new OCCTIntrvInterval();
  ref->interval = Intrv_Interval(start, tolStart, end, tolEnd);
  return ref;
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

// MARK: - Intrv_Intervals (v0.73)
// --- Intrv_Intervals ---

struct OCCTIntrvIntervals
{
  Intrv_Intervals intervals;
};

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

void OCCTIntrvIntervalsRelease(OCCTIntrvIntervalsRef _Nonnull intervals)
{
  delete intervals;
}

int32_t OCCTIntrvIntervalsCount(OCCTIntrvIntervalsRef _Nonnull intervals)
{
  return (int32_t)intervals->intervals.NbIntervals();
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

// MARK: - v0.92: Bnd_Range
// MARK: - Bnd_Range (v0.92.0)

#include <Bnd_Range.hxx>

struct OCCTRange
{
  Bnd_Range range;
};

OCCTRangeRef OCCTRangeCreate(double min, double max)
{
  auto* ref  = new OCCTRange();
  ref->range = Bnd_Range(min, max);
  return ref;
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

// MARK: - v0.94: math_Matrix/Gauss/SVD/DirectPolynomialRoots/Jacobi
// MARK: - math_Matrix (v0.94.0)

#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <math_Gauss.hxx>
#include <math_SVD.hxx>
#include <math_DirectPolynomialRoots.hxx>
#include <math_Jacobi.hxx>

struct OCCTMathMatrix
{
  math_Matrix mat;

  OCCTMathMatrix(int r, int c, double v)
      : mat(1, r, 1, c, v)
  {
  }
};

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

// MARK: - math_Gauss (v0.94.0)

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

// MARK: - math_SVD (v0.94.0)

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

// MARK: - math_DirectPolynomialRoots (v0.94.0)

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

// MARK: - math_Jacobi (v0.94.0)

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

// MARK: - v0.95: math_Householder/Crout
// MARK: - math_Householder (v0.95.0)

#include <math_Householder.hxx>

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

// MARK: - math_Crout (v0.95.0)

#include <math_Crout.hxx>

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

// MARK: - v0.97/v0.98: Precision + IntAna
// MARK: - Precision (v0.97.0)

#include <Precision.hxx>

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

// MARK: - IntAna (v0.98.0)

#include <IntAna_IntConicQuad.hxx>
#include <IntAna_QuadQuadGeo.hxx>
#include <IntAna_Int3Pln.hxx>
#include <IntAna_IntLinTorus.hxx>
#include <IntAna_Quadric.hxx>

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

// MARK: - v0.103/v0.104: Bnd_Sphere + BndLib Analytic + IntAna_IntQuadQuad
// MARK: - Bnd_Sphere (v0.103.0)

struct OCCTBndSphere
{
  Bnd_Sphere sphere;
};

OCCTBndSphereRef OCCTBndSphereCreate(double cx, double cy, double cz, double radius)
{
  auto s    = new OCCTBndSphere();
  s->sphere = Bnd_Sphere(gp_XYZ(cx, cy, cz), radius, 0, 0);
  s->sphere.SetValid(true);
  return s;
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

// MARK: - BndLib Analytic Bounding (v0.104.0)

#include <BndLib.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <BndLib_AddSurface.hxx>

void OCCTBndLibLine(double  px,
                    double  py,
                    double  pz,
                    double  dx,
                    double  dy,
                    double  dz,
                    double  p1,
                    double  p2,
                    double  tol,
                    double* xmin,
                    double* ymin,
                    double* zmin,
                    double* xmax,
                    double* ymax,
                    double* zmax)
{
  try
  {
    Bnd_Box box;
    gp_Lin  line(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
    BndLib::Add(line, p1, p2, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

void OCCTBndLibCircle(double  cx,
                      double  cy,
                      double  cz,
                      double  nx,
                      double  ny,
                      double  nz,
                      double  radius,
                      double  tol,
                      double* xmin,
                      double* ymin,
                      double* zmin,
                      double* xmax,
                      double* ymax,
                      double* zmax)
{
  try
  {
    Bnd_Box box;
    gp_Ax2  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Circ circ(ax, radius);
    BndLib::Add(circ, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

void OCCTBndLibSphere(double  cx,
                      double  cy,
                      double  cz,
                      double  radius,
                      double  tol,
                      double* xmin,
                      double* ymin,
                      double* zmin,
                      double* xmax,
                      double* ymax,
                      double* zmax)
{
  try
  {
    Bnd_Box   box;
    gp_Sphere sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
    BndLib::Add(sphere, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

void OCCTBndLibCylinder(double  cx,
                        double  cy,
                        double  cz,
                        double  nx,
                        double  ny,
                        double  nz,
                        double  radius,
                        double  vmin,
                        double  vmax,
                        double  tol,
                        double* xmin,
                        double* ymin,
                        double* zmin,
                        double* xmax,
                        double* ymax,
                        double* zmax)
{
  try
  {
    Bnd_Box     box;
    gp_Cylinder cyl(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
    BndLib::Add(cyl, vmin, vmax, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

void OCCTBndLibTorus(double  cx,
                     double  cy,
                     double  cz,
                     double  nx,
                     double  ny,
                     double  nz,
                     double  majorRadius,
                     double  minorRadius,
                     double  tol,
                     double* xmin,
                     double* ymin,
                     double* zmin,
                     double* xmax,
                     double* ymax,
                     double* zmax)
{
  try
  {
    Bnd_Box  box;
    gp_Torus torus(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
    BndLib::Add(torus, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

void OCCTBndLibEdge(OCCTShapeRef shape,
                    double       tol,
                    double*      xmin,
                    double*      ymin,
                    double*      zmin,
                    double*      xmax,
                    double*      ymax,
                    double*      zmax)
{
  if (!occtShapeIsPresent(shape))
  {
    // The same zeroed outputs the catch below already writes; nothing invented here.
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
    return;
  }
  try
  {
    Bnd_Box           box;
    BRepAdaptor_Curve ac(TopoDS::Edge(shape->shape));
    BndLib_Add3dCurve::Add(ac, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

void OCCTBndLibFace(OCCTShapeRef shape,
                    double       tol,
                    double*      xmin,
                    double*      ymin,
                    double*      zmin,
                    double*      xmax,
                    double*      ymax,
                    double*      zmax)
{
  try
  {
    Bnd_Box             box;
    BRepAdaptor_Surface as(TopoDS::Face(shape->shape));
    BndLib_AddSurface::Add(as, tol, box);
    box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
  }
  catch (...)
  {
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
  }
}

// MARK: - IntAna_IntQuadQuad (v0.104.0)

#include <IntAna_IntQuadQuad.hxx>
#include <IntAna_Quadric.hxx>

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

// MARK: - v0.105: BndLib extras + IntAna extensions
// MARK: - BndLib extras (v0.105.0)

#include <BndLib.hxx>
#include <Bnd_Box.hxx>

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

void OCCTBndLibEllipse(double  cx,
                       double  cy,
                       double  cz,
                       double  nx,
                       double  ny,
                       double  nz,
                       double  xdx,
                       double  xdy,
                       double  xdz,
                       double  major,
                       double  minor,
                       double  tol,
                       double* bounds6)
{
  try
  {
    gp_Ax2   ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
    gp_Elips elips(ax, major, minor);
    Bnd_Box  box;
    BndLib::Add(elips, tol, box);
    fillBounds6(box, bounds6);
  }
  catch (...)
  {
    for (int i = 0; i < 6; i++)
      bounds6[i] = 0;
  }
}

void OCCTBndLibCone(double  cx,
                    double  cy,
                    double  cz,
                    double  nx,
                    double  ny,
                    double  nz,
                    double  semiAngle,
                    double  refRadius,
                    double  vmin,
                    double  vmax,
                    double  tol,
                    double* bounds6)
{
  try
  {
    gp_Ax3  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Cone cone(ax, semiAngle, refRadius);
    Bnd_Box box;
    BndLib::Add(cone, vmin, vmax, tol, box);
    fillBounds6(box, bounds6);
  }
  catch (...)
  {
    for (int i = 0; i < 6; i++)
      bounds6[i] = 0;
  }
}

void OCCTBndLibCircleArc(double  cx,
                         double  cy,
                         double  cz,
                         double  nx,
                         double  ny,
                         double  nz,
                         double  radius,
                         double  u1,
                         double  u2,
                         double  tol,
                         double* bounds6)
{
  try
  {
    gp_Ax2  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Circ circ(ax, radius);
    Bnd_Box box;
    BndLib::Add(circ, u1, u2, tol, box);
    fillBounds6(box, bounds6);
  }
  catch (...)
  {
    for (int i = 0; i < 6; i++)
      bounds6[i] = 0;
  }
}

void OCCTBndLibEllipseArc(double  cx,
                          double  cy,
                          double  cz,
                          double  nx,
                          double  ny,
                          double  nz,
                          double  xdx,
                          double  xdy,
                          double  xdz,
                          double  major,
                          double  minor,
                          double  u1,
                          double  u2,
                          double  tol,
                          double* bounds6)
{
  try
  {
    gp_Ax2   ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
    gp_Elips elips(ax, major, minor);
    Bnd_Box  box;
    BndLib::Add(elips, u1, u2, tol, box);
    fillBounds6(box, bounds6);
  }
  catch (...)
  {
    for (int i = 0; i < 6; i++)
      bounds6[i] = 0;
  }
}

void OCCTBndLibParabolaArc(double  cx,
                           double  cy,
                           double  cz,
                           double  nx,
                           double  ny,
                           double  nz,
                           double  xdx,
                           double  xdy,
                           double  xdz,
                           double  focal,
                           double  u1,
                           double  u2,
                           double  tol,
                           double* bounds6)
{
  try
  {
    gp_Ax2   ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
    gp_Parab parab(ax, focal);
    Bnd_Box  box;
    BndLib::Add(parab, u1, u2, tol, box);
    fillBounds6(box, bounds6);
  }
  catch (...)
  {
    for (int i = 0; i < 6; i++)
      bounds6[i] = 0;
  }
}

void OCCTBndLibHyperbolaArc(double  cx,
                            double  cy,
                            double  cz,
                            double  nx,
                            double  ny,
                            double  nz,
                            double  xdx,
                            double  xdy,
                            double  xdz,
                            double  major,
                            double  minor,
                            double  u1,
                            double  u2,
                            double  tol,
                            double* bounds6)
{
  try
  {
    gp_Ax2  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
    gp_Hypr hypr(ax, major, minor);
    Bnd_Box box;
    BndLib::Add(hypr, u1, u2, tol, box);
    fillBounds6(box, bounds6);
  }
  catch (...)
  {
    for (int i = 0; i < 6; i++)
      bounds6[i] = 0;
  }
}

// MARK: - IntAna extensions (v0.105.0)

#include <IntAna_Curve.hxx>

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

// MARK: - v0.109-v0.111: math_TrigonometricFunctionRoots + Math Solver Adapters +
// math_FunctionRoot/SetRoot/BFGS/Powell/Brent + math_PSO + GlobOptMin + FunctionRoots +
// GaussSingleIntegration + NewtonFunctionSetRoot + MathPoly_Laguerre + math_NewtonMinimum MARK: -
// math_TrigonometricFunctionRoots (v0.109.0)

#include <math_TrigonometricFunctionRoots.hxx>

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

// MARK: - Math Solver Callback Adapters (v0.110.0)

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

// MARK: - math_FunctionRoot (v0.110.0)

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

// MARK: - math_FunctionSetRoot (v0.110.0)

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

// MARK: - math_BFGS (v0.110.0)

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

// MARK: - math_Powell (v0.110.0)

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

// MARK: - math_BrentMinimum (v0.110.0)

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

// MARK: - math_PSO (v0.111.0)

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
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <MathPoly_Laguerre.hxx>

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

// MARK: - math_GlobOptMin (v0.111.0)

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

// MARK: - math_FunctionRoots (v0.111.0)

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

// MARK: - math_GaussSingleIntegration (v0.111.0)

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

// MARK: - math_NewtonFunctionSetRoot (v0.111.0)

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

// MARK: - MathPoly_Laguerre (v0.111.0)

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

// MARK: - math_NewtonMinimum (v0.111.1)

#include <math_NewtonMinimum.hxx>
#include <math_MultipleVarFunctionWithHessian.hxx>

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

// MARK: - v0.112: Intf_Tool
// --- Intf_Tool ---

struct OCCTIntfTool
{
  Intf_Tool tool;
  int       nbSeg;

  OCCTIntfTool()
      : nbSeg(0)
  {
  }
};

OCCTIntfToolRef OCCTIntfToolCreate(void)
{
  return new OCCTIntfTool();
}

void OCCTIntfToolRelease(OCCTIntfToolRef tool)
{
  delete tool;
}

int32_t OCCTIntfToolLinBox(OCCTIntfToolRef tool,
                           double          px,
                           double          py,
                           double          pz,
                           double          dx,
                           double          dy,
                           double          dz,
                           double          xmin,
                           double          ymin,
                           double          zmin,
                           double          xmax,
                           double          ymax,
                           double          zmax)
{
  if (!tool)
    return 0;
  try
  {
    gp_Lin  line(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
    Bnd_Box box;
    box.Update(xmin, ymin, zmin, xmax, ymax, zmax);
    Bnd_Box lineBox;
    tool->tool.LinBox(line, box, lineBox);
    tool->nbSeg = tool->tool.NbSegments();
    return tool->nbSeg;
  }
  catch (...)
  {
    return 0;
  }
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

// math_BracketedRoot

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

// math_BracketMinimum

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

// math_FRPR

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

// math_FunctionAllRoots

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

// math_GaussLeastSquare

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

// math_NewtonFunctionRoot

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

// math_Uzawa

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

// math_EigenValuesSearcher

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

// math_KronrodSingleIntegration

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

// math_GaussMultipleIntegration

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

// math_GaussSetIntegration

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

// end of v0.116.0 implementations

// ============================================================================
// v0.117.0 implementations
// ============================================================================

// MathPoly rc4 polynomial solvers

#include <MathPoly_Quadratic.hxx>
#include <MathPoly_Cubic.hxx>
#include <MathPoly_Quartic.hxx>

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

// MathInteg rc4 integration

#include <MathInteg_Gauss.hxx>
#include <MathInteg_Kronrod.hxx>
#include <MathInteg_DoubleExp.hxx>

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

// UnitsMethods

#include <UnitsMethods.hxx>

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

// === TopExp extras ===
// --- gp_Pln distance/contains ---

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

// --- gp_Lin distance/contains ---

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

// MARK: - v0.120: gp_Vec extras + gp_Dir extras
// --- gp_Vec extras ---

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

// --- gp_Dir extras ---

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

// MARK: - Ray Casting Implementation (Issue #12)

#include <IntCurvesFace_ShapeIntersector.hxx>
#include <gp_Lin.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopExp.hxx>

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
