// Epic #766 kernel-parity probe: MathSolverGlobOptMinTests, MathSolverNewtonSystemTests,
// MathSolverPowellTests, MathSolverPSOTests, MathSolverSystemTests, MathSVDTests.
// Same OCCT calls and inputs as OCCTMathGlobOptMin (math_GlobOptMin(&f, lo, hi).Perform,
// Points(1), GetF), OCCTMathNewtonFuncSetRoot (math_NewtonFunctionSetRoot(sys, tolVec, tol,
// maxIter).Perform), OCCTMathPowell (math_Powell(f, tol, maxIter).Perform(f, start, identity)),
// OCCTMathPSO (math_PSO(&f, lo, hi, steps, particles, iter).Perform(steps, val, res)),
// OCCTMathFunctionSetRoot (math_FunctionSetRoot(sys, tolVec, maxIter).Perform) and
// OCCTMathSVDSolve (math_SVD(A).Solve(B, X)).
#include <math_GlobOptMin.hxx>
#include <math_NewtonFunctionSetRoot.hxx>
#include <math_FunctionSetRoot.hxx>
#include <math_FunctionSetWithDerivatives.hxx>
#include <math_MultipleVarFunction.hxx>
#include <math_Powell.hxx>
#include <math_PSO.hxx>
#include <math_SVD.hxx>
#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <cstdio>

struct Bowl : math_MultipleVarFunction
{
  int  NbVariables() const override { return 2; }
  bool Value(const math_Vector& X, double& F) override
  {
    F = (X(1) - 3) * (X(1) - 3) + (X(2) - 4) * (X(2) - 4);
    return true;
  }
};

struct Bowl1D : math_MultipleVarFunction
{
  int  NbVariables() const override { return 1; }
  bool Value(const math_Vector& X, double& F) override
  {
    F = (X(1) - 2) * (X(1) - 2) + 1;
    return true;
  }
};

struct Rosen : math_MultipleVarFunction
{
  int  NbVariables() const override { return 2; }
  bool Value(const math_Vector& X, double& F) override
  {
    double x = X(1), y = X(2);
    F        = (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x);
    return true;
  }
};

// kind 0: x^2 + y^2 - 25, x - y - 1. kind 1: 2x + y - 5, x - y - 1.
struct Sys : math_FunctionSetWithDerivatives
{
  int kind;
  Sys(int k)
      : kind(k)
  {
  }
  int  NbVariables() const override { return 2; }
  int  NbEquations() const override { return 2; }
  bool Value(const math_Vector& X, math_Vector& F) override
  {
    if (kind == 0)
    {
      F(1) = X(1) * X(1) + X(2) * X(2) - 25;
      F(2) = X(1) - X(2) - 1;
    }
    else
    {
      F(1) = 2 * X(1) + X(2) - 5;
      F(2) = X(1) - X(2) - 1;
    }
    return true;
  }
  bool Derivatives(const math_Vector& X, math_Matrix& D) override
  {
    if (kind == 0)
    {
      D(1, 1) = 2 * X(1);
      D(1, 2) = 2 * X(2);
    }
    else
    {
      D(1, 1) = 2;
      D(1, 2) = 1;
    }
    D(2, 1) = 1;
    D(2, 2) = -1;
    return true;
  }
  bool Values(const math_Vector& X, math_Vector& F, math_Matrix& D) override
  {
    return Value(X, F) && Derivatives(X, D);
  }
};

static void globopt(const char* name, math_MultipleVarFunction& f, int n, double lo, double hi)
{
  math_Vector     l(1, n, lo), h(1, n, hi);
  math_GlobOptMin g(&f, l, h);
  g.Perform();
  printf("%s: done=%d nbExtrema=%d", name, (int)g.isDone(), g.NbExtrema());
  if (g.isDone() && g.NbExtrema() > 0)
  {
    math_Vector s(1, n);
    g.Points(1, s);
    printf(" point=");
    for (int i = 1; i <= n; i++)
      printf(" %.17g", s(i));
    printf(" F=%.17g", g.GetF());
  }
  printf("\n");
}

static void pso(const char* name, math_MultipleVarFunction& f, double lo, double hi, double step, int np, int it)
{
  math_Vector l(1, 2, lo), h(1, 2, hi), st(1, 2, step), res(1, 2);
  math_PSO    p(&f, l, h, st, np, it);
  double      val;
  p.Perform(st, val, res);
  printf("%s: point= %.17g %.17g minimum=%.17g\n", name, res(1), res(2), val);
}

static void sysroot(const char* name, int kind, double x0, double y0)
{
  Sys         s(kind);
  math_Vector start(1, 2), tol(1, 2, 1e-8);
  start(1) = x0;
  start(2) = y0;
  math_FunctionSetRoot fs(s, tol, 100);
  fs.Perform(s, start);
  if (fs.IsDone())
    printf("%s FunctionSetRoot: done=1 x=%.17g %.17g\n", name, fs.Root()(1), fs.Root()(2));
  else
    printf("%s FunctionSetRoot: done=0\n", name);
  math_NewtonFunctionSetRoot nr(s, tol, 1e-8, 100);
  nr.Perform(s, start);
  if (nr.IsDone())
    printf("%s NewtonFunctionSetRoot: done=1 x=%.17g %.17g\n", name, nr.Root()(1), nr.Root()(2));
  else
    printf("%s NewtonFunctionSetRoot: done=0\n", name);
}

int main()
{
  Bowl   bowl;
  Bowl1D bowl1;
  Rosen  rosen;
  globopt("globalMinBowl", bowl, 2, -10, 10);
  globopt("globalMin1D", bowl1, 1, -5, 5);
  sysroot("solveCircleLine (original start 4, 3)", 0, 4, 3);
  sysroot("solveCircleLine (rewritten start 4.5, 3.5)", 0, 4.5, 3.5);
  sysroot("solveLinearSystem", 1, 0, 0);
  {
    math_Vector start(1, 2, 0.0);
    math_Matrix dirs(1, 2, 1, 2, 0.0);
    dirs(1, 1) = dirs(2, 2) = 1;
    math_Powell pw(bowl, 1e-8, 200);
    pw.Perform(bowl, start, dirs);
    printf("Powell minimizeBowl: done=%d x=%.17g %.17g min=%.17g\n",
           (int)pw.IsDone(),
           pw.Location()(1),
           pw.Location()(2),
           pw.Minimum());
  }
  pso("PSO minimizeBowl", bowl, -10, 10, 0.5, 64, 100);
  pso("PSO minimizeRosenbrock", rosen, -5, 5, 0.1, 128, 200);
  {
    math_Matrix A(1, 3, 1, 2, 0.0);
    A(1, 1) = 1;
    A(2, 2) = 1;
    A(3, 1) = 1;
    A(3, 2) = 1;
    math_SVD    svd(A);
    math_Vector B(1, 3), X(1, 2, 0.0);
    B(1) = 1;
    B(2) = 2;
    B(3) = 4;
    svd.Solve(B, X);
    printf("SVD leastSquares: done=%d x=%.17g %.17g\n", (int)svd.IsDone(), X(1), X(2));
  }
  return 0;
}
