// Epic #766 kernel-parity probe: MathSolverFunctionRootsTests, MathSolverFunctionRootTests,
// MathSolverGaussIntegrateTests. Same OCCT calls and inputs as OCCTMathFunctionRoots
// (math_FunctionRoots(f, a, b, nbSample)), OCCTMathFunctionAllRoots (math_FunctionSample +
// math_FunctionAllRoots(f, sample, 1e-8, 1e-8, 1e-8)), OCCTMathFunctionRoot
// (math_FunctionRoot(f, guess, 1e-8, 100)), OCCTMathFunctionRootBounded
// (math_FunctionRoot(f, guess, 1e-8, a, b, 100)), OCCTMathBissecNewton
// (math_BissecNewton(1e-8).Perform(f, a, b, 100)) and OCCTMathGaussIntegrate
// (math_GaussSingleIntegration(f, lower, upper, order)).
#include <math_FunctionRoots.hxx>
#include <math_FunctionAllRoots.hxx>
#include <math_FunctionSample.hxx>
#include <math_FunctionRoot.hxx>
#include <math_BissecNewton.hxx>
#include <math_GaussSingleIntegration.hxx>
#include <math_FunctionWithDerivative.hxx>
#include <math_Function.hxx>
#include <cmath>
#include <cstdio>

struct FD : math_FunctionWithDerivative
{
  int kind; // 0: x^2 - 4, 1: sin, 2: x^3 - 8
  FD(int k)
      : kind(k)
  {
  }
  bool Value(const double x, double& f) override
  {
    double d;
    return Values(x, f, d);
  }
  bool Derivative(const double x, double& d) override
  {
    double f;
    return Values(x, f, d);
  }
  bool Values(const double x, double& f, double& d) override
  {
    if (kind == 0)
    {
      f = x * x - 4;
      d = 2 * x;
    }
    else if (kind == 1)
    {
      f = std::sin(x);
      d = std::cos(x);
    }
    else
    {
      f = x * x * x - 8;
      d = 3 * x * x;
    }
    return true;
  }
};

struct F : math_Function
{
  int kind; // 0: sin, 1: x^2, 2: 1
  F(int k)
      : kind(k)
  {
  }
  bool Value(const double x, double& f) override
  {
    f = kind == 0 ? std::sin(x) : kind == 1 ? x * x : 1.0;
    return true;
  }
};

static void roots(const char* name, int kind, double a, double b, int n)
{
  FD                 f(kind);
  math_FunctionRoots fr(f, a, b, n);
  printf("%s FunctionRoots: done=%d", name, (int)fr.IsDone());
  if (fr.IsDone())
    for (int i = 1; i <= fr.NbSolutions(); i++)
      printf(" %.17g", fr.Value(i));
  printf("\n");
  math_FunctionSample   s(a, b, n);
  math_FunctionAllRoots ar(f, s, 1e-8, 1e-8, 1e-8);
  printf("%s FunctionAllRoots(samples %d): done=%d", name, n, (int)ar.IsDone());
  if (ar.IsDone())
    for (int i = 1; i <= ar.NbPoints(); i++)
      printf(" %.17g", ar.GetPoint(i));
  printf("\n");
}

int main()
{
  roots("findAllRootsQuadratic", 0, -5.0, 5.0, 20);
  roots("findAllRootsSin", 1, -0.5, 6.5, 30);
  {
    FD                f(0);
    math_FunctionRoot r1(f, 3.0, 1e-8, 100);
    printf("findRootNewton(near: 3): done=%d root=%.17g\n", (int)r1.IsDone(), r1.Root());
    math_FunctionRoot r2(f, -3.0, 1e-8, 100);
    printf("findRootNewton(near: -3): done=%d root=%.17g\n", (int)r2.IsDone(), r2.Root());
    math_FunctionRoot r3(f, 3.0, 1e-8, 0.0, 5.0, 100);
    printf("findRootBounded: done=%d root=%.17g\n", (int)r3.IsDone(), r3.Root());
    math_BissecNewton bn(1e-8);
    bn.Perform(f, 0.0, 5.0, 100);
    printf("findRootBisection: done=%d root=%.17g\n", (int)bn.IsDone(), bn.IsDone() ? bn.Root() : NAN);
    FD                c(2);
    math_FunctionRoot r4(c, 3.0, 1e-8, 100);
    printf("findRootCubic: done=%d root=%.17g\n", (int)r4.IsDone(), r4.Root());
  }
  {
    F                           s(0), p(1), k(2);
    math_GaussSingleIntegration g1(s, 0, M_PI, 10);
    printf("integrateSin: done=%d value=%.17g\n", (int)g1.IsDone(), g1.Value());
    math_GaussSingleIntegration g2(p, 0, 1, 5);
    printf("integratePolynomial: done=%d value=%.17g\n", (int)g2.IsDone(), g2.Value());
    math_GaussSingleIntegration g3(k, 0, 5, 3);
    printf("integrateConstant: done=%d value=%.17g\n", (int)g3.IsDone(), g3.Value());
  }
  return 0;
}
