// Epic #766 kernel-parity probe: NewtonMinimumTests, NewtonRootTests, NonUniformScaleTests.
// Same OCCT calls and inputs as OCCTMathNewtonMinimum (math_NewtonMinimum(f, tol, maxIter)
// .Perform(f, start)), OCCTMathNewtonFunctionRoot (math_NewtonFunctionRoot(f, guess, epsX, epsF,
// maxIter)) and OCCTShapeNonUniformScale (gp_GTrsf vectorial part diag(sx, sy, sz) through
// BRepBuilderAPI_GTransform(shape, gtrsf, true)); size is read with BRepBndLib::Add and volume with
// BRepGProp::VolumeProperties.
#include <math_NewtonMinimum.hxx>
#include <math_MultipleVarFunctionWithHessian.hxx>
#include <math_NewtonFunctionRoot.hxx>
#include <math_FunctionWithDerivative.hxx>
#include <math_Vector.hxx>
#include <math_Matrix.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Bnd_Box.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Mat.hxx>
#include <cstdio>

struct H : math_MultipleVarFunctionWithHessian
{
  bool rosen;
  H(bool r)
      : rosen(r)
  {
  }
  int  NbVariables() const override { return 2; }
  bool Value(const math_Vector& X, double& F) override
  {
    double x = X(1), y = X(2);
    F = rosen ? (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x)
              : (x - 3) * (x - 3) + (y - 4) * (y - 4);
    return true;
  }
  bool Gradient(const math_Vector& X, math_Vector& G) override
  {
    double x = X(1), y = X(2);
    if (rosen)
    {
      G(1) = -2 * (1 - x) + 100 * 2 * (y - x * x) * (-2 * x);
      G(2) = 100 * 2 * (y - x * x);
    }
    else
    {
      G(1) = 2 * (x - 3);
      G(2) = 2 * (y - 4);
    }
    return true;
  }
  bool Values(const math_Vector& X, double& F, math_Vector& G) override
  {
    return Value(X, F) && Gradient(X, G);
  }
  bool Values(const math_Vector& X, double& F, math_Vector& G, math_Matrix& Hm) override
  {
    double x = X(1), y = X(2);
    if (rosen)
    {
      Hm(1, 1) = 2 + 100 * (12 * x * x - 4 * y);
      Hm(1, 2) = -400 * x;
      Hm(2, 1) = -400 * x;
      Hm(2, 2) = 200.0;
    }
    else
    {
      Hm(1, 1) = 2;
      Hm(1, 2) = 0;
      Hm(2, 1) = 0;
      Hm(2, 2) = 2;
    }
    return Values(X, F, G);
  }
};

struct Sq : math_FunctionWithDerivative
{
  bool Value(const double x, double& f) override
  {
    f = x * x - 4.0;
    return true;
  }
  bool Derivative(const double x, double& d) override
  {
    d = 2.0 * x;
    return true;
  }
  bool Values(const double x, double& f, double& d) override
  {
    return Value(x, f) && Derivative(x, d);
  }
};

static void newtonMin(const char* name, bool rosen, int maxIter)
{
  H                  f(rosen);
  math_NewtonMinimum n(f, 1e-8, maxIter);
  math_Vector        start(1, 2, 0.0);
  n.Perform(f, start);
  if (n.IsDone())
    printf("%s: done=1 x=%.17g %.17g min=%.17g\n", name, n.Location()(1), n.Location()(2), n.Minimum());
  else
    printf("%s: done=0\n", name);
}

static void scaled(const char* name, double sx, double sy, double sz)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  gp_GTrsf     g;
  g.SetVectorialPart(gp_Mat(sx, 0, 0, 0, sy, 0, 0, 0, sz));
  BRepBuilderAPI_GTransform b(box, g, true);
  Bnd_Box                   bb;
  BRepBndLib::Add(b.Shape(), bb, true);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  GProp_GProps p0, p1;
  BRepGProp::VolumeProperties(box, p0);
  BRepGProp::VolumeProperties(b.Shape(), p1);
  printf("%s: done=%d size(BRepBndLib::Add, with gap)=%.17g %.17g %.17g volume=%.17g ratio=%.17g\n",
         name,
         (int)b.IsDone(),
         x1 - x0,
         y1 - y0,
         z1 - z0,
         p1.Mass(),
         p1.Mass() / p0.Mass());
}

int main()
{
  newtonMin("NewtonMinimum minimizeQuadratic", false, 40);
  newtonMin("NewtonMinimum minimizeRosenbrock", true, 100);
  {
    Sq                      f;
    math_NewtonFunctionRoot nr(f, 3.0, 1e-10, 1e-10, 100);
    printf("NewtonRoot findRoot: done=%d root=%.17g\n", (int)nr.IsDone(), nr.Root());
  }
  scaled("scaleBox (2, 1, 0.5)", 2, 1, 0.5);
  scaled("volumeRatio (2, 3, 0.5)", 2, 3, 0.5);
  return 0;
}
