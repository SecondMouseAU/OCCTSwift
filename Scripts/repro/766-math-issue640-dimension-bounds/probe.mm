// Epic #766 kernel-parity probe for Tests/OCCTMathTests/Issue640MathDimensionBoundsTests.swift.
// Almost every expectation in that file is a Swift-side argument guard with no kernel
// counterpart (recorded N/A). This probe covers the control computations the guards let
// through: the determinants via math_Gauss / math_Crout (as OCCTMathGaussDeterminant and
// OCCTMathCroutDeterminant build them), including the singular fixture the
// "distinguishes an invalid dimension from a genuinely singular matrix" tests pin at .some(0.0).
#include <math_Crout.hxx>
#include <math_Gauss.hxx>
#include <math_Matrix.hxx>
#include <cstdio>

static math_Matrix mat(const double* d, int n)
{
  math_Matrix A(1, n, 1, n, 0.0);
  for (int i = 0; i < n; i++)
    for (int j = 0; j < n; j++)
      A(i + 1, j + 1) = d[i * n + j];
  return A;
}

static void gauss(const char* name, const double* d, int n)
{
  math_Gauss g(mat(d, n));
  printf("%s: math_Gauss IsDone=%d", name, g.IsDone() ? 1 : 0);
  if (g.IsDone())
    printf(" Determinant=%.17g", g.Determinant());
  printf("\n");
}

static void crout(const char* name, const double* d, int n)
{
  math_Crout c(mat(d, n));
  printf("%s: math_Crout IsDone=%d", name, c.IsDone() ? 1 : 0);
  if (c.IsDone())
    printf(" Determinant=%.17g", c.Determinant());
  printf("\n");
}

int main()
{
  const double g2[4]   = {2, 1, 1, 3};
  const double c2[4]   = {4, 2, 2, 3};
  const double sing[4] = {1, 2, 2, 4};
  gauss("gaussDeterminantBounds control", g2, 2);
  gauss("gaussDeterminantSentinelDistinguishability singular", sing, 2);
  crout("croutDeterminantBounds control", c2, 2);
  crout("croutDeterminantSentinelDistinguishability singular", sing, 2);
  return 0;
}
