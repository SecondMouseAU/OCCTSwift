//
//  OCCTBridge_Spatial_Bounding.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Spatial.mm (#1380): Bnd_Range/Sphere, BndLib (analytic bounding + extras).
//  Public C surface unchanged; every sibling file imports the same headers this one does
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

OCCTRangeRef OCCTRangeCreate(double min, double max)
{
  auto* ref  = new OCCTRange();
  ref->range = Bnd_Range(min, max);
  return ref;
}

OCCTBndSphereRef OCCTBndSphereCreate(double cx, double cy, double cz, double radius)
{
  auto s    = new OCCTBndSphere();
  s->sphere = Bnd_Sphere(gp_XYZ(cx, cy, cz), radius, 0, 0);
  s->sphere.SetValid(true);
  return s;
}

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
  if (!occtShapeIsPresent(shape))
  {
    // The same zeroed outputs the catch below already writes; nothing invented here.
    *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0;
    return;
  }
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
