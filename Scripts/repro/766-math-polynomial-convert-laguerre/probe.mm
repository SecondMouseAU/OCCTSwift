// Epic #766 kernel-parity probe for PolynomialConvertTests.swift and
// PolynomialSolverLaguerreTests.swift. Same OCCT calls, same inputs, as
// OCCTConvertPolynomialToPoles, OCCTPolyLaguerreRoots, OCCTPolyLaguerreComplexRoots
// and OCCTPolyQuinticRoots (Sources/OCCTBridge/src/OCCTBridge_Spatial_MathSolvers.mm).
#include <Convert_CompPolynomialToPoles.hxx>
#include <MathPoly_Laguerre.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <cstdio>
#include <vector>

static void convert(const char* name, int dim, int maxDeg, int deg, std::vector<double> c,
                    double p0, double p1, double t0, double t1)
{
  NCollection_Array1<double> coeff(1, (int)c.size());
  for (size_t i = 0; i < c.size(); i++)
    coeff((int)i + 1) = c[i];
  NCollection_Array1<double> pi(1, 2);
  pi(1) = p0;
  pi(2) = p1;
  NCollection_Array1<double> ti(1, 2);
  ti(1) = t0;
  ti(2) = t1;
  Convert_CompPolynomialToPoles conv(dim, maxDeg, deg, coeff, pi, ti);
  printf("%s: done=%d degree=%d nbPoles=%d poles=[", name, conv.IsDone(), conv.Degree(),
         conv.NbPoles());
  const NCollection_Array2<double>& P = conv.Poles();
  for (int i = P.LowerRow(); i <= P.UpperRow(); i++)
    for (int j = P.LowerCol(); j <= P.UpperCol(); j++)
      printf(" %.17g", P(i, j));
  printf(" ] knots=[");
  const NCollection_Array1<double>& K = conv.Knots();
  for (int i = K.Lower(); i <= K.Upper(); i++)
    printf(" %.17g", K(i));
  printf(" ]\n");
}

static void laguerre(const char* name, std::vector<double> c)
{
  auto r = MathPoly::Laguerre(c.data(), (int)c.size() - 1);
  printf("%s: done=%d nbRoots=%d roots=[", name, r.IsDone(), (int)r.NbRoots);
  for (size_t i = 0; i < r.NbRoots; i++)
    printf(" %.17g", r.Roots[i]);
  printf(" ] nbComplex=%d complex=[", (int)r.NbComplexRoots);
  for (size_t i = 0; i < r.NbComplexRoots; i++)
    printf(" (%.17g, %.17g)", r.ComplexRoots[i].real(), r.ComplexRoots[i].imag());
  printf(" ]\n");
}

int main()
{
  convert("linearPolynomial", 1, 1, 1, {1.0, 2.0}, 0, 1, 0, 1);
  convert("quadraticPolynomial", 1, 2, 2, {1.0, 1.0, 1.0}, 0, 1, 0, 1);
  convert("remappedInterval", 1, 1, 1, {0.0, 1.0}, 0, 1, -1, 1);

  laguerre("quadraticRoots", {6.0, -5.0, 1.0});
  laguerre("cubicRoots", {-6.0, 11.0, -6.0, 1.0});
  laguerre("complexRoots", {1.0, 0.0, 1.0});
  auto q = MathPoly::Quintic(1, -15, 85, -225, 274, -120);
  printf("quinticRoots: done=%d nbRoots=%d roots=[", q.IsDone(), (int)q.NbRoots);
  for (size_t i = 0; i < q.NbRoots; i++)
    printf(" %.17g", q.Roots[i]);
  printf(" ]\n");
  return 0;
}
