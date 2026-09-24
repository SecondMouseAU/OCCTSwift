// Epic #766 kernel-parity probe for Tests/OCCTMathTests/Issue1643EigenvalueOffDiagonalTests.swift.
// Same math_EigenValuesSearcher call as OCCTMathEigenValues / OCCTMathEigenValuesAndVectors:
// subdiag(1) is the dead slot (set to 0), the caller's n - 1 entries go in 2..n. Also prints the
// pre-#1643 convention (entries in 1..n-1, so the first is discarded) for the record.
#include <NCollection_Array1.hxx>
#include <math_EigenValuesSearcher.hxx>
#include <math_Vector.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void run(const char* name, const std::vector<double>& d, const std::vector<double>& off, bool oldConvention)
{
  int                        n = (int)d.size();
  NCollection_Array1<double> diag(1, n), sub(1, n);
  for (int i = 0; i < n; i++)
    diag(i + 1) = d[i];
  sub(1) = 0.0;
  for (int i = 1; i < n; i++)
    sub(i + 1) = off[i - 1];
  if (oldConvention)
  {
    // The caller's array landed in slots 1..n-1 and slot 1 was discarded.
    for (int i = 0; i < n; i++)
      sub(i + 1) = i < (int)off.size() ? off[i] : 0.0;
  }
  math_EigenValuesSearcher evs(diag, sub);
  printf("%s%s: done=%d dim=%d values:", name, oldConvention ? " [old convention]" : "",
         evs.IsDone() ? 1 : 0, evs.IsDone() ? evs.Dimension() : 0);
  if (!evs.IsDone())
  {
    printf("\n");
    return;
  }
  double maxResidual = 0, maxNormErr = 0;
  for (int k = 1; k <= evs.Dimension(); k++)
  {
    double lambda = evs.EigenValue(k);
    printf(" %.17g", lambda);
    math_Vector v = evs.EigenVector(k);
    double      nrm = 0;
    for (int i = 1; i <= n; i++)
      nrm += v(i) * v(i);
    maxNormErr = std::max(maxNormErr, std::fabs(std::sqrt(nrm) - 1));
    for (int i = 0; i < n; i++)
    {
      double av = d[i] * v(i + 1);
      if (i > 0)
        av += off[i - 1] * v(i);
      if (i < n - 1)
        av += off[i] * v(i + 2);
      maxResidual = std::max(maxResidual, std::fabs(av - lambda * v(i + 1)));
    }
  }
  printf("  max|Av - lambda v|=%.3g max||v|-1|=%.3g\n", maxResidual, maxNormErr);
}

int main()
{
  run("constantDiagonalSpectrum", {2, 2, 2}, {1, 1}, false);
  run("constantDiagonalSpectrum", {2, 2, 2}, {1, 1}, true);
  run("asymmetricDiagonalSpectrum / eigenvectorsSolveTheIntendedMatrix", {1, 2, 3}, {1, 2}, false);
  run("asymmetricDiagonalSpectrum reversed offDiagonal", {1, 2, 3}, {2, 1}, false);
  run("oneByOne", {5}, {}, false);
  return 0;
}
