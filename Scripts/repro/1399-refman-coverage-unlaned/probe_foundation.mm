//  probe_foundation.mm: #1399 foundation family, the claims no detector can read.
//
//  Five measurements against the pinned kernel, each backing one row of
//  family-foundation.md. Build and run per CLAUDE.md's "Compile a Ground Truth C++ Test":
//
//    clang++ -std=c++17 -ObjC++ -w \
//      -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//      -L"Libraries/OCCT.xcframework/macos-arm64" \
//      -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//      Scripts/repro/1399-refman-coverage-unlaned/probe_foundation.mm -o /tmp/occt_probe_foundation
//    /tmp/occt_probe_foundation

#include <Bnd_Box.hxx>
#include <Precision.hxx>
#include <Prs3d.hxx>
#include <UnitsMethods.hxx>
#include <NCollection_Array1.hxx>
#include <math_EigenValuesSearcher.hxx>
#include <math_GaussMultipleIntegration.hxx>
#include <math_IntegerVector.hxx>
#include <math_MultipleVarFunction.hxx>
#include <math_Vector.hxx>

#include <cstdio>

// 1. math_GaussMultipleIntegration over n variables.
//
// The brief for this pass said this class was #640's defect, returning IsDone() == true with a
// wrong answer for more than one variable. docs/reference/Document-Transforms.md says the
// opposite: that it "genuinely supports any number of variables" and it is
// math_GaussSetIntegration that does not. One of those is wrong; this settles it.
class Poly : public math_MultipleVarFunction
{
  int myN;

public:
  Poly(int n)
      : myN(n)
  {
  }

  int NbVariables() const override { return myN; }

  // sum of x_i^2 over every variable
  bool Value(const math_Vector& X, double& F) override
  {
    F = 0.0;
    for (int i = 1; i <= myN; i++)
      F += X(i) * X(i);
    return true;
  }
};

static void integrate(int n, double expected)
{
  Poly               f(n);
  math_Vector        lo(1, n, 0.0), up(1, n, 1.0);
  math_IntegerVector ord(1, n);
  ord.Init(10);
  math_GaussMultipleIntegration gmi(f, lo, up, ord);
  printf("  n=%d  IsDone=%s  Value=%.12f  expected=%.12f  %s\n",
         n,
         gmi.IsDone() ? "true" : "false",
         gmi.IsDone() ? gmi.Value() : 0.0,
         expected,
         (gmi.IsDone() && std::abs(gmi.Value() - expected) < 1e-9) ? "MATCH" : "MISMATCH");
}

