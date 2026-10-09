// Epic #766 kernel-parity probe: MathMatrixTests, MathPolynomialRootsTests.
// Same OCCT calls and inputs as OCCTMathMatrixCreate/Rows/Cols/GetValue/SetValue/Determinant/
// Invert (math_Matrix) and OCCTMathPolynomialRoots (math_DirectPolynomialRoots).
#include <math_Matrix.hxx>
#include <math_DirectPolynomialRoots.hxx>
#include <cstdio>

static void roots(const char* name, math_DirectPolynomialRoots& r)
{
  printf("%s: done=%d n=%d", name, (int)r.IsDone(), r.IsDone() ? r.NbSolutions() : -1);
  if (r.IsDone())
    for (int i = 1; i <= r.NbSolutions(); i++)
      printf(" %.17g", r.Value(i));
  printf("\n");
}

int main()
{
  {
    math_Matrix m(1, 3, 1, 3, 0.0);
    printf("createAndQuery: rows=%d cols=%d\n", m.RowNumber(), m.ColNumber());
  }
  {
    math_Matrix m(1, 2, 1, 2, 0.0);
    m(1, 1) = 5.0;
    printf("setGetValue: (1,1)=%.17g (2,1)=%.17g\n", m(1, 1), m(2, 1));
  }
  {
    math_Matrix m(1, 2, 1, 2, 0.0);
    m(1, 1) = 1;
    m(1, 2) = 2;
    m(2, 1) = 3;
    m(2, 2) = 4;
    printf("determinant: %.17g\n", m.Determinant());
    m.Invert();
    printf("invert: %.17g %.17g %.17g %.17g\n", m(1, 1), m(1, 2), m(2, 1), m(2, 2));
  }
  {
    math_DirectPolynomialRoots q(1.0, -5.0, 6.0);
    roots("quadratic", q);
    math_DirectPolynomialRoots l(2.0, 4.0);
    roots("linear", l);
    math_DirectPolynomialRoots n(1.0, 0.0, 1.0);
    roots("noRealRoots", n);
  }
  return 0;
}
