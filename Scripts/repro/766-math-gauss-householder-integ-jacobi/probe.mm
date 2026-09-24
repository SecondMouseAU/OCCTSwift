// Epic #766 kernel-parity probe: MathGaussTests, MathHouseholderTests, MathIntegRc4Tests,
// MathJacobiTests. Same OCCT calls and inputs as OCCTMathGaussSolve / OCCTMathGaussDeterminant
// (math_Gauss), OCCTMathHouseholderSolve (math_Householder, Value(sol, 1)), OCCTMathInteg*
// (MathInteg::Gauss / GaussAdaptive / KronrodRule / Kronrod / TanhSinh) and
// OCCTMathJacobiEigenvalues (math_Jacobi).
#include <math_Gauss.hxx>
#include <math_Householder.hxx>
#include <math_Jacobi.hxx>
#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <MathInteg_Gauss.hxx>
#include <MathInteg_Kronrod.hxx>
#include <MathInteg_DoubleExp.hxx>
#include <cmath>
#include <cstdio>

namespace
{
struct SinF
{
  bool Value(double x, double& f)
  {
    f = std::sin(x);
    return true;
  }
};
} // namespace

int main()
{
  {
    math_Matrix A(1, 2, 1, 2, 0.0);
    A(1, 1) = 2; A(1, 2) = 1; A(2, 1) = 1; A(2, 2) = 3;
    math_Gauss g(A);
    math_Vector B(1, 2, 0.0), X(1, 2, 0.0);
    B(1) = 5; B(2) = 7;
    g.Solve(B, X);
    printf("solve2x2: done=%d x=%.17g %.17g\n", (int)g.IsDone(), X(1), X(2));
    printf("determinant (Gauss): %.17g\n", g.Determinant());
  }
  {
    math_Matrix A(1, 3, 1, 2, 0.0);
    A(1, 1) = 1; A(1, 2) = 0; A(2, 1) = 0; A(2, 2) = 1; A(3, 1) = 1; A(3, 2) = 1;
    math_Vector B(1, 3, 0.0);
    B(1) = 1; B(2) = 2; B(3) = 4;
    math_Householder hh(A, B);
    math_Vector sol(1, 2, 0.0);
    if (hh.IsDone())
      hh.Value(sol, 1);
    printf("overdetermindedSolve: done=%d x=%.17g %.17g\n", (int)hh.IsDone(), sol(1), sol(2));
  }
  {
    SinF f;
    auto r1 = MathInteg::Gauss(f, 0.0, M_PI, 15);
    printf("gauss: done=%d value=%.17g\n", (int)r1.IsDone(), r1.Value ? *r1.Value : NAN);
    MathUtils::IntegConfig c;
    c.Tolerance     = 1e-10;
    c.MaxIterations = 100;
    auto r2         = MathInteg::GaussAdaptive(f, 0.0, M_PI, c);
    printf("gaussAdaptive: done=%d value=%.17g\n", (int)r2.IsDone(), r2.Value ? *r2.Value : NAN);
    auto r3 = MathInteg::KronrodRule(f, 0.0, M_PI, 7);
    printf("kronrod: done=%d value=%.17g\n", (int)r3.IsDone(), r3.Value ? *r3.Value : NAN);
    MathInteg::KronrodConfig kc;
    kc.NbGaussPoints = 7;
    kc.Tolerance     = 1e-10;
    kc.MaxIterations = 100;
    kc.Adaptive      = true;
    auto r4          = MathInteg::Kronrod(f, 0.0, M_PI, kc);
    printf("kronrodAdaptive: done=%d value=%.17g\n", (int)r4.IsDone(), r4.Value ? *r4.Value : NAN);
    MathInteg::DoubleExpConfig dc;
    dc.Tolerance = 1e-8;
    dc.NbLevels  = 6;
    auto r5      = MathInteg::TanhSinh(f, 0.0, M_PI, dc);
    printf("tanhSinh: done=%d value=%.17g\n", (int)r5.IsDone(), r5.Value ? *r5.Value : NAN);
  }
  {
    math_Matrix A(1, 2, 1, 2, 0.0);
    A(1, 1) = 2; A(1, 2) = 1; A(2, 1) = 1; A(2, 2) = 2;
    math_Jacobi j(A);
    printf("eigenvalues (Jacobi): done=%d %.17g %.17g\n", (int)j.IsDone(), j.Value(1), j.Value(2));
  }
  return 0;
}
