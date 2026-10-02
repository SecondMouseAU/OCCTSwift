// Probe for OCCTSwift #2860, carried OCCT patch 0046.
//
// math_Uzawa sizes Errinit by Cont.ColNumber() and writes it by row, so an overdetermined system
// writes past the end. Takes a mode on argv[1] so each size runs in its own process; the large
// ones fault unpatched.
//
// Build and run: Scripts/repro/2860-uzawa-errinit-dimension/run.sh

#include <math_Matrix.hxx>
#include <math_Uzawa.hxx>
#include <math_Vector.hxx>

#include <cstdio>
#include <cstring>

// Builds a consistent least-squares-shaped system of theRows constraints in theCols unknowns.
static int run(const int theRows, const int theCols)
{
  math_Matrix aCont(1, theRows, 1, theCols);
  math_Vector aSecont(1, theRows);
  math_Vector aStart(1, theCols);
  for (int i = 1; i <= theRows; ++i)
  {
    for (int j = 1; j <= theCols; ++j)
    {
      aCont(i, j) = (i == j) ? 1.0 : 0.25;
    }
    aSecont(i) = 1.0;
  }
  for (int j = 1; j <= theCols; ++j)
  {
    aStart(j) = 0.0;
  }

  math_Uzawa aSolver(aCont, aSecont, aStart, 1.0e-6, 1.0e-6, 500);
  std::printf("rows=%d cols=%d IsDone=%d", theRows, theCols, aSolver.IsDone() ? 1 : 0);
  if (aSolver.IsDone())
  {
    std::printf(" InitialError().Length()=%d", aSolver.InitialError().Length());
    std::printf(" expected=%d", theRows);
    std::printf(" Value(1)=%g", aSolver.Value()(1));
  }
  std::printf("\n");
  if (!aSolver.IsDone())
  {
    return 0;
  }
  return aSolver.InitialError().Length() == theRows ? 0 : 1;
}

int main(int argc, char** argv)
{
  const char* aMode = argc > 1 ? argv[1] : "square";
  if (std::strcmp(aMode, "square") == 0)
  {
    return run(2, 2); // the shape every existing test uses
  }
  if (std::strcmp(aMode, "small-over") == 0)
  {
    return run(4, 2); // below the 32-double inline buffer: silent, wrong, testable
  }
  if (std::strcmp(aMode, "edge-over") == 0)
  {
    return run(33, 32); // one slot past the inline buffer
  }
  if (std::strcmp(aMode, "heap-over") == 0)
  {
    return run(40, 33); // seven past a heap block
  }
  if (std::strcmp(aMode, "far-over") == 0)
  {
    return run(100, 2); // deterministic SIGSEGV unpatched
  }
  std::fprintf(stderr, "unknown mode %s\n", aMode);
  return 2;
}