int main()
{
  printf("=== 1. math_GaussMultipleIntegration, integral of sum(x_i^2) over the unit n-cube ===\n");
  // n=1: 1/3.  n=2: 2/3 (the value docs/reference/Document-Transforms.md's example claims).
  // n=3: 3 * (1/3) = 1.
  integrate(1, 1.0 / 3.0);
  integrate(2, 2.0 / 3.0);
  integrate(3, 1.0);

  printf("\n=== 2. Prs3d::GetDeflection, the scaling docs/reference/Display.md does not name ===\n");
  {
    const double coefficient = 0.001;
    const double maxChordial = 0.0001; // Prs3d_Drawer's own default
    for (double side : {1.0, 10.0, 100.0})
    {
      Bnd_Box box;
      box.Update(0.0, 0.0, 0.0, side, side, side);
      double d = Prs3d::GetDeflection(box, coefficient, maxChordial);
      printf("  box %6.1f cube  diagonal=%9.4f  GetDeflection=%.9f  (coefficient alone would be "
             "%.9f)\n",
             side,
             std::sqrt(3.0) * side,
             d,
             coefficient);
    }
  }

  printf("\n=== 3. math_EigenValuesSearcher, the class docs/ calls `math_EigenVectors` ===\n");
  {
    // Symmetric tridiagonal [[2,-1,0],[-1,2,-1],[0,-1,2]]: eigenvalues 2 - sqrt(2), 2, 2 + sqrt(2).
    NCollection_Array1<double> diag(1, 3), sub(1, 3);
    diag(1) = diag(2) = diag(3) = 2.0;
    sub(1)                      = 0.0; // ignored: the sub-diagonal is read from index 2
    sub(2) = sub(3) = -1.0;
    math_EigenValuesSearcher evs(diag, sub);
    printf("  IsDone=%s\n", evs.IsDone() ? "true" : "false");
    if (evs.IsDone())
      for (int i = 1; i <= 3; i++)
        printf("  lambda(%d) = %.9f\n", i, evs.EigenValue(i));
    printf("  expected  = %.9f, %.9f, %.9f\n", 2.0 - std::sqrt(2.0), 2.0, 2.0 + std::sqrt(2.0));

    // Which end of the sub-diagonal array is ignored? docs/reference/Document-Transforms.md and
    // MathSolver.eigenvalues' own doc comment both say "last unused". The kernel's
    // shiftSubdiagonalElements() moves work(i-1) = work(i) for i in 2..n and then zeroes work(n),
    // so it is the FIRST entry that is discarded. Poison one end at a time and see which moves.
    for (int poison = 1; poison <= 3; poison += 2)
    {
      NCollection_Array1<double> d(1, 3), e(1, 3);
      d(1) = d(2) = d(3) = 2.0;
      e(1)               = 0.0;
      e(2) = e(3) = -1.0;
      e(poison)   = 999.0;
      math_EigenValuesSearcher ev(d, e);
      printf("  poison sub(%d)=999 -> %s", poison, ev.IsDone() ? "" : "NOT DONE");
      if (ev.IsDone())
        for (int i = 1; i <= 3; i++)
          printf(" %.6f", ev.EigenValue(i));
      printf("   %s\n", poison == 1 ? "(docs call this entry USED)" : "(docs call this entry UNUSED)");
    }

    // The example shipped in MathSolver.eigenvalues' doc comment and in
    // docs/reference/Document-Transforms.md: diagonal [2,2,2], subdiagonal [1,1,0]. Under the
    // "last unused" convention those docs state, that is off-diagonals (1, 1) and eigenvalues
    // 2 - sqrt(2), 2, 2 + sqrt(2). Under the real convention it is off-diagonals (1, 0).
    {
      NCollection_Array1<double> d(1, 3), e(1, 3);
      d(1) = d(2) = d(3) = 2.0;
      e(1) = e(2) = 1.0;
      e(3)        = 0.0;
      math_EigenValuesSearcher ev(d, e);
      printf("  shipped doc example diagonal [2,2,2] subdiagonal [1,1,0] ->");
      for (int i = 1; i <= 3; i++)
        printf(" %.9f", ev.EigenValue(i));
      printf("\n  'last unused' would predict %.9f %.9f %.9f\n",
             2.0 - std::sqrt(2.0),
             2.0,
             2.0 + std::sqrt(2.0));
    }
  }

  printf("\n=== 4. Precision::PConfusion(), the constant docs/ calls 'scaled by curve-space "
         "bounds' ===\n");
  printf("  Confusion()   = %.12g\n", Precision::Confusion());
  printf("  PConfusion()  = %.12g   (Confusion / 100, a constant: nothing is passed to it)\n",
         Precision::PConfusion());
  printf("  PConfusion(1) = %.12g   (the overload that DOES take a tangent length)\n",
         Precision::PConfusion(1.0));
  printf("  Intersection()  = %.12g\n", Precision::Intersection());
  printf("  Approximation() = %.12g\n", Precision::Approximation());

  printf("\n=== 5. UnitsMethods::GetLengthFactorValue, 'in millimetres' ===\n");
  for (int code : {1, 2, 4, 6})
    printf("  IGES unit %d -> %.6f\n", code, UnitsMethods::GetLengthFactorValue(code));

  return 0;
}
