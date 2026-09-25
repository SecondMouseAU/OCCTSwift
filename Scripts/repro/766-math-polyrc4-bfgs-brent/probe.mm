// Epic #766 kernel-parity probe: MathPolyRc4Tests, MathSolverBFGSTests, MathSolverBrentTests.
// Same OCCT calls and inputs as OCCTMathPolyLinear/Quadratic/Cubic/Quartic (MathPoly::*),
// OCCTMathBFGS (math_BFGS(n, tol, maxIter, tol).Perform) and OCCTMathBrentMinimum
// (math_BrentMinimum(tol, maxIter, tol).Perform(f, ax, bx, cx)).
#include <MathPoly_Quadratic.hxx>
#include <MathPoly_Cubic.hxx>
#include <MathPoly_Quartic.hxx>
#include <math_BFGS.hxx>
#include <math_BrentMinimum.hxx>
#include <math_MultipleVarFunctionWithGradient.hxx>
#include <math_FunctionWithDerivative.hxx>
#include <math_Vector.hxx>
#include <cmath>
#include <cstdio>

static void poly(const char* name, const MathUtils::PolyResult& r)
{
  printf("%s: done=%d status=%d n=%zu", name, (int)r.IsDone(), (int)r.Status, r.NbRoots);
  for (size_t i = 0; i < r.NbRoots; i++)
    printf(" %.17g", r.Roots[i]);
  printf("\n");
}

struct Quad2 : math_MultipleVarFunctionWithGradient
{
  int  NbVariables() const override { return 2; }
  bool Value(const math_Vector& X, double& F) override
  {
    F = (X(1) - 3) * (X(1) - 3) + (X(2) - 4) * (X(2) - 4);
    return true;
  }
  bool Gradient(const math_Vector& X, math_Vector& G) override
  {
    G(1) = 2 * (X(1) - 3);
    G(2) = 2 * (X(2) - 4);
    return true;
  }
  bool Values(const math_Vector& X, double& F, math_Vector& G) override
  {
    return Value(X, F) && Gradient(X, G);
  }
};

struct Rosen : math_MultipleVarFunctionWithGradient
{
  int  NbVariables() const override { return 2; }
  bool Value(const math_Vector& X, double& F) override
  {
    double x = X(1), y = X(2);
    F        = (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x);
    return true;
  }
  bool Gradient(const math_Vector& X, math_Vector& G) override
  {
    double x = X(1), y = X(2);
    G(1)     = -2 * (1 - x) - 400 * x * (y - x * x);
    G(2)     = 200 * (y - x * x);
    return true;
  }
  bool Values(const math_Vector& X, double& F, math_Vector& G) override
  {
    return Value(X, F) && Gradient(X, G);
  }
};

struct F1 : math_FunctionWithDerivative
{
  int kind;
  F1(int k)
      : kind(k)
  {
  }
  bool Value(const double x, double& f) override
  {
    f = kind == 0 ? x * x - 4 : std::sin(x);
    return true;
  }
  bool Derivative(const double x, double& d) override
  {
    d = kind == 0 ? 2 * x : std::cos(x);
    return true;
  }
  bool Values(const double x, double& f, double& d) override
  {
    return Value(x, f) && Derivative(x, d);
  }
};

static void bfgs(const char* name, math_MultipleVarFunctionWithGradient& f, double tol, int maxIter)
{
  math_Vector start(1, 2, 0.0);
  math_BFGS   b(2, tol, maxIter, tol);
  b.Perform(f, start);
  if (b.IsDone())
    printf("%s: done=1 x=%.17g %.17g min=%.17g\n",
           name,
           b.Location()(1),
           b.Location()(2),
           b.Minimum());
  else
    printf("%s: done=0\n", name);
}

static void brent(const char* name, int kind, double ax, double bx, double cx)
{
  F1                f(kind);
  math_BrentMinimum b(1e-8, 100, 1e-8);
  b.Perform(f, ax, bx, cx);
  if (b.IsDone())
    printf("%s: done=1 location=%.17g minimum=%.17g\n", name, b.Location(), b.Minimum());
  else
    printf("%s: done=0\n", name);
}

int main()
{
  poly("linear", MathPoly::Linear(2, 4));
  poly("linearDegenerate", MathPoly::Linear(0, 0));
  poly("quadratic", MathPoly::Quadratic(1, -5, 6));
  poly("quadraticNoRealRoots", MathPoly::Quadratic(1, 0, 1));
  poly("cubic", MathPoly::Cubic(1, -6, 11, -6));
  poly("quartic", MathPoly::Quartic(1, -10, 35, -50, 24));
  Quad2 q;
  bfgs("BFGS minimizeQuadratic", q, 1e-8, 200);
  Rosen r;
  bfgs("BFGS minimizeRosenbrock", r, 1e-10, 1000);
  brent("Brent minimizeQuadratic", 0, -1.0, 1.0, 5.0);
  brent("Brent minimizeSine", 1, 3.0, 5.0, 6.0);
  return 0;
}
