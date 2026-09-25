// Epic #766 kernel-parity probe for PolynomialTests.swift and PrecisionTests.swift.
// Same OCCT calls, same inputs, as occtSolvePolynomial (OCCTSolveQuadratic/Cubic/Quartic)
// and the OCCTPrecision* functions in Sources/OCCTBridge/src/OCCTBridge_Spatial_MathSolvers.mm.
#include <Precision.hxx>
#include <math_DirectPolynomialRoots.hxx>
#include <algorithm>
#include <cstdio>

static void report(const char* name, math_DirectPolynomialRoots& s)
{
  double r[4] = {0, 0, 0, 0};
  int    n    = s.IsDone() ? std::min(s.NbSolutions(), 4) : 0;
  for (int i = 0; i < n; i++)
    r[i] = s.Value(i + 1);
  std::sort(r, r + n);
  printf("%s: done=%d count=%d roots=[", name, s.IsDone(), n);
  for (int i = 0; i < n; i++)
    printf(" %.17g", r[i]);
  printf(" ]\n");
}

int main()
{
  math_DirectPolynomialRoots q1(1, -5, 6);
  report("quadratic", q1);
  math_DirectPolynomialRoots q2(1, 0, 1);
  report("quadraticNoRoots", q2);
  math_DirectPolynomialRoots q3(1, -2, 1);
  report("quadraticOneRoot", q3);
  math_DirectPolynomialRoots c(1, -6, 11, -6);
  report("cubic", c);
  math_DirectPolynomialRoots q4(1, 0, -10, 0, 9);
  report("quartic", q4);

  printf("confusion: %.17g\n", Precision::Confusion());
  printf("angular: %.17g\n", Precision::Angular());
  printf("isInfinite: isInfinite(3e100)=%d isInfinite(1.0)=%d\n",
         Precision::IsInfinite(3e100),
         Precision::IsInfinite(1.0));
  printf("ordering: intersection=%.17g confusion=%.17g approximation=%.17g\n",
         Precision::Intersection(),
         Precision::Confusion(),
         Precision::Approximation());
  printf("infinite: %.17g isInfinite(infinite)=%d\n",
         Precision::Infinite(),
         Precision::IsInfinite(Precision::Infinite()));
  printf("pConfusion: %.17g confusion/100=%.17g\n",
         Precision::PConfusion(),
         Precision::Confusion() / 100.0);
  return 0;
}
